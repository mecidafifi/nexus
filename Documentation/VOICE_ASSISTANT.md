# NEXUS Voice Assistant

## Setup

1. Open NEXUS Settings and read `SES YARDIMCISI`.
2. Optionally change the two-or-more-word wake phrase and select Turkish or Arabic recognition. The default is `Merhaba Yardımcı` and `tr-TR`; Arabic is accepted only if Apple's on-device `ar-SA` recognizer is available on this Mac.
3. Press `Sesi Etkinleştir`, read the explanation, then confirm. Only now does NEXUS ask macOS for Microphone and Speech Recognition permission.
4. Use the wake phrase or Push-to-Talk. A green orb/status makes listening visible. Use `Tamamen Kapat` in Settings, the assistant panel or menu-bar item to stop it immediately.
5. Optional remote answers: create/fund an OpenAI API account separately, paste the key into the local SecureField, save, then press Connection Test. Do not paste the key into chat or notes. ChatGPT Pro does not include API usage/billing; see [OpenAI's billing explanation](https://help.openai.com/en/articles/9039756).

The assistant does not need an API key for local commands or reports.

## Supported local Turkish subset

- `Bugün ne var?` / `Günlük özet`
- `Bu hafta ne var?` / `Haftalık özet`
- `Tamamlanmamış görevleri göster`
- `Devamsızlık riskim nedir?`
- `Yaklaşan son tarihler` / `Yaklaşan sınavlar`
- `Finans bakiyem` / `Bütçem ve borçlarım`
- `Spor ilerleme ve odak`
- `Çalışma bölümünü aç`, `Devam bölümüne git`, `Spor bölümünü aç`, `Finansı aç`, `Notları göster`, `Takvimi aç`, `OBS'yi aç`, `Projeleri göster`
- `Yardım` / `Komutlar`

Matching is deterministic and local. Unsupported language is not guessed into a local action. With no saved API key it receives a clear setup response. With a saved key it is treated as a question-only remote request.

## Phase 15 safe voice actions

Supported create destinations remain independent: Study task/course/weekly lesson, Organization task/project, Calendar event/task/reminder, planned Gym session, Finance income/expense and Note. Existing deterministic Turkish Quick Entry sentences also produce these voice drafts. Representative local forms include:

- `Yarın saat 17'de Rapor çalışma görevi, 45 dakika`
- `Her pazartesi saat 10'da Yapay Zeka var, 20 Aralık'a kadar`
- `Fakülte projesine Sunum görev ekle`
- `50 lira Kahve gider ekle`
- `Not ekle Toplantı: Danışmana sorulacaklar`
- `بكرا الساعة خمسة عندي درس الذكاء الاصطناعي`
- `أضف واجب تقرير بكرا الساعة خمسة`
- `أضف مصروف 50 ليرة قهوة`

`آخر الأسبوع حط نادي` deliberately asks for a date/time instead of guessing. Every accepted parse opens `SESLİ EYLEM TASLAĞI`; the screen and speech expose the exact fields and state that nothing has been saved. Confirm with `Onayla`, `Evet`, `تأكيد`, `نعم`, Return on the native Confirm button, or cancel. While a draft is open, `başlığı … yap`, `saati 18 yap`, `süreyi 45 dakika yap`, `tarihi yarın yap` changes only the preview.

Unique source-owned Study/Organization tasks can be moved or set to their real cancelled status after preview. Unique Calendar/Gym scheduled records can be moved. NEXUS does not misuse “completed” to pretend an event or workout was cancelled. `Geri al` restores the last confirmed session action or deletes only the record(s) that action created.

Timed conflicts are calculated from existing schedule, Calendar and Gym records. `Başka zaman bul` revises the draft, `Yine de taslakta tut` acknowledges the warning but does not save, and `İptal` writes nothing. A second explicit confirmation is always required.

## Data scopes and transmission

Local report scopes are Study, Tasks, Attendance, Deadlines, Finance, Gym, Focus, Calendar, OBS and Organization. The conversation shows which were read. Nothing is sent for a local report.

If the user asks OpenAI to interpret a produced local report, NEXUS opens a default-deny confirmation sheet containing the exact outbound report and its scopes. `Reddet` sends nothing. `Bir Kez İzin Ver` permits that payload once only. There is no global "send all data" permission.

The optional client calls the official [Responses API](https://developers.openai.com/api/reference/cli/resources/responses/methods/create) with `store: false`. No microphone audio is sent. For action interpretation it exposes exactly one strict `propose_nexus_action` function schema. The app never sends a function result and the model cannot invoke persistence; returned arguments become another inert local draft. NEXUS does not log request bodies or keys.

## macOS lifecycle and limitations

- While enabled and NEXUS is running, local wake listening continues after the main window closes. A menu-bar item remains visible and controllable.
- This build is a normal sandboxed app, not a privileged/background daemon. Quit, Force Quit, logout, restart or a crash stops listening. It does not launch at login.
- On-device Turkish or selected Arabic recognition must be supported by the installed macOS/Speech assets. Otherwise NEXUS reports the limitation and typed fallback remains.
- NEXUS processes microphone buffers in memory and creates no continuous recording file. Local Speech framework processing is subject to Apple's platform implementation and system permissions.
- Touch ID lock always wins. Locked NEXUS refuses reports, navigation and remote answering; it never authenticates invisibly.
- The API key is device-only Keychain state. It is not recovered by NEXUS JSON backup or device sync.
- Session conversation history disappears when the process exits.

## Not implemented

No auto-login helper, remote wake service, cloud audio upload, OpenAI key bundling, subscription management, autonomous/background write, arbitrary tool execution, device sync, Apple Calendar sync, OBS login automation, banking sync or HealthKit is included.
