# 08. Clicky Codebase Refactor Plan: Analisis Berkas & Rencana Refaktorisasi Terstruktur

<!-- Status: Comprehensive Codebase Audit & Refactor Blueprint -->
<!-- Target: boringNotch / Clicky Subsystem -->
<!-- Governance: Superpowers + ECC + Zero-Regression Guarantee -->
<!-- Date: September 2026 -->

---

## 🔍 1. Hasil Audit Menyeluruh Berkas Clicky Saat Ini

Saat ini di dalam direktori `boringNotch/Clicky/`, terdapat total **56 berkas Swift** dan sejumlah folder pendukung:
- **Audio/** (6 berkas): Penanganan transkripsi suara (Apple Speech, OpenAI, AssemblyAI) dan dikte.
- **Context/** (1 berkas): Pemantau integrasi dan saran kontekstual.
- **Floating/** (2 berkas): Jendela mengambang dan efek bola kaca aqua.
- **HomeSpace/** (2 berkas): Antarmuka studio chat utama (`HomeSpaceRootView.swift` sebesar 135 KB dan window manager).
- **Onboarding/** (2 berkas): Wawancara pembuatan companion baru dan workspace manager.
- **Rail/** (4 berkas): Bilah sisi mengambang di tepi layar (`FloatingCompanionRailView`, popover card, overflow switcher).
- **Roster/** (2 berkas): Pengelola profil companion (`CompanionProfile.swift` dan `CompanionRosterStore.swift`).
- **Tools/** (6 berkas): Alat navigasi, penggambaran chart, dan layout TradingView.
- **Root Clicky/** (31 berkas): Berkas monolitik (`CompanionManager.swift` sebesar 260 KB), mesin kuantitatif Astronacci, konektor BingX, driver CUA, dan TTS ElevenLabs.

Berikut adalah rencana refaktorisasi terstruktur yang dibagi menjadi 5 kategori mutlak:
1. 🗑️ **APA YANG DIHAPUS (DELETED / DEPRECATED)**
2. ✏️ **APA YANG DI-EDIT (MODIFIED)**
3. 📦 **APA YANG DIPINDAHKAN (MOVED / RESTRUCTURED)**
4. ➕ **APA YANG DITAMBAH (ADDED / NEW MODULES)**
5. 🔧 **APA YANG DIPERBAIKI & DIPERKOKOH (FIXED & HARDENED)**

---

## 🗑️ 2. APA YANG DIHAPUS (DELETED / DEPRECATED)

| Berkas / Komponen | Alasan Penghapusan / Deprekasi | Pengganti |
| :--- | :--- | :--- |
| `artwork_cache/ClickyCharacters.png` | Spritesheet raster 2D awan statis yang kaku dan buram saat diskalakan di layar retina. | Format vektor prosedural `.avatar.json` dari Bible Strong Avatar Lab. |
| `AgentCloudFaceView` (Path awan SwiftUI di `CompanionProfile.swift`) | Bentuk kartun awan flat yang seragam untuk semua companion tanpa kepribadian peran. | `CompanionProceduralAvatarView` (geometri squircle/capsule berdimensi, rigging mata mandiri, dan aksesoris spesifik). |
| Hardcoded Prompt String Builders di `CompanionManager.swift` | String template prompt buatan tangan yang memaksakan percabangan teks manual. | JSON Schema resmi xAI Function Calling (`ClickyFunctionToolRegistry`). |
| Tombol & Aksi Tong Sampah CUA Legacy di `TradingViewDrawingTool.swift` | Sisa-sisa dead-code selector klik fisik tong sampah yang sudah didepresiasi oleh Universal Command Palette `Cmd+K`. | Dibersihkan total untuk merampingkan codebase. |

---

## ✏️ 3. APA YANG DI-EDIT (MODIFIED)

### 1. `boringNotch/Clicky/Roster/CompanionProfile.swift`
- **Perubahan**:
  - Ganti `mood: AgentCloudFaceMood` menjadi referensi ekspresi Avatar Lab `expression: CompanionExpressionType`.
  - Tambahkan properti link definisi avatar: `avatarDefinitionPath: String` (mengarah ke berkas `.avatar.json`).
  - Tambahkan properti isolasi ruang kerja: `workspacePath: String`, `browserDataPath: String`, dan `memoryPath: String`.
  - Tambahkan daftar rutinitas aktif: `routines: [CompanionRoutine]`.

### 2. `boringNotch/Clicky/ClickyEnums.swift`
- **Perubahan**:
  - Perluas `HomeSpaceChatMessage` dari sekadar teks string menjadi model polimorfik:
    ```swift
    public struct HomeSpaceChatMessage: Identifiable, Codable, Equatable {
        public let id: UUID
        public let isUser: Bool
        public let text: String
        public let timestamp: Date
        public var computerPayload: ComputerCardPayload? // Mendukung Foto 1!
        public var toolCalls: [ClickyToolCallSnippet]?
        public var requiresSecretInput: Bool?
    }
    ```

### 3. `boringNotch/Clicky/Onboarding/CompanionWorkspaceManager.swift`
- **Perubahan**:
  - Jangan hanya membuat `output/` dan `<slug>.md`.
  - Inisialisasi struktur folder lengkap: `workspace/`, `shared_workspace/`, `browser_data/`, `memory.json`, dan `avatar.json`.
  - Tambahkan metode pembacaan dan penulisan memory jangka panjang companion.

### 4. `boringNotch/Clicky/HomeSpace/HomeSpaceRootView.swift`
- **Perubahan**:
  - Di dalam `chatWorkspaceView`, jika `message.computerPayload != nil`, render komponen baru `HomeSpaceComputerCardView` (Foto 1) alih-alih bubble teks biasa.
  - Ganti ikon awan di sidebar dan dock bawah dengan `CompanionProceduralAvatarView`.
  - Tambahkan dukungan pengetikan `@` untuk autocomplete nama companion (Group Chat).

### 5. `boringNotch/Clicky/Rail/FloatingCompanionRailView.swift` & `CompanionPopoverCardView.swift`
- **Perubahan**:
  - Ganti render lingkaran awan dengan `CompanionProceduralAvatarView` mini (ukuran 36–44pt).
  - Hubungkan gaze tracking: bola mata avatar di rail melirik ke arah kursor pengguna secara halus saat mouse mendekat.

### 6. `boringNotch/Clicky/CompanionManager.swift`
- **Perubahan**:
  - Dekopel (pangkas) logika pemanggilan tool yang selama ini menumpuk di file ini.
  - Alihkan eksekusi tool ke `ClickyToolDispatcher` dan `ClickyFunctionToolRegistry`.
  - Pasang pendengar sinyal takeover untuk menghentikan loop eksekusi saat pengguna diminta login.

---

## 📦 4. APA YANG DIPINDAHKAN (MOVED / RESTRUCTURED)

Untuk menjaga struktur folder rapi dan modular:

| Berkas Saat Ini | Lokasi Baru | Alasan |
| :--- | :--- | :--- |
| `boringNotch/Clicky/BingXMarketDataEngine.swift` | `boringNotch/Clicky/Tools/Market/BingXMarketDataEngine.swift` | Mengelompokkan semua modul market data di subfolder tools yang jelas. |
| `boringNotch/Clicky/FuturesScoutMarketDataService.swift` | `boringNotch/Clicky/Tools/Market/FuturesScoutMarketDataService.swift` | Penataan namespace domain market. |
| `boringNotch/Clicky/Astronacci*.swift` (8 berkas) | `boringNotch/Clicky/Tools/Astronacci/` | Mengumpulkan 8 engine astrologi/Fibonacci ke dalam 1 subfolder terisolasi agar tidak mengotori root `Clicky/`. |
| `boringNotch/Clicky/WorkSettingsViews.swift` | `boringNotch/Clicky/HomeSpace/WorkSettingsViews.swift` | Komponen pengaturan ini adalah sub-tampilan dari HomeSpace Studio. |

---

## ➕ 5. APA YANG DITAMBAH (ADDED / NEW MODULES)

| Berkas Baru | Namespace / Tanggung Jawab | Deskripsi Fitur |
| :--- | :--- | :--- |
| `ClickyFunctionTool.swift` | `boringNotch/Clicky/Tools/` | Protokol tool terstandarisasi xAI JSON Schema (`parametersSchema`, `execute`, `ClickyToolResult`). |
| `ClickyFunctionToolRegistry.swift` | `boringNotch/Clicky/Tools/` | Singleton registri penyimpan seluruh katalog tools yang dapat dipanggil model AI. |
| `ClickyToolDispatcher.swift` | `boringNotch/Clicky/Tools/` | Engine eksekusi paralel berbasis `TaskGroup` dengan pemisahan Plane A (API) vs Plane B (CUA). |
| `HomeSpaceComputerCardView.swift` | `boringNotch/Clicky/HomeSpace/` | Komponen SwiftUI kartu chat 1:1 Foto 1 (Header `Computer`, status pill `Working`/`Done`, frame visual jendela dark-mode, tombol Takeover). |
| `CompanionAvatarDefinition.swift` | `boringNotch/Clicky/Avatars/` | Parser & model data berkas `.avatar.json` dari Bible Strong Avatar Lab. |
| `CompanionProceduralAvatarView.swift` | `boringNotch/Clicky/Avatars/` | Engine rendering vektor prosedural SwiftUI (squircle 3D, rigging mata, procedural blinking, gaze tracking). |
| `CompanionCollaborationBus.swift` | `boringNotch/Clicky/Collaboration/` | Actor event-bus untuk menangani delegasi tugas asinkron antar-companion dan `VisualLock` mutex kursor. |
| `AutoReviewSecurityEngine.swift` | `boringNotch/Clicky/Security/` | Implementasi aturan keamanan Grok Bot (`Ask first` vs `Allow automatically` dan masked secret fields). |
| `CompanionRoutineManager.swift` | `boringNotch/Clicky/Routines/` | Pengelola rutinitas latar belakang terjadwal (cron/interval) dengan batas approval. |

---

## 🔧 6. APA YANG DIPERBAIKI & DIPERKOKOH (FIXED & HARDENED)

1. **Perbaikan Masalah Pembajakan Kursor Fisik (Screen Hijacking)**:
   - **Penyebab**: `cua-driver` langsung menggerakkan mouse fisik pengguna tanpa memeriksa apakah pengguna sedang mengetik.
   - **Solusi**: Terapkan `VisualLock` pada `CompanionCollaborationBus`. Jika tool yang dipanggil adalah Plane A (baca data BingX, baca file, search web), CUA **sama sekali tidak disentuh (0 sentuhan mouse)**. Jika tool Plane B membutuhkan CUA, sistem mengecek idle user dan memberikan feedback visual di kartu `Computer`.
2. **Perbaikan Celah 2FA / Login Macet**:
   - **Penyebab**: Companion gagal atau timeout saat menemukan formulir login/CAPTCHA.
   - **Solusi**: Integrasikan tool `request_human_takeover`. Status kartu chat seketika berubah menjadi amber `Takeover Required`, kursor dilepas ke pengguna, dan companion menunggu sinyal resume sebelum melanjutkan.
3. **Perbaikan Monolitik `CompanionManager.swift` (260 KB)**:
   - **Penyebab**: Terlalu banyak tanggung jawab (audio, LLM network call, roster synchronization, CUA dispatching) disatukan dalam 1 file raksasa.
   - **Solusi**: Pecah secara bertahap tanpa regresi ke sub-service: `ClickyToolDispatcher`, `CompanionCollaborationBus`, dan `CompanionRoutineManager`.
4. **Perbaikan Skalabilitas Format Chat**:
   - **Penyebab**: Teks chat hanya bisa menerima string tunggal, tidak bisa menyajikan bukti visual (*evidence preservation*).
   - **Solusi**: Payload `computerPayload` memungkinkan penanaman screenshot frame jendela yang disimpan lokal di `workspace/snapshots/` langsung ke dalam bubble percakapan.

---

## 🗺️ 7. Pemetaan Eksekusi Refaktorisasi ke Fitur Mikro (F-01 s/d F-10)

Untuk menjamin tidak ada perubahan yang bertabrakan (*zero conflict*) atau memicu regresi pada fitur yang sudah stabil, seluruh refaktorisasi di atas dikelompokkan ke dalam 10 unit fitur mikro pada [`09_FEATURE_BY_FEATURE_TRACKER.md`](file:///Users/heizaaa/Desktop/cdev/iza-3/docs/grok-bot-companion-adoption/09_FEATURE_BY_FEATURE_TRACKER.md):

| Unit Refaktorisasi | Berkas yang Dikerjakan | Dipetakan ke Fitur Mikro |
| :--- | :--- | :---: |
| **Model Avatar & Canvas Parser** | `CompanionAvatarDefinition.swift`, `CompanionProceduralAvatarView.swift` | **F-01** |
| **Kedipan & State Ekspresi Wajah** | `CompanionExpressionType`, procedural timer di avatar view | **F-02** |
| **Interaktivitas Gaze Tracking** | Kalkulasi vektor pupil terhadap `NSEvent.mouseLocation` | **F-03** |
| **Penggantian Awan di Rail & HomeSpace**| `FloatingCompanionRailView`, `CompanionPopoverCardView`, `HomeSpaceRootView` | **F-04** |
| **Isolasi Folder & Storage Per-Bot** | `CompanionWorkspaceManager.swift` (`workspace/`, `browser_data/`) | **F-05** |
| **Registri JSON Schema & Dispatcher** | `ClickyFunctionTool.swift`, `ClickyFunctionToolRegistry.swift` | **F-06** |
| **Desain Kartu Chat Foto 1 (Static)** | `HomeSpaceComputerCardView.swift`, payload di `ClickyEnums.swift` | **F-07** |
| **Streaming Frame Jendela Riil** | `CGWindowListCreateImage` pipeline ke `HomeSpaceComputerCardView` | **F-08** |
| **Penanganan 2FA / Login Takeover** | `request_human_takeover`, tombol takeover & resume di kartu | **F-09** |
| **Group Chat & Bus Handoff Antar-Bot** | `CompanionCollaborationBus.swift`, autocomplete `@` di HomeSpace | **F-10** |

