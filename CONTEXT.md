# CONTEXT.md — Izanotchy Application & Cognitive Model Context

<!-- Single Source of Truth for Izanotchy Architecture, Models, and Inter-Model Contracts -->

---

## 🎯 1. Mission & Product Paradigm

Membangun **Isolated Workspace Assistant** native macOS — terinspirasi langsung dari paradigma **xAI Grok Bot** (https://x.ai/bot) dan **Dot (OpenAI)**.

### Karakteristik Inti:
1. **Zero Host Screen Intrusion**:
   - Asisten dan connected apps (Mail, Browser, Terminal, Notes, dll.) beroperasi 100% di dalam workspace terisolasi (`CGVirtualDisplay` / Sandbox Container / WebKit Persistent Store).
   - Kursor fisik mouse dan jendela layar utama host pengguna bebas interupsi 100%.
2. **In-Chat Native Stream**:
   - Aktivitas CUA (Computer Use Agent), progres sub-goal, dan viewport streaming jendela langsung ditampilkan di kartu chat interaktif (`HomeSpace`) dan modal interaktif.
3. **Autonomous Execution via Pure Physical Cursor Hand (Zero Shortcut Cheats)**:
   - Universal physical actions: `left_click`, `right_click`, `mouse_down` / `mouse_up` (drag/hold), `scroll_up` / `scroll_down` (kinematic wheel), dan `type`.
   - **Dilarang keras pintasan keyboard spesifik per aplikasi** (seperti `⌘↑` untuk Mail). Seluruh interaksi menggunakan kursor mouse fisik universal.
   - **AXUIElement murni sensor persepsi**: Hanya untuk membaca hierarki elemen dan koordinat (x, y); dilarang membypass UI fisik.
   - **Cursor Always Stay & Ready**: Kursor maskot selalu hadir di kanvas virtual, meluncur halus (*smooth gliding* 45 FPS) ke target, tanpa teleportasi instan.
   - **Prinsip "See ➔ Plan ➔ Act"**: Asisten wajib melihat kondisi layar terkini sebelum merencanakan aksi berikutnya.
4. **Human Takeover Protocol**:
   - Jika autentikasi, CAPTCHA, 2FA, atau aksi sensitif (kirim pesan/transaksi) membutuhkan persetujuan manusia, asisten memicu takeover interaktif (`[ ✋ Take Over Screen ]`). Kursor AI disembunyikan 100%, kursor pengguna berdaulat penuh.
5. **No Fake Mockups**:
   - Dilarang membuat antarmuka tiruan palsu atau folder/data dummy. Semua eksekusi berjalan di atas aplikasi dan runtime nyata macOS.

---

## 🧠 2. Model Kognitif & Batasan Mutlaknya (Mental Model Wajib)

Sistem Izanotchy beroperasi menggunakan koordinasi multi-model hierarkis. Setiap model memiliki karakteristik dan batasan kognitif yang **WAJIB** dipahami oleh setiap agen coding sebelum merancang prompt atau alur logika:

### A. AFM (Apple Foundation Models, ~3B Parameter On-Device NPU)
- **Runtime:** Framework Apple `FoundationModels` (`LanguageModelSession`) dan daemon `SiriAIEngine` (port 1976) di Neural Engine Apple Silicon.
- **Peran:** Perencanaan langkah atomik (`TaskStepPlanner`), validasi state & ekstraksi fakta (`TaskEgressValidator`), dekomposisi maksud tugas (`TaskIngressGateway`).
- ⚠️ **Karakteristik & Batasan Kritis Model 3B:**
  > *"Model kita 3B, kalau dikasih instruksi panjang, bertumpuk, atau kontradiktif, dia GAK AKAN BISA!"*
  1. **Sangat Rentan Few-Shot Overfitting & Prompt Regurgitation:**
     - Jika prompt memuat contoh angka atau teks literal (misal: "seperti index 10", "misal OpenAI 18:19"), model 3B akan langsung menjiplak teks contoh tersebut alih-alih membaca fakta nyata di layar!
     - **Aturan:** Dilarang keras menyisipkan contoh literal. Wajib murni menggunakan **placeholder tipe data abstrak** (`<targetIndex>`, `<targetEntity>`, `<factualData>`).
  2. **Dilarang "God Prompt" (Multi-Responsibility Prompts):**
     - Model 3B **TIDAK MAMPU** mengevaluasi 5 aturan teknis (cek index, cek reading pane, cek scroll, cek takeover) sekaligus menyusun kalimat ramah dalam bahasa manusia dalam satu tarikan inferensi.
     - **Aturan:** Prompt wajib **Single Responsibility**. Pecah menjadi fungsi terpisah:
       - **Fungsi 1 (Evaluasi Teknis/Fakta):** Evaluasi apakah aksi sukses, apakah target tercapai, dan ekstrak fakta ke JSON/struct.
       - **Fungsi 2 (Sintesis Bahasa):** Merangkai fakta yang sudah diekstrak menjadi respons ramah dalam bahasa pengguna (`userLanguage`).
  3. **Konteks Ringkas & Terarah (No Raw Screen Dumps):**
     - Jangan pernah memberikan seluruh dump JSON layar (seluruh topbar + seluruh sidebar + seluruh 9 item list + preview) ke dalam riwayat observasi langkah.
     - Model 3B akan tersesat dalam token yang berlebihan. Berikan observasi ringkas terarah per-item (*Targeted Item Observation*).

### B. Luna (`gpt-6-luna` via Headless Codex CLI)
- **Runtime:** Codex CLI headless (`~/.codex/auth.json` account pool).
- **Peran:** Sensor penglihatan visual resolusi tinggi (Visual Grounder).
- **Karakteristik:** Menemukan koordinat fisik piksel (x, y) dari deskripsi elemen target jika sensor Accessibility AXUIElement tidak menemukan elemen tersebut.

### C. Claude API (Tier 3 Cloud Fallback)
- **Runtime:** `ClaudeAPIClient` / Anthropic API.
- **Peran:** Cadangan penalaran jika AFM daemon on-device offline atau mengalami error berulang.

---

## 📡 3. Protokol Kontrak Antarmodel (Canonical JSON Contract)

Untuk mencegah kebocoran bahasa alami atau halusinasi instruksi kamus, seluruh agen dan model internal berkomunikasi murni menggunakan **Canonical English JSON Task Contract**:

```json
{
  "intentType": "inspect | compose | search | interact",
  "targetEntity": "topmost_item | compose_button | main_window",
  "targetIndex": 1,
  "searchQuery": null,
  "normalizedGoal": "Inspect the latest inbox item",
  "userLanguage": "id"
}
```

- **Ingress Gateway (`TaskIngressGateway`)**: Menerjemahkan bahasa alami pengguna ke kontrak kanonikal di atas. Deteksi bahasa menggunakan framework Apple `NaturalLanguage` (`NLLanguageRecognizer`).
- **Planner (`TaskStepPlanner`)**: Merencanakan 1 langkah atomik berikutnya murni berdasarkan kontrak kanonikal dan observasi layar.
- **Action Executor (`CUAPhysicalActionDispatcher`)**: Menjalankan aksi fisik mouse/keyboard.
- **Egress Gateway (`TaskEgressValidator`)**: Mengevaluasi pencapaian target dan menyintesis kembali respons ramah ke bahasa asli pengguna (`userLanguage`).

---

## 🏗️ 4. Peta Arsitektur Kode (Clean Architecture)

```text
boringNotch/Clicky/
├── UI/                                    # LAPISAN FRONTEND (SwiftUI Views & Window Controllers)
│   ├── HomeSpace/                         # Panel Chat & Kartu Interaktif
│   ├── Rail/                              # Floating Companion Rail & Popover
│   ├── Floating/                          # Floating Aqua Bubble & Glass Sphere
│   ├── Avatars/                           # Avatar Maskot & Animasi Prosedural
│   ├── Viewport/                          # Viewport Streaming & Display UI
│   └── Common/                            # Dialog, Consent & Windows Umum
├── Reasoning/                             # LAPISAN PENALARAN AI (Cognitive Engines)
│   ├── Ingress/                           # Intent Classifier & Task Contract (TaskIngressGateway)
│   ├── Planner/                           # Dynamic AFM Step Reasoner (TaskStepPlanner)
│   ├── Validator/                         # Modular AFM Egress Synthesizer (TaskEgressValidator)
│   └── Coordination/                      # Hierarchical AFM ⇄ Luna Bridge
├── CUA/                                   # LAPISAN COMPUTER USE AGENT (Hands, Loop & Actions)
│   ├── Loop/                              # State Machine CUA & Background Watcher
│   ├── Actions/                           # Modular Physical Hands Tools (Click, Scroll, Type, Read)
│   ├── Grounding/                         # Hybrid Sensor & Visual Grounder (Luna / AXUIElement)
│   └── Execution/                         # Low-Level Physical Drivers & Cursors
├── Workspace/                             # INFRASTRUKTUR DISPLAY & SANDBOX TERISOLASI
│   ├── VirtualDisplay/                    # CGVirtualDisplay Management (Layar Virtual Sekunder)
│   ├── Streaming/                         # ScreenCaptureKit Retina In-Memory Streaming
│   ├── Discovery/                         # Native App & Window Discovery
│   └── WindowManagement/                  # Window Geometries & Leveling
├── Roster/                                # DATA MASKOT & WORKSPACE PERSISTENCE
├── Services/                              # HARDWARE & MODEL CLIENTS
│   ├── Audio/                             # Speech Recognition & Dictation
│   ├── Vision/                            # Vision Account Pools
│   ├── Models/                            # LLM Clients & Daemons (SiriAIEngine, ClaudeAPI)
│   └── Domain/                            # Domain Extensions (TradingView, Astronacci, FuturesScout)
└── Core/                                  # CORE APPLICATION LIFECYCLE & DISPATCH
```
