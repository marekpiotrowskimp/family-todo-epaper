# Rodzinna lista zadań na e-paper

Wspólny wyświetlacz e-paper 4,2" z zadaniami domowymi całej rodziny. Każdy domownik prowadzi swoje zadania w aplikacji iOS (priorytet, termin, przypomnienie). Telefony synchronizują je przez **BLE** z urządzeniem ESP32-S3, które przechowuje listę, scala zmiany z wielu telefonów i samo wybiera, co pokazać. Urządzenie nie korzysta z Wi-Fi, więc można je przenieść w dowolne miejsce w domu bez żadnej konfiguracji.

Wymagania: [`specyfikacja_systemu_todo.md`](specyfikacja_systemu_todo.md). Integracja z ChatGPT nie jest jeszcze częścią projektu (czeka na weryfikację mechanizmu).

---

## 1. Funkcje

| Gdzie | Co |
|---|---|
| iOS | dodawanie, edycja, ukończenie i usuwanie zadań; priorytet (wysoki/normalny/niski), termin, przypomnienie |
| iOS | lokalne przypomnienia o ustawionej porze, także bez połączenia z wyświetlaczem (tylko na telefonie właściciela zadania) |
| iOS ↔ ESP32 | bez parowania: otwarta aplikacja sama wykrywa wyświetlacz w zasięgu BLE i synchronizuje się (krótkie połączenie, wysłanie zmian, pobranie cudzych, rozłączenie); przycisk „Synchronizuj” wymusza to od razu |
| ESP32 | trwała lista zadań (LittleFS), odporna na restart; scalanie zmian z wielu telefonów (LWW) |
| e-paper | do 9 zadań, bez nagłówka: priorytet ↓, termin ↑; **każda osoba z aktywnym zadaniem ma co najmniej jeden wiersz**; przy więcej niż 9 osobach strony zmieniają się co 5 min |
| dostęp | tylko aplikacja ze wspólnym **kluczem rodziny** (HMAC-SHA256 z nonce sesji) może czytać i zmieniać zadania; łącze BLE nie jest szyfrowane, więc iOS nie pokazuje dialogu parowania |

---

## 2. Sprzęt

| Element | Model | Uwagi |
|---|---|---|
| Mikrokontroler | **Seeed Studio XIAO ESP32-S3** | 240 MHz, dual-core, 8 MB flash, BLE 5, USB-C |
| Antena | zewnętrzna antena 2.4 GHz (U.FL) | podłączona do złącza na XIAO |
| Sterownik ekranu | **Seeed ePaper Driver Board for XIAO** | złącze FPC 24-pin, wyprowadzenia `3V3 GND DAT SCL CS DC RES BUSY` |
| Wyświetlacz | **DKE DEPG0420BNS19AF**, 4,2" | 400×300 px, czarno-biały, kontroler SSD1683 (lub zgodny); tylko pełne odświeżanie, patrz sekcja 6 |
| Zasilanie | kabel USB-C + zasilacz 5 V | stałe zasilanie, bez baterii |

### Połączenia (driver board ↔ XIAO ESP32-S3)

| Sygnał e-paper | Pin XIAO | GPIO ESP32-S3 | Funkcja |
|---|---|---|---|
| RES | D0 | GPIO1 | reset panelu |
| CS | D1 | GPIO2 | SPI chip select |
| BUSY | D5 | GPIO6 | panel zajęty (wejście) |
| DC | D3 | GPIO4 | data / command |
| SCL | D8 | GPIO7 | SPI SCK |
| DAT | D10 | GPIO9 | SPI MOSI |
| 3V3 / GND | 3V3 / GND | – | zasilanie |

> ✅ **Sprawdzone na sprzęcie (2026-10-18):** wiki Seeed podaje BUSY na D2, ale na tej płytce BUSY jest na **D5**. Pomiar programem diagnostycznym pokazał, że w czasie odświeżania w stan wysoki przechodzi tylko D5. Mapowanie pilnuje test `test/test_config_pins`.

---

## 3. Architektura

```
ios/FamilyTodo        aplikacja SwiftUI: widoki, CoreBluetooth (BLEDeviceLink), powiadomienia, Keychain
  └─ ios/TodoCore     czysta logika (SPM): model, LWW, kolejność, repozytorium, protokół, ramki,
                      SyncEngine, planowanie przypomnień
src/                  firmware: main (pętla), ble/gatt (serwer GATT), storage/flash (LittleFS), ui/screen
  └─ lib/todo_core    czysta logika C++17: TaskStore, LWW, selectForDisplay, HMAC, kodek JSON,
                      ramki BLE, SyncSession (protokół), RefreshScheduler
```

Model zadania: `id, ownerId, title (≤120 B UTF-8), priority (0..2), dueAt?, status, reminderAt?, createdAt, updatedAt, updatedBy, deleted`. Czasy są w ms od epoki Unix.

### Scalanie
- Wygrywa wersja z nowszym `updatedAt`. Przy remisie wygrywa większy `updatedBy`, więc każde urządzenie dochodzi do tego samego wyniku.
- Usunięcie zostaje jako tombstone (`deleted=true`), żeby dotarło do pozostałych telefonów.
- Każda przyjęta zmiana na urządzeniu zwiększa licznik `revision`, a telefon pobiera tylko zmiany od swojego kursora.
- Po wyczyszczeniu pamięci urządzenie ma nowy `storeId`. Telefon to wykrywa, wysyła wszystkie swoje rekordy i pobiera listę od zera.
- Ponowienie po zerwanym połączeniu wysyła te same wersje, więc nie powstają duplikaty.

---

## 4. Protokół BLE

Usługa `8b1f0001-6a4e-4d2b-9c7e-3f5a2b1c0d10` ma dwie charakterystyki: żądanie `…0002` (write) i odpowiedź `…0003` (indicate: telefon potwierdza każdą ramkę). Łącze nie jest szyfrowane.

Każda wiadomość JSON jest dzielona na ramki `[seq u16 LE][flags u8, bit0 = ostatnia][dane]`. Rozmiar ramki to MTU − 3, a wiadomość ma najwyżej 16 KiB.

| Żądanie | Odpowiedź |
|---|---|
| `{"op":"hello"}` | `{"ok":true,"nonce":"<16 B hex>","store":"…","rev":n}` (nowa sesja) |
| `{"op":"auth","user":u,"name":n,"mac":"<HMAC-SHA256(klucz rodziny, nonce‖user) hex>"}` | `{"ok":true}` (urządzenie zapamiętuje imię) lub `bad_mac` / `no_session` / `bad_request` |
| `{"op":"push","tasks":[≤20]}` | `{"ok":true,"results":["inserted"\|"updated"\|"ignored"\|"rejected_full"\|"rejected_invalid"…],"rev":n}` |
| `{"op":"pull","since":r,"limit":≤20}` | `{"ok":true,"store":"…","rev":kursor,"more":bool,"tasks":[…]}` |

Błędy mają postać `{"ok":false,"err":"…"}`. Wiadomość, której ramek nie da się złożyć, dostaje od razu `bad_frame`. Przykładowe zadanie w JSON:

```json
{"id":"0b6f…","owner":"anna","title":"Kupić mleko","prio":2,"due":1793520000000,"status":"done",
 "rem":1793516400000,"created":1793430000000,"updated":1793433600000,"by":"bartek","del":false}
```

### Klucz rodziny i imiona (bez parowania)
1. Raz, przed pierwszym buildem: `tools/make-family-key.sh`. Skrypt zapisuje ten sam losowy klucz do `include/family_key.h` (firmware) i `ios/FamilyTodo/FamilyKey.swift` (aplikacja). Oba pliki są w `.gitignore`.
2. Wgraj firmware i zainstaluj aplikację z tego samego klucza. Wszyscy domownicy używają tego samego buildu aplikacji.
3. Pierwsze uruchomienie aplikacji: podajesz imię (maks. 32 B). Telefon przedstawia się nim przy każdej synchronizacji.
4. Urządzenie pamięta do 8 osób. Przy 9. usuwa osobę najdawniej widzianą, a jej zadania pokazuje wtedy bez imienia.

Każdy, kto ma aplikację z kluczem, może zmieniać zadania. Obca aplikacja BLE w zasięgu nie może.

### Kiedy aplikacja synchronizuje się sama
- **Kiedy działa:** tylko gdy aplikacja jest na pierwszym planie i wyświetlacz jest w zasięgu.
- **Po pierwszym wykryciu:** synchronizacja od razu.
- **Po lokalnej zmianie:** 2 s po ostatniej zmianie.
- **Bez lokalnych zmian:** najwyżej raz na minutę.
- **Po nieudanej próbie:** kolejna po 10 s, potem po 30 s, potem co 60 s.

---

## 5. Ekran (400×300)

```
 ┌──────────────────────────────────────┐
 │ ⚑ Anna: Kupić mleko            31.10 │  9 wierszy od samej góry
 │ ⚐ Bartek: Wynieść śmieci             │  termin dd.mm po prawej
 │ — Anna: Umyć okna                    │
 │ …                                    │
 │ Pranie                          1/2  │  numer strony w rogu tylko przy rotacji
 └──────────────────────────────────────┘
```

- Ikony priorytetu (bitmapy 18×18 z `lib/todo_core/src/todo/priority_icon.cpp`, w aplikacji SF Symbols `flag.fill` / `flag` / `minus`): **pełna flaga** = wysoki, **flaga w obrysie** = normalny, **kreska** = niski.
- Kolejność: priorytet ↓, zadania z terminem przed zadaniami bez terminu, termin ↑, data utworzenia ↑.
- Najpierw każda osoba dostaje swoje najlepsze zadanie, a wolne wiersze wypełniają kolejne zadania według tej samej kolejności.
- Przy więcej niż 9 osobach z zadaniami pokazywane są strony po 9 osób, po jednym zadaniu na osobę. Strona zmienia się co 5 min.
- Po zmianie danych ekran odświeża się po 3 s ciszy, żeby seria zapisów z jednej synchronizacji dała jedno odświeżenie.

---

## 6. Ograniczenia panelu

Na tym panelu nie działa szybkie częściowe odświeżanie (sprawdzone 2026-10-18), dlatego każda zmiana to pełne odświeżenie (~3 s z mignięciem):
- fabryczny tryb częściowy (GxEPD2, `0x22` = `0xFC`) trwa ~2,96 s i miga całym ekranem;
- tryb częściowy Seeed_GFX (`0xFF`) kończy po ~264 ms, ale obraz się nie zmienia;
- własne tablice LUT (`0x32`, formaty SSD1680 i SSD1683) kontroler wykonuje, ale piksele się nie zmieniają.

Ramkę panelu (`EPD_BORDER = 0x00`, czarna) firmware ustawia przed każdym odświeżeniem.

---

## 7. Budowanie i testy

| Co | Polecenie |
|---|---|
| Klucz rodziny (raz) | `tools/make-family-key.sh` |
| Firmware na XIAO | `pio run -e xiao_esp32s3 -t upload` |
| Testy logiki ESP32 na Macu (Unity) | `pio test -e native` |
| Testy logiki iOS (Swift Testing) | `swift test --package-path ios/TodoCore` |
| Projekt Xcode aplikacji | `xcodegen generate --spec ios/project.yml`, potem otwórz `ios/FamilyTodo.xcodeproj` |

PlatformIO instaluj w `~/.platformio/penv`; wersja z Homebrew na tym macOS nie działa. Konfiguracja (piny, UUID BLE) jest w `include/config.h`. Wi-Fi i `secrets.h` nie są już potrzebne.

---

## 8. Otwarte kwestie

- [ ] Czyszczenie starych ukończonych zadań (urządzenie mieści 256 rekordów, a przy zapełnieniu najpierw wypiera najstarsze tombstone'y).
- [ ] Synchronizacja w tle, gdy aplikacja nie jest otwarta.
- [ ] Szyfrowanie treści zadań kluczem rodziny (łącze BLE jest otwarte).
- [ ] Zmiana imienia w aplikacji (protokół już to obsługuje).
- [ ] Integracja z ChatGPT po potwierdzeniu obsługiwanego mechanizmu.
