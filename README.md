# NEXUS

NEXUS 0.15.5 is a native, local-first macOS student-life system built with Swift, SwiftUI, MVVM and SwiftData. Turkish is the default UI language. DAILY PLAN remains the dashboard family, all eight independent modules and all prior workflows are preserved.

## Requirements and run

- macOS 14 or newer
- Xcode 16 or newer (verified with Xcode 26.6)
- Apple Silicon or Intel Mac

Open `NEXUS.xcodeproj`, select the `NEXUS` scheme and `My Mac`, then press Command-R.

```sh
xcodebuild -project NEXUS.xcodeproj -scheme NEXUS -destination 'platform=macOS' build
xcodebuild -project NEXUS.xcodeproj -scheme NEXUS -destination 'platform=macOS' test
```

No external package, web technology, analytics, remote push or device sync is used. The strictly opt-in OpenAI Responses client remains unusable until the user separately saves their own API key in Keychain; local NEXUS commands, reports and the documented Turkish/Arabic action grammar need no network or key.

## 0.15.5 rolling upcoming Daily Plan

- DAILY PLAN opens in `HAFTA` with the selected day reset to the current local day. The default is an operational rolling seven-day window, not the calendar's Monday-Sunday week; on 29 August 2026 its explicit header is `29 Ağu–4 Eyl | ÖNÜMÜZDEKİ 7 GÜN`.
- Previous/next navigation moves that anchor by seven days, so historical and later ranges remain available only through an explicit user action. `Bugün` returns to the current local date. Reopening DAILY PLAN does not restore a stale past selection.
- Each day continues to aggregate only real dated records from the independent Study, Organization, Calendar, OBS, Finance and Gym models. Weekly Study rules are projected transiently, preserving provisional warnings, conflicts and occurrence-specific attendance semantics.
- The current Notes entity has no due/reminder date. Therefore undated and pinned notes, including the persistent nutrition note, remain available in Notes but are not promoted into a dated Daily Plan card. A dated reminder remains owned and surfaced by Calendar; NEXUS invents no note date.
- `BUGÜN` and `AY` also begin on the current local date after a fresh home presentation. The full-day 00:00–24:00 timeline, five actual Gym sessions, Wednesday conflict and every underlying user record remain unchanged.
- This is presentation/read-model policy only. It adds no SwiftData field, migration, backup payload, permission, API, Keychain or Touch ID change.

## 0.15.4 provisional timetable history projection correction

- DAILY PLAN now projects the undated provisional previous-year timetable on every matching selected local date, including past, current and future Week/Month inspection. The stored import day remains provenance only; it is not treated as an official semester start or a display cutoff.
- Normal non-provisional semester rules continue to respect their explicit effective start/end dates. This targeted exception therefore does not flatten real semester boundaries.
- HAFTA cards list each actual lesson with its time/course and existing provisional warning. Selecting a historical weekday opens the same occurrence in the full 00:00–24:00 BUGÜN grid; viewing creates no attendance or other persistent record.
- The five stored 21:00 Gym sessions, pinned-note filtering, Wednesday Mobile/Yapay Zeka overlap warning, Robotik mismatch, routes, schemas and all permissions/settings remain unchanged.

## 0.15.3 provisional previous-year timetable

- The seven existing Study courses are not duplicated or renamed. Twelve weekly rules project the supplied Monday–Friday slots into DAILY PLAN Today, Week and Month.
- Every imported rule visibly says `Geçen yıl programı — doğrulanmayı bekliyor`; its activation date is the local import day only and is not presented as an official semester start. No end date, room, exam or attendance record is invented.
- The supplied Wednesday 10:15 overlap between `Mobil Uygulama Geliştirme` and `Yapay Zeka` is retained and produces the existing schedule-conflict warning. NEXUS does not reschedule either lesson.
- The two Robotik rules stay linked to the user's existing `Robotik` course (`251141202`) and visibly disclose the source mismatch `Robotik Kodlama 251111106 → bağlı ders Robotik 251141202`.
- Source and modality metadata use the existing schedule location-override field with a namespaced local encoding. This is presentation metadata, not a SwiftData schema change; JSON backup v9 compatibility and every unrelated record remain unchanged.

## 0.15.2 Daily Plan full-day timeline correction

- The detailed `BUGÜN` timeline always represents the complete selected local day from `00:00` through `24:00`. Its compact 24-points-per-hour scale keeps the whole day in the primary canvas, draws an exact hourly grid, labels every two hours visually, and exposes every hour to VoiceOver.
- A planned Gym session has a start instant but no persisted end or duration. Daily Plan now renders that truthful point as a bordered minimum-height block at its exact time, labels it `Süre belirtilmedi`, and no longer invents a 30- or 60-minute interval for timeline, conflict or proposed-plan calculations.
- Week membership continues to be date-derived. With the current production records, 24–30 August contains only `29 Ağu 21:00 · Bacak B Hafif + Kardiyo`; 31 August–6 September contains the four separately stored Monday–Thursday sessions. NEXUS does not create past, recurring or missing Gym sessions.
- Pinned notes remain fully available in Notes and in the local read model, but are omitted from repeated dated Week/Month cards. This prevents a persistent nutrition-target note from visually competing with actual dated workouts without deleting or modifying the note.
- This is a presentation/read-model correction only: no SwiftData entity, production record, backup schema, permission, API, assistant or Touch ID state changes.

## 0.15.1 Daily Plan Gym title correction

- Planned Gym items in BUGÜN, HAFTA and AY use the actual linked workout/routine title rather than the enclosing generic weekly-plan name. Time and Gym source semantics remain visible; compact cards truncate visually while VoiceOver receives the complete time/title/source label.
- The correction is presentation/read-model only. It does not change a Gym plan, planned-session date, recurrence, completion state, SwiftData schema, backup contract, permission or privacy preference. Only existing planned sessions are shown; NEXUS does not synthesize future workouts.

## Phase 15 voice-first actions

- Spoken or typed create requests are always converted to a transient `VoiceActionDraft`. NEXUS visibly lists and speaks the exact operation, owning model, title, date/time, duration, recurrence, course/project and amount fields. Recognition, deterministic parsing and optional remote interpretation have no persistence capability.
- `Onayla` / `Evet` and Arabic `تأكيد` / `نعم` are explicit confirmation controls. Native Confirm/Edit/Cancel buttons remain available and keyboard accessible. Ambiguous input produces a clarifying question and no draft write. Pending-title/date/time/duration corrections change only the draft.
- Initial independent-model destinations are Study task/course/weekly lesson, Organization task/project, Calendar event/task/reminder, planned Gym session, Finance income/expense and Note. No combined voice entity was added. Existing-record move/cancel support is intentionally conservative: a unique Study/Organization task can be moved/cancelled, and unique Calendar/Gym scheduled records can be moved. Unsupported cancellation semantics are rejected rather than fabricated.
- Validation and duplicate checks run before preview and again before confirmation. Schedule conflicts show `Başka zaman bul / Yine de taslakta tut / İptal`; accepting a conflict still requires a separate final confirmation. The last confirmed voice action can be undone during the current process without touching unrelated records.
- Turkish recognition remains the default. Settings can select Arabic `ar-SA` only when Apple's on-device recognizer reports it available; Arabic wake phrases, core create grammar and confirmations are local. No development permission request was made.
- If local grammar cannot safely interpret a likely write request and a user key exists, NEXUS shows the exact question-only payload before any request. One-time approval calls Responses with `store:false`, one strict `propose_nexus_action` function and no executor/function-result loop. Returned JSON is locally decoded, validated, previewed and still requires explicit confirmation.
- No SwiftData entity changed. Voice draft, conflict, undo, consent, recognition-language and history state are excluded from JSON backup; schema v9 and validated v1-v9 import compatibility remain unchanged.

## Phase 14 opt-in voice assistant

- Voice starts OFF. NEXUS does not ask for Microphone or Speech Recognition at launch. Settings first explains continuous local wake listening, visible status and the hard OFF control; only the explicit `Sesi Etkinleştir` confirmation requests both macOS permissions.
- After enablement, Apple's on-device Turkish Speech recognizer listens in memory for the configurable local phrase `Merhaba Yardımcı`. It requires on-device recognition, creates no audio file and uploads no pre-wake audio. Push-to-Talk remains available. Unsupported on-device recognition is reported honestly.
- Closing the last main window does not terminate NEXUS. A visible menu-bar item keeps the same signed app process available and exposes status, Push-to-Talk, open-window and hard OFF actions. This is not a hidden daemon or login item: Quit, logout, restart or process termination stops it, and NEXUS does not auto-launch at login.
- Touch ID remains the privacy boundary. When the lock is active, voice cannot read reports, navigate data-bearing pages or invoke remote answering. The existing inactivity timer can lock the retained process while its window is closed.
- Deterministic local commands provide today/week, incomplete-task, attendance-risk, deadline, finance and Gym/Focus summaries plus navigation to all eight modules. Reports read independent source models and never write. Future writes have no executor: they must use proposal/preview/confirmation before implementation.
- Unknown questions can use OpenAI only after the user saves their own key in the device-only Keychain field. NEXUS never logs, displays in full, exports or backs up the key. The Settings copy explains that ChatGPT Pro and API billing are separate. Connection Test runs only when the user presses it after saving.
- A normal external question transmits only the typed/spoken question. Grounding with a local report is default-deny: NEXUS shows the exact summary text and named data scopes, then requires one-time Allow. Denial sends nothing. The Responses request uses `store: false` and no write-capable tool.
- Voice history is session-memory only and labels local versus transmitted responses and their data scopes. It is not written to SwiftData or JSON backup.
- Phase 14 changes no SwiftData entity. Backup schema remains v9 with validated v1–v9 import compatibility; voice enablement/wake phrase, permission status, history and API key are excluded.

See `Documentation/VOICE_ASSISTANT.md` for setup, supported Turkish commands, privacy boundaries and exact platform limitations.

## Phase 13 local completion

- GELİŞMİŞ AKŞAM DEĞERLENDİRMESİ opens from DAILY PLAN or Command-Shift-E. It reports only actual selected-day records: scheduled/held/attended/cancelled lessons, source-owned task completion, persisted Focus seconds, planned/completed/logged Gym work, deadlines and overdue counts. A cancelled lesson is never held or absent.
- The configurable local evening time only highlights the manual review action. NEXUS never interrupts the user, opens a destructive dialog automatically or silently reschedules. Acknowledgement is a device-local day key; the review remains manually reopenable.
- Overdue Study and Organization tasks retain four explicit choices. Tomorrow/another date/keep act only after their button is selected; cancelling a source task requires confirmation. No recurrence, attendance, unrelated record or completed task is changed.
- Turkish Quick Entry remains offline and confirmation-gated. Its documented grammar now covers bugün, yarın, öbür gün, a remaining weekday in bu hafta, explicit Turkish dates with optional year, HH, HH:MM, HH.MM, start-end ranges, minutes/hours, finite weekday lesson counts, Study tasks, Calendar tasks/events, lessons and Gym sessions. The explicit final noun chooses the owning model.
- Unsupported or ambiguous text produces an editable non-writing error. Parse and preview do not touch SwiftData; only Onayla ve kaydet writes the validated independent record. No free-form NLP, cloud AI or network request is claimed.
- Phase 13 adds only device-local preferences for review time/acknowledgement, no SwiftData entity or backup payload. JSON backup schema therefore remains v9 and validated v1-v9 imports are preserved.

## External integration preflight — deliberately not implemented

- iCloud/CloudKit needs the user's Apple Developer team/account decision, a production iCloud container identifier, signing/entitlement provisioning and a merge/conflict/data-retention policy before code or migration work.
- Apple Calendar needs an explicit product decision about read/write scope, an EventKit usage description, a user-triggered permission explanation and stable reconciliation rules. Phase 13 requests no calendar permission.
- University/OBS automation needs a named institution/provider, an authorized official API or approved workflow, credential/OAuth ownership and terms/privacy review. Existing OBS tracking stays manual and stores no portal credential.
- Bank sync needs a selected regulated provider/API, supported institutions/region, OAuth/consent and transaction reconciliation policy. Existing Finance remains manual/local; NEXUS asks for no banking secret.
- HealthKit requires confirmation that the target macOS/product distribution supports the intended data types, user-facing health scope and entitlements/permission copy. Existing Gym remains manual and requests no health permission.

## Phase 12.1 strict BUGÜN interaction

- At desktop width, `BUGÜN` follows a fixed terminal hierarchy: compact `… HAFTASI` day rail, narrow hour gutter plus central grid, and right-side `GÜNÜN GÖREVLERİ / KATILIM DURUMU / SEÇİLİ DERS` panels. The bottom status strip and subdued dashboard-only globe remain behind functional content.
- Every eligible right-panel task is a real Button rendered as `[ ]` or `[x]`. Mouse/trackpad activation or focused Space/Return toggles the owning Study, Organization, Calendar-task or planned-Gym record immediately, saves its SwiftData context and never opens an editor or waits for Command-S. A second activation restores the incomplete state.
- Header `GÜN İLERLEMESİ` is task-only and live: exact `completed/total`, a one-decimal percentage only when needed, and a 20-cell terminal bar. Lessons/attendance, assessments, finance due items, notes and history are deliberately excluded because they do not expose the same safe completion contract. The left rail uses the identical policy.
- Timeline lessons remain independently selectable. Their occurrence-specific attendance panel writes only the selected stable occurrence; it never edits the recurring rule or a future lesson.
- `HAFTA` remains the post-boot default. Phase 12.1 adds no entity, backup field, permission, external integration or production sample data.

## Phase 12 DAILY PLAN layout

- `HAFTA` remains the post-boot default. The shared native header now groups the selected date, `BUGÜN / HAFTA / AY`, previous/today/next navigation, NEXUS menu and contextual `Ders planla` action without changing Command-K/F/N/S behavior.
- `BUGÜN` is a responsive operational dashboard. Wide windows use a compact Monday–Sunday rail, a real time grid and a selected-day task/attendance inspector. Medium windows stack the rail horizontally above the timeline/inspector; compact windows become one readable vertical scroll rather than hiding controls.
- The time grid is derived only from the transient DAILY PLAN read model. It displays real lesson occurrences, accepted proposal placements, calendar events and planned gym sessions; flexible tasks remain in the actual selected-day task list. Unoccupied intervals are explicitly labelled free time. No demonstration record ships in production.
- Overlaps receive deterministic lanes across an exact `00:00–24:00` local-day canvas. Existing work-hour free-time settings remain honest overlays rather than cropping bounds, and empty data produces an explicit empty state plus its configured free-time range. Decorative grid/backdrop layers ignore hit testing and accessibility.
- Selecting a lesson exposes its existing per-occurrence attendance status and actions. Those actions retain the invariant that only the stable selected occurrence is updated; cancelled lessons remain excluded from held/absence calculations.
- `HAFTA` and `AY` keep their existing real views and data ownership. The week view adopts the same panel language and completion summaries; no feature entity, SwiftData schema, backup contract, permission or external integration changes in Phase 12.

## Phase 11 application icon

- Finder, Dock and the built application now use a real `AppIcon` asset: a near-black forest-green field with a centered phosphor-green wireframe globe, restrained orbit and four readable network nodes.
- `DesignAssets/AppIcon/render_app_icon.swift` is the deterministic project-owned source. It uses AppKit/Core Graphics only and renders each native representation at 16, 32, 64, 128, 256, 512 and 1024 pixels; no downloaded/generated external asset or package is required.
- `NEXUS/Resources/Assets.xcassets/AppIcon.appiconset` contains the checked-in representations and 1024-pixel master. Xcode compiles them to `AppIcon.icns` and `Assets.car`, while `CFBundleIconName`/`CFBundleIconFile` identify the resource in the built bundle.
- Phase 11 changes presentation metadata only. SwiftData entities, backup schema v9, permissions, navigation and every existing workflow remain unchanged.

## Phase 10 Settings hotfix

- NEXUS now owns one explicit native `Ayarlar…` menu command with `Command-,`; it opens from DAILY PLAN, feature pages and the full-window Control System without relying on SwiftUI's implicit app-settings command.
- Control System displays a non-clickable, keyboard-primary `[9] AYARLAR` line below the stable module routes. Bare `9` opens Settings while the normal `1`–`8` module mapping remains unchanged. VoiceOver announces the line and both `9` and `Command-,` alternatives.
- Settings is a separate native macOS scene. Escape closes it without changing the underlying navigation state: a Control System caller returns to Control System, while a DAILY PLAN caller returns to DAILY PLAN. Search and Command-F/N/S/K behavior are unchanged.

## Phase 10.2: dashboard behavior

- Boot still uses the full wireframe network core. After boot, DAILY PLAN opens in `HAFTA` by default. The user can select `BUGÜN` or `AY` normally; the launch default is applied only once per running app process and does not rewrite data.
- DAILY PLAN alone retains a very low-opacity rotating wireframe globe behind its content. It ignores hit testing and accessibility. Reduce Motion pauses it in a static state. Opening Control System or any numbered feature module removes the layer completely.
- On the first 0.10.2/default window launch, NEXUS expands the primary native window to `NSScreen.visibleFrame`, leaving the menu bar and Dock available rather than entering a separate macOS full-screen Space. A local one-shot preference then permits macOS scene restoration to preserve later user resize and placement choices.

## Phase 10 hotfix: DAILY PLAN new-item flow

- The visible DAILY PLAN `+ Yeni` / `Ders planla` control is always actionable. With no course it opens a native prerequisite course form and then continues to the lesson-plan form after an explicit save; with existing courses it opens the lesson-plan form directly.
- Mouse/trackpad, accessibility activation and Command-N use the same contextual action. The macOS default New Window command group is replaced so it cannot steal Command-N.
- Cancelling either form writes nothing. This hotfix adds no model, schema, backup, permission or integration change.

## Phase 10: boot and navigation presentation

- Every fresh process launch begins with a brief native NEXUS boot transition: a restrained wireframe network core drawn with SwiftUI Canvas, then an automatic transition to DAILY PLAN. It is not a dashboard and reads no fake module data.
- Enter or the explicit `DAILY PLAN'E GEÇ` action skips immediately. Reduce Motion uses a static core and a 0.35-second continuation instead of rotation. VoiceOver receives the final text, never partial animated speech.
- Command-K now opens the full-window `NEXUS KONTROL SİSTEMİ`. Its eight module lines are intentionally not mouse buttons: keys `1`–`8` are primary, Escape returns to DAILY PLAN, and the native NEXUS menu remains the accessible alternate route.
- The prior cross-module local search remains available through `/` inside Control System or Command-Shift-F. Command-F remains the existing context search and Command-N/S semantics are unchanged.
- NEXUS-generated boot/control/status/section headings can reveal progressively with a quiet cursor. `TerminalRevealText` exposes deterministic complete accessibility text, supports interruption/skip, and bypasses animation for Reduce Motion or VoiceOver. It is never applied to TextField, TextEditor, notes, forms, searches or other user-authored content. There is no sound.
- Boot state exists only for the current process. Navigation never replays it and no model, backup or user record changes in Phase 10.

## Phase 9: opt-in local notifications

- NEXUS never requests notification authorization at launch. Settings first explains exactly which enabled categories are eligible, then only the explicit `macOS iznini iste` action calls `UNUserNotificationCenter.requestAuthorization`.
- Categories are lesson start, real incomplete task/exam deadlines, meaningful attendance risk near the configured absence limit, and actual overlap between fixed future intervals. Lead time is 5, 15, 30 or 60 minutes.
- A deterministic 15-day projection uses stable `nexus.v9.*` identifiers. SwiftData query changes, settings changes, foregrounding and the manual reconcile action upsert applicable requests and remove obsolete NEXUS-owned requests without touching another app's notifications.
- Denied/not-determined permission never reports scheduled success. Disabling NEXUS notifications removes pending NEXUS requests; macOS permission itself can only be revoked in System Settings.
- Notification details are hidden by default. The privacy-safe title/body never includes a course, task or person name; this protection is forced when Touch ID lock is enabled.
- Preferences and audit status are device-local. macOS owns authorization. Neither is included in JSON backups.

## Phase 9: optional Touch ID lock

- Enabling requires an explicit Settings action, available biometric policy and successful Touch ID authentication. `LocalAuthentication` uses biometrics only; NEXUS implements no plaintext password or PIN fallback.
- Keychain stores only a device-bound boolean lock-enabled flag. It stores no student data, biometric material, password or credential. Timeout, privacy-mask and notification-detail choices are ordinary device-local preferences.
- When enabled, a new launch starts locked. Returning after the selected inactivity interval (immediate, 1, 5 or 15 minutes) locks the app. An inactive privacy mask hides content; commands and sheets cannot expose module data while locked.
- Authentication failure does not alter or erase data. If biometrics become unavailable, the lock screen reports the real system error and permits clearing only the local lock flag to prevent permanent lockout.

## Existing contracts retained

- Morning Briefing remains once per local day and reads actual data. Focus Mode retains monotonic timing, Stop/Complete separation and guarded source ownership.
- Proposed Daily Plan remains transient until explicit acceptance; Turkish quick entry remains draft/confirmation gated.
- Complete Study, Attendance, Gym, Finance, Notes, Calendar, manual OBS and Organization modules remain independent.
- Numeric module routes `[1]`–`[8]`, Control System `[9] AYARLAR`, Command-K Control System, Command-Shift-F local search, Command-F/N/S, Command-, Settings, Escape, mouse/trackpad and native menus remain.
- Turkish String Catalog remains prepared for English, German, Arabic RTL and French.
- JSON backup schema v9 retains all model payloads and accepts validated v1–v9 imports. Notification authorization/preferences and biometric/Keychain state are deliberately excluded.

## Explicit future boundary

Still not implemented: device sync, Apple Calendar sync, university portal automation, banking sync, HealthKit, cloud/remote notifications, analytics, autonomous writes, unrestricted voice command execution or a bundled AI subscription. Phase 14's optional remote answer path is question/consent scoped and user-funded through a separately configured API key; every NEXUS report remains available locally without it.

See `Documentation/ARCHITECTURE.md` for invariants and `VERIFICATION.md` for exact build, test, backup, permission and launch evidence.
