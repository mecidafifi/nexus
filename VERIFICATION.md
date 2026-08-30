# 0.15.5 Rolling Upcoming Daily Plan Verification — 29 August 2026

| Validation layer | Result |
|---|---|
| Navigation policy | Fresh launch/home selection is local today and `HAFTA`. The seven cards are anchored to that day instead of the locale calendar week; previous/next retain explicit seven-day historical/future access. |
| Exact current range | Native isolated production-snapshot AX and screenshot showed `29 Ağu–4 Eyl \| ÖNÜMÜZDEKİ 7 GÜN` with Saturday 29, Sunday 30, Monday 31, Tuesday 1, Wednesday 2, Thursday 3 and Friday 4. No 24–28 August card was present in the default range. |
| Real future content | The same native view showed the actual Saturday 21:00 Gym session; Monday–Thursday provisional lessons plus the four separately stored 21:00 Gym sessions; Friday's Fizik I; and the real dated Calendar item. Cards kept provisional/mismatch labels and the Wednesday overlap source data. |
| Note policy | The persisted Note model exposes no due/reminder date, so no undated/pinned Note is aggregated into any Daily Plan date. The nutrition note remains unchanged and available in Notes; dated Calendar reminders remain Calendar records. |
| Past accessibility | Focused policy/integration tests prove explicit prior navigation projects the historical provisional lessons unchanged. Viewing a range creates no occurrence, attendance or source-model mutation. |
| Debug/tests | arm64 build-for-testing passed; 171 unit/integration tests executed, 171 passed, 0 failed, 0 skipped. The combined scheme run again reached the existing host XCUITest authorization/tool-service wait; only that hung `xcodebuild` process was interrupted and the unit target was rerun successfully. |
| Isolated integrity | The UI used a separate Debug bundle and online production-store snapshot. Before/after logical SQL dumps are byte-identical; quick-check is `ok`; data remains seven courses, 12 active provisional rules, zero attendance linked to those rules and five planned Gym sessions. |
| Release | Passed — 0.15.5 (25), optimized universal `x86_64 arm64`; strict deep codesign passed. Executable SHA-256: `ba89c45e81a97fe370416d51296786046b4da6b1680312df57c420805044f7bc`. |
| Backup/install | Exact running Desktop 0.15.4 (24), online snapshot, checkpointed closed store/sidecars, device preference copy and logical SQL dumps are under `work/rolling-upcoming-week-preinstall-backup`. Checkpoint was `0\|0\|0`; integrity is `ok`, source/copy store SHA-256 values match and pre/post-install dumps are byte-identical. |
| Desktop runtime | Exact `/Users/mecid/Desktop/NEXUS.app` 0.15.5 (25) runs as PID `37672`; executable SHA matches the verified Release, strict codesign passes and `lsof` proves that binary has the real production store open. The legitimate Touch ID lock screen appeared and was not bypassed. |

This release changes no user record, SwiftData schema, backup contract, notification/voice/API preference, permission, Keychain item or Touch ID state. Unlocked feature evidence comes from the separate exact-store snapshot; installed-production inspection stopped at its legitimate biometric boundary.

# 0.15.4 Provisional Timetable History Projection Verification — 29 August 2026

| Validation layer | Result |
|---|---|
| Root cause | The provisional import stored 29 August as `effectiveStart` for provenance. The generic occurrence guard treated it as an authoritative lower semester boundary, hiding otherwise-active Monday–Friday rules on 24–28 August and all earlier selected dates. Week cards were already capable of listing every item; their snapshots were empty because of that guard. |
| Targeted fix | `ScheduleRuleProjectionPolicy` treats namespaced provisional previous-year rules as undated recurring read-model rules for any matching selected date. Ordinary rules still enforce their explicit start/end range. No schedule row or date is rewritten. |
| Projection regressions | The exact 12-rule fixture now produces `[2,3,4,2,1,0,0]` lessons for a past week, 24–30 August and 31 August–6 September; Monday/Tuesday/Wednesday titles and ordering, Sunday empty state, Robotik mismatch and the one Wednesday 10:15 overlap are asserted. |
| Non-mutation | An in-memory persistence test projects the same provisional rule across past/current/future Mondays and proves attendance remains zero and the rule count, start date, updated date and active state do not change. The isolated exact-store runtime's before/after logical SQL dumps are byte-identical. |
| Native current-week runtime | Against an online production-store snapshot, HAFTA 24–30 August exposed all Monday–Friday lesson cards with exact time/title and kept only the real Saturday 21:00 Gym card; Sunday alone was honestly empty. No pinned nutrition note appeared as a dated card. |
| Historical BUGÜN runtime | Selecting Monday 24 August opened the full `00:00–24:00` timeline with selectable `10:15 Siber Güvenliğe Giriş` and `13:00 Optimizasyon`, provisional warnings and unmarked attendance text. |
| Debug/tests | arm64 build-for-testing passed; 169 unit/integration tests executed, 0 failures, 0 skipped. |
| Release | Passed — 0.15.4 (24), optimized hardened universal `x86_64 arm64`; strict deep codesign passed. Verified/installed executable SHA-256: `fea523c6a1df52abb72027a9128ac86d4cca9f30def17faa4abf3f85675fe386`. |
| Backup/install | Exact running Desktop 0.15.3 (23), online store, checkpointed closed store/sidecars and before-install logical dump are under `work/provisional-history-hotfix-preinstall-backup`. Checkpoint returned `0|0|0`; source/copies integrity are `ok`, and the closed source/copy SHA-256 values match. |
| Desktop runtime | Exact `/Users/mecid/Desktop/NEXUS.app` 0.15.4 (24) runs as PID `32152`; `lsof` proves that binary and the real production store are open. Existing Touch ID/system authentication boundary was not bypassed. Production quick-check is `ok` and before/after-install logical dumps are identical. |
| Data/schema boundary | Production and isolated data remain seven courses, 12 active provisional rules, zero attendance linked to those rules and five planned Gym sessions. No model/schema, route, metadata, note, Gym, permission, API, voice, Keychain or Touch ID change. |

# 0.15.3 Provisional Previous-Year Timetable Verification — 29 August 2026

| Validation layer | Result |
|---|---|
| Safety backup | Before any mutation, the exact production store received an online SQLite snapshot and a clean closed-store/sidecar snapshot under `work/provisional-timetable-preimport-backup`; online, source and closed-copy integrity checks returned `ok`. The prior Desktop 0.15.2 (22) bundle is included. |
| Existing courses | The closed production store contains exactly the seven intended course name/code pairs, one row each. Import links rules by their existing UUIDs and creates no course row. |
| Imported rules | Twelve active weekly rules: Monday 2, Tuesday 3, Wednesday 4, Thursday 2 and Friday 1. All are source-labelled, have no recurrence end, and activate on the local import date without claiming it is a semester boundary. Two obsolete Bilimsel 09:00 rules are retained but inactive; no schedule row is deleted. |
| Conflict/mismatch | Native BUGÜN accessibility on Wednesday 2 September exposed `1 zaman çakışması bulundu` and separate selectable 10:15 blocks for Mobile and Yapay Zeka. Dönem Planı exposed the Robotik source mismatch on both linked rules. |
| Daily Plan runtime | Native isolated production-snapshot AX showed correct HAFTA projections for 31 Aug–6 Sep, the exact 00:00–24:00 Wednesday timeline, AY entries for every weekday rule, and every card announced `Geçen yıl programı — doğrulanmayı bekliyor`. |
| Preserved records | The isolated store remained at seven courses, one pre-existing attendance record and five planned Gym sessions. HAFTA continued to show the real five 21:00 Gym intentions on their existing dates; no attendance status, Gym record or unrelated data was added or edited. |
| Debug/tests | arm64 build-for-testing passed; 168 unit/integration tests executed, 0 failures, 0 skipped. The focused test proves exact occurrence counts/order, no end dates, source/mismatch labels and one deterministic Wednesday overlap. |
| Release | Passed — 0.15.3 (23), optimized hardened universal `x86_64 arm64`; strict deep codesign passed. Verified/installed executable SHA-256: `642f9526ad8771901b7a4ea88010f7fb6f785dd562c8d2fa23ac515609f1e4a2`. |
| Production mutation | With no process holding the store, the validated transaction produced 12 active provisional rules and retained two prior erroneous Bilimsel rules as inactive. Protected non-schedule SQL dumps before/after are identical; post-import checkpoint is `0|0|0`, integrity is `ok`, and no active provisional rule has an attendance record. |
| Desktop runtime | Exact `/Users/mecid/Desktop/NEXUS.app` runs as PID `30068` and `lsof` proves that binary plus the production store. Existing Touch ID lock appeared; no biometric action, Keychain flag or lock preference was touched. Unlocked UI evidence is from the isolated exact-store snapshot, not falsely presented as unlocked production evidence. |
| Schema/privacy | No SwiftData entity, backup schema, API, permission, voice, microphone, Keychain or Touch ID change. Provisional metadata is stored in the existing rule metadata string and decoded only for presentation. |

# 0.15.2 Daily Plan Full-Day Timeline Verification — 29 August 2026

| Validation layer | Result |
|---|---|
| Root cause | `BUGÜN` timeline bounds were fixed to 08:00–20:00 while the real Saturday `PlannedWorkoutSession` starts at 21:00. Aggregation also supplied a fabricated 60-minute Gym end, even though that entity persists no duration/end. The dated-card read model repeated every pinned note on every day. |
| Presentation fix | Timeline bounds are exactly 00:00–24:00 with a compact 24 pt/hour scale, hourly grid semantics, two-hour visual labels and all 25 boundary labels available to accessibility. A start-only Gym record is a minimum-height point block at its exact time with `Süre belirtilmedi`; it is not treated as an interval. |
| Exact production dates | Read-only store audit proves five and only five planned Gym sessions: Sat 29 Aug 21:00, Mon 31 Aug 21:00, Tue 1 Sep 21:00, Wed 2 Sep 21:00 and Thu 3 Sep 21:00. No session, recurrence, past date or duration was created or edited. |
| Week separation | Isolated native HAFTA AX showed only `21:00, Bacak B Hafif + Kardiyo` in 24–30 Aug. After Next Week it showed exactly `Üst Vücut A`, `Bacak A`, `Kardiyo ve Karın`, and `Üst Vücut B` at 21:00 in 31 Aug–6 Sep. |
| BUGÜN runtime | On the isolated online production-store snapshot, native AX exposed `00:00–24:00 tam günlük zaman çizelgesi`, hour boundaries 00:00 through 24:00, and selectable `21:00, Bacak B Hafif + Kardiyo, Spor, Süre belirtilmedi`. The full desktop canvas screenshot is `work/dailyplan-full-day-runtime-saturday.png`. |
| Pinned note | `Beslenme ve Toparlanma Hedefleri — Kullanıcı Planı` remains pinned and unchanged in `ZNEXUSNOTE`/Notes. Presentation-only filtering keeps it out of repeated Week/Month dated cards; AX week snapshots contained no duplicate note card. |
| Debug/tests | arm64 build-for-testing passed; 167 unit/integration tests executed, 0 failures, 0 skipped. Result bundle: `work/dailyplan-full-day-tests-2.xcresult`. |
| Release | Passed — 0.15.2 (22), optimized hardened universal `x86_64 arm64`; strict deep codesign passed. Verified/installed binary SHA-256: `2a095acd2a97b97fc703de8b0a16a898837816bba0ce5dea69b80082a170917f`. |
| Backup/install | Running 0.15.1 (21) bundle, `lsof`-resolved online store, cleanly checkpointed closed store/sidecars and preference copy are under `work/dailyplan-full-day-preinstall-backup`. Checkpoint returned `0|0|0`; source/copies/postinstall integrity are `ok`; pre-close/closed/postinstall logical dumps are identical. |
| Desktop runtime | Exact `/Users/mecid/Desktop/NEXUS.app` runs as PID 25320 and has the actual production store open. Existing Touch ID lock appeared after relaunch; no biometric action, Keychain flag, lock preference or user data was changed. |

This targeted release changes presentation/read-model policy only. It adds no data/schema migration, backup payload, permission, API/voice behavior or external integration. The unlocked feature path was exercised only in a separate Debug bundle with an online production-store snapshot; installed production inspection stopped at its legitimate Touch ID boundary.

# 0.15.1 Daily Plan Gym Title Correction Verification — 29 August 2026

| Validation layer | Result |
|---|---|
| Root cause | Daily Plan aggregation assigned every linked `PlannedWorkoutSession` the enclosing `WorkoutPlan.name`, so all five real cards displayed the generic weekly-plan title even though each session carried a specific routine title in its linked plan metadata. |
| Fix | One deterministic presentation policy resolves the existing session's exact routine title and is shared by aggregation, Today timeline/inspector, Week cards, Month mini-cards and planner fixed-item labels. Custom session titles are preserved; no future session is generated. |
| Focused regressions | Passed — all five real routine-name shapes resolve to `Üst Vücut A`, `Bacak A`, `Kardiyo ve Karın`, `Üst Vücut B`, and `Bacak B Hafif + Kardiyo`; time remains 21:00, record link remains stable, custom/unlinked fallbacks remain safe. |
| Debug/tests | arm64 build-for-testing passed; 165 unit/integration tests executed, 0 failures, 0 skipped. |
| Isolated production snapshot | Passed — SQLite quick/integrity checks `ok`; native HAFTA AX exposed a selectable full label `21:00, Bacak B Hafif + Kardiyo, Spor`; compact visual card showed the same clean title. Before/after logical dumps were byte-identical. |
| Release | Passed — 0.15.1 (21), signed hardened universal `x86_64 arm64`; strict deep codesign verification passed. |
| Backup/install | Running 0.15.0 (20) app and exact `lsof`-resolved online/closed store backups are under `work/dailyplan-gym-title-preinstall-backup`; checkpoint `0|0|0` and integrity checks passed. Verified Release/installed executable SHA-256 match. |
| Desktop runtime | Exact `/Users/mecid/Desktop/NEXUS.app` runs as PID 22641 and opens the same production store. Native AX reached the existing Touch ID lock screen; no biometric action or lock-setting change was attempted. Pre/post logical store dumps are identical. |

This correction changes no Gym data, plan, date, schema, JSON backup compatibility, personalization, permission, assistant/API or Touch ID state. The live production interface cannot be inspected beyond its existing lock without the user's normal biometric unlock; the exact code path was therefore exercised against an isolated online production-store snapshot, not presented as unlocked-live evidence.

# Phase 14 Opt-in Voice Assistant Verification — 29 August 2026

## 0.14.0 result

| Validation layer | Result |
|---|---|
| Scope | Passed — native opt-in local wake assistant, Push-to-Talk, visible menu-bar/background lifecycle, deterministic local reports/navigation, Keychain API setup and one-time exact data-scope consent; no external package, login helper, write action, bundled key or development API call |
| Permission guard | Passed — fresh isolated runtime showed `KAPALI`; microphone and Speech Recognition controls remained disabled until the explicit Settings explanation/enable path. Verification did not press Enable and no permission dialog was requested. |
| Local speech boundary | Passed by injectable service tests — `tr-TR` recognizer requires on-device recognition, creates no recording file, wake phrase is local, hard OFF stops recognition, and a Touch ID lock suspends/resumes wake listening without reading data. Host microphone was intentionally not activated. |
| Debug arm64 build-for-testing | Passed — application, 142-test unit/integration target and UI regression target compile/link; log `work/phase14-final-build-for-testing.log` |
| Unit/integration tests | Passed — 142 executed, 142 passed, 0 failed, 0 skipped; final result `build/phase14-final-debug/Logs/Test/Test-NEXUS-2026.08.29_15-31-43-+0300.xcresult` |
| Focused Phase 14 tests | Passed — 17 tests cover phrase/parser routes, no implicit permission, explicit enable/hard OFF, privacy lock suspension, Keychain-only secret ownership, question-only transmission, default-deny grounding, exact approved payload, lock guards, real/cancelled data semantics, read-only reports, write-proposal contract and backup exclusion |
| Native isolated runtime | Passed — boot transitioned to HAFTA; Command-Shift-V exposed `NEXUS // SESLİ YARDIMCI`, `KAPALI`, default `Merhaba Yardımcı`, disabled Push-to-Talk and local/transmission help. Settings exposed the explicit enable explanation and blank SecureField. Closing the main window left the same visible menu-bar app process running. |
| Network/API | Not invoked by design — no key was requested or provisioned, Keychain lookup confirms no Phase 14 API-key item exists, and no Connection Test/Responses request ran. Fake remote tests prove question-only versus consent-grounded payloads. |
| Release | Passed — `0.14.0 (19)`, optimized hardened universal Mach-O `x86_64 arm64`; strict deep codesign verification passed. Entitlements are sandbox, user-selected files, microphone input and outbound network for the later explicit user-key flow. |
| Release/installed executable SHA-256 | `ee164236966f306a82b7cd58fdb5b6c871c5d1543a0999e2d21659bd1a5b0b6a` |
| Preinstall recovery | Passed — 0.13.0 build 18 Desktop bundle, resolved production store/WAL/SHM and device preference plist are under `work/phase14-preinstall-backup`; checkpoint returned `0|0|0`, source/copy store hashes match and both integrity checks returned `ok` |
| Closed production-store SHA-256 | `8a5740149107b13cfeff46f83dd1fc9f0dee735e2fa34e979530f4e1bf152bba` |
| Desktop install/runtime | Passed — byte-identical `/Users/mecid/Desktop/NEXUS.app` is 0.14.0 (19), signed and running as PID 9687 from the exact Desktop binary; `lsof` proves the resolved production store is open and post-launch integrity is `ok` |
| Touch ID boundary | Preserved — no Touch ID click, authentication, Keychain lock flag change, preference mutation or security bypass was attempted. The final exact Desktop runtime opened normally under the user's current persisted lock state; this is not claimed as a biometric-hardware test. |
| Backup compatibility | Unchanged intentionally — voice settings/history/permissions and API Keychain state are not SwiftData content. Schema remains v9, accepts validated v1–v9 imports and serializes no voice secret/history field. |
| XCUITest boundary | UI target, including the off/no-permission voice-panel regression, compiles. Full host XCUITest execution remains unavailable under the existing macOS UI-automation authorization; equivalent isolated native AX inspection supplied launch/panel/settings/window-lifecycle evidence. |

Background availability is precise: NEXUS stays alive after its last main window closes through the normal signed app process and visible menu-bar item. It is not a daemon, privileged helper or login item; Quit, Force Quit, logout, restart or a crash stops listening. When Touch ID locks the retained process, wake recognition is proactively suspended until a normal unlock.

The only remaining user actions are optional and occur inside Settings: normally unlock NEXUS; press `Sesli Yardımcıyı etkinleştir…`; read and confirm the explanation; grant macOS Microphone and Speech Recognition permissions. Local reports then work without an API key. For optional non-local answers, the user must separately enable OpenAI API billing, paste their own key into the local SecureField, save it to Keychain and explicitly press Connection Test. ChatGPT Pro billing is separate. NEXUS never asks for a key in chat.

# Phase 13 Local Completion Verification — 28 August 2026

## 0.13.0 result

| Validation layer | Result |
|---|---|
| Scope | Passed — Advanced Evening Review, deterministic Turkish quick-entry expansion and documentation-only external prerequisite audit; no external service, permission, entitlement or network request was added |
| Debug arm64 build-for-testing | Passed — application, unit target and UI route target compile/link |
| Unit/integration tests | Passed — 125 executed, 125 passed, 0 failed, 0 skipped; result `/Users/mecid/Library/Developer/Xcode/DerivedData/NEXUS-cdzpigyrqxgwfbefjvzodkmntulp/Logs/Test/Test-NEXUS-2026.08.28_04-48-43-+0300.xcresult` |
| Focused Phase 13 tests | Passed — 11 tests cover Istanbul local-day acknowledgement/thresholds, cancelled-lesson semantics, actual metrics/deadlines, valid/invalid grammar, legacy grammar, finite recurrence, independent-model routing, duplicate guard and no-write parsing |
| Evening Review runtime | Passed in an isolated signed native Debug runtime using an exact closed production-store snapshot — button and Command-Shift-E both opened `GELİŞMİŞ AKŞAM DEĞERLENDİRMESİ`; AX reported 15/15 actual selected-day tasks, 0/0 held lessons, 0 focus minutes, 0/0 gym and no fabricated deadlines/overdue records |
| Quick Entry runtime | Passed — `Yarın saat 14:30'da Rapor çalışma görevi, 45 dakika` produced an editable Study-task preview for 29 August 2026 at 14:30, duration 45 minutes; Cancel returned to DAILY PLAN and a closed-store inspection confirmed no `Rapor` record was persisted |
| Release | Passed — `0.13.0 (18)`, optimized hardened universal Mach-O `x86_64 arm64`; strict deep codesign verification passed |
| Release/installed executable SHA-256 | `9445823efc12f338ab79eaf4c66b453990db51e321256ebea9a07ef29855cbe1` |
| Preinstall recovery | Passed — no process held the resolved production store; checkpoint returned `0|0|0`, source/copy integrity returned `ok`; exact 0.12.1 build 17 Desktop bundles plus store/WAL/SHM are under `work/phase13-preinstall-backup` |
| Closed production-store SHA-256 | `f0fd54d4209cd71eb284f2fc45fc12e31db5e11cfb719eed1cd910ebe861ff49` |
| Desktop install/runtime | Passed — byte-identical `/Users/mecid/Desktop/NEXUS.app` is 0.13.0 (18), signed and running as PID 57755 from the exact Desktop binary with the resolved production store open |
| Touch ID boundary | Preserved — no biometric prompt, authentication state, Keychain flag or security preference was bypassed or changed. Native feature interaction used only the isolated Debug runtime; the production Release was validated by exact binary path/PID/store evidence. |
| Backup compatibility | Unchanged intentionally — Phase 13 adds only device-local review time/acknowledgement preferences, so backup schema remains v9 and validated v1-v9 imports remain supported |
| XCUITest boundary | UI route target compiles. Full host XCUITest execution remains unavailable under the existing macOS UI-automation authorization; native accessibility/Computer Use supplied Phase 13 button, shortcut, preview, cancellation and AX-value evidence. |

The Evening Review never silently moves a task: overdue Study/Organization items expose source-owned choices for tomorrow, another date, keep overdue or cancel, with cancellation confirmation. Review acknowledgement is local-day scoped and the configured end-of-day time only highlights availability; it never forces a sheet or performs a destructive action.

The Turkish parser remains offline and deterministic. It accepts only documented unambiguous task/event/lesson/gym forms, creates an editable preview without a `ModelContext`, and writes to one independent owning model only after explicit confirmation. No SwiftData entity or backup payload was needed.

# Phase 12.1 Strict BUGÜN Verification — 28 August 2026

## 0.12.1 result

| Validation layer | Result |
|---|---|
| Scope | Passed — strict BUGÜN layout/direct task interaction only; no entity, backup schema, permission, integration or feature-module change |
| Debug arm64 build-for-testing | Passed — application, unit target and updated UI route target compile/link; log `work/phase12_1-debug-final.log` |
| Unit/integration tests | Passed — 114 executed, 114 passed, 0 failed, 0 skipped; result `build/phase12_1-debug/Logs/Test/Test-NEXUS-2026.08.28_04-08-51-+0300.xcresult` |
| Added regressions | Passed — task-only eligibility, exact 6/15 = 40% and 7/15 = 46.7%, ASCII bar, direct StudyTask persistence, completion timestamp and reversible planned-state restoration |
| Runtime geometry | Passed in isolated signed Debug probe with an exact closed-store snapshot — compact week-of rail, narrow 08:00–20:00 time gutter/grid, dashed free block, right TASKS/ATTENDANCE/SELECTED LESSON stack and bottom strip; evidence `work/phase12_1-runtime-today-6-of-15.png` |
| Direct pointer toggle | Passed — native AX activation of `TEST — Günlük görev 07` changed `[ ]` to `[x]`, header/right panel/week rail from 6/15 40% to 7/15 46.7%; second activation restored 6/15 40% |
| Keyboard toggle | Passed — Tab focused the stable task button; Return changed 6/15 to 7/15 and retained focus on the reordered `[x]` row; Space changed it back to 6/15 `[ ]` |
| Release | Passed — `0.12.1 (17)`, optimized hardened universal Mach-O `x86_64 arm64`; strict deep codesign verification passed |
| Release/installed executable SHA-256 | `d1b91997d429b341e0a81593c8f19ee4202b4e3a9bcac2c7fc2f9ae1cf021607` |
| Preinstall recovery | Passed — live 0.12.0 (15), interim 0.12.1 (16), closed production store and sidecars are under `work/phase12-1-preinstall-backup`; checkpoints returned `0|0|0` and copied-store integrity is `ok` |
| Desktop install | Passed — byte-identical `/Users/mecid/Desktop/NEXUS.app` is 0.12.1 (17), signed and running as PID 53811 from the exact Desktop binary with the actual production store open |
| Live data final state | Preserved — read-only SQLite evidence reports exactly 15 `TEST — Günlük görev` records, 6 completed, 9 incomplete, task 07 `planned`; production store SHA-256 still exactly matches the preinstall closed snapshot and integrity is `ok` |
| Touch ID boundary | Preserved — final Desktop runtime is at `NEXUS KİLİTLİ`; no biometric prompt, Keychain flag or security setting was bypassed or changed. Post-install live checkbox activation therefore remains blocked until the user normally unlocks it. |
| Isolated-data hygiene | Passed — after UI verification, the copied live store was removed from the probe container and its original empty store restored; probe task count is 0 |
| XCUITest boundary | UI regression target compiles. Full host XCUITest execution remains unavailable under the unchanged macOS UI-automation authorization; native accessibility/Computer Use supplied the pointer, keyboard, geometry and AX-value evidence above. |

`DailyPlanTaskProgressPolicy` defines one denominator for header, rail and task panel: only source records with a real safe completion state are included. `DailyPlanTaskCompletionService` changes only the owning Study/Organization/Calendar-task/planned-Gym record and saves immediately. Lessons/attendance, OBS assessments, finance due items, notes, histories and free blocks do not corrupt the ratio.

The final Desktop app is installed and open, but Touch ID intentionally prevents automated access to the user's live interface after relaunch. The strict final code was therefore exercised against an isolated byte-identical closed-store snapshot, while read-only production-store checks prove the live data stayed at the requested 6/15 state. Normal user unlock is the only remaining step for a final live click-through; no security workaround was attempted.

# Phase 12 DAILY PLAN Layout Verification — 28 August 2026

## 0.12.0 result

| Validation layer | Result |
|---|---|
| Scope | Passed — DAILY PLAN presentation/read-model layout only; no SwiftData entity, backup schema, permission, integration or feature-module redesign |
| Debug arm64 build-for-testing | Passed — app, 112-test unit target and updated UI regression target compile/link; log `build/phase12-final-debug-build.log` |
| Unit/integration tests | Passed — 112 executed, 112 passed, 0 failed, 0 skipped; result `build/DerivedData-Phase12-final/Logs/Test/Test-NEXUS-2026.08.28_02-56-43-+0300.xcresult` |
| Focused Phase 12 tests | Passed — responsive breakpoints, early/late timeline bounds, deterministic overlap lanes, honest empty/free-only state and real populated task ordering/read-model coverage |
| Release | Passed — `0.12.0 (15)`, optimized hardened universal Mach-O `x86_64 arm64`; strict deep codesign verification passed |
| Release/installed executable SHA-256 | `78507d61cc590a16312b6c69668ff8d6160d5322d43bd247b7d30c8f0f141e6a` |
| Runtime empty state | Passed in isolated native Debug app — HAFTA remained the clean-launch default; BUGÜN exposed the week rail, 08:00–20:00 honest free timeline, empty tasks/inspector and low dashboard-only globe with no fake record |
| Runtime controls | Passed — `Ders planla` opened the real prerequisite course editor and cancellation wrote nothing; NEXUS menu opened by mouse/accessibility and Escape returned to DAILY PLAN |
| Populated behavior | Passed through in-memory unit/integration snapshots — actual source-linked lessons/events/tasks/placements exercise aggregation, ordering, overlapping lane and selected-occurrence attendance invariants without shipping fixtures |
| Backup | Passed — lsof resolved the live store, app closed, checkpoint `0|0|0`; source and copied store integrity `ok`; 0.11.0 bundle plus store/WAL/SHM are in `work/phase12-dailyplan-layout-preinstall-backup` |
| Desktop install/runtime | Passed — exact `/Users/mecid/Desktop/NEXUS.app` Release is PID `42064`; lsof proves the installed binary and actual sandbox store are open; live store integrity is `ok` |
| Privacy lock | Preserved — installed runtime correctly opens at the user's existing Touch ID lock screen; no authentication, lock setting or Keychain state was bypassed or changed |
| XCUITest boundary | UI regression target compiles. Full XCUITest execution remains unavailable because the host's existing macOS UI-automation authorization is unchanged; equivalent empty-state/control flows were inspected through native accessibility/Computer Use. |

The lsof-resolved production store before replacement was:

`/Users/mecid/Library/Containers/com.nexus.studentlife/Data/Library/Application Support/NEXUS.store`

The recovery set contains `NEXUS-0.11.0-build14.app`, `NEXUS-0.11.0-replaced-original.app`, `store/NEXUS.store`, `store/NEXUS.store-wal` and `store/NEXUS.store-shm`. The installed executable hash exactly matches the verified Release product.

`DailyPlanDashboardLayoutPolicy` provides compact/medium/wide fallbacks. `DailyPlanTimelinePolicy` expands the real time range, excludes free blocks from selection, derives selected-day tasks and assigns deterministic non-overlapping presentation lanes. All persistent feature ownership remains independent; attendance actions still modify only the stable selected lesson occurrence and cancellation is excluded from held/absence semantics.

# Phase 11 App Icon Verification — 28 August 2026

## 0.11.0 result

| Validation layer | Result |
|---|---|
| Icon source | Passed — deterministic AppKit/Core Graphics renderer at `DesignAssets/AppIcon/render_app_icon.swift`; no downloaded/generated external asset, package or network dependency |
| Source representations | Passed — checked-in native PNGs at 16, 32, 64, 128, 256, 512 and 1024 px; JSON-valid macOS `AppIcon.appiconset` |
| Visual inspection | Passed — 1024, 64 and 16 px files inspected at original pixels; centered globe, latitude/longitude arcs and restrained orbit/nodes remain readable without text or tiny UI |
| Xcode asset integration | Passed — both app configurations select `AppIcon`; actool emits `CFBundleIconName=AppIcon`, `CFBundleIconFile=AppIcon`, `AppIcon.icns` and `Assets.car` with 16–1024 px icon renditions |
| Debug arm64 build-for-testing | Passed — app, 108-test unit target and UI regression target compile/link |
| Unit/integration tests | Passed — 108 executed, 108 passed, 0 failed, 0 skipped; result bundle `build/DerivedData-Phase11/Logs/Test/Test-NEXUS-2026.08.28_02-06-56-+0300.xcresult` |
| Release | Passed — `0.11.0 (14)`, signed hardened universal Mach-O `x86_64 arm64`, strict codesign verification passed |
| Release/installed executable SHA-256 | `b2f1de7d7854f925a0ade1d3f8174387cd5dc6b1b7f1cde36e6c43bc40d53fe4` |
| Installed icon SHA-256 | `181345ea55076d3ef22a503bb9b3bf9b3596de68d38d852ef8c086e783d57e97` (`AppIcon.icns`) |
| Backup | Passed — Desktop `0.10.3 (13)` and the lsof-resolved closed store/WAL/SHM are under `work/phase11-icon-preinstall-backup`; checkpoint `0|0|0`, source and copied store integrity `ok` |
| Desktop launch/runtime | Passed — exact `/Users/mecid/Desktop/NEXUS.app` Release runs as PID `36270`; lsof proves that binary and the real sandbox store are open; live SQLite integrity is `ok` |
| Finder/accessibility inspection | Passed — Finder renders the new green globe icon for Desktop NEXUS; native runtime opens to the user's existing Touch ID lock screen without bypassing or changing the lock |

`lsof` resolved the actual Phase 11 preinstall store before shutdown to:

`/Users/mecid/Library/Containers/com.nexus.studentlife/Data/Library/Application Support/NEXUS.store`

The recovery set contains `NEXUS-0.10.3-build13.app`, `NEXUS-0.10.3-replaced-original.app`, `store/NEXUS.store`, `store/NEXUS.store-wal` and `store/NEXUS.store-shm`. Phase 11 changes no SwiftData model, JSON backup schema, local preference, Keychain state, notification permission or feature behavior.

Full host XCUITest execution remains outside this run because the host's existing macOS UI-automation authorization limitation is unchanged. The UI target compiled in Debug build-for-testing; Finder icon rendering and the installed app's native lock/runtime state were inspected through Computer Use.

# Phase 15 Voice-First Actions Verification — 29 August 2026

## 0.15.0 (20) result

| Validation layer | Result |
|---|---|
| Safety contract | Speech, typed local commands and optional Responses output can create only an inert `VoiceActionDraft`. The single persistence entry point remains behind visible/spoken exact-field preview, source-model validation, conflict handling and a separate explicit Confirm / `Onayla` / `Evet` / `تأكيد` / `نعم`. Ambiguity, Cancel, lock and denied data-scope consent write nothing. |
| Independent destinations | Verified Study task/course/weekly rule, Organization task/project, Calendar event/task/reminder, planned Gym session, Finance expense/income and Note creation. Bounded edit/cancel/undo uses only source-owned semantics; there is no merged voice entity or autonomous tool executor. |
| Local language path | Turkish reuses the deterministic Quick Entry grammar and adds bounded action/edit phrases. Arabic local forms cover tomorrow lesson/task, dated gym, note/project/organization/calendar/reminder and income/expense; ambiguous `آخر الأسبوع حط نادي` asks for date/time rather than guessing. Recognition preference is `tr-TR` or device-supported on-device `ar-SA`. |
| Optional OpenAI draft path | The exact request builder sets `store: false`, disables parallel calls and exposes only the strict inert `propose_nexus_action` schema. It requires a saved Keychain key plus a one-time exact-text consent, returns draft JSON only and never submits a function result or persistence command. No key was provisioned and no request was made in this phase. |
| Debug arm64 build-for-testing | Passed — app, 163-test unit target and updated UI regression target compile and link. |
| Unit/integration tests | Passed — 163 executed, 0 failures, 0 skipped; 21 are Phase 15 parser, confirmation/no-write, conflict, routing, undo, lock, consent and `store:false` tests. Result bundle: `build/phase15-final-results.xcresult`. |
| Release | Passed — optimized universal `x86_64 arm64`, hardened ad-hoc signature for local distribution, strict deep codesign verification passed. |
| Release / installed SHA-256 | `3f2535d6f67e9fecec266b956bc7311b8ffa2092f35310e13dddeec062480bce`. |
| Runtime accessibility | Exact Desktop Release opened naturally as PID `17875`. Native AX reported the normal HAFTA dashboard, then `⌘⇧V` exposed `voice.assistant.screen`, Turkish `KAPALI` status, disabled Push-to-Talk, local-only/no-write help and accessible typed fallback. No permission prompt or biometric bypass occurred. |
| Live-data guard | No test action was confirmed. Direct read-only SQLite verification found zero Study tasks matching the attempted test title; live `PRAGMA quick_check` returned `ok`. |
| Backup / install | `lsof` tied the running 0.14.0 PID `9687` to the exact Desktop binary and sandbox store. The app closed normally, WAL checkpoint returned `0|0|0`, source and copied integrity returned `ok`, then the verified Release replaced Desktop. |
| XCUITest execution | Updated UI regression compiles. Full XCUITest execution remains excluded because the host's macOS UI-automation authorization limitation is unchanged; installed Release inspection used native accessibility instead. |

The closed preinstall recovery set is under `work/phase15-preinstall-backup`: `NEXUS-0.14.0-build19.app`, `Desktop-NEXUS-0.14.0-original.app`, `store/NEXUS.store`, `store/NEXUS.store-wal`, `store/NEXUS.store-shm` and `com.nexus.studentlife.plist`. The store path proved by `lsof` was:

`/Users/mecid/Library/Containers/com.nexus.studentlife/Data/Library/Application Support/NEXUS.store`

The installed binary is byte-identical to the verified Release and reopened that same store. Phase 15 adds no SwiftData entity and therefore keeps JSON backup schema v9 / import compatibility v1–v9; voice drafts, transcript history, consent state, system permissions and Keychain material remain outside backup.

## Required user setup

- Voice remains hard-off until the user opens Settings, reads the permission explanation and explicitly enables it; only that action may request Microphone and Speech Recognition permissions.
- Arabic speech recognition depends on Apple's on-device `ar-SA` availability. Typed Arabic draft commands remain usable independently.
- Local commands/actions need no API key. Optional free-form remote interpretation requires the user's separately billed OpenAI API account/key saved directly in NEXUS Keychain settings and a one-time exact outgoing-text consent. ChatGPT Pro does not include API billing.
- Background availability means the sandboxed app remains running with its menu-bar control after the main window closes. Quit, Force Quit, logout, restart or crash stops it; no login item/helper daemon is installed.

# Phase 10 Settings Hotfix Verification — 27 August 2026

## 0.10.3 result

| Validation layer | Result |
|---|---|
| Root cause | Redesigned Control System exposed only static routes 1–8; no Settings row or 9 route existed. `Command-,` depended on SwiftUI's implicit Settings command instead of a NEXUS-owned command, and Settings had no reliable native Escape close path. |
| Fix | NEXUS replaces `.appSettings` with one explicit `Ayarlar…` / `Command-,` action. Control System displays non-clickable `[9] AYARLAR`, scopes a native unmodified physical-number monitor to module mode, and maps top-row/keypad 1–9 deterministically. Settings scopes Escape to close only the native Settings window. |
| Debug arm64 build-for-testing | Passed — app, 108-test unit target and updated UI regression target compile and link |
| Unit/integration tests | Passed — 108 executed, 0 failures, 0 skipped; result bundle `build/DerivedData-SettingsHotfix/Logs/Test/Test-NEXUS-2026.08.27_23-39-09-+0300.xcresult` |
| Runtime keyboard/accessibility | Passed in an isolated native Debug runtime using the final source: DAILY PLAN → Command-K → visible/announced `[9] AYARLAR` → 9 → Settings → Escape → Control System → Escape → DAILY PLAN; DAILY PLAN → Command-, → Settings → Escape → DAILY PLAN also passed |
| User lock boundary | The installed user's opt-in Touch ID lock is enabled. It was not disabled, edited or bypassed. A Debug-only XCTest initialization path prevents automated test hosts from inheriting the user's Keychain flag; this code is absent from Release. |
| Release | Passed — `0.10.3 (13)`, signed hardened universal Mach-O `x86_64 arm64`, strict codesign verification passed |
| Release/installed SHA-256 | `a30eff2e5fbf2ddf3c882ead9913d0606d6c54911d800cefa6e7ac4680807359` |
| String Catalog | JSON-valid, 870 Turkish keys |
| Backup | Existing Desktop `0.10.2 (12)` and the lsof-resolved closed store plus WAL/SHM are under `work/phase10-settings-hotfix-preinstall-backup`; source and copied SQLite integrity are `ok`, checkpoint `0|0|0` |
| Desktop launch | Exact `/Users/mecid/Desktop/NEXUS.app` Release runs as PID `20738`; lsof proves that binary and `/Users/mecid/Library/Containers/com.nexus.studentlife/Data/Library/Application Support/NEXUS.store` are open |
| XCUITest execution | UI regressions compile. Full XCUITest execution remains excluded because this host lacks macOS UI-automation authorization; the same flows were exercised through native accessibility/Computer Use in the isolated runtime above. |

The physical-number monitor exists only while Control System is visible and in module mode. It ignores modified/repeated events and is removed on disappearance, so Control System search and normal editable fields retain numeric input. Stable feature routes remain 1–8; 9 is a Control System destination, not a ninth module. Opening Settings never changes the underlying route or Control System state.

The backup recovery set includes `NEXUS-0.10.2-build12.app`, `NEXUS-0.10.2-replaced-original.app`, `store/NEXUS.store`, `store/NEXUS.store-wal`, and `store/NEXUS.store-shm`. Additional pre-final 0.10.3 bundles retained during verification are non-authoritative; the Desktop and verified Release hashes above are authoritative.

# Phase 10.2 Verification — 27 August 2026

## Environment and product

- Xcode 26.6 (build 17F113), Apple Swift 6.3.3
- macOS 14.0+ deployment target
- NEXUS 0.10.2, build 12, Turkish development language
- Native SwiftUI/MVVM/SwiftData; no external package, raster reference asset, web technology, new network/permission/API or data-model change

## Results

| Validation layer | Result |
|---|---|
| Debug arm64 build-for-testing | Passed — app, unit target and updated UI target compiled and linked |
| Unit/integration tests | Passed — 106 executed, 0 failures, 0 skipped |
| Phase 10 focused tests | Passed — 13 routing, launch-state, Reduce Motion, text reveal, contextual new-item, Week default, dashboard-only globe and one-shot window policy tests |
| Release build | Passed — optimized universal Mach-O contains `x86_64 arm64` |
| Codesign | Passed — ad-hoc hardened runtime, strict deep verification and designated requirement |
| Release entitlements | Only app sandbox and user-selected file read/write; no `get-task-allow`, network or new permission entitlement |
| String Catalog | Passed — JSON-valid, 865 Turkish keys |
| Persistence/backup | Unchanged schema v9 and v1–v9 import contract; Phase 10 adds no persisted launch/navigation/animation state |
| Desktop Phase 10.2 backup | Passed — PID 3763's exact store resolved with `lsof`, app closed, WAL checkpointed, 0.10.1 app/store/sidecars backed up |
| Desktop launch | Passed — exact `/Users/mecid/Desktop/NEXUS.app` 0.10.2 (12) runs as PID 7609 |
| Runtime UI/accessibility | Passed — clean boot used a 1277×768 available-frame window, transitioned to HAFTA, rendered the subtle dashboard globe, and removed it for Control System and route 1/Study |
| XCUITest execution | Host limitation unchanged — UI target compiles; execution was not run because this host lacks required macOS UI-automation/Accessibility authorization |

## Build and test artifacts

Debug arm64 derived data:

`work/DerivedData-Phase10-2`

Passing result bundle:

`work/DerivedData-Phase10-2/Logs/Test/Test-NEXUS-2026.08.27_22-19-58-+0300.xcresult`

`xcresulttool` reports 106 total, 106 passed, 0 failed and 0 skipped on the Apple Silicon MacBook Pro. The updated UI target, including HAFTA launch routing, also compiles in the Debug arm64 build-for-testing; host XCUITest execution authorization remains unavailable.

Verified universal Release:

`work/DerivedData-Phase10-2-Release/Build/Products/Release/NEXUS.app`

The Release and installed Desktop executable SHA-256 values match:

`2f6b94e9ca6b61d62d6705dc8d51c1b77597e981407a609257809d33c5a02414`

## 0.10.2 implementation and runtime evidence

`DailyPlanPresentationPolicy.defaultMode` is `.week`; `AppState` consumes that launch default once per process so scene restoration cannot substitute the previous Today state after boot. Native AX inspection of the installed Release reported `HAFTA, Value: 1` and `BUGÜN, Value: 0`. Manual Today selection remains available and no record was changed.

The post-boot screenshot showed the reused wireframe globe at restrained opacity behind the full weekly schedule. The policy admits that layer only for an empty feature route with Control System closed. Command-K inspection reported `controlSystem.screen` with no backdrop, and numeric route `1` opened the real `Çalışma` module with its normal controls and no globe. The decorative Canvas is hit-test disabled, accessibility hidden and static under Reduce Motion.

The native primary window measured 1277×768 in the Computer Use capture, matching the current screen's available application frame rather than entering a full-screen Space. The one-shot preference was written only after the boot-to-dashboard layout completed; later launches leave macOS window restoration and user resizing alone.

## 0.10.1 hotfix evidence

The failing control was DAILY PLAN's visible `+ Yeni` button (accessibility name `Ders planla`). Source diagnosis found `.disabled(courses.isEmpty)` on the button even though `newSchedule()` contained a no-course recovery branch. The disabled modifier prevented mouse, keyboard and accessibility activation from ever reaching that branch. Runtime inspection separately proved another visible Finance `Yeni` control worked, ruling out a global boot/reveal overlay or application-wide hit-testing failure.

The control now remains enabled. `DailyPlanNewItemPolicy` sends zero-course state to the native `CourseEditorView`, which explains the prerequisite and advances to `DailyPlanRuleEditor` only after a successful save. Existing-course state opens the schedule editor directly. Cancellation does not advance or write. Stable accessibility identifiers cover the new control and both forms.

Runtime keyboard inspection also exposed that macOS's default `Yeni Pencere` command owned Command-N before the NEXUS command. Replacing the default new-item command group removes that collision while retaining Command-Shift-N quick entry. In the exact installed Desktop build, native accessibility/Computer Use activation of the button and Command-N each opened `courseEditor.screen`; both flows were cancelled without saving user data.

## Phase 10 implementation evidence

`BootSequenceCoordinator` begins in `booting`, performs one cancellable/idempotent in-memory transition, and never changes a feature route. Standard duration is 2.4 seconds; Reduce Motion uses a static network core and 0.35-second continuation. Enter/the visible continuation action completes immediately. Boot cannot replay during navigation and has no stored preference or model.

`BootNetworkCore` is SwiftUI Canvas geometry using the existing phosphor tokens: a rotating wireframe sphere, projected lines and restrained connected nodes. It has no image/package/network dependency and is accessibility-hidden decoration. Runtime accessibility inspection saw `boot.screen`, the complete NEXUS description and `DAILY PLAN'E GEÇ`, then saw `home.screen` automatically.

Command-K exposes the full-window `controlSystem.screen`; underlying feature content is hit-test-disabled and hidden from accessibility while it is open. Runtime inspection saw all eight module options as non-button static elements, each announcing its number shortcut and native-menu alternative. Number `5` opened `notes.screen`. Reopening Control System from Notes and pressing Escape returned to `home.screen` as specified.

Command-Shift-F opened the explicit `controlSystem.search` TextField. The prior local cross-module read-only search remains intact; Command-F remains context search, and Command-N/S are unchanged. `/` is also available inside Control System.

`TerminalRevealText` is applied only to NEXUS-generated boot/control/status/section headings. Its progress advances by Swift grapheme, exposes the full deterministic accessibility label/value, completes when interrupted/tapped, and bypasses partial rendering for Reduce Motion or VoiceOver. No TextField, TextEditor, note, form, search input or other user-authored text uses the effect; there is no audio.

## Migration and recovery

For Phase 10.2, `lsof` resolved PID 3763's active store to:

`/Users/mecid/Library/Containers/com.nexus.studentlife/Data/Library/Application Support/NEXUS.store`

The 0.10.1 process was closed normally, WAL checkpoint returned `0|0|0`, and source/backup integrity checks returned `ok`. Recovery set:

`work/phase10-2-preinstall-backup/NEXUS-0.10.1-build11.app`

`work/phase10-2-preinstall-backup/NEXUS-0.10.1-replaced-original.app`

`work/phase10-2-preinstall-backup/store/NEXUS.store`

`work/phase10-2-preinstall-backup/store/NEXUS.store-wal`

`work/phase10-2-preinstall-backup/store/NEXUS.store-shm`

The backed-up app reports 0.10.1 (11). Phase 10.2 changes no SwiftData entity, store schema or JSON backup contract.

The following sections retain earlier Phase 10 recovery history.

For the hotfix, `lsof` proved both PID 216 (Desktop 0.10.0) and the temporary verified Release process used the actual sandbox store at the path below. Both processes were closed normally. WAL checkpoint returned `0|0|0`, and source and backup integrity checks returned `ok`. The current recovery set is:

`work/phase10-hotfix-preinstall-backup/NEXUS-0.10.0-build10.app`

`work/phase10-hotfix-preinstall-backup/NEXUS-0.10.0-replaced-original.app`

`work/phase10-hotfix-preinstall-backup/store/NEXUS.store`

`work/phase10-hotfix-preinstall-backup/store/NEXUS.store-wal`

`work/phase10-hotfix-preinstall-backup/store/NEXUS.store-shm`

The backed-up bundle reports 0.10.0 (10). This hotfix changes no SwiftData model or JSON backup schema.

The following records the preceding Phase 10 installation backup:

Before replacement, `lsof` proved both the running 0.9 Desktop app and temporary 0.10 Debug inspection app used the actual sandbox store:

`/Users/mecid/Library/Containers/com.nexus.studentlife/Data/Library/Application Support/NEXUS.store`

Both processes were closed with native Command-Q. WAL checkpoint returned `0|0|0`; closed and backed-up store integrity checks returned `ok`. Recovery set:

`work/phase10-preinstall-backup/NEXUS-0.9.0-build9.app`

`work/phase10-preinstall-backup/store/NEXUS.store`

`work/phase10-preinstall-backup/store/NEXUS.store-wal`

`work/phase10-preinstall-backup/store/NEXUS.store-shm`

The backup bundle reports 0.9.0 (9) and executable SHA-256 `26f2e4ee308fbc7b35828294e85236e3bc63a80b46a96c3fe379588da69be711`. Phase 10 changes no SwiftData entity or JSON backup payload.

The final installed app's binary is byte-identical to the verified Release. `lsof` proves PID 7609 executes the exact Desktop binary and has the resolved store open; live SQLite integrity is `ok`. Phase 10.2 did not request notification or any other OS permission.

## Explicit scope boundary

Phase 10 is visual/navigation-only. It does not add a second dashboard, fake module data, feature/model merging, new backup fields, notifications changes, device sync, Apple Calendar/OBS/banking/HealthKit integration, network/cloud services, analytics, external assets/packages, photorealistic CRT hardware, gaming HUD styling or audio effects.
