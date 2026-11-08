import Foundation
import Observation
import TodoCore

/// Stan aplikacji: tożsamość, lokalne zadania, przypomnienia i synchronizacja z wyświetlaczem.
/// Na pierwszym planie aplikacja stale obserwuje zasięg BLE i synchronizuje się sama
/// według `AutoSyncPolicy`; przycisk „Synchronizuj” omija politykę.
@MainActor
@Observable
final class AppModel {
    private(set) var identity: Identity?
    /// Wspólny klucz rodziny z Keychain; bez niego aplikacja działa jako lokalna lista, bez synchronizacji.
    private(set) var familyKey: Data?
    /// Zadania do zrobienia (lista główna).
    private(set) var tasks: [TodoTask] = []
    /// Wykonane zadania z czasem wykonania, od najnowszego.
    private(set) var history: [HistoryEntry] = []
    /// Zadania z notatką (tylko w tym telefonie) — do ikony na liście i w historii.
    private(set) var notedIDs: Set<String> = []
    private(set) var isBusy = false
    private(set) var pendingCount = 0
    var message: String?

    private var repository: TaskRepository?
    private var reminders: ReminderScheduler?
    private let notifications = UserNotificationScheduler()
    private let link = BLEDeviceLink()
    private var policy = AutoSyncPolicy()
    private var lastLocalChange: Date?
    private var isActive = false
    private var scheduled: Task<Void, Never>?
    /// Tryb demonstracyjny (zrzuty ekranu): dane przykładowe w pamięci, bez BLE i powiadomień.
    let isDemo: Bool

    /// Po nieudanej decyzji „nie teraz” skanujemy ponownie po tym czasie.
    private static let idleRescan: Duration = .seconds(15)

    init() {
        isDemo = false
        familyKey = FamilyKeyStore.load()
        if let identity = IdentityStore.load() {
            open(identity)
        }
    }

    /// Model z gotowymi danymi, bez Keychain, BLE i powiadomień (zrzuty ekranu, podglądy).
    init(demoIdentity: Identity, familyKey: Data?, repository: TaskRepository, needsSetup: Bool = false) {
        isDemo = true
        identity = needsSetup ? nil : demoIdentity
        self.familyKey = familyKey
        self.repository = repository
        tasks = repository.activeTasks
        history = repository.history
        notedIDs = Self.notedIDs(in: repository)
    }

    // MARK: - Konfiguracja

    /// Pierwsze uruchomienie: imię i opcjonalnie klucz rodziny (można go dodać później w ustawieniach).
    func setUp(displayName: String, keyText: String) {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return message = String(localized: "Podaj imię.") }
        guard name.utf8.count <= Self.maxNameBytes else { return message = String(localized: "Imię jest za długie.") }
        if !keyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard setFamilyKey(keyText) else { return }
        }
        message = nil
        open(IdentityStore.create(displayName: name))
        startDiscoveryIfPossible()
        Task { await requestNotifications() }
    }

    // MARK: - Klucz rodziny

    /// Zapisuje klucz wpisany ręcznie lub wklejony (hex albo link). Fałsz i komunikat, gdy tekst nie jest kluczem.
    @discardableResult
    func setFamilyKey(_ text: String) -> Bool {
        guard let key = FamilyKeyCode.parse(text) else {
            message = String(localized: "To nie jest klucz rodziny (64 znaki 0–9, a–f albo link familytodo://).")
            return false
        }
        return store(key)
    }

    /// Link `familytodo://key?k=…` otwarty z kodu QR aparatem iPhone'a.
    func handle(url: URL) {
        guard let key = FamilyKeyCode.key(from: url) else {
            message = String(localized: "Ten link nie zawiera klucza rodziny.")
            return
        }
        if store(key) { message = String(localized: "Zapisano klucz rodziny.") }
    }

    func removeFamilyKey() {
        if !isDemo { FamilyKeyStore.delete() }
        familyKey = nil
        scheduled?.cancel()
        link.stopDiscovery()
    }

    private func store(_ key: Data) -> Bool {
        guard isDemo || FamilyKeyStore.save(key) else {
            message = String(localized: "Nie udało się zapisać klucza w pęku kluczy.")
            return false
        }
        familyKey = key
        policy = AutoSyncPolicy()
        startDiscoveryIfPossible()
        return true
    }

    private func startDiscoveryIfPossible() {
        guard isActive, !isDemo, identity != nil, familyKey != nil else { return }
        link.startDiscovery { [weak self] in self?.deviceSeen() }
    }

    /// Wywoływane przy zmianie `scenePhase`: obserwujemy zasięg tylko na pierwszym planie.
    func setActive(_ active: Bool) {
        isActive = active
        guard identity != nil, !isDemo else { return }
        if active {
            startDiscoveryIfPossible()
        } else {
            scheduled?.cancel()
            link.stopDiscovery()
        }
    }

    // MARK: - Zadania

    func create(title: String, note: String, priority: Priority, dueAt: Date?, reminderAt: Date?) -> Bool {
        perform { try $0.create(title: title, note: note, priority: priority, dueAt: dueAt, reminderAt: reminderAt) }
    }

    /// Zapis formularza: tylko pola edytowane, status i usunięcie zostają z bieżącej wersji.
    /// Notatka jest zapisywana najpierw, bo za długa nie powinna zostawić zapisanych pozostałych pól.
    /// Gdy zmieniła się tylko notatka, zadanie nie dostaje nowej wersji i nie jest synchronizowane
    /// (notatka zostaje w telefonie).
    func save(_ draft: TaskDraft, note: String, for id: String) -> Bool {
        if let current = repository?.task(id: id), TaskDraft(current) == Self.normalized(draft) {
            return perform(syncs: false) { try $0.setNote(id: id, note) }
        }
        return perform {
            try $0.setNote(id: id, note)
            try $0.update(id: id) { draft.apply(to: &$0) }
        }
    }

    /// Tytuł tak, jak zapisuje go repozytorium (bez białych znaków na brzegach), żeby porównanie
    /// z bieżącą wersją nie uznało samych spacji za zmianę.
    private static func normalized(_ draft: TaskDraft) -> TaskDraft {
        var draft = draft
        draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return draft
    }

    /// Notatka zadania z tego telefonu ("" gdy brak).
    func note(for task: TodoTask) -> String {
        repository?.note(id: task.id) ?? ""
    }

    func hasNote(_ task: TodoTask) -> Bool {
        notedIDs.contains(task.id)
    }

    func complete(_ task: TodoTask) {
        _ = perform { try $0.complete(id: task.id) }
    }

    func reopen(_ task: TodoTask) {
        _ = perform { try $0.update(id: task.id) { $0.status = .active } }
    }

    func delete(_ task: TodoTask) {
        _ = perform { try $0.delete(id: task.id) }
    }

    func isMine(_ task: TodoTask) -> Bool {
        task.ownerId == identity?.userId
    }

    // MARK: - Synchronizacja

    /// Ręczna synchronizacja (przycisk): bez czekania na politykę.
    func syncNow() async {
        guard familyKey != nil else {
            return message = String(localized: "Dodaj klucz rodziny w ustawieniach, żeby synchronizować z wyświetlaczem.")
        }
        scheduled?.cancel()
        await runSync()
    }

    private func deviceSeen() {
        guard isActive, !isBusy else { return }
        let now = Date()
        scheduled?.cancel()
        guard let fire = policy.fireDate(deviceSeenAt: now, lastLocalChange: lastLocalChange) else {
            scheduled = Task { [weak self] in
                try? await Task.sleep(for: Self.idleRescan)  // anulowanie = nowe zdarzenie przejęło harmonogram
                guard !Task.isCancelled else { return }
                self?.link.rescan()
            }
            return
        }
        scheduled = Task { [weak self] in
            let delay = fire.timeIntervalSince(now)
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard !Task.isCancelled, let self else { return }
            await self.runSync()
        }
    }

    private func runSync() async {
        guard let identity, let repository, let familyKey, !isDemo, !isBusy else { return }
        isBusy = true
        // Czas startu, nie końca: zmiana zrobiona w trakcie sesji ma być nowsza od sukcesu
        // i dostać własną synchronizację po 2 s (AutoSyncPolicy.debounce).
        let started = Date()
        let engine = SyncEngine(
            repository: repository, link: link,
            credentials: Credentials(userId: identity.userId, displayName: identity.displayName, secret: familyKey))
        do {
            let report = try await engine.sync()
            policy.recordSuccess(at: started)
            if !report.rejectedIDs.isEmpty {
                message = String(localized: "Wyświetlacz odrzucił \(report.rejectedIDs.count) zadań (pełna pamięć lub błędne dane).")
            } else if let error = repository.lastSaveError {
                message = String(localized: "Nie udało się zapisać danych: \(error.localizedDescription)")
            } else {
                message = nil
            }
        } catch {
            policy.recordFailure(at: Date())
            message = Self.describe(error)
        }
        isBusy = false
        await refresh()
        link.rescan()  // zmiany zrobione w trakcie i kolejne odświeżenia złapie następne wykrycie
    }

    // MARK: - Prywatne

    private static let maxNameBytes = 32  // kMaxNameBytes w firmware

    private func open(_ identity: Identity) {
        self.identity = identity
        do {
            repository = try TaskRepository(userId: identity.userId, storage: FileTaskStorage(url: Self.storageURL()))
        } catch {
            message = String(localized: "Nie udało się wczytać zadań: \(error.localizedDescription)")
        }
        reminders = ReminderScheduler(center: notifications, userId: identity.userId)
        Task { await refresh() }
    }

    /// `syncs: false` — zmiana tylko lokalna (notatka): bez znacznika zmiany i ponownego skanowania.
    private func perform(syncs: Bool = true, _ change: (TaskRepository) throws -> Void) -> Bool {
        guard let repository else { return false }
        do {
            try change(repository)
        } catch {
            message = Self.describe(error)
            notedIDs = Self.notedIDs(in: repository)  // część zmian (np. notatka) mogła się już zapisać
            return false
        }
        if syncs {
            lastLocalChange = Date()
            link.rescan()  // urządzenie w zasięgu zostanie zgłoszone ponownie i dostanie zmianę
        }
        Task { await refresh() }
        return true
    }

    private func refresh() async {
        guard let repository else { return }
        tasks = repository.activeTasks
        history = repository.history
        notedIDs = Self.notedIDs(in: repository)
        pendingCount = repository.pendingIDs.count
        await reminders?.reconcile(repository.allTasks)
        if reminders?.lastError != nil {
            message = String(localized: "Nie udało się zaplanować przypomnienia. Sprawdź zgodę na powiadomienia.")
        }
    }

    private func requestNotifications() async {
        do {
            _ = try await notifications.requestAuthorization()
        } catch {
            message = String(localized: "Brak zgody na powiadomienia: \(error.localizedDescription)")
        }
    }

    private static func notedIDs(in repository: TaskRepository) -> Set<String> {
        Set(repository.allTasks.lazy.map(\.id).filter { !repository.note(id: $0).isEmpty })
    }

    private static func storageURL() -> URL {
        URL.applicationSupportDirectory.appending(path: "tasks.json")
    }

    private static func describe(_ error: Error) -> String {
        switch error {
        case TaskValidationError.emptyTitle: return String(localized: "Tytuł nie może być pusty.")
        case TaskValidationError.titleTooLong: return String(localized: "Tytuł jest za długi (maks. \(TaskLimits.maxTitleBytes) bajtów).")
        case TaskValidationError.noteTooLong: return String(localized: "Notatka jest za długa (maks. \(TaskLimits.maxNoteBytes) bajtów).")
        case TaskValidationError.notFound: return String(localized: "Nie znaleziono zadania.")
        case SyncError.unauthorized: return String(localized: "Wyświetlacz ma inny klucz rodziny niż ta aplikacja.")
        case SyncError.device("bad_frame"): return String(localized: "Zakłócona transmisja. Synchronizacja zostanie ponowiona.")
        case let SyncError.device(code): return String(localized: "Błąd wyświetlacza: \(code).")
        case SyncError.malformedResponse: return String(localized: "Niezrozumiała odpowiedź wyświetlacza.")
        case let SyncError.transport(reason): return String(localized: "Brak połączenia z wyświetlaczem (\(reason)).")
        default: return error.localizedDescription
        }
    }
}
