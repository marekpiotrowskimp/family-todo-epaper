# App Review demo video — what to record

Goal: show the reviewer that the app really works with the display, which they do not have.
Length: 45–90 s in total. No voice-over needed; `make_review_video.sh` adds captions.

## Before recording

- Film **landscape** (horizontal) with a second phone or a camera, so the iPhone and the display fit in one frame. Portrait clips also work, but the caption bar covers their lower part.
- On the filming iPhone: Settings → Camera → Formats → **Most Compatible**, and turn **HDR Video** off (HDR clips look washed out after conversion).
- Use a task title that reads well, e.g. **"Buy milk"** with priority **High**, so it lands at the top of the display.
- **Do not show the family key or its QR code** (Settings → Show QR code). The video will be on YouTube; anyone with the key could change your tasks. If you want to show the QR code, generate a test key first and flash it.
- Avoid other private things in the frame (other tasks with names, documents, the street outside).
- Lock the filming phone's exposure (long press on the screen), because the e-paper refresh flashes black and white.

## Shots

Name the files `footage/NN_something.mov` (NN = shot number). Each gets the caption below; to change it, add `footage/NN_something.txt` with your own caption in the first line.

| # | What to film | Duration | Caption added by the script |
|---|---|---|---|
| 01 | The display on the wall or shelf, showing the current list. Slowly move closer. | 4–6 s | The e-paper display at home, built from the open-source project |
| 02 | iPhone in hand next to the display: open the app, tap **+**, type "Buy milk", set priority High, tap **Save**. | 10–15 s | Adding a task in the app, next to the display |
| 03 | The sync button spinning in the toolbar (or tap it). Keep the display in frame. | 3–5 s | The app syncs over Bluetooth Low Energy (no pairing) |
| 04 | The display refreshes (about 3 s after the sync it flashes and redraws) and "Buy milk" appears at the top. Keep filming until the refresh finishes. | 8–12 s | The display refreshes and shows the new task |
| 05 | Swipe right on "Buy milk" in the app → **Done**. | 3–5 s | Marking the task as done in the app |
| 06 | Sync, then the display refreshes without "Buy milk". | 8–12 s | After the sync the task disappears from the display |
| 07 | Optional: a second iPhone with the app open shows the task added from the first phone. | 5–8 s | A second phone sees the task of another family member |

Tip: shots 02–06 can be one continuous take. Then cut it into clips with QuickTime (Edit → Split Clip, or Trim) or just save it as `footage/02_demo.mov` with a `.txt` caption such as "Add a task → sync → the display shows it → mark it done → it disappears".

## Build and check

```sh
release_apple_store/review_video/make_review_video.sh
open release_apple_store/review_video/out/review_video.mp4
```

Watch it once to the end: the new task must be clearly readable on the display.

Then upload it to YouTube as **Unlisted** (texts in `YOUTUBE.md`) and put the link in the review notes (`../REVIEW_NOTES.md`).
