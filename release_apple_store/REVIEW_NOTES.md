# App Review information

App Store Connect → the version → **App Review Information**.

| Field | Value |
|---|---|
| Sign-in required | **No** (uncheck "Sign-in required") |
| Contact | Your first and last name, phone and e-mail (App Review calls only if something is unclear) |
| Notes | The text below, after replacing `<YOUTUBE_LINK>` with the link to the unlisted video (`review_video/`) |
| Attachment | Optional: the same `review_video/out/review_video.mp4`, if you prefer not to rely on YouTube |

## Notes (paste as is, about 1,900 of 4,000 characters)

```
Family To-Do for E-Paper is the companion app for an open-source DIY e-paper display (ESP32-S3 + 4.2" e-paper). The hardware is not sold; users build it from the instructions, firmware and 3D-printable case at https://github.com/marekpiotrowskimp/family-todo-epaper

DEMO VIDEO WITH THE REAL DISPLAY
<YOUTUBE_LINK>
It shows adding a task in the app, the sync over Bluetooth Low Energy, the display showing the task, and the task disappearing from the display after it is marked as done.

THE APP IS FULLY USABLE WITHOUT THE HARDWARE
1. Launch the app, enter any name, leave "Family key" empty and tap Continue.
2. Tap + to add a task: title, an optional note, priority, due date and a reminder. Tap Save.
3. Swipe right on a task to mark it done, swipe left to delete it.
4. Completed tasks are listed under History (clock icon), where they can be restored.
5. Reminders arrive as local notifications if you allow notifications.

FAMILY KEY (optional)
The family key lets the app authenticate to the user's own display. To see this flow, paste this test key into the "Family key" field on the Welcome screen, or in Settings (gear icon) and tap "Save key":
familytodo://key?k=659bff0319594c91a0e038aee876c2559a19c62eac3eafa2276b0f2cc1ae0464
Settings then offers "Show QR code for a family member": another family member scans it with the Camera app. The test key is not used by any real display.

BLUETOOTH
Bluetooth is used only to find the user's own display and exchange tasks with it while the app is open. Without a family key, tapping the sync button asks to add the key in Settings. With the test key but no display in range, it shows "Cannot connect to the display (…)". Both are expected.

PRIVACY
No account, no server, no analytics, no network requests. Tasks stay on the phone and on the user's own display. Notes stay on the phone only.

Thank you for reviewing!
```
