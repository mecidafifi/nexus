# NEXUS Phase 15 Requirements and Architecture

## Voice-first mutation safety boundary

`LocalVoiceActionParser` runs before the report/question router and reuses `TurkishQuickEntryParser` where syntax overlaps. It also implements a bounded Arabic subset without cloud or model inference. Its only successful output is a transient `VoiceActionDraft`; ambiguity returns a clarification string and no persistence object. Turkish/Arabic confirmation, cancellation, undo and bounded title/date/time/duration corrections are parsed separately by `VoiceActionSpeechControl`.

`VoiceActionPersistenceService.prepare` resolves only unique targets/projects, validates required fields and duplicates, and derives schedule conflicts without saving. `confirm` repeats preparation and is the only persistence entry point. Each case writes only the independent owning entity: Study, Organization, Calendar, Gym, Finance or Notes. A session `VoiceActionUndoToken` names exact created identifiers or captures a minimal source-owned edit snapshot; it is neither persisted nor backed up. Calendar/Gym cancellation is not implemented because those models do not expose a truthful cancelled state.

The optional remote path is an interpreter, not an action tool. A likely unsupported write request first creates `VoiceDraftInterpretationConsent` containing exactly the question text. Only one-time approval and an existing Keychain API key can call `OpenAIResponsesClient.proposeAction`. The request uses `store:false`, disables parallel calls, forces one strict `propose_nexus_action` schema and never sends a function result. Returned arguments are decoded into an inert draft, then pass the same local validation/preview/confirmation boundary. No model response can call `ModelContext`.

Speech recognition locale is a device preference (`tr-TR` default, optional `ar-SA`) and is accepted only when Apple's on-device recognizer reports support. The wake matcher preserves Unicode letters, and speech output selects an Arabic system voice for Arabic responses. Neither locale setting nor Phase 15 transient state changes the SwiftData schema or JSON backup v9.

## Voice process and permission boundary

`VoiceAssistantCoordinator` is the sole lifecycle boundary. Its persisted `voice.enabled` preference defaults false. Initialization reads current permission status but never calls a permission request. Only `enableAfterExplanation`, reached from the explicit Settings confirmation sheet, may request Microphone followed by Speech Recognition. Hard OFF immediately ends recognition/speech, clears pending consent and returns the coordinator to off.

`AppleOnDeviceSpeechRecognizer` sets `requiresOnDeviceRecognition = true` for `tr-TR`, accepts in-memory `AVAudioEngine` buffers, and never creates an audio file. In wake mode it discards nonmatching transcripts locally. A configured phrase match opens the visible orb and changes to command recognition; Push-to-Talk enters the same command path. No audio or transcript is sent to OpenAI by the wake recognizer. Machines without supported on-device Turkish recognition receive an honest unavailable state.

NEXUS uses `applicationShouldTerminateAfterLastWindowClosed = false` and a persistent `MenuBarExtra`. Closing the main window therefore retains the same signed foreground application process with visible listening/status controls. There is deliberately no LaunchAgent, privileged helper, login-item registration or hidden daemon. Quit/logout/reboot stops service, and the user must launch NEXUS again. The menu-bar item is always present so an active listener cannot be concealed.

The existing `AppLockCoordinator` remains authoritative. Its inactivity task can enter locked state while NEXUS is inactive/windowless; the voice coordinator's injected access closure denies every report, navigation and remote-answer path while locked. It never invokes LocalAuthentication itself and cannot bypass Touch ID.

## Local report and command ownership

`VoiceCommandParser` is a deterministic Turkish normalizer/router, not NLP. It recognizes help, today/week, incomplete tasks, attendance risk, deadlines, finance, Gym/Focus and explicit module-open phrases. `VoiceLocalReportService` fetches the independent SwiftData entities and returns a transient `VoiceReport` containing spoken text, visible detail rows and named scopes. Cancelled lesson occurrences are excluded from held lessons. All report methods are read-only and expose no `ModelContext` mutation.

Unknown text is an optional external question, never a local action guess. Local reports and all eight navigation commands work without an API key. No voice write executor exists in Phase 14; a future mutation must introduce a source-owned proposal, editable preview and explicit confirmation rather than reusing the read path.

## Secret, network and consent boundary

`KeychainSecureStringStore` stores only the optional OpenAI API key under `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. The value never enters UserDefaults, SwiftData, logs, UI history, JSON backup or documentation. Settings uses `SecureField`, clears its temporary state after save and shows only saved/not-saved status. The user supplies the key locally; NEXUS never asks for a key in chat and does not provision one.

`OpenAIResponsesClient` has exactly two user-triggered capabilities: an explicit connection test and an answer request. A connection test is unavailable before save. A normal unknown question sends only that question. A local-grounded question first creates `VoiceRemoteConsent`; the sheet lists every `VoiceDataScope` and the exact `transmissionPreview`. Default deny and dismissal transmit nothing; one-time Allow sends precisely that preview with the question. Requests set `store: false`, cap output and expose no local write tool.

ChatGPT plans and API billing are separate products, as described by [OpenAI billing guidance](https://help.openai.com/en/articles/9039756). The optional client uses the official [Responses API](https://developers.openai.com/api/reference/cli/resources/responses/methods/create). Development and verification do not call either endpoint.

Conversation messages are process-memory only and explicitly label local-only versus transmitted content. Voice preferences remain device-local; macOS owns permission decisions. Phase 14 adds no model or backup payload, so schema v9 and validated v1–v9 import remain unchanged.

## Phase 13 evening read boundary

EveningReviewService is a pure transient read service. It receives independent lesson occurrences, per-occurrence attendance, Study/Organization/Calendar tasks, accepted placement links, Focus history, Gym records and OBS assessments. It emits counts/deadline rows only; it never creates a combined entity. Held attendance uses the established present/absent/online/late set, so cancelled and excused records cannot inflate held lessons or absences.

OverdueReviewService remains the only mutation boundary in the review. It resolves a selected row back to its Study or Organization owner. Move tomorrow, choose another date, keep overdue and cancel run only from an explicit control; cancellation has an additional destructive confirmation. The selected review date supplies the local calendar-day semantics. No scheduled lesson rule, future occurrence, attendance row or cross-module record is mutated.

EveningReviewAcknowledgement converts the date through the supplied local Calendar and compares it with one device-local AppStorage key. The configured end-of-day minute merely changes the DAILY PLAN action to a non-disruptive recommended state. The app never auto-presents the review and manual reopen remains available. These preferences are device UI state, not user content, so they are intentionally excluded from backup.

## Phase 13 deterministic Turkish grammar

TurkishQuickEntryParser is an ordered regular grammar with Turkish locale tables for weekdays, month names and small written counts. Supported date tokens are today/tomorrow/day-after-tomorrow, a non-past weekday in the current week, the next named weekday, and a validated explicit date with optional year. Supported clocks are whole hour, colon/dot minutes, hyphen/ile ranges, Turkish -dan/-den … -a/-e ranges, or an explicit minute/hour duration.

The final noun is mandatory and is the ownership discriminator: çalışma görevi creates a StudyTask draft; görev/takvim görevi creates a Calendar task draft; etkinlik creates a Calendar event draft; ders creates a finite StudyScheduleRule/Course draft; spor creates planned Gym session draft(s). Repeated lessons require an explicit weekday plus until date or count. Ambiguous alternatives, invalid dates/times, unsupported text and duplicate owner/time combinations fail without a write.

QuickEntryView exposes every parsed field for editing. QuickEntryPersistenceService.confirm validates the final draft and duplicate guards before inserting exactly one owning model family. Parse/preview/cancel paths never receive a ModelContext write. No external package, network request, probabilistic/NLP model or secret is involved.

No new persisted model was required, so SwiftData and JSON backup schema remain v9. Import validation continues to accept v1-v9.

## External preflight boundary

- CloudKit/iCloud: requires user Apple Developer account/team selection, production container identifier, entitlements/provisioning and merge/conflict/deletion policy.
- Apple Calendar: requires approved EventKit read/write scope, permission copy and reconciliation ownership.
- OBS/university: requires a named institution and approved official API/OAuth/credential policy; scraping or credential capture is not acceptable.
- Banking: requires an authorized provider, region/institution coverage, OAuth consent and reconciliation rules; no secret may be requested before that decision.
- HealthKit: requires confirmed platform/product availability, data-type scope, entitlement and permission UX.

Phase 13 performs no preflight network call, permission request, entitlement change, credential prompt or fake integration.

## Product boundary

NEXUS remains a private, offline-first macOS 14+ SwiftUI/MVVM/SwiftData app. Phase 13 adds only the transient Evening Review read service, explicit source-owned overdue actions and the deterministic preview/confirmation parser expansion. The Phase 12 DAILY PLAN composition, Phase 11 native icon, Phase 10 launch presentation/navigation, Phase 9 local notifications/biometric lock, and all Study, Attendance, Gym, Finance, Notes, Calendar, manual OBS, Organization, Morning Briefing and Focus ownership remain unchanged.

There is no network, cloud, remote push, analytics, external package or account. No Apple Calendar, university portal, bank or HealthKit integration is introduced.

## Phase 12.1 completion ownership and progress invariant

`DailyPlanTaskProgressPolicy` is the single definition of a TODAY checklist row and its progress denominator. It admits only actionable read-model items with a real owner identifier and a safe completion flag: Study task, Organization task, non-event Calendar entry and planned Gym session. Lesson/attendance occurrences, OBS assessments, finance due items, notes, study/focus history and free blocks remain visible in their appropriate panels but never inflate or corrupt task progress. Sorting is deterministic: incomplete first, then time and stable identifier.

`DailyPlanTaskCompletionService` resolves the selected read-model row back to its independent SwiftData owner and toggles only that owner's completion state. Study completion timestamps and source update timestamps are maintained and the context is saved in the same action. The service cannot edit due dates, proposed placements, recurring lesson rules, attendance, grades or finance records. Unsupported or missing owners produce a visible error instead of a speculative write.

The header and week rail both derive from the same transient policy after SwiftData query invalidation, so a direct row activation changes `[ ]` to `[x]`, exact completed/total, percentage and terminal bar without an editor or Command-S. At desktop width, Today is explicitly composed as a compact week rail, narrow time-axis/strong grid and three stacked inspector panels. Decorative lines, free-block dashes and the globe are hit-test disabled; task rows and lesson cards remain native Buttons with stable accessibility identifiers.

## Phase 12 DAILY PLAN presentation boundary

`DailyPlanAggregator` remains the only cross-module read boundary. It emits transient `DailyPlanItem` values linked back to their independent owners; Phase 12 does not add a persistent entity or merge Study, Attendance, Gym, Finance, Notes, Calendar, OBS or Organization data. `DailyPlanTimelinePolicy` filters timed read-model items, derives an honest visible day, sorts selected-day tasks and assigns deterministic greedy overlap lanes. It never persists or reschedules a source.

`DailyPlanDashboardLayoutPolicy` has explicit compact, medium and wide breakpoints. The wide layout is a week rail, time grid and inspector; medium retains the rail as a horizontal strip and keeps timeline/inspector side by side; compact exposes the same controls and content in a single vertical scroll. `ViewThatFits` and horizontally scrollable native toolbars prevent date/navigation/new/menu actions from becoming unreachable. The default launch mode remains `.week` through `DailyPlanPresentationPolicy`.

The detailed Today grid uses only real lesson occurrences, accepted proposal placements, Calendar events and planned Gym sessions. Empty intervals are non-interactive free-time read-model blocks, and a data-free day is explicitly described rather than populated. Flexible Study/Organization/Calendar tasks are listed from the selected-day snapshot in the inspector. Selecting a real item preserves its source route and existing Focus action where ownership permits it.

Attendance actions call the existing stable occurrence workflow. Status lookup and writes use the selected lesson occurrence identifier/date/course only; future recurrence rules are not changed. Cancelled remains a non-held, non-absence state. Grid lines, free blocks and the dashboard globe remain behind content, ignore hit testing, are hidden from accessibility where decorative, and introduce no motion of their own.

The isolated Phase 12 Debug runtime uses a bundle-identifier-suffixed XCTest initialization path so empty-state UI can be inspected without reading or altering the installed user's Keychain lock flag or production store. The branch is compiled only under `DEBUG`; Release always initializes the real lock and persistence services.

## Application icon pipeline

`DesignAssets/AppIcon/render_app_icon.swift` is the authoritative deterministic artwork source. AppKit/Core Graphics draws the near-black rounded field, phosphor globe, latitude/longitude structure, single orbit and four nodes directly at each requested pixel size. Native-size drawing and minimum stroke widths preserve the silhouette at 16–64 px instead of depending on one blind downscale.

The generated, checked-in files live in `NEXUS/Resources/Assets.xcassets/AppIcon.appiconset`. Its macOS idiom slots cover 16/32/128/256/512 points at 1x/2x, including the `NEXUS-AppIcon-1024.png` master. Both target configurations set `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`; Xcode supplies `CFBundleIconName`, `CFBundleIconFile`, `AppIcon.icns` and the complete representations in `Assets.car`.

The asset is artwork and bundle metadata only. It is not used as an in-app dashboard, interactive navigation map, user-data source or network resource. Regeneration performs no model/store migration and requests no permission.

## Launch state and visual boundary

`BootSequenceCoordinator` is an in-memory, one-shot state machine: `booting → dashboard`. It starts only after the Phase 9 app-lock boundary permits access, never persists, never repeats during navigation, and cannot select or mutate a feature route. A cancellable timed task performs the normal transition; the explicit default button always calls the same idempotent completion method, so a failed or cancelled animation cannot trap the app.

`BootNetworkCore` is native SwiftUI Canvas geometry. It draws a central wireframe sphere, projected meridians/latitudes and thin connected nodes with existing phosphor tokens. It has no raster dependency, package, model data or network request. Reduce Motion pauses its timeline and uses the short static continuation policy.

Morning Briefing and active Focus restoration are deferred until the boot state is `dashboard`. If Touch ID is enabled, the lock screen remains first and boot begins once the user unlocks; this preserves the security boundary without exposing data.

## Control System navigation

Command-K presents a full-window terminal layer rather than a floating palette. `ManualNavigationPolicy` deterministically maps `1...8` to the eight stable `AppRoute` cases and maps Control System-only `9` to Settings without adding a ninth feature route. Module and Settings lines are static accessibility elements—not Buttons—and announce their number-key shortcuts. A scoped native key monitor exists only while Control System is visible in module mode; it maps physical top-row and keypad keycodes 1–9, ignores modified/repeated events, and is removed on disappearance. Search/editable fields therefore retain ordinary numeric input. Native menu commands provide the alternate keyboard/VoiceOver path. Escape from Control System always closes it and returns to DAILY PLAN; outside it Escape returns the current feature to DAILY PLAN.

The app replaces SwiftUI's implicit `.appSettings` command group with one explicit `openSettings` action carrying `Command-,`. Like other data-bearing commands, it is disabled while the optional privacy lock blocks access. Control System 9 invokes the same native Settings scene. Opening Settings never mutates `AppState.route`, `isCommandPalettePresented` or search state. Because the scrollable Settings form can consume SwiftUI exit commands, a Settings-scoped native Escape monitor closes only the key window when its identifier is SwiftUI's Settings window; it is removed with that scene. The prior Control System or DAILY PLAN therefore remains intact underneath.

Debug XCTest hosts initialize the lock coordinator with an in-process disabled test state so they never read or mutate the signed user's Keychain lock flag. This path is compiled only under `DEBUG`; production Release always uses the real Keychain-backed initialization.

The former cross-module search is retained as an explicit Control System mode opened by `/` or Command-Shift-F. Search fields and locally stored result titles are normal non-animated controls. Command-F continues to post the existing context-search event; Command-N and Command-S are unchanged.

## Generated terminal text motion

`TerminalRevealText` is restricted to NEXUS-generated boot, control, status and section-heading strings. `TerminalRevealProgress` advances by Swift grapheme cluster, can complete immediately, and provides a deterministic final value for tests. The view's accessibility label/value is always the complete final string. Reduce Motion and VoiceOver bypass partial rendering; editable or user-authored text never uses the component. The effect is silent and contains no audio API.

## Data and preference ownership

| State | Owner | Backup v9 |
|---|---|---|
| Feature records and ended Focus history | SwiftData | Included |
| Notification category, lead-time and privacy choices | device-local UserDefaults/AppStorage | Excluded |
| Notification authorization | macOS `UNUserNotificationCenter` | Excluded |
| Pending local requests | macOS `UNUserNotificationCenter` | Excluded and reconcilable |
| Touch ID lock-enabled flag | Keychain, this-device-only | Excluded |
| Lock timeout and inactive privacy-mask choice | device-local UserDefaults/AppStorage | Excluded |
| Biometric templates/results | Secure Enclave/macOS LocalAuthentication | Never available to NEXUS |

No notification preference, system permission, Keychain flag or biometric state is encoded into a JSON backup. Backup schema v9 changes the compatibility envelope rather than adding an OS-preference payload; validated schemas v1–v9 are accepted.

## Notification architecture

`NotificationReconcilerView` is an invisible SwiftData query observer over Courses/rules/attendance, Study and Organization tasks, Calendar entries, OBS assessments, accepted placements and planned workouts. It builds a transient 15-day `NotificationPlanningSnapshot` whenever relevant records change. It also responds to settings/reconcile events and foreground status refresh.

`LocalNotificationPlanner` is a pure deterministic function. It:

- emits only enabled categories;
- subtracts the selected 5/15/30/60-minute lead time;
- excludes past triggers, completed/cancelled sources and cancelled lesson occurrences;
- emits attendance risk only when absences reach `max(allowed - 1, 1)` and a real next lesson exists;
- emits conflict warnings only for two future fixed intervals with a real positive overlap;
- deduplicates stable `nexus.v9.<category>.<source/occurrence>` identifiers, sorts by fire date then identifier and caps pending plans at 60;
- replaces source content with generic Turkish title/body when hide-details or Touch ID lock is active.

`LocalNotificationService` owns the system boundary through injectable `LocalNotificationCenterClient`. Normal reconciliation can read authorization and add/remove requests only when permission already permits it. The only method that can call `requestAuthorization` is `enableFromExplicitUserAction`, reached solely after the Settings explanation and `macOS iznini iste` action.

Reconciliation reads only NEXUS identifiers, removes obsolete NEXUS requests, and re-adds stable desired identifiers so edits replace rather than duplicate. Denied/not-determined/disabled states remove stale pending NEXUS requests and expose honest audit state; they never claim scheduling success. Disabling cannot revoke the macOS permission and the UI says that System Settings owns revocation.

## Touch ID lock architecture

`AppLockCoordinator` owns lifecycle state: initializing, disabled, unlocked, locked, authenticating or unavailable. `BiometricAuthenticating` and `SecureBoolStore` are injectable for hardware-independent tests. Production adapters are `LAContext` with `.deviceOwnerAuthenticationWithBiometrics` and `KeychainBoolStore`.

The Keychain entry is one byte under the NEXUS security service with `AfterFirstUnlockThisDeviceOnly`. It indicates only that the app lock is enabled. No password, PIN, token, biometric value or student record is stored.

Enablement order is invariant:

1. User reads Settings explanation and presses Enable.
2. NEXUS verifies biometric availability.
3. NEXUS asks LocalAuthentication for Touch ID.
4. Only success writes the Keychain flag and enters unlocked state.

At launch an existing flag produces locked state before module content is created. When the scene becomes inactive, sheets/palette close and an optional privacy mask covers the app. On return, elapsed wall time is compared to the configured inactivity threshold; the app locks at or beyond that boundary. Commands and routes guard against access while locked. A running Focus controller remains in app memory but its sheet is hidden; it can return after unlock without silently completing or discarding the session.

Authentication failure never deletes or changes user data. If the biometric policy is no longer available while the flag exists, the lock screen shows the actual LocalAuthentication error and offers a narrowly scoped recovery action that clears only the local lock flag. NEXUS does not implement a password/PIN fallback and does not claim biometric availability on every Mac.

## Navigation and accessibility

Settings exposes the native macOS permission status, NEXUS pending count, granular categories, lead time, privacy mode, reconcile/disable actions, Touch ID status, inactivity choices and manual lock. The notification opt-in explanation has accessibility identifier `notifications.optIn`; Settings has `settings.phase9.screen`; locked content has `lock.screen`; the inactive shield has `privacy.mask`.

All Phase 1–8 keyboard commands and numbered routes remain. While locked, data-navigation, create, save, search and palette commands are disabled. Return activates the primary unlock/permission action where appropriate, and non-color status labels accompany success, warning and error states.

## Testing boundary

Pure planning tests cover deterministic identifiers, no-past/no-duplicate behavior, lead time, category filters, privacy redaction, attendance threshold and conflict pair stability. A fake notification center proves authorization request isolation, denied/not-determined guards and NEXUS-only reconciliation. Fake biometric and secure stores prove launch lock, explicit enable success/failure, unavailable fallback, Keychain-write ordering, timeout and privacy mask without depending on host hardware.

Host runtime inspection may read the current notification/Touch ID availability and inspect the explanation/lock UI, but verification must not grant system permission or enable persistent biometric lock merely for a test. XCUITest execution remains separately subject to the host's macOS Accessibility/UI-automation authorization.

## Explicit future boundary

Phase 11 does not add or change SwiftData/backup schemas, feature workflows, device sync, Apple Calendar sync, university automation, bank sync, HealthKit, remote/push service, cloud analytics, permissions, plaintext credential fallback, broad natural-language AI or advanced Evening Review analytics. It retains all Phase 10 presentation and navigation invariants below.

## Phase 10 hotfix invariant

`DailyPlanNewItemPolicy` is the single deterministic decision point for DAILY PLAN creation. Zero courses selects the native `CourseEditorView`; one or more courses selects `DailyPlanRuleEditor`. The prerequisite editor reports an explicit successful save before the schedule editor can follow, so cancellation never persists or advances. The visible control is not disabled merely because the prerequisite is missing.

The File menu replaces macOS's default New Window command group with NEXUS's contextual new-item command. Therefore mouse activation, accessibility activation and Command-N all publish the same `.nexusNewItem` event without creating an unrelated window. Existing Command-Shift-N quick entry and all numeric Control System routes remain unchanged.

## Phase 10.2 dashboard presentation invariant

`DailyPlanPresentationPolicy` owns the launch mode and decorative-layer boundary. The process-local `AppState.consumeDailyPlanLaunchDefault()` returns `.week` exactly once, preventing SwiftUI scene restoration from replacing the required boot-to-HAFTA transition while still preserving manual mode changes during that process. The globe is admitted only when `route == nil` and Control System is not presented; feature pages and the Control System therefore neither render nor animate it.

`DailyPlanNetworkBackdrop` reuses the native Canvas globe at 5.5–7.5% opacity. It is behind content, has no actions, ignores hit testing and is hidden from accessibility. Reduce Motion pauses the TimelineView and produces a static frame.

`PrimaryWindowConfigurator` applies the primary window's `NSScreen.visibleFrame` provisionally during boot and once more after dashboard layout settles. Only then does it set `window.primaryDidApplyDefaultMaximize.v1`. It never requests a full-screen Space. Later launches do not change the window frame, leaving native scene restoration and explicit user placement intact.
