# 09. Feature-by-Feature Tracker: Pembangunan Modular Bertahap

<!-- Format Wajib: Backend ➔ Frontend ➔ Cara Ngetest ➔ Lanjut/Revisi -->
<!-- Status Dokumen: Master Execution Tracker -->
<!-- Governance: Superpowers + ECC + User Consent Protocol -->
<!-- Date: September 2026 -->

---

## 🧭 1. Prinsip Siklus Eksekusi ("Rule of 4 Steps")

Setiap fitur kecil di bawah ini wajib dikerjakan satu per satu secara disiplin dan tidak boleh melompat ke fitur berikutnya sebelum disetujui:

```text
[ 1. BACKEND ]      Membangun fondasi logika, model data, parser, atau protokol Swift.
        ⬇
[ 2. FRONTEND ]     Membangun tampilan antarmuka visual SwiftUI, layout, dan interaksi layar.
        ⬇
[ 3. CARA NGETEST ] Memberikan panduan pengujian fisik/nyata yang konkret untuk Anda (pengguna).
        ⬇
[ 4. LANJUT/REVISI] Menunggu umpan balik & konfirmasi Anda: Lanjut ke fitur berikutnya atau revisi jika ada kekurangan.
```

---

## 📊 2. Master Progress Tracking Table

| ID | Nama Fitur Kecil | Fokus Utama | Target Komponen | Status | Verifikasi Pengguna |
| :---: | :--- | :--- | :--- | :---: | :---: |
| **F-01** | **Avatar Lab Parser & Model Geometri Strobi 3D** | Backend + 1:1 Canvas Projection | Model `.avatar.json` & Strobi 3D Ball Projection | 🟢 Approved | Disetujui Pengguna ("oke lanjut") |
| **F-02** | **Procedural Blinking & Transisi Ekspresi Waktu-Nyata** | Animasi Kedipan & Morphing 280ms | Harmonic squash height & 25 calibrated expressions | 🟢 Approved | Disetujui Pengguna ("oke saya acc") |
| **F-03** | **Dynamic Gaze Tracking & Notch Home Reactions** | Interaktivitas Kursor & Welcoming Bot | Dual-layer gaze parallax, Grok Bot White, Preset 25 (`angry-brows`) & Preset 26 (`uneasy-left`) 1:1 Spec | 🟢 Approved | Disetujui Pengguna ("oke sudah bagus") |
| **F-04** | **Integrasi Avatar Baru ke Rail & HomeSpace** | Penggantian Ikon Awan | `FloatingCompanionRail` & `HomeSpace` Studio | 🟢 Approved | 11 Templates, 27 Presets, 23 Animations, 3D Strobi Projection |
| **F-05** | **Isolasi Workspace & Storage Per-Companion** | Lingkungan Mandiri | `workspace/`, `browser_data/`, `memory.json`, shared workspace | 🟢 Approved | Disetujui Pengguna (Opsi 1 Clean Sandboxing) |
| **F-06** | **xAI Function Calling Engine (Registry & Dispatcher)**| Standar JSON Schema xAI | `ClickyFunctionToolRegistry` & `ClickyToolDispatcher`| 🟢 Approved | 6/6 TDD passed, parallel dispatch & UI mini-pill verified |
| **F-07** | **Kartu Chat "Computer" 1:1 Foto 1 (Static UI)** | Komponen Kartu Chat Baru | `HomeSpaceComputerCardView` (Header, pill, frame) | 🟢 Approved | 5/5 TDD passed, 1:1 Foto 1 visual canvas verified via screencapture |
| **F-08** | **Live Window Frame Streaming & Interactive Modal**| Snapshot Real-time & Modal 1:1 Foto 2 | `CompanionWindowStreamService` & `HomeSpaceInteractiveComputerModalView` | 🟢 Approved | 5/5 TDD passed, 1:1 Foto 2 semi-fullscreen modal verified (PID 49105) |
| **F-09** | **Alur Kerja Email & Web (Safari + Mail) & Human Takeover** | Safari/Mail App Switcher & Takeover | `MailWorkflowOperationTool`, Live Window Mirroring, `[ ✋ Take Over Screen ]` | 🟢 Approved | 5/5 TDD passed, live Apple Mail mirror & Takeover banner verified (PID 60674) |
| **F-10** | **6 Luna Medium Vision VM, Multi-Account Session Pool, & Notch Monitor** | Headless Codex CLI & Multi-Account Failover | `ChatGPTCodexVisionService`, `ChatGPTAccountPoolManager`, `ChatGPTAccountMonitorWidget` | 🟢 Implemented | 4/4 suites pass, headless Apple Menu vision verified, zero-restart pool, PID 65900 |

---

## 🛠️ 3. Rincian Teknis Per-Fitur (Detail 4 Langkah)

---

### 🔹 Fitur F-01: Avatar Lab Parser & Model Geometri Dasar Strobi 3D
*Mengadopsi format `.avatar.json` dari Bible Strong Avatar Lab dan merender bola 3D Strobi dengan sepasang mata kapsul/pill terproyeksi di SwiftUI.*

* **1. Backend**:
  - Buat berkas `boringNotch/Clicky/Avatars/CompanionAvatarDefinition.swift`.
  - Struktur data autentik: `AvatarSurfaceConfig` (sphere/capsule/cube, width, height, depth), `AvatarColors` (body, eyes), dan `AvatarExpression` (headX, headY, headZ, widthLeft, widthRight, heightLeft, heightRight, spacing, positionY, leftAngle, rightAngle, perspective).
  - Bundling berkas template avatar default Strobi: `boringNotch/Resources/Avatars/clicky_default.avatar.json`.
* **2. Frontend**:
  - Buat berkas `boringNotch/Clicky/Avatars/CompanionProceduralAvatarView.swift`.
  - Porting matematika 3D: `quaternionFromEuler`, `ellipsoidFrontSample`, `canonicalFaceCoordinates`, dan proyeksi perspektif `FOCAL_LENGTH = 620`.
  - Menggambar siluet bola kepala dan sepasang kapsul mata gelap yang terproyeksi secara 3D menggunakan `Canvas` CoreGraphics SwiftUI dengan clipping siluet.
  - Sediakan jendela uji coba/preview mandiri untuk memastikan render tajam di layar Retina.
* **3. Cara Ngetest Pengguna**:
  1. Jalankan aplikasi atau test view yang disediakan.
  2. Amati bola kepala 3D Strobi minimalis dengan sepasang mata pil gelap yang melengkung alami di permukaan bola, 100% bebas dari mulut/blush kartun.
  3. Cek apakah warna palet sesuai dengan konfigurasi JSON.
* **4. Lanjut / Revisi**:
  - Konfirmasi visual dari Anda: Apakah bentuk dasar Strobi 3D dan proporsi mata sudah pas? Jika OK $\rightarrow$ lanjut ke F-02.

---

### 🔹 Fitur F-02: Procedural Blinking & Transisi Ekspresi Waktu-Nyata
*Menghidupkan avatar Strobi dengan kedipan mata alami otomatis (squash height vertikal) dan transisi antar 25 calibrated expressions.*

* **1. Backend**:
  - Tambahkan timer prosedural kedipan: memicu kedipan acak setiap 3.5 hingga 6 detik selama 120ms (`isBlinking = true`).
  - Animasi kedipan menyusutkan tinggi kapsul mata secara vertikal: `height = 5 + (restingHeight - 5) * blinkProgress`.
  - Sediakan fungsi interpolasi ekspresi `interpolatePose(from:to:progress:)` untuk transisi halus antar orientasi kepala 3D dan bentuk mata.
* **2. Frontend**:
  - Perbarui `CompanionProceduralAvatarView.swift` dengan animasi transisi yang halus (`.easeInOut(duration: 0.12)`).
  - Tambahkan selector ekspresi di preview view untuk memvalidasi perubahan ekspresi saat bot berpikir atau mendengarkan.
* **3. Cara Ngetest Pengguna**:
  1. Buka tampilan avatar dan diamkan selama 10 detik.
  2. Perhatikan: Kapsul mata karakter menyusut berkedip alami seperti makhluk hidup.
  3. Ganti status companion (misal dari Idle ke Listening/Thinking), amati kepala berputar 3D dan mata meluncur ekspresif di permukaan bola.
* **4. Lanjut / Revisi**:
  - Jika ritme kedipan dan transisi ekspresi terasa natural $\rightarrow$ lanjut ke F-03.

---

### 🔹 Fitur F-03: Dynamic Gaze Tracking (Mata Mengikuti Kursor Mouse)
*Membuat pupil mata avatar melirik dan mengikuti gerakan mouse fisik pengguna di layar.*

* **1. Backend**:
  - Tangkap posisi kursor mouse global via `NSEvent.mouseLocation`.
  - Hitung vektor sudut dan jarak dari titik tengah mata avatar ke kursor mouse:
    `dx = mouseX - eyeCenterX`, `dy = mouseY - eyeCenterY`.
  - Terapkan pembatas radius maksimum (*clamping*) agar pupil tidak keluar dari bola mata (*sclera*).
* **2. Frontend**:
  - Sinkronkan offset pupil di dalam `CompanionProceduralAvatarView` secara real-time dengan interpolasi peredam spring.
* **3. Cara Ngetest Pengguna**:
  1. Posisikan mouse di sebelah kiri avatar $\rightarrow$ pupil melirik ke kiri.
  2. Gerakkan mouse ke pojok kanan atas $\rightarrow$ pupil melirik ke atas kanan.
  3. Gerakkan mouse menjauh $\rightarrow$ pupil tetap berada di batas tepi bola mata dengan rapi.
* **4. Lanjut / Revisi**:
  - Konfirmasi kehalusan lirik mata $\rightarrow$ lanjut ke F-04.

---

### 🔹 Fitur F-04: Penggantian Total Ikon Awan di Rail & HomeSpace Studio
*Menggantikan seluruh icon awan lama di antarmuka utama Izanotchy dengan avatar prosedural Avatar Lab.*

* **1. Backend**:
  - Hubungkan profil setiap companion di `CompanionProfile.swift` dengan avatar unik masing-masing (Clicky: Cyber-Orb, Market Scout: Cyber-Analyst, Research Buddy: Scholar, Shippy: Builder).
* **2. Frontend**:
  - Ganti `AgentCloudFaceView` di `FloatingCompanionRailView.swift` (rail di tepi layar), `CompanionPopoverCardView.swift`, dan dock bawah `HomeSpaceRootView.swift` dengan `CompanionProceduralAvatarView`.
  - Depresiasi spritesheet `artwork_cache/ClickyCharacters.png`.
* **3. Cara Ngetest Pengguna**:
  1. Buka Floating Rail di sisi layar macOS: amati slot maskot kini menampilkan avatar prosedural 3D-like berdimensi dengan gaze tracking.
  2. Buka HomeSpace Studio (klik notch): periksa dock bawah dan daftar session di sidebar menampilkan karakter baru tanpa ada sisa awan lama.
* **4. Lanjut / Revisi**:
  - Jika antarmuka visual sudah 100% bersih dari awan lama $\rightarrow$ lanjut ke F-05.

---

### 🔹 Fitur F-05: Isolasi Workspace & Storage Direktori Per-Companion
*Mewujudkan konsep "Each Bot has a Workspace" dengan memisahkan berkas, browser cookies, dan memori per companion.*

* **1. Backend**:
  - Modifikasi `CompanionWorkspaceManager.swift` untuk menginisialisasi struktur direktori lengkap di `~/.izanotchy/companions/<slug>/`:
    * `workspace/` (berkas kerja privat bot)
    * `browser_data/` (penyimpanan cookies & sesi peramban terisolasi)
    * `memory.json` (fakta & riwayat preferensi jangka panjang)
  - Inisialisasi folder bersama: `~/.izanotchy/shared_workspace/` untuk handoff berkas antar-bot.
* **2. Frontend**:
  - Di HomeSpace Studio bagian detail companion, tambahkan info path direktori kerja companion yang aktif dan tombol *"Open Workspace in Finder"*.
* **3. Cara Ngetest Pengguna**:
  1. Jalankan perintah terminal: `ls -la ~/.izanotchy/companions/`
  2. Pastikan setiap companion (`clicky`, `market-scout`, `research-buddy`) memiliki subfolder `workspace/` dan `browser_data/` tersendiri.
  3. Klik tombol *"Open Workspace in Finder"* di HomeSpace, buktikan Finder membuka folder yang tepat.
* **4. Lanjut / Revisi**:
  - Konfirmasi isolasi direktori $\rightarrow$ lanjut ke F-06.

---

### 🔹 Fitur F-06: Engine xAI Function Calling (Registry & Dispatcher)
*Mengadopsi protokol resmi xAI Function Calling berbasis JSON Schema dengan eksekusi paralel di Swift.*

* **1. Backend**:
  - Buat `ClickyFunctionTool.swift` (protokol tool dengan deklarasi JSON Schema).
  - Buat `ClickyFunctionToolRegistry.swift` (registri tools terpusat).
  - Buat `ClickyToolDispatcher.swift` (dispatcher eksekusi paralel via `withTaskGroup`).
  - Daftarkan tool pertama: `get_crypto_market_analysis` dan `workspace_file_operation`.
* **2. Frontend**:
  - Sediakan visual feedback berupa mini-pill di progress bar HomeSpace saat sebuah tool sedang dieksekusi (misal: `⚙️ Tool: get_crypto_market_analysis`).
* **3. Cara Ngetest Pengguna**:
  1. Jalankan unit test script: `swift scripts/test_function_calling_registry.swift`.
  2. Periksa output validasi: skema JSON terverifikasi sesuai format xAI API dan eksekusi mengembalikan `ClickyToolResult` yang presisi.
* **4. Lanjut / Revisi**:
  - Konfirmasi fungsionalitas tool calling $\rightarrow$ lanjut ke F-07.

---

### 🔹 Fitur F-07: Kartu Chat Interaktif "Computer" (1:1 Foto 1)
*Membangun kartu visual `[Computer • Working / Done]` persis seperti foto referensi yang diunggah pengguna.*

* **1. Backend**:
  - Perluas `HomeSpaceChatMessage` di `ClickyEnums.swift` dengan payload opsional `computerPayload: ComputerCardPayload?`.
  - Field payload: `cardTitle` ("Computer"), `status` (`.working`, `.done`, `.takeoverNeeded`), `instructionText`, dan `snapshotImagePath`.
* **2. Frontend**:
  - Buat `HomeSpaceComputerCardView.swift` lengkap dengan:
    * Header bar: teks "Computer", status pill (`Working` biru animasi / `Done` hijau).
    * Teks instruksi: *"Sign in to Salesforce so I can see the accounts you own."*
    * Frame visual canvas jendela aplikasi bergaya dark mode dengan bayangan halus di atas wallpaper desktop.
  - Pasang komponen ini di dalam alur pesan chat `HomeSpaceRootView.swift`.
* **3. Cara Ngetest Pengguna**:
  1. Buka HomeSpace Studio.
  2. Lihat kartu `Computer` ter-render di dalam bubble pesan chat dengan layout, pill status, dan frame jendela yang 1:1 identik dengan Foto 1.
* **4. Lanjut / Revisi**:
  - Cek kecocokan visual dengan Foto 1 $\rightarrow$ lanjut ke F-08.

---

### 🔹 Fitur F-08: Live Window Frame Streaming & Interactive Semi-Fullscreen Modal (1:1 Foto Baru)
*Menghubungkan frame snapshot jendela aplikasi riil ke dalam kartu chat Computer dan menyediakan modal mekar semi-fullscreen interaktif 1:1 Foto Baru.*

* **1. Backend**:
  - Bangun `CompanionWindowStreamService.swift` (singleton `@MainActor`).
  - Menangkap jendela target aplikasi macOS via `CGWindowListCopyWindowInfo` dan `CGWindowListCreateImage`.
  - Simpan frame berkala ke `~/.izanotchy/companions/<slug>/workspace/snapshots/active_frame.png` dengan timer streaming ter-throttle.
* **2. Frontend**:
  - Buat `HomeSpaceInteractiveComputerModalView.swift` dengan layout 1:1 Foto Baru (`media_1790936424964.png`):
    * Backdrop gelap transparan `Color.black.opacity(0.70)` meredupkan seluruh jendela termasuk sidebar.
    * Tombol tutup `[ ✕ ]` di sudut kanan atas modal.
    * Kanvas pemandangan alam (perbukitan zaitun di kiri, amber emas di kanan, dan sungai turquoise di tengah).
    * Dua jendela dark-mode macOS melayang (CRM accounts table & Outreach queue).
    * Badge kursor pengambilalihan `"You"` (`youCursorBadge`) di atas jendela aktif.
    * Floating glass mini dock di bagian bawah kanvas dengan ikon Safari dan Mail interaktif (hover zoom spring & click-to-switch capture).
  - Hubungkan kartu chat `HomeSpaceComputerCardView` agar saat diklik mekar membuka modal interaktif ini.
* **3. Cara Ngetest Pengguna**:
  1. Klik kartu chat `[Computer]` atau jalankan: `open "izanotchy://trigger-computer-modal"`.
  2. Saksikan modal semi-fullscreen mekar di tengah jendela dengan backdrop gelap meredupkan sidebar dan chat.
  3. Coba hover ikon Safari dan Mail di mini dock, dan klik tombol `[ ✕ ]` di sudut kanan atas untuk menutup modal dengan suara lembut.
* **4. Lanjut / Revisi**:
  - Konfirmasi modal interaktif & live streaming $\rightarrow$ lanjut ke F-09 (Protokol Human Takeover).

---

### 🔹 Fitur F-09: Alur Kerja Email & Web (Safari + Mail.app) & Protokol Human Takeover
*Alur kerja gabungan browser & client email native macOS dengan live window projection (tanpa mockup palsu), mini dock app switcher interaktif, dan protokol pengambilalihan kontrol aman saat 2FA / Login.*

* **1. Backend**:
  - `ClickyEnums.swift`: Menambahkan `workflowAppNames` pada `BuddySession` (default `["Safari", "Mail"]` untuk Inbox Buddy) serta `activeWorkflowApp` dan `takeoverReason` pada `ComputerCardPayload`.
  - `CompanionWindowStreamService.swift`: Menambahkan `switchTargetApp(appName:slug:)`, `resolveRunningAppWindows(appNames:)`, dan `launchOrFocusWorkflowApp(appName:)`.
  - `ClickyFunctionTool.swift` & `ClickyFunctionToolRegistry.swift`: Mengimplementasikan `MailWorkflowOperationTool` (`mail_workflow_operation`) dengan aksi `read_inbox`, `create_draft`, dan `request_takeover`.
* **2. Frontend**:
  - `HomeSpaceInteractiveComputerModalView.swift`:
    * Mengeliminasi 100% wallpaper alam Sonoma dan jendela CRM palsu.
    * Memproyeksikan citra nyata jendela aplikasi target (Apple Mail.app / Safari) secara langsung ke kanvas. Jika aplikasi belum dibuka, menampilkan kartu koneksi interaktif dengan tombol `[ ↗ Launch <App> ]`.
    * Meng-upgrade mini dock menjadi **Interactive App Switcher** dengan ring seleksi bercahaya biru pada aplikasi aktif.
    * Banner Protokol Human Takeover (`takeoverNotificationBanner`): Kapsul amber `✋ Takeover Needed` dengan deskripsi alasan 2FA/login dan tombol aksi `[ Take Over Screen ]` (memfokuskan aplikasi macOS) serta `[ ▶️ Resume Companion ]`.
  - `HomeSpaceComputerCardView.swift`: Menyematkan status `Takeover Needed` dan tombol interaktif `[ ✋ Take Over Screen ]` pada kartu chat timeline.
* **3. Cara Ngetest Pengguna**:
  1. Jalankan `open "izanotchy://trigger-computer-modal?app=Mail&takeover=true"` untuk melihat modal semi-fullscreen dengan live mirror Apple Mail.app dan banner Takeover.
  2. Buka chat HomeSpace dan saksikan kartu `Computer` dengan badge `• Takeover Needed` dan tombol `[ ✋ Take Over Screen ]`.
  3. Klik ikon Safari atau Mail pada mini dock di bagian bawah modal untuk berganti aplikasi kerja bot secara instan.
* **4. Lanjut / Revisi**:
  - Setelah verifikasi alur kerja Safari & Mail disetujui $\rightarrow$ lanjut ke F-10 (Multi-Companion Group Chat & @Mentions).
  - Konfirmasi alur takeover mulus $\rightarrow$ lanjut ke F-10.

---

### 🔹 Fitur F-10: Multi-Companion Collaboration Mesh & Group Chats
*Menggabungkan beberapa companion dalam satu thread chat, delegasi @mention, dan handoff asinkron.*

* **1. Backend**:
  - Bangun `CompanionCollaborationBus.swift` (actor event queue dengan mutex `VisualLock`).
  - Handoff request membawa pointer file artefak di `~/.izanotchy/shared_workspace/`.
* **2. Frontend**:
  - Tambahkan autocomplete `@` di composer HomeSpace untuk memilih companion.
  - Tampilkan pill transisi kolaborasi di chat: `Asking Market Scout...` $\rightarrow$ `Looping in Pine Script Dev...`.
* **3. Cara Ngetest Pengguna**:
  1. Buka thread Group Chat di HomeSpace.
  2. Ketik perintah: *"@MarketScout scan koin, lalu minta @ResearchBuddy simpulkan beritanya."*
  3. Amati: Bot pertama menyelesaikan tugasnya, lalu otomatis memicu bot kedua di thread yang sama tanpa copy-paste manual dari Anda.
* **4. Lanjut / Revisi**:
  - Verifikasi handoff antar bot selesai dengan sempurna.
