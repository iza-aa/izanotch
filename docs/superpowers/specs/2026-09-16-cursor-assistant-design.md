# Cursor Assistant Feature Design Spec

## 1. Overview & Goals
Fitur **Cursor Assistant** di `boringNotch` adalah asisten visual pintar interaktif yang mendampingi kursor pengguna di macOS. Terinspirasi langsung dari arsitektur *HeyClicky*, asisten ini:
- Mengikuti pergerakan kursor pengguna sebagai *Ghost Cursor* yang elegan.
- Mampu mendengarkan perintah suara secara lokal via `SFSpeechRecognizer` (Apple Speech Framework).
- Menangkap layar menggunakan `ScreenCaptureKit` dan menganalisis elemen layar menggunakan Multimodal Vision API (Gemini / Antigravity Bridge).
- Memberikan panduan interaktif:
  - **Teks pendek & status** (misal: "Mendengarkan...", "Klik di sini") muncul di balon mini dekat kursor (*CursorMiniBubbleView*).
  - **Teks panjang & penjelasan detail** muncul secara elegan langsung dari **boringNotch** (*CursorAssistantNotchView*).
  - **Gerakan**: Kursor meluncur (*glide animation*) menunjuk tombol atau target yang harus diklik pengguna.
- Dilengkapi tombol Toggle On/Off di samping ikon Settings (gear) di `BoringHeader.swift`.

---

## 2. Architecture & File Structure

```text
boringNotch/
├── models/
│   ├── CursorAssistantModels.swift           # Model data, state, guided click targets, AI JSON payload
│   └── Constants.swift                       # Defaults key: cursorAssistantEnabled, cursorAssistantVoiceEnabled
│
├── enums/
│   └── generic.swift                         # Tambahan enum CursorAssistantState (idle, listening, thinking, pointing)
│
├── managers/
│   ├── AppleSpeechTranscriptionProvider.swift # Voice transcription via Apple Speech Framework on-device
│   ├── ScreenCaptureProvider.swift           # Screen capture via ScreenCaptureKit
│   └── CursorAssistantManager.swift          # Main coordinator singleton (event listener, AI routing, state machine)
│
└── components/
    ├── CursorAssistant/
    │   ├── CursorOverlayPanel.swift          # Floating borderless transparent NSPanel
    │   ├── GhostCursorView.swift             # Cursor visual (pointer, glide, spinner, waveform)
    │   ├── CursorMiniBubbleView.swift        # Mini bubble for short text near cursor
    │   └── CursorAssistantNotchView.swift    # Detailed explanation view in boringNotch
    └── Notch/
        └── BoringHeader.swift                # Toggle On/Off button next to gear settings
```

---

## 3. Component Details & Data Flow

### A. State Machine (`CursorAssistantState`)
- `.idle`: Mengikuti mouse dengan offset halus (companion mode).
- `.listening`: Merekam suara pengguna via `AppleSpeechTranscriptionProvider`, kursor menampilkan animasi waveform.
- `.thinking`: Sedang menangkap layar dan mengirim ke Vision Model, kursor menampilkan animasi spinner.
- `.pointing(target: GuidedClickTarget)`: Kursor meluncur (*glide animation*) ke target `(x, y)` di layar.

### B. Voice Input (`AppleSpeechTranscriptionProvider`)
- Menggunakan `SFSpeechRecognizer` dan `AVAudioEngine` bawaan macOS.
- 100% diproses lokal (on-device Neural Engine).
- Streaming dictation: hasil transkripsi langsung dapat dibaca saat jeda bicara terdeteksi.

### C. Screen Capture (`ScreenCaptureProvider`)
- Menggunakan `ScreenCaptureKit` (`SCShareableContent` + `SCScreenshotManager`).
- Menghasilkan `CGImage` / `NSImage` layar utama tanpa lag dan hemat memori.

### D. Vision & AI Routing (`CursorAssistantManager`)
- Mengirim screenshot base64 + prompt pertanyaan ke Multimodal endpoint (Antigravity Bridge / Gemini Flash).
- Format respon JSON:
```json
{
  "action": "point",
  "coordinates": {"x": 1024, "y": 350},
  "short_hint": "Klik tombol Share",
  "detailed_explanation": "Untuk membagikan file ini, klik tombol Share di bilah navigasi kanan atas..."
}
```
- Jika teks $\le 10$ kata: ditampilkan pada balon mini kursor.
- Jika teks $> 10$ kata: ringkasan tampil di balon mini, penjelasan lengkap disalurkan ke `CursorAssistantNotchView` di boringNotch.

### E. Window & Visual Overlay (`CursorOverlayPanel`)
- `NSPanel` dengan:
  - `styleMask = [.borderless, .nonactivatingPanel]`
  - `level = .floating` (atau `.screenSaver`)
  - `backgroundColor = .clear`
  - `ignoresMouseEvents = true` (agar klik tembus ke jendela aplikasi lain)
  - `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`

---

## 4. Error Handling & Permissions
- Izin Mikrofon (`NSMicrophoneUsageDescription`) & Speech (`NSSpeechRecognitionUsageDescription`): ditangani dengan ramah jika pengguna belum memberikan izin.
- Izin Screen Recording: jika belum aktif, sistem menampilkan panduan membuka System Settings > Privacy & Security > Screen Recording.
- Fallback jaringan: jika bridge lokal / cloud offline, kursor menampilkan notifikasi singkat "Koneksi asisten offline".
