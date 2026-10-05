# Implementation Plan: Clean Architecture Folder Restructuring & Dynamic Autonomous Intent Gate

**Date:** 2026-10-04  
**Author:** Antigravity  
**Goal:** Merestrukturisasi tata letak file dan folder di `boringNotch/Clicky` sesuai arsitektur bersih standar industri (pemisahan mutlak antara **Frontend / UI** dan **Logic / Reasoning / CUA / Workspace**), mengeliminasi segala bentuk hardcoded coupling semantik intent, serta mengabadikan standar arsitektur baru ke dalam `AGENTS.md`.

---

## 🎯 1. Problems & Motivation

### Problem 1: File & Folder Berantakan (No Clean Separation of UI vs Logic)
- Folder `Clicky/Tools/` saat ini menampung 26+ file dari berbagai domain yang saling bercampur:
  - UI Views (`InteractiveVirtualDesktopView`, `AppSystemIconView`).
  - AI Reasoning (`TaskIngressGateway`, `TaskStepPlanner`, `TaskEgressValidator`, `AFMLunaCoordinationBridge`).
  - Virtual Display & Window Streaming (`MascotVirtualDesktopService`, `CompanionWindowStreamService`, `CompanionVMViewportController`).
  - CUA State Machine (`CompanionVMAgentLoop`, `CompanionVMBackgroundWatcher`).
  - TradingView Tools legacy (`TradingView*.swift`).
  - Physical Mouse Actions (`Actions/`).
- Root folder `Clicky/` menampung 30+ file acak (`Astronacci*.swift`, `FuturesScout*.swift`, `ClaudeAPI.swift`, `OverlayWindow.swift`, dll.).
- Akibatnya: Navigasi kode menjadi membingungkan, sulit membedakan lapisan presentasi (SwiftUI) dengan lapisan domain bisnis dan runtime CUA.

### Problem 2: Hardcoding Semantik Intent & Kasus "Halo Dijawab Computer Use"
- Saat pengguna mengirim "halo", sistem justru memicu Computer Use pada Mail.app (`requiresCUA: true`, `targetAppName: "Mail"`, `targetIndex: 1`).
- Akar masalah:
  1. `TaskIngressGateway` belum memiliki prinsip pemisah yang tegas antara intent percakapan (*conversational*) vs tugas operasional aplikasi (*action*).
  2. Kode di berbagai tempat masih melakukan hardcoding pengecekan string intent:
     - `let isSendTask = (taskPlan?.intentType == "send") || (taskPlan?.normalizedGoal.contains("send"))`
     - `dict["requiresCUA"] as? Bool ?? (app != "None" && !app.isEmpty)`
     - `requiresCUA = (candidateApp != "None" && !connectedApps.isEmpty)`
  3. Ini adalah bentuk hardcoding semantik: logika kode mencoba menebak maksud model alih-alih model itu sendiri yang secara otonom menentukan atribut kelas satu (*first-class contract booleans*).

---

## 🏛️ 2. Target Clean Architecture (Structure Standard)

Seluruh komponen `boringNotch/Clicky` dibagi ke dalam domain modular yang terisolasi dengan batas tanggung jawab yang jelas:

```text
boringNotch/Clicky/
├── UI/                                    # LAPISAN FRONTEND (SwiftUI Views & Window Controllers)
│   ├── HomeSpace/                         # Panel Chat & Kartu Interaktif
│   │   ├── HomeSpaceRootView.swift
│   │   ├── HomeSpaceComputerCardView.swift
│   │   ├── HomeSpaceInteractiveComputerModalView.swift
│   │   ├── HomeSpaceWindowManager.swift
│   │   └── CompanionVMViewportView.swift
│   ├── Rail/                              # Floating Companion Rail
│   │   ├── FloatingCompanionRailView.swift
│   │   ├── FloatingCompanionRailWindow.swift
│   │   ├── CompanionPopoverCardView.swift
│   │   └── CompanionOverflowSwitcherView.swift
│   ├── Floating/                          # Floating Aqua Bubble
│   │   ├── AquaGlassSphereView.swift
│   │   └── FloatingCompanionWindowManager.swift
│   ├── Avatars/                           # Avatar Maskot & Animasi Prosedural
│   │   ├── CompanionProceduralAvatarView.swift
│   │   ├── CompanionAnimationEngine.swift
│   │   ├── CompanionAvatarDefinition.swift
│   │   ├── CompanionAvatarLabCatalog.swift
│   │   └── CompanionGazeTracker.swift
│   ├── Viewport/                          # Viewport Streaming & Display UI
│   │   ├── InteractiveVirtualDesktopView.swift
│   │   └── AppSystemIconView.swift
│   └── Common/                            # Dialog, Consent & Windows Umum
│       ├── OverlayWindow.swift
│       ├── ComputerUseConsentCardView.swift
│       ├── NotchComputerUseConsentWindow.swift
│       ├── CompanionResponseOverlay.swift
│       ├── WorkSettingsViews.swift
│       └── DesignSystem.swift
│
├── Reasoning/                             # LAPISAN PENALARAN AI (Cognitive Engines)
│   ├── Ingress/                           # Intent Classifier & Task Contract
│   │   ├── TaskIngressGateway.swift
│   │   └── CanonicalTaskContract.swift
│   ├── Planner/                           # Dynamic AFM Step Reasoner
│   │   └── TaskStepPlanner.swift
│   ├── Validator/                         # Dynamic AFM Egress Synthesizer
│   │   └── TaskEgressValidator.swift
│   └── Coordination/                      # Hierarchical AFM ⇄ Luna Bridge
│       └── AFMLunaCoordinationBridge.swift
│
├── CUA/                                   # LAPISAN COMPUTER USE AGENT (Hands, Loop & Actions)
│   ├── Loop/                              # State Machine CUA & Background Watcher
│   │   ├── CompanionVMAgentLoop.swift
│   │   └── CompanionVMBackgroundWatcher.swift
│   ├── Actions/                           # Modular Physical Hands Tools
│   │   ├── CUAPhysicalActionDispatcher.swift
│   │   ├── CUAPhysicalActionTool.swift
│   │   ├── CUAClickActionTool.swift
│   │   ├── CUAScrollActionTool.swift
│   │   ├── CUATypeActionTool.swift
│   │   └── CUAReadActionTool.swift
│   ├── Grounding/                         # Hybrid Sensor & Visual Grounder
│   │   ├── ClickyHybridGroundingEngine.swift
│   │   ├── CuaVisualGrounder.swift
│   │   ├── MacOSVisualGroundingEngine.swift
│   │   ├── MacOSROIGrounding.swift
│   │   ├── MacOSMarkRenderer.swift
│   │   ├── MacOSCandidacyResolver.swift
│   │   ├── ElementLocationDetector.swift
│   │   └── GoogleStudioGrounderClient.swift
│   └── Execution/                         # Low-Level Physical Drivers & Cursors
│       ├── ComputerUsePhysicalExecutor.swift
│       ├── CuaActionCursorManager.swift
│       ├── CuaDriverClient.swift
│       └── CuaMotionEngine.swift
│
├── Workspace/                             # INFRASTRUKTUR DISPLAY & SANDBOX TERISOLASI
│   ├── VirtualDisplay/                    # CGVirtualDisplay Management
│   │   └── MascotVirtualDesktopService.swift
│   ├── Streaming/                         # ScreenCaptureKit Streaming
│   │   ├── CompanionWindowStreamService.swift
│   │   ├── CompanionScreenCaptureUtility.swift
│   │   └── CompanionVMViewportController.swift
│   ├── Discovery/                         # Native App & Window Discovery
│   │   └── InstalledAppsDiscoveryService.swift
│   └── WindowManagement/                  # Window Geometries
│       └── WindowPositionManager.swift
│
├── Roster/                                # DATA MASKOT & WORKSPACE PERSISTENCE
│   ├── CompanionProfile.swift
│   ├── CompanionRosterStore.swift
│   ├── Onboarding/
│   │   ├── CompanionWorkspaceManager.swift
│   │   └── CompanionInterviewEngine.swift
│   └── Context/
│       └── IntegrationSuggestionMonitor.swift
│
├── Services/                              # HARDWARE & MODEL CLIENTS
│   ├── Audio/                             # Speech Recognition & Dictation
│   │   ├── BuddyDictationManager.swift
│   │   ├── BuddyAudioConversionSupport.swift
│   │   ├── BuddyTranscriptionProvider.swift
│   │   ├── AppleSpeechTranscriptionProvider.swift
│   │   ├── OpenAIAudioTranscriptionProvider.swift
│   │   ├── AssemblyAIStreamingTranscriptionProvider.swift
│   │   ├── ElevenLabsTTSClient.swift
│   │   ├── ClickySoundEngine.swift
│   │   └── GlobalPushToTalkShortcutMonitor.swift
│   ├── Vision/                            # Vision Account Pools
│   │   ├── ChatGPTCodexVisionService.swift
│   │   ├── ChatGPTAccountPoolManager.swift
│   │   └── ChatGPTAccountMonitorWidget.swift
│   ├── Models/                            # LLM Clients & Daemons
│   │   ├── SiriAIEngine.swift
│   │   ├── ClaudeAPI.swift
│   │   ├── OpenAIAPI.swift
│   │   └── IntegrationsManager.swift
│   └── Domain/                            # Domain-Specific Extensions
│       ├── TradingView/
│       │   ├── TradingViewActionDispatcher.swift
│       │   ├── TradingViewDrawingTool.swift
│       │   ├── TradingViewInputSupport.swift
│       │   ├── TradingViewLayoutTool.swift
│       │   ├── TradingViewNavigationTool.swift
│       │   └── TradingViewTypes.swift
│       ├── Astronacci/
│       │   ├── AstronacciClusterEngine.swift
│       │   ├── AstronacciDeterministicEngine.swift
│       │   ├── AstronacciDivergenceEngine.swift
│       │   ├── AstronacciEconomicCalendarEngine.swift
│       │   ├── AstronacciEphemerisEngine.swift
│       │   ├── AstronacciPlanetaryAspectEngine.swift
│       │   └── AstronacciQuasimodoEngine.swift
│       └── FuturesScout/
│           ├── FuturesScoutBackgroundWatcher.swift
│           ├── FuturesScoutChartAnalyst.swift
│           ├── FuturesScoutCoreAnalyst.swift
│           ├── FuturesScoutMarketDataService.swift
│           └── BingXMarketDataEngine.swift
│
└── Core/                                  # CORE APPLICATION LIFECYCLE & DISPATCH
    ├── CompanionManager.swift
    ├── ClickyLogger.swift
    ├── ClickyEnums.swift
    ├── ClickyAnalytics.swift
    ├── ClickyDeterministicPipeline.swift
    ├── ClickyFunctionTool.swift
    ├── ClickyFunctionToolRegistry.swift
    ├── ClickyToolDispatcher.swift
    ├── AppBundleConfiguration.swift
    └── PCCGroundingEscalation.swift
```

---

## ⚡ 3. Dynamic Intent Contract (Zero String Coupling)

### Peningkatan `AFMTaskDecomposition` / `CanonicalTaskContract`:
Menambahkan properti boolean kelas satu (*first-class semantic booleans*) yang dihasilkan 100% oleh model:
1. `requiresCUA: Bool`  
   - `false` untuk sapaan, perkenalan, chit-chat, Q&A santai ➔ langsung ke `companion.askViaText`.
   - `true` untuk perintah yang membutuhkan navigasi/inspeksi aplikasi komputer.
2. `requiresTakeoverOnCompletion: Bool`  
   - Model secara otonom menentukan apakah aksi tersebut merupakan pengiriman data/transaksi final yang butuh persetujuan fisik pengguna (misal kirim email, submit form pembayaran).
   - Menghapus pengecekan manual: `let isSendTask = (taskPlan?.intentType == "send") || (taskPlan?.normalizedGoal.contains("send"))`.
3. `isConversational: Bool`  
   - Menandai secara eksplisit bahwa input pengguna adalah percakapan biasa tanpa target aplikasi (`targetAppName = "None"`).

### Penyempurnaan Ingress Prompt (`TaskIngressGateway.swift`):
Prinsip klasifikasi intent diajarkan secara tegas kepada model:
- **`conversational`**: Sapaan ("halo", "hi"), basa-basi, pertanyaan identitas, atau pertanyaan konseptual tanpa permintaan interaksi aplikasi ➔ `requiresCUA: false`, `targetAppName: "None"`, `plannedSubGoals: []`.
- **`action`**: Perintah memeriksa, membaca, mencari, mengetik, atau mengoperasikan software ➔ `requiresCUA: true`, `targetAppName: "<App>"`, `plannedSubGoals: [...]`.

---

## 📋 4. Step-by-Step Execution Plan

### Step 1: Perbarui Kontrak & Ingress Classifier (Dynamic Intent Gate)
- Perbarui `CanonicalTaskContract.swift` dengan atribut first-class:
  - `requiresTakeoverOnCompletion: Bool`
- Perbarui prompt dekomposisi di `TaskIngressGateway.swift` dengan Ingress Intent Principles (Conversational vs Action).
- Hapus semua pengecekan hardcoded `intentType == "send"` atau `normalizedGoal.contains("send")` di `CompanionVMAgentLoop.swift` dan `TaskEgressValidator.swift`, gantikan dengan `taskPlan?.requiresTakeoverOnCompletion == true`.
- Hapus fallback heuristik yang memaksakan `candidateApp = connectedApps.first` saat prompt adalah sapaan; ganti dengan fallback netral `requiresCUA = false`, `intentType = "conversational"`.

### Step 2: Restrukturisasi Direktori Fisik
- Buat folder-folder standar:
  - `boringNotch/Clicky/UI/{HomeSpace,Rail,Floating,Avatars,Viewport,Common}`
  - `boringNotch/Clicky/Reasoning/{Ingress,Planner,Validator,Coordination}`
  - `boringNotch/Clicky/CUA/{Loop,Actions,Grounding,Execution}`
  - `boringNotch/Clicky/Workspace/{VirtualDisplay,Streaming,Discovery,WindowManagement}`
  - `boringNotch/Clicky/Services/{Audio,Vision,Models,Domain/TradingView,Domain/Astronacci,Domain/FuturesScout}`
  - `boringNotch/Clicky/Core`
- Pindahkan file-file Swift dari lokasi lama ke subfolder yang sesuai secara bertahap.

### Step 3: Sinkronisasi `project.pbxproj`
- Perbarui jalur file (`path = ...`) di `boringNotch.xcodeproj/project.pbxproj` agar mencocokkan struktur folder baru.
- Pastikan tidak ada duplikasi `PBXFileReference` atau `PBXBuildFile`.

### Step 4: Perbarui Aturan di `AGENTS.md`
- Perbarui Bagian 3 (`Arsitektur Isolated Workspace`) dengan bagan direktori baru yang memisahkan Frontend (`UI/`) vs Logic (`Reasoning/`, `CUA/`, `Workspace/`, `Services/`, `Core/`).
- Tambahkan Invariant 12: **Strict Domain Layering (UI vs Logic Isolation)**.
  - Dilarang menempatkan komponen UI (`View`, `Window`, `Overlay`) ke dalam folder logika CUA/Tools.
  - Dilarang memasukkan logika CUA AI atau orkestrator loop ke dalam folder UI.

### Step 5: Verifikasi Komprehensif (TDD, Build, Test Runtime)
- Buat test suite TDD:
  - Memverifikasi input "halo", "hi", "selamat pagi", "siapa kamu" menghasilkan `requiresCUA == false` dan `intentType == "conversational"`.
  - Memverifikasi input "buka email saya", "cek inbox", "kirim pesan ke Doni" menghasilkan `requiresCUA == true` dan `requiresTakeoverOnCompletion == true` (untuk kirim).
  - Memverifikasi struktur direktori file di disk sesuai standar.
- Eksekusi `xcodebuild` hingga `** BUILD SUCCEEDED **` (exit code 0).
- Relaunch aplikasi via `scripts/launch_app.sh`, cek PID dan verifikasi log `clicky.log`.
- Dokumentasikan di `CHANGELOG.md` dan `ERRORS.md`.

---

## 🔒 5. Verification Checklist
- [ ] Model on-device AFM merespons "halo" dengan `requiresCUA: false` (tidak ada kartu computer use).
- [ ] Model on-device AFM merespons "tolong check email saya" dengan `requiresCUA: true` (membuka kartu computer use).
- [ ] Seluruh file di `boringNotch/Clicky` tertata rapi di folder `UI/`, `Reasoning/`, `CUA/`, `Workspace/`, `Services/`, `Core/`.
- [ ] `boringNotch.xcodeproj` terkompilasi bersih tanpa peringatan file missing.
- [ ] `AGENTS.md` memuat aturan isolasi folder Frontend vs Logic.
