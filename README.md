# Family to-do list on e-paper

A shared 4.2" e-paper display showing the whole family's household tasks. Each family member manages their own tasks in an iOS app (priority, due date, reminder). Phones sync them over **BLE** with an ESP32-S3 device that stores the list, merges changes from multiple phones and decides on its own what to show. The device does not use Wi-Fi, so it can be moved anywhere in the house without any configuration.

Requirements (in Polish): [`specyfikacja_systemu_todo.md`](specyfikacja_systemu_todo.md). ChatGPT integration is not part of the project yet (waiting for the mechanism to be verified).

---

## 1. Features

| Where | What |
|---|---|
| iOS | add, edit, complete and delete tasks; priority (high/normal/low), due date, reminder |
| iOS | local reminders at the set time, even without a connection to the display (only on the task owner's phone) |
| iOS ↔ ESP32 | no pairing: the open app discovers the display within BLE range and syncs on its own (short connection, send own changes, fetch others', disconnect); the "Sync" button forces it immediately |
| ESP32 | persistent task list (LittleFS) that survives restarts; merging changes from multiple phones (LWW) |
| e-paper | up to 9 tasks, no header: priority ↓, due date ↑; **every person with an active task gets at least one row**; with more than 9 people, pages rotate every 5 min |
| access | only an app holding the shared **family key** (HMAC-SHA256 with a session nonce) can read and change tasks; the BLE link is not encrypted, so iOS shows no pairing dialog |

---

## 2. Hardware

| Part | Model | Notes |
|---|---|---|
| Microcontroller | **Seeed Studio XIAO ESP32-S3** | 240 MHz, dual-core, 8 MB flash, BLE 5, USB-C |
| Antenna | external 2.4 GHz antenna (U.FL) | connected to the XIAO connector |
| Display driver | **Seeed ePaper Driver Board for XIAO** | 24-pin FPC connector, pins `3V3 GND DAT SCL CS DC RES BUSY` |
| Display | **DKE DEPG0420BNS19AF**, 4.2" | 400×300 px, black and white, SSD1683 controller (or compatible); full refresh only, see section 6 |
| Power | USB-C cable + 5 V power supply | always powered, no battery |

3D-printed enclosure: [`enclosure/`](enclosure/).

### Wiring (driver board ↔ XIAO ESP32-S3)

| e-paper signal | XIAO pin | ESP32-S3 GPIO | Function |
|---|---|---|---|
| RES | D0 | GPIO1 | panel reset |
| CS | D1 | GPIO2 | SPI chip select |
| BUSY | D5 | GPIO6 | panel busy (input) |
| DC | D3 | GPIO4 | data / command |
| SCL | D8 | GPIO7 | SPI SCK |
| DAT | D10 | GPIO9 | SPI MOSI |
| 3V3 / GND | 3V3 / GND | – | power |

> ✅ **Verified on hardware (2026-10-18):** the Seeed wiki lists BUSY on D2, but on this board BUSY is on **D5**. A diagnostic program showed that only D5 goes high during a refresh. The mapping is guarded by the `test/test_config_pins` test.

---

## 3. Architecture

```
ios/FamilyTodo        SwiftUI app: views, CoreBluetooth (BLEDeviceLink), notifications, Keychain
  └─ ios/TodoCore     pure logic (SPM): model, LWW, ordering, repository, protocol, frames,
                      SyncEngine, reminder scheduling
src/                  firmware: main (loop), ble/gatt (GATT server), storage/flash (LittleFS), ui/screen
  └─ lib/todo_core    pure C++17 logic: TaskStore, LWW, selectForDisplay, HMAC, JSON codec,
                      BLE frames, SyncSession (protocol), RefreshScheduler
```

Task model: `id, ownerId, title (≤120 B UTF-8), priority (0..2), dueAt?, status, reminderAt?, createdAt, updatedAt, updatedBy, deleted`. Times are in ms since the Unix epoch.

### Merging
- The version with the newer `updatedAt` wins. On a tie the larger `updatedBy` wins, so every device reaches the same result.
- A deletion stays as a tombstone (`deleted=true`) so it reaches the other phones.
- Every accepted change on the device increments the `revision` counter, and a phone fetches only the changes since its own cursor.
- After its storage is wiped the device gets a new `storeId`. The phone detects this, sends all of its records and fetches the list from scratch.
- A retry after a dropped connection sends the same versions, so no duplicates are created.

---

## 4. BLE protocol

Service `8b1f0001-6a4e-4d2b-9c7e-3f5a2b1c0d10` has two characteristics: request `…0002` (write) and response `…0003` (indicate: the phone acknowledges every frame). The link is not encrypted.

Each JSON message is split into frames `[seq u16 LE][flags u8, bit0 = last][data]`. The frame size is MTU − 3 and a message is at most 16 KiB.

| Request | Response |
|---|---|
| `{"op":"hello"}` | `{"ok":true,"nonce":"<16 B hex>","store":"…","rev":n}` (new session) |
| `{"op":"auth","user":u,"name":n,"mac":"<HMAC-SHA256(family key, nonce‖user) hex>"}` | `{"ok":true}` (the device remembers the name) or `bad_mac` / `no_session` / `bad_request` |
| `{"op":"push","tasks":[≤20]}` | `{"ok":true,"results":["inserted"\|"updated"\|"ignored"\|"rejected_full"\|"rejected_invalid"…],"rev":n}` |
| `{"op":"pull","since":r,"limit":≤20}` | `{"ok":true,"store":"…","rev":cursor,"more":bool,"tasks":[…]}` |

Errors look like `{"ok":false,"err":"…"}`. A message whose frames cannot be reassembled gets `bad_frame` immediately. Sample task in JSON:

```json
{"id":"0b6f…","owner":"anna","title":"Buy milk","prio":2,"due":1793520000000,"status":"done",
 "rem":1793516400000,"created":1793430000000,"updated":1793433600000,"by":"bartek","del":false}
```

### Family key and names (no pairing)
1. Once, before the first build: `tools/make-family-key.sh`. The script writes the same random key to `include/family_key.h` (firmware) and `ios/FamilyTodo/FamilyKey.swift` (app). Both files are in `.gitignore`.
2. Flash the firmware and install the app built with the same key. All family members use the same app build.
3. On first launch you enter your name (max. 32 B). The phone identifies itself with it on every sync.
4. The device remembers up to 8 people. When a 9th appears it drops the least recently seen person, whose tasks are then shown without a name.

Anyone with the app containing the key can change tasks. A foreign BLE app in range cannot.

### When the app syncs on its own
- **When it runs:** only while the app is in the foreground and the display is in range.
- **On first discovery:** sync immediately.
- **After a local change:** 2 s after the last change.
- **Without local changes:** at most once a minute.
- **After a failed attempt:** next try after 10 s, then 30 s, then every 60 s.

---

## 5. Screen (400×300)

```
 ┌──────────────────────────────────────┐
 │ ⚑ Anna: Buy milk               31.10 │  9 rows from the very top
 │ ⚐ Bartek: Take out the trash         │  due date dd.mm on the right
 │ — Anna: Wash the windows             │
 │ …                                    │
 │ Laundry                         1/2  │  page number in the corner only when rotating
 └──────────────────────────────────────┘
```

- Priority icons (18×18 bitmaps from `lib/todo_core/src/todo/priority_icon.cpp`; in the app the SF Symbols `flag.fill` / `flag` / `minus`): **filled flag** = high, **outlined flag** = normal, **dash** = low.
- Order: priority ↓, tasks with a due date before tasks without one, due date ↑, creation date ↑.
- First every person gets their top task, then free rows are filled with the next tasks in the same order.
- With more than 9 people with tasks, pages of 9 people are shown, one task per person. The page changes every 5 min.
- After a data change the screen refreshes after 3 s of quiet, so a burst of writes from one sync results in a single refresh.

---

## 6. Panel limitations

Fast partial refresh does not work on this panel (verified 2026-10-18), so every change is a full refresh (~3 s with a flash):
- the factory partial mode (GxEPD2, `0x22` = `0xFC`) takes ~2.96 s and flashes the whole screen;
- the Seeed_GFX partial mode (`0xFF`) finishes after ~264 ms, but the image does not change;
- custom LUT tables (`0x32`, SSD1680 and SSD1683 formats) are executed by the controller, but the pixels do not change.

The firmware sets the panel border (`EPD_BORDER = 0x00`, black) before every refresh.

---

## 7. Build and test

| What | Command |
|---|---|
| Family key (once) | `tools/make-family-key.sh` |
| Firmware for the XIAO | `pio run -e xiao_esp32s3 -t upload` |
| ESP32 logic tests on a Mac (Unity) | `pio test -e native` |
| iOS logic tests (Swift Testing) | `swift test --package-path ios/TodoCore` |
| App Xcode project | `xcodegen generate --spec ios/project.yml`, then open `ios/FamilyTodo.xcodeproj` |

Install PlatformIO in `~/.platformio/penv`; the Homebrew version does not work on this macOS. Configuration (pins, BLE UUIDs) lives in `include/config.h`. Wi-Fi and `secrets.h` are no longer needed.

---

## 8. Open items

- [ ] Clean-up of old completed tasks (the device holds 256 records and, when full, evicts the oldest tombstones first).
- [ ] Background sync while the app is not open.
- [ ] Encrypting task contents with the family key (the BLE link is open).
- [ ] Changing your name in the app (the protocol already supports it).
- [ ] ChatGPT integration once the supported mechanism is confirmed.

## License

MIT — see [LICENSE](LICENSE).
