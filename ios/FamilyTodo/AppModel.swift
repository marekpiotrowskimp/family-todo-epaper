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
    private(set) var tasks: [TodoTask] = []
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

    /// Po nieudanej decyzji „nie teraz” skanujemy ponownie po tym czasie.
    private static let idleRescan: Duration = .seconds(15)

    init() {
        if let identity = IdentityStore.load() {
            open(identity)
        }
    }

    // MARK: - Konfiguracja

    func setUp(displayName: String) {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return message = "Podaj imię." }
        guard name.utf8.count <= Self.maxNameBytes else { return message = "Imię jest za długie." }
        open(IdentityStore.create(displayName: name))
        if isActive { link.startDiscovery { [weak self] in self?.deviceSeen() } }
        Task { await requestNotifications() }
    }

    /// Wywoływane przy zmianie `scenePhase`: obserwujemy zasięg tylko na pierwszym planie.
    func setActive(_ active: Bool) {
        isActive = active
        guard identity != nil else { return }
        if active {
            link.startDiscovery { [weak self] in self?.deviceSeen() }
        } else {
            scheduled?.cancel()
            link.stopDiscovery()
        }
    }

    // MARK: - Zadania

    func create(title: String, priority: Priority, dueAt: Date?, reminderAt: Date?) -> Bool {
        perform { try $0.create(title: title, priority: priority, dueAt: dueAt, reminderAt: reminderAt) }
    }

    /// Zapis formularza: tylko pola edytowane, status i usunięcie zostają z bieżącej wersji.
    func save(_ draft: TaskDraft, for id: String) -> Bool {
        perform { try $0.update(id: id) { draft.apply(to: &$0) } }
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
        guard let identity, let repository, !isBusy else { return }
        isBusy = true
        // Czas startu, nie końca: zmiana zrobiona w trakcie sesji ma być nowsza od sukcesu
        // i dostać własną synchronizację po 2 s (AutoSyncPolicy.debounce).
        let started = Date()
        let engine = SyncEngine(
            repository: repository, link: link,
            credentials: Credentials(userId: identity.userId, displayName: identity.displayName, secret: FamilyKey.secret))
        do {
            let report = try await engine.sync()
            policy.recordSuccess(at: started)
            if !report.rejectedIDs.isEmpty {
                message = "Wyświetlacz odrzucił \(report.rejectedIDs.count) zadań (pełna pamięć lub błędne dane)."
            } else if let error = repository.lastSaveError {
                message = "Nie udało się zapisać danych: \(error.localizedDescription)"
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
            message = "Nie udało się wczytać zadań: \(error.localizedDescription)"
        }
        reminders = ReminderScheduler(center: notifications, userId: identity.userId)
        Task { await refresh() }
    }

    private func perform(_ change: (TaskRepository) throws -> Void) -> Bool {
        guard let repository else { return false }
        do {
            try change(repository)
        } catch {
            message = Self.describe(error)
            return false
        }
        lastLocalChange = Date()
        link.rescan()  // urządzenie w zasięgu zostanie zgłoszone ponownie i dostanie zmianę
        Task { await refresh() }
        return true
    }

    private func refresh() async {
        guard let repository else { return }
        tasks = repository.visibleTasks
        pendingCount = repository.pendingIDs.count
        await reminders?.reconcile(repository.allTasks)
        if reminders?.lastError != nil {
            message = "Nie udało się zaplanować przypomnienia. Sprawdź zgodę na powiadomienia."
        }
    }

    private func requestNotifications() async {
        do {
            _ = try await notifications.requestAuthorization()
        } catch {
            message = "Brak zgody na powiadomienia: \(error.localizedDescription)"
        }
    }

    private static func storageURL() -> URL {
        URL.applicationSupportDirectory.appending(path: "tasks.json")
    }

    private static func describe(_ error: Error) -> String {
        switch error {
        case TaskValidationError.emptyTitle: return "Tytuł nie może być pusty."
        case TaskValidationError.titleTooLong: return "Tytuł jest za długi (maks. \(TaskLimits.maxTitleBytes) bajtów)."
        case TaskValidationError.notFound: return "Nie znaleziono zadania."
        case SyncError.unauthorized: return "Wyświetlacz ma inny klucz rodziny niż ta aplikacja."
        case SyncError.device("bad_frame"): return "Zakłócona transmisja. Synchronizacja zostanie ponowiona."
        case let SyncError.device(code): return "Błąd wyświetlacza: \(code)."
        case SyncError.malformedResponse: return "Niezrozumiała odpowiedź wyświetlacza."
        case let SyncError.transport(reason): return "Brak połączenia z wyświetlaczem (\(reason))."
        default: return error.localizedDescription
        }
    }
}
