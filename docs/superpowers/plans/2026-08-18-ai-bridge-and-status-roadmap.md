# 🗺️ NotchDeck — Status Implementasi & Blueprint Integrasi Multi-AI (Antigravity, Claude Code, Codex)

Dokumen ini memetakan **arsitektur teknis integrasi notifikasi & live chat multi-AI**, perancangan **Top Bar modular untuk fungsi yang berbeda**, serta **checklist status fitur yang sudah selesai (Completed) dan yang akan dikerjakan (Upcoming)**.

---

## 1. 🧠 Bagaimana NotchDeck Terhubung dengan Antigravity, Claude Code, & Codex?

Agar NotchDeck bisa menjadi **Actual HUD & Notification Center** untuk agent AI Anda (bukan sekadar tampilan tiruan), kita menggunakan **arsitektur Event-Driven File Watcher + CLI Subprocess Dispatcher** tanpa bergantung pada inject GUI yang rapuh.

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                    NOTCHDECK HUD                                        │
│  [✨ Antigravity ▾]  [ 🔴 Live Activity: Task Done / Needs Approval ]  [ 💬 Prompt Bar ] │
└───────────────────────────▲───────────────────────────────────┬─────────────────────────┘
                            │                                   │
              1. Observasi Transkrip & Status          2. Inject Prompt / Balasan User
                            │                                   │
       ┌────────────────────┴───────────────────┐               │
       │     macOS FSEvents / File Watcher      │               ▼
       │      (AntigravityTranscriptWatcher)    │    ┌──────────────────────┐
       └────────────────────▲───────────────────┘    │  Subprocess Runner   │
                            │                        │  (CLI / stdin bridge)│
 ┌──────────────────────────┴──────────────────────────┐     └──────────┬───────────┘
 │                   SISTEM AGENT AKTIF                │                │
 │                                                     │                │
 │ • Antigravity: `~/.gemini/antigravity/brain/...`    │◄───────────────┘
 │ • Claude Code: `~/.claude/projects/...` & CLI       │
 │ • OpenAI Codex: Local Workspace Session Logs        │
 └─────────────────────────────────────────────────────┘
```

### A. Mekanisme Notifikasi Otomatis (Saat AI Selesai / Butuh Input)
1. **Transcript Watcher (`FSEventStream`):**
   * NotchDeck memantau direktori kerja Antigravity (`~/.gemini/antigravity/brain/<session-id>/.system_generated/logs/transcript.jsonl`).
2. **Deteksi Event Penting:**
   * **Saat Agent Membutuhkan Klarifikasi / Approval (`ask_question` / `waiting_for_input`):**
     * NotchDeck langsung berubah ke state `.liveActivity(title: "Antigravity: Needs Input", countdown: "Action Required")`.
     * Menampilkan pertanyaan/opsi di kartu expanded.
   * **Saat Agent Selesai Mengerjakan Task (`status: DONE`):**
     * NotchDeck bergetar halus / menampilkan pill `✨ Antigravity: Task Complete`.
     * Memutar notifikasi audio opsional via `VoiceOverSpeaker`.

### B. Mekanisme Actual Chat & Prompting dari NotchDeck
1. **Live Chat Viewer:**
   * Jendela Notch menampilkan stream respons terakhir AI (markdown summary, code diff snippet).
2. **Bidirectional Dispatcher (Kirim Balasan / Prompting Langsung):**
   * Saat Anda mengetik di Prompt Bar NotchDeck dan tekan Enter:
   * **Antigravity:** NotchDeck mengirim prompt ke session aktif atau menjalankan task runner.
   * **Claude Code:** NotchDeck mem-pipe prompt langsung via `claude -p "..."` subprocess atau file trigger.

---

## 2. 🎛️ Perancangan Top Bar Khusus untuk Fungsi Berbeda

Alih-alih satu topbar statis yang campur aduk, NotchDeck memiliki **Top Bar Adaptif** yang berubah sesuai Mode Kerja yang dipilih:

```
Mode 1: ✨ AI Studio & Chat
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│ [✨ Antigravity ▾]  [🟢 Idle / 🟡 Working / 🔴 Needs Input]  [ 🔍 Ask AI or Prompt... ] │
└─────────────────────────────────────────────────────────────────────────────────────────┘

Mode 2: 📅 Smart Schedule & Voice
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│ [📅 Calendar & Reminders]  [🎙️ Push-to-Talk ⌥Space]  [ 🔍 "Meeting jam 3 sore..." ]     │
└─────────────────────────────────────────────────────────────────────────────────────────┘

Mode 3: 📋 Developer Clipboard & Dropzone
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│ [📋 Clipboard Hub]  [🔒 Secret Masking: ON]  [ 🔍 Search Snippets or Drop Files... ]   │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

* **Switcher Mode di Header:** Tab switcher yang bersih di kiri atas untuk berpindah fungsi secara instan (`AI Chat` | `Schedule` | `Clipboard`).
* **Header Context:** Menampilkan status koneksi model, indikator apakah agent sedang *thinking*, *waiting for approval*, atau *idle*.

---

## 3. 📊 Matriks Status Fitur (Completed vs Upcoming)

### ✅ Fitur yang SUDAH SELESAI (Completed & Merged to `main`):

| # | Modul / Fitur | Status | File Implementasi |
|---|---|:---:|---|
| 1 | **Indonesian TTS & Number-to-Words (0–59)** | ✅ Selesai | [`LocalVoiceOverBuilder.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/Audio/LocalVoiceOverBuilder.swift) |
| 2 | **Offline NLP Schedule Regex Parser** | ✅ Selesai | [`LocalScheduleParser.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/Scheduler/LocalScheduleParser.swift) |
| 3 | **Cloud Gemini 2.5 Flash / Claude Client** | ✅ Selesai | [`NotchDeckAIClient.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/AIBridge/NotchDeckAIClient.swift) |
| 4 | **macOS Keychain Secure Storage (BYOK)** | ✅ Selesai | [`KeychainManager.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/Core/KeychainManager.swift) |
| 5 | **Clipboard Analyzer & Exact Secret Masking** | ✅ Selesai | [`ClipboardManager.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/Clipboard/ClipboardManager.swift) |
| 6 | **Antigravity CLI Subprocess Runner** | ✅ Selesai | [`AntigravityCoordinator.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/AIBridge/AntigravityCoordinator.swift) |
| 7 | **Hardware Notch Height & Geometry Engine** | ✅ Selesai | [`NotchGeometryCalculator.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/UI/Window/NotchGeometryCalculator.swift) |
| 8 | **AppKit Floating Window (`.statusBar + 1`)** | ✅ Selesai | [`NotchPanel.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/UI/Window/NotchPanel.swift), [`NotchWindowController.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/UI/Window/NotchWindowController.swift) |
| 9 | **Global & Local Hotkeys (`⌥ Space`, `⌘ ⇧ Space`, `Esc`)** | ✅ Selesai | [`HotkeyManager.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/Core/HotkeyManager.swift), [`NotchDeckApp.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/NotchDeckApp.swift) |
| 10 | **Click-to-Expand & Hover Trigger** | ✅ Selesai | [`NotchHoverMonitor.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/UI/Window/NotchHoverMonitor.swift), [`NotchRootView.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/UI/Views/NotchRootView.swift) |
| 11 | **Dynamic Audio Waveform & Speech-to-Text (`id-ID`)** | ✅ Selesai | [`AudioLevelProcessor.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/Audio/AudioLevelProcessor.swift), [`SpeechRecognitionManager.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/Audio/SpeechRecognitionManager.swift) |
| 12 | **Native Voice-Over Siri Speaker** | ✅ Selesai | [`VoiceOverSpeaker.swift`](file:///Sources/NotchDeck/Audio/VoiceOverSpeaker.swift) |
| 13 | **Apple EventKit Sync (Calendar & Reminders)** | ✅ Selesai | [`EventKitService.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/Scheduler/EventKitService.swift) |
| 14 | **Dual-Engine Schedule Coordinator** | ✅ Selesai | [`ScheduleCoordinator.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/Scheduler/ScheduleCoordinator.swift) |
| 15 | **Background Reminder Alarm Timer** | ✅ Selesai | [`ReminderAlarmMonitor.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/Scheduler/ReminderAlarmMonitor.swift) |
| 16 | **Curved Bézier Notch Ear Shape** | ✅ Selesai | [`NotchShape.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/UI/Views/NotchShape.swift) |
| 17 | **Borderless Minimalist Monochrome UI** | ✅ Selesai | [`NotchRootView.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/UI/Views/NotchRootView.swift), [`CardCarouselView.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/UI/Views/CardCarouselView.swift) |
| 18 | **BYOK Settings Window** | ✅ Selesai | [`SettingsView.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/UI/Views/SettingsView.swift) |

---

### ⏳ Fitur Lanjutan yang AKAN DIKERJAKAN (Upcoming Implementation):

| # | Fitur / Rencana Kerja | Prioritas | Estimasi & Detail |
|---|---|:---:|---|
| 1 | **FSEvent Live Transcript Watcher** | 🔴 Kritis | Membaca real-time event Antigravity & Claude Code saat task berjalan / selesai. |
| 2 | **Actual Interactive AI Chat View** | 🔴 Kritis | UI jendela chat multi-turn dalam NotchDeck yang menampilkan respons AI, diff code, dan quick-approval buttons. |
| 3 | **Mode-Specific Modular Topbars** | 🟡 Tinggi | Topbar khusus AI Chat, Topbar khusus Schedule, dan Topbar khusus Clipboard. |
| 4 | **Interactive Clarification / Approval Modal** | 🟡 Tinggi | Saat Antigravity menanyakan klarifikasi (misal: pertanyaan ganda), NotchDeck memunculkan pill tombol opsi interaktif. |
| 5 | **Codex & Claude Code CLI Pipe Streamer** | 🟢 Menengah | Integrasi komunikasi bidirectional langsung via subprocess stream. |

---

## 4. Rencana Kerja Selanjutnya (Action Items)

1. **Membuat `AILiveTranscriptObserver.swift`:** Watcher otomatis untuk file JSONL transkrip Antigravity & Claude Code.
2. **Merancang `AIModeTopBarView.swift`:** Top bar khusus AI yang menampilkan status agent (Idle, Thinking, Waiting Input).
3. **Membangun `AIChatStreamView.swift`:** Tampilan chat aktual di dalam kartu carousel NotchDeck untuk membaca dan mengirim prompt langsung ke agent.
