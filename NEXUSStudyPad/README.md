# NEXUS STUDY PAD

NEXUS STUDY PAD is a standalone native iPad study workspace. It is intentionally separate from the NEXUS macOS application and never opens or migrates the desktop application's SwiftData store.

## Phase 4

- iPadOS 17+, Swift, SwiftUI, MVVM-style feature models, SwiftData
- Turkish source/default interface through a String Catalog
- Touch-first Today, Courses, Lectures, Documents, Notes and Tasks navigation
- Real local CRUD with confirmation before destructive deletion
- User-selected PDF import, an app-owned PDF copy, PDFKit viewing and a saved per-page PencilKit annotation sheet
- Markdown/plain notes plus saved PencilKit handwritten notes
- Lecture records with attendance/review state and opt-in local audio recording
- Local-only storage; no cloud, network client, analytics or external package
- A touch-first course notebook with Overview, 15-week lesson notebook, PDFs, Notes, Tasks and Audio sections
- A configurable 1–30 week semester layout (15 by default), with separate numbered lesson sessions inside every week
- Each lesson session keeps its own audio list and a page-length, monospaced text notebook directly below the audio; the text autosaves locally after a short debounce and can also be saved explicitly
- Long Markdown/plain-text notes with safe debounced autosave after the first explicit save
- Per-lecture audio pause/resume/playback, storage-size visibility and confirmed removal
- Local `StudyPadTransfer v2` JSON import/export through Files, with complete validation, preview, duplicate policy and explicit confirmation; v1 remains import-compatible and maps safely to week 1 / lesson 1
- Read-only mapping of the clear Study subset in NEXUS macOS backup JSON schema v1-v9; the macOS database itself is never opened
- A prominent `Mac'ten verileri aktar` card at the top of Today and a persistent `Mac'ten aktar` sidebar route; both open the same validated transfer screen
- A real `Bugün / Hafta` home switch. Active weekly course rules are projected transiently into the current day and rolling seven-day agenda, including rules imported from a Mac backup; viewing never creates a Lecture or attendance record.
- Course-owned weekly schedule CRUD for weekday, start time, duration, validity range, optional location and active state, with overlap warnings and confirmed deletion.
- Concrete Lecture records take precedence over a projected rule at the same course/date/minute so Today does not show the same occurrence twice.

Open `NEXUSStudyPad.xcodeproj`, select an iPad simulator and run the shared `NEXUSStudyPad` scheme.

```sh
xcodebuild -project NEXUSStudyPad.xcodeproj -scheme NEXUSStudyPad \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' test
```

The exact simulator name depends on the Xcode installation. Hotfix 0.2.1 was also built, signed with the user's existing Apple Development team, installed and launched on the connected iPad (A16). Future physical-device builds continue to require that user-owned signing setup.

## Privacy boundaries

- PDF access begins only from the native file importer. NEXUS STUDY PAD copies the chosen PDF into its own container and does not retain broad access to Files.
- Microphone permission is not requested on launch. A lecture screen first explains local recording; only the explicit enable/record action can request permission.
- Audio remains inside the app container. No transcription or upload exists.
- The annotation foundation saves a real PencilKit drawing per PDF page, separately from the PDF. Phase 1 does not claim that ink is embedded into the PDF file or geometrically synchronized with arbitrary PDF zoom/scroll.

See [requirements](Documentation/REQUIREMENTS.md), [architecture](Documentation/ARCHITECTURE.md), and [verification](Documentation/VERIFICATION.md).

## Honest Phase 4 boundary

PDF annotations remain durable, page-scoped PencilKit layers stored beside the imported document; they are not flattened into the PDF. Handwritten notes are durable PencilKit canvases. Audio permission and recording require a real user action and were intentionally not exercised by automation. JSON transfer does not contain PDF, audio or PencilKit binary data. There is no sync and no existing Mac data is transferred until the user exports a file, selects it in Files, reviews the preview and confirms. Physical iPad microphone and Pencil behavior remain user-controlled device checks.

Schedule projection is a read model, not bulk generation: a weekly rule appears on matching active dates in Today/Week but does not manufacture persistent lecture, review or attendance history. The user still creates a concrete lecture record when they want session-specific notes, review state, attendance or audio. Transfer remains manual; no production Mac backup was imported during development.

The semester notebook does not pre-create 30 fictional lecture rows. It presents 15 empty week folders by default and writes a real `Lecture` only when the user adds the lesson actually taken. Two lesson buttons are offered as the common case, while additional numbered sessions remain available. Audio and notebook text stay owned by that exact lesson session.
