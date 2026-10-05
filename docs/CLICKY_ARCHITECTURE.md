# Struktur Folder & Arsitektur Clicky / Izanotchy

Dokumen ini memetakan seluruh file dan folder di dalam modul `boringNotch/Clicky`. Setiap entri mencantumkan **tujuan/fungsi spesifik** dalam tanda kurung `(...)` dan **koneksi ketergantungan (file/fungsi terkait)** dalam tanda kurung siku `[...]`.

---

## 📂 `boringNotch/Clicky`

### 📁 `CUA/` (Computer Use Agent — Lapisan Eksekusi dan Interaksi Fisik Layar)
* 📁 **`Actions/`** (Implementasi alat aksi fisik universal mouse, keyboard, dan pembacaan AX)
  * `CUAClickActionTool.swift` — (Eksekusi klik mouse fisik, hover, dan double click dengan Accessibility fallback) [Terhubung ke: `CuaDriverClient`, `MascotVirtualDesktopService`, `CUAPhysicalActionDispatcher`]
  * `CUAPhysicalActionDispatcher.swift` — (Router eksekutor yang memetakan jenis aksi CUA ke tool yang bersangkutan) [Terhubung ke: `CompanionVMAgentLoop`, `CUAClickActionTool`, `CUAScrollActionTool`, `CUATypeActionTool`, `CUAReadActionTool`]
  * `CUAPhysicalActionTool.swift` — (Protokol dasar antarmuka tool aksi fisik sistem komputer) [Terhubung ke: seluruh kelas tool di `Actions/`]
  * `CUAReadActionTool.swift` — (Pembacaan teks dan inspeksi hierarki elemen UI via Accessibility IPC) [Terhubung ke: `CuaVisualGrounder`, `TaskStepPlanner`]
  * `CUAScrollActionTool.swift` — (Scroll kinetik adaptif berbasis proporsi baris list serta reset scroll ke posisi paling atas) [Terhubung ke: `CuaDriverClient`, `CompanionVMAgentLoop`]
  * `CUATypeActionTool.swift` — (Pengetikan teks keyboard fisik, enter key, dan sintesis shortcut) [Terhubung ke: `CuaDriverClient`, `ComputerUsePhysicalExecutor`]
* 📁 **`Execution/`** (Mesin tingkat rendah untuk pergerakan kursor, socket daemon, dan sintesis event)
  * `ComputerUsePhysicalExecutor.swift` — (Sintesis input tingkat rendah CGEvent, aktivasi jendela aplikasi, dan penghentian proses) [Terhubung ke: `CUATypeActionTool`, `CuaActionCursorManager`]
  * `CuaActionCursorManager.swift` — (Manajemen kursor virtual & reticle maskot di atas layar saat companion bekerja) [Terhubung ke: `MascotVirtualDesktopService`, `CUAPhysicalActionDispatcher`]
  * `CuaDriverClient.swift` — (Klien IPC socket Unix ke helper daemon `cua-driver` untuk bypass event tap sandbox) [Terhubung ke: `CUAClickActionTool`, `CUAScrollActionTool`, `CUATypeActionTool`]
  * `CuaMotionEngine.swift` — (Perhitungan interpolasi kurva kinetik pergerakan kursor yang halus dan alamiah) [Terhubung ke: `CuaActionCursorManager`, `MascotVirtualDesktopService`]
* 📁 **`Grounding/`** (Pencarian koordinat dan identifikasi elemen antarmuka pengguna)
  * `ClickyHybridGroundingEngine.swift` — (Orkestrasi grounding hibrida menggabungkan OCR teks lokal dan koordinat visual) [Terhubung ke: `AFMLunaCoordinationBridge`, `CuaVisualGrounder`]
  * `CuaVisualGrounder.swift` — (Ekstraksi universal elemen antarmuka dari AX Tree dan OCR teks tanpa hardcoding aplikasi) [Terhubung ke: `CompanionVMAgentLoop`, `ClickyHybridGroundingEngine`]
* 📁 **`Loop/`** (Siklus iterasi otonom agen komputer)
  * `CompanionVMAgentLoop.swift` — (Loop otonom CUA multi-step: snapshot -> observasi terarah -> step planner -> eksekusi aksi -> egress validator) [Terhubung ke: `TaskIngressGateway`, `TaskStepPlanner`, `TaskEgressValidator`, `CUAPhysicalActionDispatcher`, `CompanionWindowStreamService`]
  * `CompanionVMBackgroundWatcher.swift` — (Pemantau latar belakang untuk mendeteksi perubahan status jendela dan target aplikasi aktif) [Terhubung ke: `CompanionVMAgentLoop`, `CompanionWindowStreamService`]

---

### 📁 `Core/` (Fondasi Arsitektur, Logging, dan Pipeline Cepat)
* `AppBundleConfiguration.swift` — (Penyedia bundle identifier dan lokasi file sumber daya aplikasi saat runtime) [Terhubung ke: `ClickySoundEngine`, `DesignSystem`]
* `ClickyAnalytics.swift` — (Pencatat metrik analitik durasi eksekusi aksi, tingkat keberhasilan tugas, dan latensi grounding) [Terhubung ke: `CompanionVMAgentLoop`, `TaskStepPlanner`]
* `ClickyDeterministicPipeline.swift` — (Pipeline deterministik cepat untuk intent langsung, peluncuran aplikasi dinamis, dan router domain) [Terhubung ke: `TradingViewCommandRouter`, `DynamicAppResolver`, `CompanionManager`]
* `ClickyEnums.swift` — (Definisi enumerasi global untuk status maskot, kategori intent tugas, dan prioritas sistem) [Terhubung ke: seluruh modul Clicky]
* `ClickyFunctionTool.swift` — (Protokol dan struktur skema deklarasi pemanggilan fungsi tool Clicky) [Terhubung ke: `ClickyFunctionToolRegistry`, `ClickyToolDispatcher`]
* `ClickyFunctionToolRegistry.swift` — (Pusat pendaftaran seluruh tool fungsi yang dapat dipanggil oleh model AI) [Terhubung ke: `ClickyToolDispatcher`, `SiriAIEngine`]
* `ClickyLogger.swift` — (Sistem logging thread-safe terpusat berbasis NSLock yang menulis ke `~/Library/Logs/Izanotchy/clicky.log`) [Terhubung ke: seluruh sub-sistem Clicky]
* `ClickyToolDispatcher.swift` — (Dispatcher yang menerjemahkan tool call dari luaran model menjadi eksekusi fungsi konkret) [Terhubung ke: `ClickyFunctionToolRegistry`, `CompanionVMAgentLoop`]
* `CompanionManager.swift` — (Manajer singleton utama siklus hidup avatar, status visibilitas notch/kursor, dan mode interaksi) [Terhubung ke: `OverlayWindowManager`, `HomeSpaceWindowManager`, `CompanionVMAgentLoop`]
* `PCCGroundingEscalation.swift` — (Mekanisme eskalasi darurat jika Accessibility Tree gagal menemukan elemen menuju VLM vision) [Terhubung ke: `AFMLunaCoordinationBridge`, `CuaVisualGrounder`]

---

### 📁 `Reasoning/` (Arsitektur Penalaran Cerdas: Ingress, Planner, Validator, dan Koordinasi Model)
* 📁 **`Coordination/`**
  * `AFMLunaCoordinationBridge.swift` — (Jembatan kolaborasi model: AFM 3B mengevaluasi logika struktural teks, Luna memverifikasi koordinat visual spasial) [Terhubung ke: `SiriAIEngine`, `ChatGPTCodexVisionService`, `CompanionVMAgentLoop`]
* 📁 **`Ingress/`** (Pintu masuk penerimaan instruksi pengguna)
  * `CanonicalTaskContract.swift` — (Struktur data kontrak tugas formal: target entity, target index, goal deskriptif, dan intent type) [Terhubung ke: `TaskIngressGateway`, `CompanionVMAgentLoop`]
  * `TaskIngressGateway.swift` — (Penerjemah bahasa bebas pengguna menjadi kontrak kanonikal terstruktur via model AFM) [Terhubung ke: `IngressPolicy`, `SiriAIEngine`, `CanonicalTaskContract`]
  * 📁 **`Policies/`**
    * `IngressPolicy.swift` — (Definisi prompt sistem murni dan skema JSON abstraksi intent tanpa hardcoding aplikasi) [Terhubung ke: `TaskIngressGateway`]
* 📁 **`Planner/`** (Perencanaan langkah per iterasi)
  * `TaskStepPlanner.swift` — (Perencana langkah aksi berikutnya per iterasi loop: click, scroll_down, type, atau finish) [Terhubung ke: `StepPolicyRegistry`, `SiriAIEngine`, `CompanionVMAgentLoop`]
  * 📁 **`Policies/`**
    * `StepPolicyRegistry.swift` — (Pusat registrasi kebijakan langkah dinamis sesuai kategori intent tugas) [Terhubung ke: `TaskStepPlanner`, `InspectStepPolicy`, `ComposeStepPolicy`]
    * `InspectStepPolicy.swift` — (Prompt kebijakan AFM untuk navigasi daftar item dengan aturan ketat anti-spurious scroll) [Terhubung ke: `StepPolicyRegistry`]
    * `ComposeStepPolicy.swift` — (Prompt kebijakan AFM untuk pengisian formulir, pengetikan teks, dan persiapan submit) [Terhubung ke: `StepPolicyRegistry`]
* 📁 **`Validator/`** (Evaluasi penyelesaian tugas)
  * `TaskEgressValidator.swift` — (Validator multi-tanggung jawab terpisah: evaluasi teknis isDone/takeover dan sintesis respons bahasa manusia) [Terhubung ke: `ValidationPolicyRegistry`, `SiriAIEngine`, `CompanionVMAgentLoop`]
  * 📁 **`Policies/`**
    * `ValidationPolicyRegistry.swift` — (Pusat registrasi kebijakan evaluasi akhir per kategori intent tugas) [Terhubung ke: `TaskEgressValidator`, `InspectValidationPolicy`, `ComposeValidationPolicy`]
    * `InspectValidationPolicy.swift` — (Prompt kebijakan verifikasi teknis apakah item target telah diklik dan reading pane telah memuat konten baru) [Terhubung ke: `ValidationPolicyRegistry`]
    * `ComposeValidationPolicy.swift` — (Prompt kebijakan verifikasi teknis apakah seluruh isian form telah lengkap sebelum meminta takeover) [Terhubung ke: `ValidationPolicyRegistry`]

---

### 📁 `Roster/` (Profil Karakter Avatar, Onboarding, dan Konteks Lingkungan)
* `CompanionProfile.swift` — (Model data konfigurasi avatar: nama, suara, warna, tema, dan kepribadian companion) [Terhubung ke: `CompanionRosterStore`, `CompanionManager`]
* `CompanionRosterStore.swift` — (Penyimpanan persisten profil-profil companion ke disk) [Terhubung ke: `CompanionProfile`, `CompanionManager`]
* 📁 **`Context/`**
  * `IntegrationSuggestionMonitor.swift` — (Pemantau aplikasi aktif untuk menyarankan integrasi automasi yang relevan kepada pengguna) [Terhubung ke: `DynamicAppResolver`, `CompanionManager`]
* 📁 **`Onboarding/`**
  * `CompanionInterviewEngine.swift` — (Engine alur wawancara onboarding interaktif untuk personalisasi avatar) [Terhubung ke: `CompanionInterviewPolicy`, `SiriAIEngine`, `CompanionProfile`]
  * `CompanionWorkspaceManager.swift` — (Manajer direktori workspace lokal dan file konfigurasi spesifik companion) [Terhubung ke: `CompanionProfile`, `CompanionRosterStore`]
  * 📁 **`Policies/`**
    * `CompanionInterviewPolicy.swift` — (Definisi prompt sistem murni untuk memandu wawancara onboarding avatar) [Terhubung ke: `CompanionInterviewEngine`]

---

### 📁 `Services/` (Penyedia Layanan Eksternal, Audio, Visi, Domain Khusus, dan AI)
* 📁 **`Audio/`** (Pemrosesan suara, transkripsi STT, dan sintesis TTS)
  * `AppleSpeechTranscriptionProvider.swift` — (Transkripsi suara on-device native macOS via Apple Speech dengan kosa kata aplikasi dinamis) [Terhubung ke: `BuddyDictationManager`, `DynamicAppResolver`]
  * `BuddyAudioConversionSupport.swift` — (Utilitas konversi format buffer audio PCM, sample rate, dan bit depth) [Terhubung ke: `BuddyDictationManager`, `AppleSpeechTranscriptionProvider`]
  * `BuddyDictationManager.swift` — (Manajer alur rekam mikrofon dan konversi suara ke teks secara real-time) [Terhubung ke: `AppleSpeechTranscriptionProvider`, `OpenAIAudioTranscriptionProvider`, `CompanionManager`]
  * `BuddyTranscriptionProvider.swift` — (Protokol kontrak antarmuka penyedia layanan transkripsi audio) [Terhubung ke: `BuddyDictationManager`]
  * `ClickySoundEngine.swift` — (Pemutar efek suara kinetik UI dan notifikasi audio companion) [Terhubung ke: `CompanionManager`, `CompanionVMAgentLoop`]
  * `ElevenLabsTTSClient.swift` — (Klien sintesis suara ElevenLabs TTS via REST API untuk menghasilkan suara natural) [Terhubung ke: `CompanionManager`, `BuddyDictationManager`]
  * `GlobalPushToTalkShortcutMonitor.swift` — (Pemantau shortcut global keyboard `⌥ Option` / `⌃ Control + ⌥ Option` untuk Push-to-Talk) [Terhubung ke: `BuddyDictationManager`, `CompanionManager`]
  * `OpenAIAudioTranscriptionProvider.swift` — (Layanan transkripsi alternatif berbasis cloud menggunakan OpenAI Whisper API) [Terhubung ke: `BuddyDictationManager`, `OpenAIAPI`]
* 📁 **`Domain/`** (Pustaka Logika Khusus Domain Tertentu)
  * 📁 **`Astronacci/`** (Algoritma analisa pasar keuangan metode Astronacci)
    * `AstronacciClusterEngine.swift` — (Kalkulasi pengelompokan zona target harga dan waktu pembalikan Fibonacci) [Terhubung ke: `AstronacciDeterministicEngine`]
    * `AstronacciDeterministicEngine.swift` — (Engine utama analisis terpadu pergerakan harga dan siklus waktu pasar) [Terhubung ke: `ClickyDeterministicPipeline`, `TradingViewActionDispatcher`]
    * `AstronacciDivergenceEngine.swift` — (Deteksi pola divergensi indikator momentum RSI/MACD terhadap harga) [Terhubung ke: `AstronacciDeterministicEngine`]
    * `AstronacciEconomicCalendarEngine.swift` — (Pengurai dampak rilis berita ekonomi global dari data kalender ekonomi) [Terhubung ke: `AstronacciDeterministicEngine`]
    * `AstronacciEphemerisEngine.swift` — (Kalkulasi posisi astronomi/planet untuk siklus waktu pasar finansial) [Terhubung ke: `AstronacciDeterministicEngine`]
    * `AstronacciPlanetaryAspectEngine.swift` — (Kalkulasi aspek sudut transit planet terhadap titik balik market) [Terhubung ke: `AstronacciDeterministicEngine`]
    * `AstronacciQuasimodoEngine.swift` — (Deteksi pola struktur chart pembalikan arah Quasimodo / Over-and-Under) [Terhubung ke: `AstronacciDeterministicEngine`]
  * 📁 **`FuturesScout/`** (Analisis pasar kripto berjangka / futures)
    * `BingXMarketDataEngine.swift` — (Klien data feed WebSocket dan REST harga kontrak berjangka BingX) [Terhubung ke: `FuturesScoutMarketDataService`]
    * `FuturesScoutBackgroundWatcher.swift` — (Pemantau pergerakan harga kripto dan sinyal likuidasi di latar belakang) [Terhubung ke: `FuturesScoutCoreAnalyst`, `CompanionManager`]
    * `FuturesScoutChartAnalyst.swift` — (Analisis pola teknikal candlestick dan level support/resistance) [Terhubung ke: `FuturesScoutCoreAnalyst`]
    * `FuturesScoutCoreAnalyst.swift` — (Engine pengambil keputusan sinyal trading futures dan manajemen risiko) [Terhubung ke: `FuturesScoutBackgroundWatcher`, `ClickyDeterministicPipeline`]
    * `FuturesScoutMarketDataService.swift` — (Layanan agregasi data orderbook dan riwayat harga futures) [Terhubung ke: `FuturesScoutCoreAnalyst`, `BingXMarketDataEngine`]
  * 📁 **`TradingView/`** (Isolasi modul spesifik antarmuka web/aplikasi TradingView)
    * `TradingViewActionDispatcher.swift` — (Dispatcher aksi spesifik TradingView: ganti timeframe, cari ticker, gambar chart) [Terhubung ke: `TradingViewNavigationTool`, `TradingViewDrawingTool`, `TradingViewLayoutTool`]
    * `TradingViewCommandRouter.swift` — (Router pendeteksi perintah `/analisa`, `/chart`, dan parser simbol crypto ticker) [Terhubung ke: `ClickyDeterministicPipeline`, `TradingViewActionDispatcher`]
    * `TradingViewDrawingTool.swift` — (Automasi pemilihan dan penarikan tool gambar trendline, Fibonacci, dan level horizontal) [Terhubung ke: `TradingViewActionDispatcher`, `CUAPhysicalActionDispatcher`]
    * `TradingViewInputSupport.swift` — (Helper format teks simbol ticker dan pengetikan timeframe) [Terhubung ke: `TradingViewNavigationTool`, `CUATypeActionTool`]
    * `TradingViewLayoutTool.swift` — (Automasi pengaturan layout multi-chart dan template indikator) [Terhubung ke: `TradingViewActionDispatcher`, `TradingViewVisualGrounder`]
    * `TradingViewNavigationTool.swift` — (Navigasi perpindahan pair ticker, interval waktu, dan toggle Pine Editor) [Terhubung ke: `TradingViewActionDispatcher`, `TradingViewVisualGrounder`]
    * `TradingViewTypes.swift` — (Definisi struktur data simbol, timeframe, dan enum tool visual TradingView) [Terhubung ke: seluruh modul domain TradingView]
    * `TradingViewVisualGrounder.swift` — (Grounding visual spesifik TradingView: symbol search pill, timeframe picker, dialog pencarian) [Terhubung ke: `TradingViewNavigationTool`, `TradingViewLayoutTool`, `ChatGPTCodexVisionService`]
* 📁 **`Models/`** (Driver model AI yang aktif)
  * `GeminiBridgeClient.swift` — (Klien integrasi model Google Gemini melalui Antigravity Bridge Manager) [Terhubung ke: `CompanionManager`, `ModelTurnResult`]
  * `IntegrationsManager.swift` — (Manajer penyimpanan aman API key untuk Gemini, OpenAI, dan ElevenLabs) [Terhubung ke: `OpenAIAPI`, `ElevenLabsTTSClient`, `GeminiBridgeClient`]
  * `ModelTurnResult.swift` — (Struktur data universal luaran inferensi model teks, status token, dan metadata giliran AI) [Terhubung ke: `SiriAIEngine`, `GeminiBridgeClient`]
  * `OpenAIAPI.swift` — (Klien HTTP untuk komunikasi dengan OpenAI API ChatCompletion dan Whisper) [Terhubung ke: `OpenAIAudioTranscriptionProvider`, `IntegrationsManager`]
  * `SiriAIEngine.swift` — (Engine inferensi model lokal on-device Siri Intelligence AFM via biner `/usr/bin/fm`) [Terhubung ke: `SiriAIPolicy`, `TaskIngressGateway`, `TaskStepPlanner`, `TaskEgressValidator`]
  * 📁 **`Policies/`**
    * `SiriAIPolicy.swift` — (Definisi prompt sistem murni dan skema respons routing intent untuk SiriAIEngine) [Terhubung ke: `SiriAIEngine`]
* 📁 **`Vision/`** (Pustaka penglihatan komputer dan visual grounding)
  * `ChatGPTAccountMonitorWidget.swift` — (Widget UI untuk memantau status sesi dan batas kuota akun OpenAI Luna) [Terhubung ke: `ChatGPTAccountPoolManager`]
  * `ChatGPTAccountPoolManager.swift` — (Manajer rotasi session token akun OpenAI Luna secara otomatis) [Terhubung ke: `ChatGPTCodexVisionService`]
  * `ChatGPTCodexVisionService.swift` — (Layanan visual grounding OpenAI Luna untuk mendeteksi koordinat elemen UI dari screenshot secara presisi) [Terhubung ke: `AFMLunaCoordinationBridge`, `TradingViewVisualGrounder`]

---

### 📁 `UI/` (Antarmuka Pengguna SwiftUI, Rendering Avatar 3D, dan Tampilan Window)
* 📁 **`Avatars/`** (Render maskot kinetik)
  * `CompanionAnimationEngine.swift` — (Engine state machine animasi avatar: kedip, napas, bicara, dan gestur) [Terhubung ke: `CompanionProceduralAvatarView`]
  * `CompanionAvatarDefinition.swift` — (Definisi data visual, warna shading, dan bentuk mesh avatar) [Terhubung ke: `CompanionProceduralAvatarView`, `CompanionAvatarLabCatalog`]
  * `CompanionAvatarLabCatalog.swift` — (Katalog pustaka preset model avatar maskot yang siap digunakan) [Terhubung ke: `WorkSettingsViews`, `CompanionProfile`]
  * `CompanionGazeTracker.swift` — (Pelacak posisi kursor mouse secara kinetik agar mata avatar menatap kursor) [Terhubung ke: `CompanionProceduralAvatarView`]
  * `CompanionProceduralAvatarView.swift` — (SwiftUI View yang merender avatar maskot dinamis secara prosedural) [Terhubung ke: `OverlayWindow`, `HomeSpaceRootView`]
* 📁 **`Common/`** (Komponen UI bersama dan window transparan)
  * `CompanionResponseOverlay.swift` — (Overlay balon teks respons avatar yang melayang di sekitar notch/kursor) [Terhubung ke: `OverlayWindow`]
  * `ComputerUseConsentCardView.swift` — (Kartu konfirmasi izin kepada pengguna sebelum aksi otomatis CUA dijalankan) [Terhubung ke: `NotchComputerUseConsentWindow`]
  * `DesignSystem.swift` — (Standar desain visual terpadu: palet warna, tipografi font, dan efek kaca liquid) [Terhubung ke: seluruh komponen UI Clicky]
  * `NotchComputerUseConsentWindow.swift` — (Window melayang di area notch untuk menampilkan kartu persetujuan CUA) [Terhubung ke: `ComputerUseConsentCardView`, `CompanionManager`]
  * `OverlayWindow.swift` — (Window transparan fullscreen tingkat Layer 1000 untuk menampilkan animasi avatar maskot) [Terhubung ke: `CompanionProceduralAvatarView`, `CompanionManager`]
  * `WorkSettingsViews.swift` — (View pengaturan aplikasi: konfigurasi API key, pemilihan companion, dan preferensi) [Terhubung ke: `HomeSpaceRootView`, `IntegrationsManager`]
* 📁 **`Floating/`** (Komponen jendela mengambang mini)
  * `AquaGlassSphereView.swift` — (Tampilan bola kaca aqua mengambang yang menampilkan status companion) [Terhubung ke: `FloatingCompanionWindowManager`]
  * `FloatingCompanionWindowManager.swift` — (Manajer jendela mengambang avatar di atas aplikasi lain) [Terhubung ke: `CompanionManager`, `AquaGlassSphereView`]
* 📁 **`HomeSpace/`** (Pusat kendali pop-down notch MacBook)
  * `CompanionVMViewportView.swift` — (View perender streaming desktop virtual di dalam kartu HomeSpace) [Terhubung ke: `CompanionVMViewportController`, `HomeSpaceComputerCardView`]
  * `HomeSpaceComputerCardView.swift` — (Kartu antarmuka yang menampilkan status aplikasi yang sedang dikendalikan AI) [Terhubung ke: `CompanionVMViewportView`, `HomeSpaceRootView`]
  * `HomeSpaceInteractiveComputerModalView.swift` — (Modal interaktif untuk mengambil alih kontrol keyboard/mouse CUA) [Terhubung ke: `HomeSpaceComputerCardView`]
  * `HomeSpaceRootView.swift` — (Kontainer utama antarmuka HomeSpace di bawah notch untuk interaksi dan chat) [Terhubung ke: `NotchUnifiedHuggingShape`, `HomeSpaceMarkdownViews`, `HomeSpaceControlPills`, `HomeSpaceWindowManager`]
  * `HomeSpaceWindowManager.swift` — (Manajer jendela pop-down HomeSpace yang menempel pada notch fisik layar) [Terhubung ke: `HomeSpaceRootView`, `CompanionManager`]
  * 📁 **`Components/`**
    * `HomeSpaceControlPills.swift` — (Tombol-tombol pill 3D untuk memilih warna tema dan aksi tombol pintas) [Terhubung ke: `HomeSpaceRootView`]
    * `HomeSpaceMarkdownViews.swift` — (Perender teks berformat Markdown berjenjang, tabel, dan blok kode pada chat) [Terhubung ke: `HomeSpaceRootView`]
    * `NotchUnifiedHuggingShape.swift` — (Bentuk geometri fisik kurva cekung yang menempel pas dengan hardware notch MacBook) [Terhubung ke: `HomeSpaceRootView`]
* 📁 **`Rail/`** (Bilah vertikal samping layar)
  * `CompanionOverflowSwitcherView.swift` — (View pemilih cepat companion aktif saat bilah samping di-expand) [Terhubung ke: `FloatingCompanionRailView`]
  * `CompanionPopoverCardView.swift` — (Popover detail status companion saat kursor diarahkan ke rail samping) [Terhubung ke: `FloatingCompanionRailView`]
  * `FloatingCompanionRailView.swift` — (Bilah vertikal ramping di sisi layar untuk akses cepat companion) [Terhubung ke: `FloatingCompanionRailWindow`]
  * `FloatingCompanionRailWindow.swift` — (Window penampung bilah rail vertikal di tepi layar monitor) [Terhubung ke: `CompanionManager`, `FloatingCompanionRailView`]
* 📁 **`Viewport/`** (Interaksi jendela desktop virtual)
  * `AppSystemIconView.swift` — (Tampilan icon native macOS dari aplikasi yang sedang menjadi target interaksi) [Terhubung ke: `HomeSpaceComputerCardView`]
  * `InteractiveVirtualDesktopView.swift` — (Permukaan interaktif penerima klik dan gestur mouse di atas streaming layar) [Terhubung ke: `CompanionVMViewportView`]

---

### 📁 `Workspace/` (Integrasi OS macOS, Streaming Layar, dan Posisi Window)
* 📁 **`Discovery/`**
  * `InstalledAppsDiscoveryService.swift` — (Pendeteksi dinamis aplikasi yang terpasang di sistem macOS via NSWorkspace/LaunchServices) [Terhubung ke: `ClickyDeterministicPipeline`, `IntegrationSuggestionMonitor`]
* 📁 **`Streaming/`**
  * `CompanionScreenCaptureUtility.swift` — (Utilitas penangkap snapshot frame layar jendela target secara presisi) [Terhubung ke: `CompanionWindowStreamService`]
  * `CompanionVMViewportController.swift` — (Pengontrol alur pembaruan frame tangkapan layar untuk UI SwiftUI) [Terhubung ke: `CompanionWindowStreamService`, `CompanionVMViewportView`]
  * `CompanionWindowStreamService.swift` — (Layanan streaming frame jendela target dan persistensi sinkron snapshot ke disk) [Terhubung ke: `CompanionVMAgentLoop`, `CompanionVMViewportController`]
* 📁 **`VirtualDisplay/`**
  * `MascotVirtualDesktopService.swift` — (Sinkronisasi koordinat kursor fisik maskot terhadap batas jendela target di layar) [Terhubung ke: `CompanionVMAgentLoop`, `CuaActionCursorManager`]
* 📁 **`WindowManagement/`**
  * `WindowPositionManager.swift` — (Pengatur dan penyimpan koordinat serta dimensi ukuran jendela aplikasi target) [Terhubung ke: `CompanionManager`, `CompanionVMAgentLoop`]

---

### 📁 `Resources/` (Aset Suara dan Data Statis)
* 📁 **`Sounds/`** (`agent-done.wav`, `clicky-question.wav`, `clicky-text-close.wav`, `clicky-text-open.wav`, `clicky-text-receive.wav`) — (File audio efek feedback kinetik) [Terhubung ke: `ClickySoundEngine`]
* `economic_calendar_2025_2026.json` — (Dataset jadwal rilis berita ekonomi global) [Terhubung ke: `AstronacciEconomicCalendarEngine`]
