# StudyPadTransfer v2 (v1 import-compatible)

## Purpose

`StudyPadTransfer v2` is a local, user-controlled JSON interchange format for NEXUS STUDY PAD. It is a backup/import path, not device sync. Import and export are initiated through the native Files interface and never scan another app container. Version 1 remains accepted and is normalized before validation.

## Envelope

```json
{
  "format": "nexus-study-pad-transfer",
  "schemaVersion": 2,
  "createdAt": "2026-08-30T00:00:00Z",
  "courses": [],
  "scheduleRules": [],
  "lectures": [],
  "notes": [],
  "tasks": []
}
```

Dates use ISO 8601. Every record has a stable UUID plus `createdAt` and `updatedAt`. Relationships use UUID fields (`courseID`, `lectureID`) and must point to records inside the same validated pack. A pack with duplicate UUIDs, invalid values, broken relationships or an unsupported version is rejected before writing.

Version 2 adds `semesterWeekCount` to each course and `weekNumber` / `lessonNumber` to each lecture. Lecture `note` is the text notebook for that exact session. When importing v1, missing fields become 15, 1 and 1 respectively; titles, dates, status and notebook text remain unchanged.

## Duplicate and commit behavior

- **Skip:** preserve the local record and ignore an incoming record with the same UUID.
- **Update:** update only fields of the local record with the same UUID.
- There is no replace-all mode and import never deletes local records.
- The whole pack is validated first. Confirmed changes use one SwiftData save; a save failure rolls back the context.

## NEXUS macOS backup compatibility

The importer recognizes the clear Study subset of NEXUS macOS backup JSON schema versions 1-9:

- courses → courses
- study schedule rules → weekly schedule rules
- Study tasks → tasks
- notes → unassigned text notes, because the Mac backup note payload has no course link

Other macOS modules are ignored and this is disclosed in preview. The importer never opens the macOS SwiftData/SQLite store.

## Intentionally excluded

PDF files, PDF ink, handwritten-note PencilKit data and audio files are not embedded or silently copied. A future explicit media-bundle format can add them with per-file size, checksum and user selection. Cloud/iCloud synchronization and automatic Mac-to-iPad transfer are outside this format.
