# Plan Detail: Migrasi Arsitektur Modular Aman & Terverifikasi (Versi 7 — Definitif Final)

> **Status:** Menunggu Persetujuan Pengguna (ACC)  
> **Tanggal:** 2026-10-05  
> **Revisi:** v7 (Mengatasi 100% Seluruh Temuan Reviewer: Sinkronisasi Folder di Langkah 0, Smoke Test Manual di Langkah 0/2/3/5, Pemisahan Headless vs AX Test di Langkah 4, Urutan Git Bebas Kehilangan File, Peta Dekomposisi Bebas Pelanggaran Layer, Titik Potong Berbasis AST Brace Depth, Model Tipe Mandiri, Anggaran Façade, Pemisahan Crypto vs TradingView, Kamus Sufiks & Whitelist Terkunci, Allowlist 9 File Existing > 800 Baris, Log Startup TCC Persis, dan Swift Concurrency Package).  
> **Target:** `boringNotch` (Izanotchy CUA & On-Device Assistant)  
> **Prinsip Utama:** *Zero Regresi, Zero Workflow Disruption, Single Responsibility, AST-Safe Decomposition, Compiler-Enforced Boundaries.*

---

## 🛑 1. Invariant Alur Produksi yang Mutlak Dipertahankan (Non-Negotiable)

Alur produksi yang telah berjalan selama ini dibangun dengan alasan teknis faktual dan **wajib dipertahankan 100% tanpa perubahan perilaku**:
1. **Dual-Layer Physical Mouse Interaction & Daemon Socket:**
   - Kursor kinetik maskot (`CuaMotionEngine` / `MascotVirtualDesktopService`) + Accessibility IPC via daemon `cua-driver` di `/tmp/cua-izanotchy-*.sock` untuk bypass sandbox macOS.
2. **Model Triplet Aktif:**
   - On-Device Siri Intelligence AFM 3B (`/usr/bin/fm` port 1976) untuk parsing intent, step planning, dan egress validation.
   - OpenAI Luna (`ChatGPTCodexVisionService`) untuk visual grounding koordinat spasial dari screenshot.
   - Google Gemini (`GeminiBridgeClient` via `AntigravityBridgeManager`) untuk fallback bridge.
3. **Clean Workspace Anchor & Anti-Spurious Scroll:**
   - Reset scroll to top (0.0) di awal tugas inspeksi umum.
   - Larangan scroll jika item target sudah terlihat di layar.
4. **Zero Hardcoding Dinamis:**
   - Resolusi aplikasi sistem menggunakan `DynamicAppResolver` (pemindaian dinamis LaunchServices & running apps), tanpa daftar statis nama app atau kata kerja.
5. **Integritas Entitlements & Permissions:**
   - App signing dengan identity `IzanotchyDev` (Certificate Leaf: `0486079929ba5d54118f2d6baa1dac26fe2019d3`) untuk menjaga izin TCC Accessibility, Screen Recording, dan Microphone agar tidak ter-reset saat build ulang.

---

## 🏛️ 2. Hirarki Layer Modular SPM (`Packages/ClickyKit/Package.swift`)

Dependensi arsitektural diatur ke dalam 8 lapisan hierarkis yang **hanya mengalir ke bawah (downwards)**:

```
[L7: App Target]  boringNotch (Main App, AppDelegate, Sparkle, macOS Notch UI)
       │
[L6: UI]          ClickyUI (SwiftUI HomeSpace Views, Avatars, Window Panels)
       │
[L5: Agent]       ClickyAgent (CompanionManager Façade, Turn Coordinator, Agent Loop)
       │          ClickyDesignSystem (Color Tokens, Typography, Glow Assets)
       │
[L4: Domain]      ClickyAstronacci, ClickyTradingView, ClickyFuturesScout, ClickyRoster
       │
[L3: Reasoning]   ClickyReasoning (TaskIngressGateway, TaskStepPlanner, TaskEgressValidator)
       │
[L2: Platform/IO] Sub-layer terurut bebas siklus:
                  ├── L2c: ClickyCUA (Actions, Kinematics, CuaDriverClient)
                  ├── L2b: ClickySpeech (ElevenLabsTTSClient, BuddyDictationManager)
                  └── L2a: ClickyAIProviders (OpenAIAPI, GeminiBridge, PCCGroundingEscalation)
       │
[L1: Platform]    ClickyPlatform (DynamicAppResolver, WindowPositionManager, DockService)
       │
[L0: Foundation]  ClickyFoundation (ClickyLogger, ClickyAnalytics, Contracts/Protocols)
```

### Aturan Swift Concurrency & Package Configuration
- **Toolchain:** Swift 6.4 (Apple Swift version 6.4 clang-2100.3.34.1).
- **Default Isolation:** Gunakan `.defaultIsolation(MainActor.self)` HANYA pada target UI dan Agent (`ClickyUI`, `ClickyAgent`, `ClickyDesignSystem`).
- **Target Murni:** Target `ClickyFoundation`, `ClickyAstronacci`, dan `ClickyReasoning` TIDAK menggunakan actor isolation default agar tetap murni komputasi.
- **Public Visibility:** Seluruh struct View yang dipindahkan ke `ClickyUI` wajib mendeklarasikan `public struct`, `public init(...)`, dan `public var body: some View`.

---

## 📂 3. Peta Dekomposisi 3 God Object Berbasis Struktur AST & Brace

### 3A. Dekomposisi `CompanionManager.swift` (4.746 baris)
Tiap potongan diekstrak sebagai **Tipe Mandiri (Class / Struct)** ber-state sendiri, bukan extension.

| Rentang Baris | Tipe Baru & Nama File | Target | Tanggung Jawab & Kepemilikan State |
|---|---|---|---|
| **1 – 211** | `MacOSDockQueryService.swift` | `ClickyPlatform` (L1) | Query dock items via Accessibility & CGWindowList (State mandiri). |
| **212 – 360** | `ActiveWorkSurfaceMonitor.swift` | `ClickyPlatform` (L1) | Deteksi frontmost application window frame & traffic light centers. |
| **361 – 1196** | `CompanionVoicePipelineCoordinator.swift` | `ClickyAgent` (L5) | Mengadopsi delegasi suara `BuddyDictationManager` (L2), memegang `@Published var voiceState`, `lastTranscript`, `currentAudioPowerLevel`. |
| **1197 – 1502** | `CompanionSessionStore.swift` | `ClickyAgent` (L5) | Riwayat chat (`HomeSpaceChatMessage`), status sesi, pembersihan turn. Nama file baku tanpa `&`. |
| **1503 – 1702** | `CompanionLifecycleService.swift` | `ClickyAgent` (L5) | Orkestrasi lifecycle app & status online; memanggil `ClickyPlatform` untuk verifikasi izin TCC OS. |
| **1703 – 2172** | `CompanionStreamingBubbleService.swift` | `ClickyAgent` (L5) | Model state streaming teks, buffer chunks, hold bubble timing. (View-nya di `ClickyUI`). |
| **2173 – 2379** | `CompanionTurnIngressCoordinator.swift` | `ClickyAgent` (L5) | Text prompt ingress, early grounding trigger, infeasible announcement. |
| **2380 – 3075** | `CompanionTurnExecutor.swift` | `ClickyAgent` (L5) | Multi-turn execution orchestrator (`sendTranscriptToClaudeWithScreenshot`), pemanggilan AFM & Luna Vision. |
| **3076 – 3123** | `CompanionTurnCompletionHandler.swift` | `ClickyAgent` (L5) | Transience hide watchdog & credit error announcement. |
| **3124 – 3485** | `CompanionFlightTargetParser.swift` | `ClickyCUA` (L2) | Parsing tag `[TARGET:x,y,r:label]` dan pengayaan ekspresi spasial. |
| **3486 – 3687** | `CompanionOnboardingPlaybackService.swift` | `ClickyAgent` (L5) | Model state AVPlayer onboarding & timing audio fade. (View-nya di `ClickyUI`). |
| **3688 – 4213** | `CompanionComputerUseConsentService.swift` | `ClickyAgent` (L5) | Dialog consent "Wants to use your Mac" & resume execution loop. |
| **4214 – 4290** | `CryptoSymbolExtractor.swift` | `ClickyFuturesScout` (L4) | Dynamic coin ticker detection (`BTC-USDT`, regex extract). |
| **4291 – 4341** | `TradingViewFeatureProtocol.swift` | `ClickyTradingView` (L4) | Proactive feature request JSON persistence. |
| **4342 – 4747** | `TradingViewPayloadExtractor.swift` | `ClickyTradingView` (L4) | Parser aksi chart TradingView dari respon model. |

**Anggaran Façade Baru:**
`CompanionManager.swift` di L5 dipertahankan sebagai façade publik tipis ($\le 350$ baris) yang mengagregasi service-service di atas dan meneruskan sinyal pembaruan melalui Combine:
```swift
// Anggaran: ~280 baris
@MainActor
public final class CompanionManager: ObservableObject {
    public static let shared = CompanionManager()
    public let voiceCoordinator = CompanionVoicePipelineCoordinator()
    public let sessionStore = CompanionSessionStore()
    public let bubbleService = CompanionStreamingBubbleService()
    // forwards objectWillChange from child services
}
```

---

### 3B. Dekomposisi `HomeSpaceRootView.swift` (3.406 baris)
Semua View diekstrak sebagai struct View independen di L6 `ClickyUI`.

| Rentang Baris | Tipe Baru & Nama File | Target | Tanggung Jawab & Komponen |
|---|---|---|---|
| **1 – 487** | `HomeSpaceRootView.swift` | `ClickyUI` (L6) | Main container layout, glass card body, navigation tabs (487 baris utuh, zero kode dihapus). |
| **488 – 956** | `HomeSpaceSidebarView.swift` | `ClickyUI` (L6) | Sidebar switcher companion roster & tab navigation buttons. |
| **957 – 1443** | `HomeSpaceChatTranscriptView.swift` | `ClickyUI` (L6) | Bubble list transcript pesan, copy button, audio playback waveform. |
| **1444 – 1762** | `HomeSpaceHeaderView.swift` | `ClickyUI` (L6) | Header bar, profile avatar pill, close & minimize controls. |
| **1763 – 2300** | `HomeSpaceCharacterStudioView.swift` | `ClickyUI` (L6) | Character prompt studio, role customizer, color theme picker. |
| **2301 – 2462** | `HomeSpaceConnectedAppsView.swift` | `ClickyUI` (L6) | Grid status integrasi aplikasi aktif (Safari, Mail, Terminal, dll.). |
| **2463 – 2571** | `HomeSpaceStudioHelpersView.swift` | `ClickyUI` (L6) | UI controls kecil, tooltip helpers, badge status. |
| **2572 – 2972** | `HomeSpaceOnboardingWizardView.swift` | `ClickyUI` (L6) | Onboarding 3-step stepper: Step 1 (Interview glowing cloud) & Step 2 (Spec review). |
| **2973 – 3406** | `HomeSpaceOnboardingAppearanceView.swift` | `ClickyUI` (L6) | Onboarding Step 3: Character Appearance Studio & Launch animation. |

---

### 3C. Dekomposisi `ClickyDeterministicPipeline.swift` (1.242 baris)

| Rentang Baris | Tipe Baru & Nama File | Target | Tanggung Jawab |
|---|---|---|---|
| **1 – 180** | `InstalledAppsDiscoveryService.swift` | `ClickyPlatform` (L1) | Dynamic LaunchServices scanning & resolver. |
| **181 – 312** | `DeterministicIntentRouter.swift` | `ClickyReasoning` (L3) | Lapis 1: Zero-call intent classifier. |
| **313 – 464** | `DeterministicToolGatingService.swift` | `ClickyAgent` (L5) | Lapis 2: Tool authorization & permission pre-check. |
| **465 – 631** | `DeterministicCommandDecomposer.swift` | `ClickyReasoning` (L3) | Multi-step chained instruction decomposer. |
| **632 – 1242** | `DeterministicChainDispatcher.swift` | `ClickyAgent` (L5) | Lapis 3: Eksekutor rantai TUNJUK, AKSI, TANYA, KETIK. |

**Anggaran Façade Baru:**
`ClickyDeterministicPipeline.swift` dipertahankan sebagai façade tipis ($\le 150$ baris) untuk memanggil service-service di atas tanpa mengubah API pemanggil yang sudah ada.

---

## 🏷️ 4. Standarisasi Penamaan: Kamus Sufiks & Whitelist

### Kamus Sufiks Arsitektural Baku
- `*Service`: Komponen background, koordinasi data, dan state management.
- `*Controller`: Pengendali lifecycle window atau overlay OS.
- `*View`: Tampilan SwiftUI murni.
- `*Client`: Pembungkus network atau socket IPC (`cua-driver`).
- `*Engine`: Kalkulasi matematika murni atau analitik deterministik.
- `*Coordinator`: Pengatur alur multi-komponen (contoh: `CompanionVoicePipelineCoordinator`).
- `*Gateway` / `*Policy`: Ingress parsing dan aturan reasoning.

### Whitelist Komponen Warisan Terkunci (Locked Legacy Whitelist)
Komponen warisan berikut diizinkan mempertahankan namanya:
1. `CompanionScreenCaptureUtility.swift` (SCKit platform wrapper).
2. `CompanionManager.swift` (façade transisi publik $\le 350$ baris).
3. `CompanionVMAgentLoop.swift` (autonomous agent loop).
4. `ClickyDeterministicPipeline.swift` (façade pipeline $\le 150$ baris).
5. `NotchUnifiedHuggingShape.swift` (SwiftUI custom shape).
6. `NotchClickyHoverSpace.swift` (notch hover area).
7. `BallClickyView.swift` (particle visualizer).

---

## 📋 5. Allowlist 9 File Warisan > 800 Baris (Non-God-Objects)

Audit menunjukkan ada 9 file di luar 3 God Object yang saat ini melebihi 800 baris. Seluruh file ini dimasukkan ke dalam daftar allowlist dengan **pagu baris maksimum terkunci** di `scripts/verify_gate.sh`:

| File | Baris Saat Ini | Pagu Maksimum (`verify_gate.sh`) | Alasan Teknis |
|---|---|---|---|
| `CompanionAvatarLabCatalog.swift` | 2.435 | 2.450 | Data catalog statis preset 3D/procedural avatars. |
| `OverlayWindow.swift` | 1.264 | 1.280 | Multi-screen window controller & event routing. |
| `FuturesScoutCoreAnalyst.swift` | 1.255 | 1.270 | Domain analitik crypto BingX swap & technical setups. |
| `CompanionVMAgentLoop.swift` | 1.070 | 1.080 | Autonomous agent loop dengan state machine multi-step. |
| `DesignSystem.swift` | 989 | 1.000 | Definisi token desain, warna, font, dan glass modifiers. |
| `CuaDriverClient.swift` | 930 | 950 | IPC unix socket client komunikasi dengan `cua-driver`. |
| `AstronacciDeterministicEngine.swift` | 916 | 930 | Kalkulasi astronomi & planetary market cycles. |
| `BuddyDictationManager.swift` | 889 | 900 | SFSpeechRecognizer & AVAudioEngine audio capture. |
| `HomeSpaceComputerCardView.swift` | 834 | 850 | Streaming card modal SwiftUI view. |

**Aturan Gate:**
1. Ke-9 file di atas dilarang bertambah baris melewati pagu maksimum.
2. Seluruh file hasil ekstraksi 3 God Object WAJIB $\le 800$ baris (target $\le 400$ baris).
3. File baru apa pun di luar allowlist dilarang keras melebihi 800 baris.

---

## 🚀 6. Rencana Eksekusi Langkah demi Langkah (Langkah 0 – Langkah 6)

### Langkah 0: Git Hygiene, Baseline Snapshot, Synchronized Folder & Negative Test
1. **Pembersihan Cache & Pindaian Secret:**
   - Untrack cache file: `git rm -r --cached artwork_cache/ 2>/dev/null || true`.
   - Update `.gitignore` untuk mengecualikan `artwork_cache/`, `*.sqlite`, `*.db`.
   - Stage perubahan: `git add -A`.
   - Jalankan pemindaian secret pada staged diff:
     ```bash
     git diff --cached | grep -iE 'api[_-]?key|sk-[a-zA-Z0-9]{20,}|bearer|token|password' || true
     ```
   - Commit kondisi bersih ke branch `main`:
     ```bash
     git commit -m "chore: commit clean working state before modular refactor"
     ```
2. **Branching:**
   - Buat dan beralih ke branch refactor: `git checkout -b refactor/modular`.
3. **Synchronized Folder di Xcode:**
   - Konfigurasi `boringNotch/Clicky` sebagai Synchronized Folder (`PBXFileSystemSynchronizedRootGroup`) di `boringNotch.xcodeproj` agar penambahan dan pemindahan file baru tidak memerlukan edit `project.pbxproj`.
4. **Clean Build & Launch App:**
   - Recompile aplikasi: `xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug build`.
   - Jalankan aplikasi: `./scripts/launch_app.sh`.
   - Verifikasi PID stabil (>15 detik).
5. **Pengambilan Baseline Setelah Launch:**
   - Tangkap identitas signing designated requirement:
     ```bash
     codesign -dr - "$APP" 2>/dev/null > docs/baseline/baseline_codesign.txt
     ```
   - Verifikasi baris startup TCC persis di log:
     ```bash
     grep -F "[START] Clicky start — AX: true, Screen: true, Mic: true, Enabled: true" ~/Library/Logs/Izanotchy/clicky.log
     ```
   - Jalankan 6 skrip test legacy (28 assertions) dan simpan hasilnya:
     ```bash
     swift scripts/test_taskR_modular_prompt_policies.swift > docs/baseline/test_results.txt
     swift scripts/test_taskQ_clean_anchor_and_no_spurious_scroll.swift >> docs/baseline/test_results.txt
     swift scripts/test_taskP_adaptive_scroll.swift >> docs/baseline/test_results.txt
     swift scripts/test_taskO_scroll_synchronous_and_target_index.swift >> docs/baseline/test_results.txt
     swift scripts/test_taskM_contract_index_fidelity.swift >> docs/baseline/test_results.txt
     swift scripts/test_taskL_master_detail_click_enforcement.swift >> docs/baseline/test_results.txt
     ```
   - Jalankan **Smoke Test Manual Baseline**: Lakukan dictation suara ("Hey Clicky"), inspeksi klik kursor fisik CUA, dan buka chart TradingView. Tangkap baris-baris log suksesnya ke `docs/baseline/smoke_test_baseline.txt`.
6. **Commit Baseline Evidence & Tagging:**
   - Commit skrip audit, baseline, dan konfigurasi ke git:
     ```bash
     git add scripts/ docs/baseline/ AGENTS.md boringNotch.xcodeproj/
     git commit -m "chore: commit baseline evidence, audit scripts, and synchronized folder configuration"
     git tag v0.9.0-clicky-baseline
     git tag step-0-start
     ```
7. **Negative Test Harness Skrip Audit:**
   - Uji 4 skrip audit terhadap kegagalan yang disengaja:
     - File buatan 801 baris $\rightarrow$ `verify_gate.sh` wajib menolak (EXIT $\neq 0$).
     - Brace tidak seimbang $\rightarrow$ `check_decomposition_map.py` wajib menolak.
     - Import ke atas (L1 mengimpor L5) $\rightarrow$ `check_layering.py` wajib menolak.
     - Manifes 111 file (ada 1 file terhapus) $\rightarrow$ `check_file_map.py` wajib menolak.
8. **Jalankan Gate Langkah 0:**
   - `./scripts/verify_gate.sh 0` (Wajib EXIT 0).

---

### Langkah 1: Putus Siklus Dependensi Lokal & Definisi Kontrak
1. Buat folder kontrak di dalam app target: `boringNotch/Clicky/Core/Contracts/`.
2. Definisikan protokol kapabilitas untuk memutus circular references:
   - `CompanionUIHost`: memutus dependensi `CompanionManager` $\leftrightarrow$ `OverlayWindowManager`.
   - `ElementGroundingProtocol`: memutus `CompanionVMAgentLoop` $\leftrightarrow$ `PCCGroundingEscalation`.
   - `DomainCommandRouterProtocol`: memutus `ClickyDeterministicPipeline` $\leftrightarrow$ `TradingViewCommandRouter`.
3. Pasang protokol pada class implementasi dan daftarkan via dependency injection di `AppDelegate.swift`.
4. Jalankan `./scripts/verify_gate.sh 1`.

---

### Langkah 2: Dekomposisi 3 God Object Menjadi Tipe Mandiri
1. Pecah `CompanionManager.swift` (4.746 baris) menjadi 15 file tipe mandiri di `boringNotch/Clicky/` sesuai Tabel 3A.
   - Pertahankan façade `CompanionManager.swift` $\le 350$ baris sebagai Combine aggregator.
2. Pecah `HomeSpaceRootView.swift` (3.406 baris) menjadi 9 struct View mandiri di `boringNotch/Clicky/UI/HomeSpace/Components/` sesuai Tabel 3B.
   - Root view `HomeSpaceRootView.swift` tetap 487 baris bersih.
3. Pecah `ClickyDeterministicPipeline.swift` (1.242 baris) menjadi 5 service mandiri sesuai Tabel 3C.
   - Façade `ClickyDeterministicPipeline.swift` tetap $\le 150$ baris.
4. Jalankan audit pemetaan file: `python3 scripts/check_file_map.py`.
5. Recompile, launch, jalankan `./scripts/verify_gate.sh 2`.
6. Lakukan **Smoke Test Manual Langkah 2** (cocokkan baris log sukses dengan `docs/baseline/smoke_test_baseline.txt`).

---

### Langkah 3: Ekstraksi Modul ke SPM `Packages/ClickyKit`
1. Buat single package multi-target: `Packages/ClickyKit/Package.swift` dengan 13 target modul.
2. Link `ClickyKit` satu kali ke `boringNotch.xcodeproj` target `boringNotch`.
3. Pindahkan file dari `boringNotch/Clicky/` ke `Packages/ClickyKit/Sources/<Target>/` secara berurutan **dari bawah ke atas**:
   - L0 `ClickyFoundation` $\rightarrow$ L1 `ClickyPlatform` $\rightarrow$ L2 `ClickyAIProviders`, `ClickySpeech`, `ClickyCUA` $\rightarrow$ L3 `ClickyReasoning` $\rightarrow$ L4 Domain Targets $\rightarrow$ L5 `ClickyDesignSystem`, `ClickyAgent` $\rightarrow$ L6 `ClickyUI`.
4. Migrasikan akses aset suara/JSON ke `Bundle.module`.
5. Recompile package: `swift build --package-path Packages/ClickyKit`.
6. Recompile app, launch, jalankan `./scripts/verify_gate.sh 3`.
7. Lakukan **Smoke Test Manual Langkah 3** (cocokkan log sukses & pastikan resource `Bundle.module` termuat sempurna).

---

### Langkah 4: Konversi & Pemisahan Test Suite Formal
1. Buat folder test di package `Packages/ClickyKit/Tests/`.
2. **Pemisahan Test Suite Formal:**
   - **`ClickyReasoningTests` (Pure Logic / Headless):**
     - Konversi `test_taskR_modular_prompt_policies` (5 test cases).
     - Konversi `test_taskM_contract_index_fidelity` (3 test cases).
     - Menjamin eksekusi headless cepat via `swift test --filter ClickyReasoningTests`.
   - **`ClickyCUATests` (CUA Logic & Kinematics / Mocked AX):**
     - Konversi `test_taskQ_clean_anchor_and_no_spurious_scroll` (6 test cases).
     - Konversi `test_taskP_adaptive_scroll` (4 test cases).
     - Konversi `test_taskO_scroll_synchronous_and_target_index` (7 test cases).
     - Konversi `test_taskL_master_detail_click_enforcement` (3 test cases).
3. Verifikasi jumlah assertion formal $\ge 28$ cases.
4. Jalankan `./scripts/verify_gate.sh 4`.

---

### Langkah 5: Penataan Ulang Nama File & Kamus Sufiks Baku
1. Lakukan penyesuaian nama file warisan agar 100% mematuhi Kamus Sufiks (Bagian 4).
2. Perbarui impor dan manifes file di `scripts/check_file_map.py`.
3. Jalankan `python3 scripts/check_layering.py` untuk memvalidasi tidak ada dependensi melanggar layer.
4. Recompile app, launch, jalankan `./scripts/verify_gate.sh 5`.
5. Lakukan **Smoke Test Manual Langkah 5** (cocokkan log sukses).

---

### Langkah 6: Verifikasi Akhir, Pensiun Skrip & Finalisasi
1. Verifikasi akhir menyeluruh via `./scripts/verify_gate.sh 6`:
   - 0 file melebihi 800 baris (kecuali 9 file warisan dalam allowlist).
   - Package builds clean, app builds clean.
   - PID stabil, log TCC valid, formal unit tests lulus 100%.
2. Hapus skrip sementara python pbxproj lama (karena seluruh kode telah berpindah ke package SPM dan synchronized folder).
3. Perbarui `CHANGELOG.md` dan `ERRORS.md`.

---

## 🛡️ 7. Matriks Gerbang Verifikasi Terpadu (Unified Gate Matrix)

Setiap langkah dieksekusi dengan perintah `./scripts/verify_gate.sh <step_number>` yang mencakup kriteria berikut:

| Kriteria Verifikasi | Perintah / Assertion | Berlaku di Langkah | Kondisi Lulus Mutlak |
|---|---|---|---|
| **Kompilasi Bersih App** | `xcodebuild -scheme boringNotch ... build` | Langkah 0 – 6 | Exit code 0 (`** BUILD SUCCEEDED **`). |
| **Kompilasi SPM Package** | `swift build --package-path Packages/ClickyKit` | **Langkah 3 – 6** | Exit code 0 tanpa compiler warning. |
| **Identitas Signing (TCC)** | `codesign -dr - "$APP" 2>/dev/null \| diff -u docs/baseline/baseline_codesign.txt -` | Langkah 0 – 6 | Diff kosong (Sertifikat `04860799...` identik). |
| **Startup Log TCC** | `grep -F "[START] Clicky start — AX: true, Screen: true, Mic: true, Enabled: true"` | Langkah 0 – 6 | Ditemukan persis di log runtime baru. |
| **Stabilitas PID** | `PID1=$(pgrep boringNotch); sleep 15; PID2=$(pgrep boringNotch); [ "$PID1" = "$PID2" ]` | Langkah 0 – 6 | PID tidak berubah dan tidak kosong. |
| **Legacy Tests (28 Cases)** | 6 skrip test swift di `scripts/` | Langkah 0 – 3 | 28/28 assertions lulus. |
| **Formal Package Tests** | `swift test --package-path Packages/ClickyKit` | **Langkah 4 – 6** | $\ge 28$ test cases lulus 100%. |
| **Batas Baris File** | Audit baris via `verify_gate.sh` | **Langkah 2 – 6** | God Object $\le 800$, 9 file allowlist $\le$ pagu, file baru $\le 800$. |
| **Audit Pemetaan File** | `python3 scripts/check_file_map.py` | Langkah 0, 2, 5 | 100% file terdaftar tepat 1 kali di target yang sah. |
| **Audit Hirarki Layer** | `python3 scripts/check_layering.py` | Langkah 0, 3, 5 | Arah dependensi 100% ke bawah (L0 $\leftarrow$ L7). |
| **Smoke Test Manual** | Voice dictation + CUA click + TV chart | **Langkah 0, 2, 3, 5** | Log sukses cocok dengan `docs/baseline/smoke_test_baseline.txt`. |

---

## 🔄 8. Prosedur Rollback Aman (Anti-Kehilangan File)

Jika pada langkah mana pun terjadi kegagalan gerbang yang tidak dapat diperbaiki:
1. Periksa file yang akan dibersihkan:
   ```bash
   git clean -fdn
   ```
2. Reset branch ke checkpoint langkah sebelumnya yang stabil:
   ```bash
   git reset --hard step-<N-1>-start
   git clean -fd
   ```
3. Karena skrip audit, `docs/baseline/`, dan konfigurasi telah di-commit sebelum tag dibuat, prosedur ini **tidak akan menghapus baseline evidence maupun tooling verifikasi**.
4. Launch ulang biner stabil:
   ```bash
   ./scripts/launch_app.sh
   ```
5. Konfirmasi aplikasi kembali hidup dengan log TCC yang valid.
