# Architecture

## Boundaries

`NEXUSStudyPad` owns its bundle identifier, sandbox container and SwiftData schema. It has no code path to the macOS NEXUS container.

## Layers

- `App`: app entry, root navigation and model-container composition.
- `Core`: routes, date logic and application state.
- `DesignSystem`: phosphor tokens, terminal cards, restrained scanlines and a passive network globe.
- `Models`: independent SwiftData records for courses, weekly course schedule rules, lectures, documents, PDF ink, notes, tasks and audio recordings.
- `Services`: app-container file copying/deletion, source-owned course deletion, opt-in AVAudioRecorder lifecycle and validated JSON transfer.
- `Features`: touch-first Home, Courses, Documents, Notes, Lectures and Tasks views plus focused view models.
- `Components`: reusable empty, error, progress and state controls.
- `Resources`: String Catalog and asset catalogs.
- `NEXUSStudyPadTests`: pure calculation/validation and in-memory SwiftData tests.

## Relationships

```text
Course
  -> semesterWeekCount (15 default, 1...30)
  <- CourseScheduleRule.courseID
  <- Lecture.courseID
  <- StudyDocument.courseID
  <- StudyNote.courseID
  <- StudyTask.courseID

Lecture
  -> weekNumber + lessonNumber
  <- StudyDocument.lectureID
  <- StudyNote.lectureID
  <- AudioRecording.lectureID

StudyDocument
  <- PDFInkLayer.documentID + pageIndex
```

UUID references keep deletion behavior explicit. Course deletion unassigns linked lectures, documents, notes and tasks, but removes its dependent `CourseScheduleRule` rows because their `courseID` is non-optional and an orphan rule cannot be projected honestly. Document deletion removes its app-owned PDF and associated ink only after confirmation. Lecture deletion removes only that lecture and its owned local audio files/records after confirmation; it does not remove the course.

## Schedule projection

`ScheduleOccurrenceProjector` is a pure, calendar-aware read model. For a requested local date range it checks active state, weekday and inclusive effective start/end days, then derives stable transient lesson items from independent `CourseScheduleRule` and `Course` records. It never inserts a `Lecture`, attendance value or review state. `HomeViewModel` merges concrete lectures with projected occurrences for Today and a rolling seven-day view. A concrete lecture with the same course and local year/month/day/hour/minute wins over the projection to prevent a duplicate row.

The course Overview owns schedule CRUD. The editor validates weekday, minute range, duration and date bounds, exposes active/inactive state, warns about same-weekday time overlaps, and requires an explicit save. Deletion is per-rule and confirmed.

## Localization and accessibility

Turkish values live in `Localizable.xcstrings`. English and Arabic localization entries can be added without changing call sites. Arabic layout inherits SwiftUI's environment direction. Decorative scanlines/globe ignore hit testing and accessibility. Dynamic Type, VoiceOver labels, large targets and Reduce Motion are respected.

## Annotation boundary

`PDFInkLayer` is keyed by document UUID and zero-based page index and stores a real `PKDrawing` data representation using SwiftData external storage. The PDF remains immutable. This makes save/reopen deterministic without claiming PDF-coordinate alignment during arbitrary zoom or exporting embedded annotations. `StudyNote` uses the same durable PencilKit data approach for handwritten notes.

## Semester lesson notebook

`Course.semesterWeekCount` defines the visible semester folders without manufacturing child records. `Lecture.weekNumber` and `Lecture.lessonNumber` identify a concrete session inside a course. `CourseNotebookPolicy` owns stable filtering, lesson ordering, next-number suggestion and duplicate detection. Existing stores migrate additively with defaults of 15 weeks and week 1 / lesson 1.

The lesson detail owns one long notebook string (`Lecture.note`) beside its existing audio relationship. `TextEditor` edits a view-local draft so normal rendering does not write. A 650 ms cancellable debounce, an explicit save button and navigation-away flush write through the current `ModelContext`; text over 1,000,000 UTF-8 bytes is rejected without replacing the stored value. No audio permission is coupled to typing.

## Transfer boundary

`StudyPadTransferService` accepts only a user-selected JSON URL from the native Files importer. It decodes into an in-memory transfer model, validates every identifier, value and relationship, then shows counts, warnings and a duplicate policy before confirmation. Confirmed records are inserted or updated in one `ModelContext.save()`; failures roll back the context. Import never performs replace-all or deletion.

The native format is `StudyPadTransfer v2`. It carries courses including semester length, weekly schedule rules, lecture metadata including week/lesson position and per-lesson notebook text, Markdown/plain notes and tasks. The importer still accepts v1 and normalizes missing organization fields to 15 weeks and week 1 / lesson 1 before validation. PDF files, PDF ink, handwritten-note drawings and audio files are deliberately excluded. The app can also decode the documented Study subset of NEXUS macOS JSON backups with schema versions 1-9. It maps courses, Study tasks, Study schedule rules and notes; Mac notes are unassigned because that backup payload has no course relationship. Other Mac modules are ignored. There is no SQLite access, container discovery, cloud or sync.

## Notebook and media lifecycle

Each course has six touch-oriented sections: Overview, Weeks, PDFs, Notes, Tasks and Audio. The Weeks section exposes the semester folders and their concrete lessons. General text notes keep metadata controls separate from a full-height editor, while each concrete lesson also has its own full-height text notebook directly below audio. Both use bounded local autosave and the current 1,000,000 UTF-8-byte safety limit.

Audio lives in the app-owned `Documents/LectureAudio` directory. Recording starts only through the explicit permission explanation/action, can pause/resume/stop, and is listed and playable by lecture. Removal requires confirmation and deletes both the file and its metadata. The UI reports storage usage; uninstalling the app removes its container. JSON export does not copy audio.
