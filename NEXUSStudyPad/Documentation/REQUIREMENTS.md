# Phase 4 requirements

## Product outcome

An iPad-native, local-first study app using the restrained NEXUS phosphor-terminal identity without reproducing the macOS window layout. Navigation uses a touch-oriented `NavigationSplitView`, large controls and platform sheets/toolbars.

## Functional scope

1. Today summarizes today's lectures, incomplete due tasks and simple completion progress from real SwiftData records.
2. Courses provide create, edit, detail and confirmed delete. Code and instructor are optional.
3. Documents import only a PDF selected through the native file importer, copy it into the app container and display it with PDFKit.
4. PDF annotation foundation provides a PencilKit sheet for the selected page. Drawings save and reopen locally. Ink is not embedded into the PDF in Phase 1.
5. Notes belong optionally to a course or lecture, support Markdown/plain text, and can instead be a saved PencilKit handwritten page.
6. Lectures belong to a course and contain date, title, attendance and review status. Audio recording is local and explicitly opt-in.
7. Tasks can belong to a course, optionally have a due date and toggle completion immediately.
8. Delete operations require confirmation; empty and error states are explicit.
9. Every course detail is a notebook with Overview, Lectures, PDFs, Notes, Tasks and Audio sections.
10. Long Markdown/plain notes must remain writable and scrollable; existing notes autosave safely while the first creation is explicit.
11. Audio never starts or requests permission automatically; it supports pause/resume/stop, playback, per-lecture lists and confirmed removal.
12. Transfer begins only with a user-selected JSON file, validates all data before any write, previews mappings/counts/duplicates, and requires confirmation.
13. Duplicate handling is explicit: skip or update records with the same UUID. Import never replaces or deletes all local data.
14. `StudyPadTransfer v1` can be exported to a user-selected Files destination. PDF, audio and drawing binaries remain excluded.
15. Today and a rolling seven-day Week view project active weekly schedule rules without persisting generated lecture or attendance rows.
16. Course Overview supports create/edit/activate/deactivate/delete for weekly rules, with validity bounds, overlap warning, large touch targets and VoiceOver copy.
17. Deleting a course cannot leave an orphan schedule rule; unrelated course rules and linked content remain preserved.
18. Every course exposes a semester notebook split into 15 weeks by default; the user can configure 1–30 weeks without pre-generating fictional sessions.
19. Every week can contain separately numbered lesson sessions (first, second and additional lessons), ordered by number and date with a duplicate course/week/lesson guard.
20. A lesson detail places its long text notebook directly below local audio. Text must support page-length input, autosave after a bounded delay, explicit save, navigation-away save and a 1 MB UTF-8 safety limit.
21. Audio titles, lesson lists and accessibility labels identify the exact week and lesson so exam-period retrieval is unambiguous.
22. `StudyPadTransfer v2` preserves semester week count plus lecture week/lesson numbers, while v1 remains readable with explicit defaults and no content loss.

## Non-goals

- No macOS store reuse, CloudKit, sync, networking, analytics or external package. Adjacent macOS source may only be inspected read-only to document its backup JSON.
- No automatic microphone request, speech recognition, transcription or background capture.
- No access to arbitrary Files content outside a user-selected import.
- No claim of complete PDF ink embedding or Apple Pencil hover-specific behavior.
- No microphone, Files-provider or Apple Pencil behavior claim without an explicit user-controlled physical-device action.
- No claim that Mac data has moved before the user selects an exported JSON file, reviews its preview and confirms.
