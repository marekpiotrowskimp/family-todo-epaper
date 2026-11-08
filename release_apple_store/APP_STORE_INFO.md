# Family To-Do for E-Paper — App Store submission

Everything to paste into App Store Connect for version 1.0, in **English (U.S.)** and **Polish**.
Character limits were checked (count shown as `n/limit`).

---

## 1. App information

| Field | Value |
|---|---|
| Name (EN) | `Family To-Do for E-Paper` (24/30) |
| Name (PL) | `Zadania rodziny na e-papier` (27/30) |
| Subtitle (EN) | `Tasks on your home e-paper` (26/30) |
| Subtitle (PL) | `Zadania na domowym e-papierze` (29/30) |
| Home-screen name | `To-Do` (EN) / `Zadania` (PL) — from `ios/FamilyTodo/InfoPlist.xcstrings` |
| Bundle ID | `pl.piotrowski.familytodo` (others: set your own with `tools/setup-ios-signing.sh`) |
| SKU | `FAMILYTODO001` |
| Primary language | English (U.S.); add localization: Polish |
| Category | Primary **Productivity**, secondary **Lifestyle** |
| Price | Free, no in-app purchases |
| Devices | iPhone only (iOS 17+); no iPad screenshots needed |
| Version / build | `1.0` / `1` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION` in `ios/project.yml`) |
| Copyright | `2026 Marek Piotrowski` |

> The App Store name must be unique. If it is taken, alternatives: `Family Tasks E-Paper`, `Hallway To-Do`, `Domowa lista na e-papier`.

---

## 2. Description

### English (max 4000)

```
One to-do list for the whole family — always visible on an e-paper display in your hallway.

Family To-Do is the companion app for an open-source DIY display (ESP32-S3 + 4.2" e-paper). Everyone at home adds tasks on their own iPhone; the display shows what needs doing, who it belongs to and when it is due. No account, no cloud, no subscription.

SHARED, BUT SIMPLE
• Add, edit, complete and delete tasks in seconds
• Three priorities, shown with the same flag icons on the phone and on the display
• Due dates and reminders that arrive on your phone even away from home
• Completed tasks move to a History screen with the time they were done
• Private notes for the details — a shopping list, an address — kept only on your phone

SYNCS ON ITS OWN
• Open the app near the display and it syncs over Bluetooth Low Energy — no pairing
• Changes from several phones are merged automatically
• The "Sync" button forces it whenever you want

PRIVATE BY DESIGN
• Your tasks stay on your phones and on your display — nothing is sent to the internet
• Access is protected by a family key that you generate yourself
• Add the key by scanning a QR code with the iPhone camera; family members can share it from Settings

WITHOUT THE DISPLAY
The app also works on its own as a task list with reminders on your phone.

BUILD THE DISPLAY
The firmware, wiring and a 3D-printable case are open source:
github.com/marekpiotrowskimp/family-todo-epaper

Available in English and Polish.
```

### Polish (max 4000)

```
Jedna lista zadań dla całej rodziny — zawsze widoczna na wyświetlaczu e-papierowym w przedpokoju.

Zadania rodziny to aplikacja do otwartego, samodzielnie budowanego wyświetlacza (ESP32-S3 + e-papier 4,2"). Każdy domownik dodaje zadania na swoim iPhonie, a wyświetlacz pokazuje, co jest do zrobienia, czyje to zadanie i na kiedy. Bez konta, bez chmury, bez abonamentu.

WSPÓLNIE, ALE PROSTO
• Dodawanie, edycja, oznaczanie jako zrobione i usuwanie w kilka sekund
• Trzy priorytety z tymi samymi ikonami flag na telefonie i na wyświetlaczu
• Terminy i przypomnienia, które przychodzą na telefon także poza domem
• Wykonane zadania trafiają do Historii z godziną wykonania
• Prywatne notatki ze szczegółami — lista zakupów, adres — zostają tylko na Twoim telefonie

SYNCHRONIZUJE SIĘ SAMA
• Otwórz aplikację w pobliżu wyświetlacza — zadania przejdą przez Bluetooth Low Energy, bez parowania
• Zmiany z kilku telefonów łączą się automatycznie
• Przycisk „Synchronizuj” wymusza synchronizację, kiedy chcesz

PRYWATNIE Z ZAŁOŻENIA
• Zadania zostają na Waszych telefonach i wyświetlaczu — nic nie trafia do internetu
• Dostęp chroni klucz rodziny, który generujesz sam
• Klucz dodajesz, skanując aparatem iPhone'a kod QR; domownicy mogą przekazać go sobie w Ustawieniach

BEZ WYŚWIETLACZA
Aplikacja działa też samodzielnie jako lista zadań z przypomnieniami na telefonie.

ZBUDUJ WYŚWIETLACZ
Firmware, schemat połączeń i obudowa do druku 3D są otwarte:
github.com/marekpiotrowskimp/family-todo-epaper

Dostępna po polsku i po angielsku.
```

---

## 3. Promotional text (max 170, editable without review)

- **EN** (150/170): `One shared to-do list for the whole family, always visible on a DIY e-paper display in your hallway. No account, no cloud — tasks sync over Bluetooth.`
- **PL** (154/170): `Jedna lista zadań dla całej rodziny, zawsze widoczna na domowym wyświetlaczu e-papierowym. Bez konta i chmury — zadania synchronizują się przez Bluetooth.`

## 4. Keywords (max 100, comma-separated, no spaces after commas)

- **EN** (96/100): `todo,family,chores,household,e-paper,eink,esp32,shared list,checklist,reminders,diy,display,home`
- **PL** (93/100): `zadania,rodzina,obowiązki,dom,e-papier,eink,esp32,wspólna lista,przypomnienia,diy,wyświetlacz`

## 5. What's New (1.0)

- **EN:** `First release: shared family tasks with priorities, due dates and reminders, private notes, task history, Bluetooth sync with the e-paper display, family key via QR code. English and Polish.`
- **PL:** `Pierwsze wydanie: wspólne zadania rodziny z priorytetami, terminami i przypomnieniami, prywatne notatki, historia zadań, synchronizacja z wyświetlaczem e-papierowym przez Bluetooth, klucz rodziny przez kod QR. Po polsku i po angielsku.`

---

## 6. URLs

| Field | URL |
|---|---|
| Support URL | `https://github.com/marekpiotrowskimp/family-todo-epaper/blob/main/release_apple_store/SUPPORT.md` |
| Privacy Policy URL | `https://github.com/marekpiotrowskimp/family-todo-epaper/blob/main/release_apple_store/PRIVACY.md` |
| Marketing URL (optional) | `https://github.com/marekpiotrowskimp/family-todo-epaper` |

The files must be on `main` on GitHub (public) before submitting.

---

## 7. Screenshots

Generated by `release_apple_store/make_screenshots.sh` from demo data (no personal data; the QR code encodes a demo key), in the simulator's native resolution, PNG without transparency.

| App Store Connect slot | Folder | Size | Command |
|---|---|---|---|
| iPhone 6.9" Display | `screenshots/1320x2868/<lang>/` | 1320 × 2868 | `make_screenshots.sh "iPhone 17 Pro Max"` |
| iPhone 6.1" / 6.3" Display | `screenshots/1206x2622/<lang>/` | 1206 × 2622 | `make_screenshots.sh "iPhone 17 Pro"` |

Upload `<size>/en/` to **English (U.S.)** and `<size>/pl/` to **Polish**, in file order (01…05).

| # | File | Shows | Optional caption EN / PL |
|---|---|---|---|
| 1 | `01_list.png` | Task list with priorities, due dates, reminders, note icon | Your family's tasks at a glance / Zadania całej rodziny w jednym miejscu |
| 2 | `02_editor.png` | Editing a task: note, priority, due date, reminder | Notes, due dates and reminders / Notatki, terminy i przypomnienia |
| 3 | `03_history.png` | History of completed tasks | See what got done / Zobacz, co już zrobione |
| 4 | `04_settings.png` | Family key QR code for a family member | Share the key with a QR code / Przekaż klucz kodem QR |
| 5 | `05_setup.png` | First launch: name and family key | Set up in seconds / Gotowe w kilka sekund |

Not screenshots: the landscape sizes 5244 × 2950 / 3840 × 1646 offered elsewhere in App Store Connect are optional **featuring artwork** for the editorial team, and 886 × 1920 is for optional **app preview videos**.

Recommended addition: a photo of the real display as the first screenshot (cropped to the slot size), since the hardware is the main selling point.

## 8. App Privacy ("nutrition label")

| Question | Answer |
|---|---|
| Do you or your third-party partners collect data from this app? | **No, we do not collect data from this app** |
| Tracking | No |

Reasoning: tasks, names and the family key never leave the user's devices, and notes never leave the phone (iPhone ↔ display over local BLE). No analytics, no crash reporting SDK, no network requests.

## 9. Age rating

All content questions: **None / No** (no user-generated content shared publicly, no web access, no chat, no ads). Result: **4+**.

## 10. Export compliance

`ITSAppUsesNonExemptEncryption = NO` is set in `Info.plist`. The app only uses HMAC-SHA256 to authenticate to the user's own device (exempt: authentication), so no documentation is needed.

---

## 11. App Review information

Notes for the reviewer, contact fields and the attachment: **[`REVIEW_NOTES.md`](REVIEW_NOTES.md)**.

Demo video with the real display (unlisted YouTube link in the notes): record the shots from [`review_video/SHOT_LIST.md`](review_video/SHOT_LIST.md), build it with `review_video/make_review_video.sh`, upload with the texts from [`review_video/YOUTUBE.md`](review_video/YOUTUBE.md).

---

## 12. Release checklist

1. [ ] Push this folder and the app changes to `main` on GitHub (URLs in section 6 must work).
2. [ ] developer.apple.com → Identifiers → register `pl.piotrowski.familytodo`.
3. [ ] App Store Connect → My Apps → **+ New App** (iOS, name, primary language English (U.S.), bundle ID, SKU).
4. [ ] Fill sections 1–6 and 8–11; add the Polish localization with the PL texts.
5. [ ] Upload screenshots (section 7).
6. [ ] Archive and upload the build:
   ```sh
   xcodebuild -project ios/FamilyTodo.xcodeproj -scheme FamilyTodo -configuration Release \
     -destination 'generic/platform=iOS' -archivePath build/FamilyTodo.xcarchive -allowProvisioningUpdates archive
   open build/FamilyTodo.xcarchive   # Xcode Organizer → Distribute App → App Store Connect
   ```
7. [ ] Record the demo video, upload it to YouTube as Unlisted and put the link in the review notes (section 11).
8. [ ] Select the build, **Add for Review**, submit.
