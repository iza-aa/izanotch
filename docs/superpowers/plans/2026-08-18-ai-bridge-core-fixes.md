# 🛠️ NotchDeck — Actual AI Bridge & Core Audit Remediation Plan

> **Goal:** Address all 11 findings from the technical audit: implement the real FSEvents transcript watcher, true bidirectional subprocess/stdin bridge, multi-AI clients (Gemini + Anthropic + Codex CLI), UI action wiring (Enter submit, real mic start/stop, hover debounce), macOS native system notifications (`UNUserNotificationCenter`), live `NSPasteboard` monitoring, and EventKit permission handling.

---

## 1. Matrix of Audit Findings & Targeted Fixes

| # | Temuan Audit | Komponen Target | Solusi & Implementasi Nyata |
|---|---|---|---|
| 1 | **FSEvent Watcher belum ada** (hanya baca file sekali, tanpa deteksi status DONE/ask_question/waiting) | `Sources/NotchDeck/AIBridge/LiveTranscriptWatcher.swift` | Gunakan `DispatchSourceFileSystemObject` / `FSEvents` untuk membaca delta baris baru pada `transcript.jsonl`. Parsing JSON event: `status == "DONE"`, `ask_question`, `waiting_for_input`, update `NotchStateController`. |
| 2 | **Claude Code & Codex belum terintegrasi** (Menu hanya kosmetik label UI) | `Sources/NotchDeck/AIBridge/MultiAIClient.swift` | Implementasi REST client Anthropic Claude (`/v1/messages`) dan Claude Code CLI runner (`claude -p`) + Codex API runner yang aktif saat model dipilih di dropdown. |
| 3 | **Subprocess runner belum bidirectional** (tanpa stdin, streaming, & exit status) | `Sources/NotchDeck/AIBridge/AISubprocessBridge.swift` | `Process` dengan `Pipe` stdin untuk inject prompt, streaming stdout/stderr asynchronous, dan validasi `terminationStatus`. |
| 4 | **Prompt teks tidak disubmit saat Enter** (`TextField` tanpa `.onSubmit` & tombol send) | `Sources/NotchDeck/UI/Views/NotchRootView.swift` | Tambahkan `.onSubmit { submitCurrentPrompt() }` dan tombol panah kirim (`arrow.up.circle.fill`). |
| 5 | **Tombol Mic tidak panggil `startRecording()` / `stopRecording()`** | `Sources/NotchDeck/UI/Views/NotchRootView.swift` | Sambungkan aksi klik mic langsung ke `speechManager.startRecording()` dan tombol stop ke `speechManager.stopRecording()`. |
| 6 | **EventKit permission tidak pernah direquest & error diabaikan** | `Sources/NotchDeck/Scheduler/EventKitService.swift`, `NotchDeckApp.swift` | Panggil `EventKitService.requestAccess()` saat `applicationDidFinishLaunching`, tangkap throw error, dan tampilkan feedback jika permission ditolak. |
| 7 | **Hover debounce tidak terpakai** (`.onHover` langsung di view) | `Sources/NotchDeck/UI/Views/NotchRootView.swift` | Hubungkan `.onHover` ke `hoverMonitor.mouseEntered()` dan `mouseExited()`. |
| 8 | **ClipboardManager belum terhubung ke `NSPasteboard`** | `Sources/NotchDeck/Clipboard/ClipboardMonitor.swift` | Tambahkan loop observer `NSPasteboard.general.changeCount`, auto-insert ke `CardDataStore`, dan fungsi copy/clear. |
| 9 | **Alarm hanya in-memory `Task`** (hilang saat suspend/close) | `Sources/NotchDeck/Scheduler/SystemNotificationService.swift` | Jadwalkan alarm melalui `UNUserNotificationCenter` (macOS Local Notification) dan `EKAlarm` bawaan macOS sehingga bunyi tepat waktu meskipun aplikasi disuspend. |
| 10 | **`walkthrough.md` belum ada di repository** | `docs/walkthrough.md` | Buat file `docs/walkthrough.md` di dalam direktori repository. |
| 11 | **Repo hygiene & Test coverage kosong** | `.gitignore`, `Tests/NotchDeckTests/` | Tambahkan `.gitignore` untuk `.build` dan `.DS_Store`. Buat unit test nyata untuk parsing JSONL event delta, stdin write, Claude payload, dan pasteboard. |

---

## 2. Rencana Implementasi Bertahap (TDD Workflow)

```
Phase 1 (AI Bridge & Watcher) ➔ Phase 2 (UI Actions & Debounce) ➔ Phase 3 (System Alarms & Clipboard) ➔ Phase 4 (Tests & Cleanup)
```

### Phase 1: Real AI Bridge & Live Transcript Watcher
1. Buat `LiveTranscriptWatcher.swift`:
   - Menggunakan `DispatchSource.makeFileSystemObjectSource` pada file `transcript.jsonl`.
   - Parsing objek JSON delta: mendeteksi event `ask_question`, `waiting_for_input`, dan `status: "DONE"`.
   - Mengubah state NotchDeck ke `.liveActivity` atau memicu dialog konfirmasi.
2. Buat `AISubprocessBridge.swift`:
   - Menjalankan `Process` dengan `standardInput = Pipe()`, `standardOutput = Pipe()`, `standardError = Pipe()`.
   - Method `sendInput(_ text: String)` untuk menulis ke stdin.
   - Stream asynchronous membaca output buffer baris demi baris.
3. Buat `MultiAIClient.swift`:
   - Integrasi Anthropic Messages API (`https://api.anthropic.com/v1/messages`) dengan header `x-api-key` & `anthropic-version`.
   - Integrasi Google Gemini API & routing model dinamis berdasarkan pilihan UI (`Antigravity`, `Claude Code`, `Codex`).

### Phase 2: UI Wiring & Direct Actions
1. Di `NotchRootView.swift`:
   - Tambahkan `.onSubmit { appDelegate.submitCurrentPrompt() }` pada `TextField`.
   - Tambahkan tombol kirim `Image(systemName: "arrow.up.circle.fill")`.
   - Sambungkan tombol mic ke `speechManager?.startRecording()` dan tombol stop ke `speechManager?.stopRecording()`.
   - Pasang `hoverMonitor?.mouseEntered()` dan `hoverMonitor?.mouseExited()` pada event `.onHover`.

### Phase 3: System Alarms, EventKit Permission, & Live Clipboard
1. Di `AppDelegate.swift`:
   - Panggil `EventKitService.shared.requestAccess()` dan `UNUserNotificationCenter.current().requestAuthorization()`.
2. Di `SystemNotificationService.swift`:
   - Mengirim notifikasi lokal via `UNNotificationRequest` dengan sound alert sistem macOS.
3. Di `ClipboardMonitor.swift`:
   - Listener berkala pada `NSPasteboard.general.changeCount`.
   - Saat teks baru di-copy user $\rightarrow$ otomatis difilter token rahasianya dan dimasukkan ke `CardDataStore`.

### Phase 4: Unit Testing & Repo Hygiene
1. Tambahkan `.gitignore` untuk `.build`, `.DS_Store`, dan artifacts.
2. Tulis test suite:
   - `LiveTranscriptWatcherTests.swift` (uji deteksi event `DONE` dan `ask_question` dari feed JSONL).
   - `AISubprocessBridgeTests.swift` (uji stdin pipe dan exit status).
   - `MultiAIClientTests.swift` (uji request payload generation untuk Anthropic & Gemini).
   - `ClipboardMonitorTests.swift` (uji deteksi perubahan pasteboard).
3. Buat `docs/walkthrough.md` di dalam git repository.
