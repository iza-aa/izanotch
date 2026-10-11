# TASKS.md — Master Execution & Progress Tracker

Dokumen ini adalah Single Source of Truth untuk memantau status pengerjaan fitur, perbaikan bug, dan optimasi arsitektur di proyek izanotchy.

---

## Daftar Tugas Aktif (Active Tasks)

| ID | Nama Tugas | Status | Dokumen Detail | Deskripsi Singkat |
|---|---|---|---|---|
| TASK-001 | Kursor Visual CuaDriver & Siklus Hidup Efemeral | Selesai | [TASK_001.md](file:///Users/heizaaa/Desktop/cdev/iza-3/tasks/TASK_001_CUA_CURSOR_VISUAL_LIFECYCLE.md) | Kursor segitiga tanpa ekor, warna tema Buddy, muncul hanya saat aksi lalu fade out |
| TASK-002 | Grounding Universal Bebas Hardcoding | Selesai | [TASK_002.md](file:///Users/heizaaa/Desktop/cdev/iza-3/tasks/TASK_002_UNIVERSAL_SEMANTIC_GROUNDING.md) | Targeting berbasis teks observasi nyata & bounding box visual (bukan frasa abstrak / koordinat statis) |
| TASK-003 | Arsip & Perampingan Dokumen Markdown Panjang | Selesai | [TASK_003.md](file:///Users/heizaaa/Desktop/cdev/iza-3/tasks/TASK_003_MD_ARCHIVE_AND_CONTEXT_OPTIMIZATION.md) | Perampingan in-place CHANGELOG.md (42KB) & ERRORS.md (59KB) selesai |
| TASK-004 | Eliminasi Hardcoding Egress & Rekonsiliasi Ordinal Ingress | Selesai | [TASK_004.md](file:///Users/heizaaa/Desktop/cdev/iza-3/tasks/TASK_004_ORDINAL_RECONCILIATION_AND_EGRESS_PURGE.md) | Pembersihan kamus kata hardcoded di Egress, rekonsiliasi angka ordinal eksak, eliminasi takeover palsu |
| TASK-005 | Telemetri Viewport Spasial Otonom & Scroll-Up Dinamis | Selesai | [TASK_005.md](file:///Users/heizaaa/Desktop/cdev/iza-3/tasks/TASK_005_AUTONOMOUS_SPATIAL_VIEWPORT_TELEMETRY.md) | Injeksi viewport.isAtTop ke observasi, model berpikir sendiri untuk scroll_up saat list ter-scroll |
| TASK-006 | Navigasi Kontainer UI Universal & Ingress Bebas Hardcoding | Selesai | [TASK_006.md](file:///Users/heizaaa/Desktop/cdev/iza-3/tasks/TASK_006_UNIVERSAL_CONTAINER_NAVIGATION.md) | Eliminasi rasio kolom statis 0.17/0.55 & injeksi targetIndex=1; routing kontainer universal berbasis semantik |
| TASK-007 | Non-Autoregressive System 1 Decision Engine (Laya) | Selesai | [TASK_007.md](file:///Users/heizaaa/Desktop/cdev/iza-3/tasks/TASK_007_NON_AUTOREGRESSIVE_DECISION_ENGINE.md) | Integrasi laya-multilingual (322M, 20ms) sebagai fast decision router sebelum grounding AFM/Luna |
| TASK-008 | Proteksi Kontrol UI Universal & Otomatisasi Daemon Laya | Selesai | [TASK_008.md](file:///Users/heizaaa/Desktop/cdev/iza-3/tasks/TASK_008_ACTION_INTENT_GROUNDING_AND_DAEMON_LIFECYCLE.md) | Proteksi tombol kontrol dari pembajakan baris data, null targetIndex di compose, lifecycle otomatis daemon |
| TASK-009 | Section-Aware Dynamic Grounding & Eliminasi Fake Completion | Selesai | [TASK_009.md](file:///Users/heizaaa/Desktop/cdev/iza-3/tasks/TASK_009_SECTION_AWARE_GROUNDING_AND_NO_FAKE_COMPLETION.md) | Whole-word matching, fast-path AXToolbar, eliminasi fake completion di Egress, seleksi elemen semantik Laya |
| TASK-010 | Pembersihan Total Hardcoding & Grounding Semantik Murni | Selesai | [TASK_010.md](file:///Users/heizaaa/Desktop/cdev/iza-3/tasks/TASK_010_COMPLETE_HARDCODE_PURGE.md) | Eliminasi kamus sinonim, heuristik koordinat tetap, daftar kata kunci kontrol, dan kamus judul jendela |
| TASK-011 | Ekstraksi Dinamis AXToolbar & Dual-Layer IPC Click | Selesai | [TASK_011.md](file:///Users/heizaaa/Desktop/cdev/iza-3/tasks/TASK_011_TOOLBAR_DYNAMIC_EXTRACTION_AND_IPC_GROUNDING.md) | Ekstraksi kontrol AXToolbar ke observasi, dual-layer AXPressAction, perbaikan normalisasi titik tengah |
| TASK-014 | Enforced System Harness Swift & Perampingan Prompt Multi-Kebijakan | Selesai | [TASK_014.md](file:///Users/heizaaa/Desktop/cdev/iza-3/tasks/TASK_014_SYSTEM_HARNESS_PROMPT_DECOMPOSITION.md) | Konversi instruksi prompt panjang menjadi proteksi deterministik kode Swift (Zero Hardcoding) & perampingan prompt < 18 baris |
| TASK-015 | Perbaikan Native Role AXToolbar & Proteksi Kontainer AXRow | Selesai | - | Perbaikan pencarian role AXToolbar pada Priority 1 Fast-Path & pencegahan deskripsi VoiceOver AXRow membajak tombol aksi |
| TASK-016 | Token Input Commit, Active Window Priority, & Adaptive Field Offset | Selesai | - | Pengiriman tombol Return pada token input, prioritas jendela aktif, offset label statis, dan guard deterministik kegagalan aksi |
| TASK-017 | Separasi Arsitektur Observasi UI, Pemulihan Luna 6 Vision, & ReAct Error Recovery | Selesai | [TASK_017.md](file:///Users/heizaaa/Desktop/cdev/iza-3/tasks/TASK_017_ARCHITECTURAL_SEPARATION_AND_REACT_REASONING.md) | Ekstraksi ClickyUIObservationService, resolusi dinamis biner Codex CLI (gpt-6-luna), refleksi rintangan ReAct pada planner, dan validasi faktual Egress |
| TASK-018 | Form Input Grounding Protection, Dynamic Laya System 1 Choices & ReAct Egress Integrity | Selesai | [TASK_018.md](file:///Users/heizaaa/Desktop/cdev/iza-3/tasks/TASK_018_FORM_GROUNDING_LAYA_AND_REACT.md) | Proteksi query input form dari pembajakan AXToolbar, choices dinamis Laya System 1, penalaran ReAct pengisian form, dan guard anti-halusinasi Egress |
| TASK-019 | Awaited Typing, Native AX Neighbor Traversal & Dynamic Window Refresh | Selesai | [TASK_019.md](file:///Users/heizaaa/Desktop/cdev/iza-3/tasks/TASK_019_AWAITED_TYPING_AND_CLEAN_GROUNDING.md) | Eliminasi race condition pengetikan non-awaited, penghapusan Return hardcoded, traversal tetangga input native tanpa offset 50pt, penyegaran candidateWindows di setiap langkah loop |
| TASK-020 | Universal Affordance Discovery, Strict Item Target Guard & Factual Preview Verification | Selesai | - | Prioritas jendela berbasis affordance native AX, guard pencegahan klik sembarangan di luar daftar, dan verifikasi faktual preview pane di Egress |
| TASK-021 | Penyelarasan Observasi Egress, Penutupan Celah Fake Completion, & Sinkronisasi Arsitektur | Selesai | - | Verifikasi adaptif konten membaca di Egress, penguncian penyelesaian tugas aksi, eliminasi wait sinkron di MainActor, dan sinkronisasi berkas ARCHITECTURE.md |
| TASK-022 | Universal Input Focus, Native Token Commit, & Action-Aware Perception | Selesai | - | Pemindahan fokus native via kAXFocusedAttribute pada seluruh elemen input teks, commit chip token universal via commitTokenField(), propagasi actionType pada grounding, dan penegakan urutan pengisian form |
| TASK-023 | Triad Architecture: Local Vision Eyes, Laya Fast Brain, Luna Truth Vision & Hands | Selesai | - | Pemisahan mutlak penglihatan holistik vs fisik: parser form fields lokal ~50ms, triage form Laya ~20ms, Pre-Terminal Vision Gate via Luna (gpt-6-luna), dan AXUIElement murni tangan fisik |
| TASK-024 | Value Hijack Prevention & Clean Field Overwrite via Select All (⌘A) | Selesai | - | Larangan pencocokan kAXValueAttribute saat mencari field input (mencegah pembajakan residu teks), penimpaan bersih input via performCuaSelectAll(clearAfter: false), dan dukungan aksi clear/delete |
| TASK-025 | Zero-Hardcoding Neural Intent Classification & Role-Contextualized Egress | Selesai | - | Klasifikasi intensi dinamis Laya Multilingual (~20ms, inspect_latest vs search_filtered) tanpa kamus kata henti statis, penyajian fakta langsung (findings-first role contextualization) di Egress synthesizer, dan eliminasi literal template |
| TASK-026 | Strict S1 Ingress & S4 CUA Execution Architectural Boundary | Selesai | - | Pemisahan mutlak wewenang S1 Ingress (eksklusif AFM System 2) vs S4 CUA Execution (Laya System 1), pencegahan pembajakan intent percakapan "halo" ke "check mail", dan perbaikan prinsip deklaratif Ingress |
| TASK-027 | Unfiltered Modal Dialog Detection, Autonomous Sheet Dismissal & Button Protection | Selesai | - | Deteksi modal sheet langsung dari windowList tanpa filter pra-syarat, dismiss draf sheet via ⌘D (0x02) pada tugas inspect, proteksi tombol kontrol dari pembajakan indeks baris isItemClick, dan penolakan teks sheet di Egress |
| TASK-028 | Dimmer Backdrop Exclusion, Modal Sheet Compositing & Deterministic CUA | Selesai | - | Eliminasi jendela dimmer backdrop tanpa judul, komposisi visual alami kartu sheet (< 550x400) di tengah jendela induk dengan drop shadow & dim, penegakan deterministik requiresCUA = true untuk aplikasi nyata, dan pembersihan deliverable korup |
| TASK-029 | Strict Geometric Dialog Threshold & Full-Sized Window Exclusion | Selesai | - | Penghapusan kata kunci statis "cleanup", penegakan batasan geometris ketat (< 550x400 pt) untuk deteksi modal blocking dialog, dan eliminasi takeover palsu pada jendela normal iCloud Mail Cleanup |
| TASK-030 | Virtual Display Window Prioritization & Empty Title Guard | Selesai | - | Penguncian checkWindowAffordance agar dilarang mencocokkan judul kosong, prioritas jendela Virtual Display (X >= 1500) di atas jendela off-screen host Mac (X: 0), dan eliminasi kanvas hitam di HomeSpace |
| TASK-031 | Universal Compose Prioritization, Utility Window Exclusion & Zero-Hardcode Audit | Selesai | - | Filter jendela utilitas background pemeliharaan ("cleanup"), prioritas jendela koleksi saat jendela draf/editor belum terbuka, pencocokan aksi kreasi ke kontrol berlabel "New" sesuai standar HIG macOS, dan audit 0% hardcoding |
| TASK-032 | Strict Display-First Allocation, Host Unhide Elimination & Collection-to-Draft Triage | Selesai | - | Eliminasi app.unhide() di layar host, alokasi Virtual Display sebelum peluncuran aplikasi, triage koleksi ke draf untuk intent kirim/tulis, dan pengujian empiris 4 skenario pengguna |
| TASK-033 | Continuous Window Relocation & Inclusive Step Recovery in Egress Validator | Selesai | - | Relokasi otomatis jendela baru ("New Message") ke Virtual Display saat lahir di tengah alur tugas, eliminasi total tiling ke layar kerja pengguna, dan pengakuan kata kerja aksi ("Executed click") pada validator pemulihan |
| TASK-034 | Pure CUA Alert Handling, Zero Premature Takeover & Collection Header Isolation | Selesai | - | Penghapusan total pencegatan skrip statis detectBlockingDialog dan ⌘D, penyerahan penanganan dialog konfirmasi secara murni ke persepsi visual Luna dan kursor fisik CUA (handle_alert), eliminasi stretched dialog di kandidat fallback, dan isolasi header bacaan |
| TASK-035 | True Stacked Virtual Workspace Capture & Alert Dismissal Priority | Selesai | - | Transformasi penangkapan ScreenCaptureKit ke ruang Virtual Display penuh (SCContentFilter display-level), penumpukan jendela native z-order alami tanpa peregangan dialog ke fullscreen, dan prioritas penutupan alert modal sebelum aksi toolbar |
| TASK-036 | Zero Host Cursor Warping, Target PID Propagation & Parent Button Traversal | Selesai | - | Eliminasi total .cgSessionEventTap dan event mouseMoved pada glideReticleTo, propagasi target PID dinamis ke seluruh aksi pengetikan/klik CUA, dan penelusuran tombol induk dari label teks statis |
| TASK-037 | Inclusive AX Normalization & SourceRect Auto-Cropping | Selesai | - | Normalisasi presisi koordinat global "Fast-Path AX" ke koordinat lokal jendela untuk kolom input "To", eliminasi salah klik ke tepi kanan (0.98), dan auto-crop sourceRect ScreenCaptureKit untuk melenyapkan margin hitam di HomeSpace |
| TASK-038 | Flicker-Free Native SCK Stability, Symmetric Sizing & Intent-Gated Forms | Selesai | - | Eliminasi total error ScreenCaptureKit dan kedipan layar dengan menghapus config.sourceRect, penataan simetris jendela memenuhi display (dW-20, dH-20), dan penguncian isFormActive khusus intensi penulisan pesan |
| TASK-039 | Zero External Screencapture Invocations & Specific Item Navigation Targeting | Selesai | - | Eliminasi 100% biner eksternal /usr/sbin/screencapture dan penggantian murni ke API in-memory Quartz CGWindowListCreateImage/CGDisplayCreateImage (melenyapkan kedipan layar monitor host), serta penargetan label item spesifik ("All Inboxes") alih-alih container ("sidebar") |
| TASK-040 | Stable CUA Workflow Recovery & Zero-Flicker Execution | Selesai | [TASK_040.md](file:///Users/heizaaa/Desktop/cdev/iza-3/tasks/TASK_040_STABLE_CUA_WORKFLOW_RECOVERY.md) | Rencana teknis komprehensif 4 fase: eliminasi kedipan layar, isolasi kursor host, presisi pengetikan kolom To & penelusuran tombol induk, serta penanganan modal alert alami |
| TASK-041 | Zero Screencapture Subprocess & Virtual Sandbox HID Event Tap Gate | Selesai | - | Pemusnahan total biner /usr/sbin/screencapture di CuaVisualGrounder dan TradingViewInputSupport, pemblokiran .cghidEventTap pada jalur legacy ComputerUsePhysicalExecutor & CompanionManager+ComputerUse saat virtual sandbox aktif, dan penghapusan AppleScript hardcoded teardown |
| TASK-042 | Synchronous Turn Result Delivery & Complete Gemini Elimination | Selesai | - | Perbaikan race condition executeTanyaChain yang mengunci UI "Berpikir..." (ERR-106) dan eliminasi total dependensi Gemini menuju arsitektur 100% on-device AFM port 1976 |
| TASK-043 | Connected Apps Sandbox Enforcement & Conversational Chain Isolation | Selesai | - | Validasi workflowAppNames pada executeAksiChain/executeKetikChain dan penyekatan splitChainedCommand pada kategori aksi murni (ERR-107) |
| TASK-044 | Ground-Truth Oracle E2E Runner (Test Boleh Gagal, Sistem yang Dibenahi) | Selesai | [TASK_044.md](file:///Users/heizaaa/Desktop/cdev/iza-3/tasks/TASK_044_GROUND_TRUTH_ORACLE_E2E_RUNNER.md) | Runner E2E dengan tiga oracle independen (AX, Log, Visual), negative control validator bypass, debug-only command injection via DistributedNotificationCenter, dan Fail-Fix Loop anti test-tailoring (ERR-108) |
| TASK-046 | Deterministic Surface Pivot — Routing Gate, Pembersihan Terledger & Web Workspace | Selesai | [TASK_046.md](file:///Users/heizaaa/Desktop/cdev/iza-3/tasks/TASK_046_DETERMINISTIC_SURFACE_PIVOT.md) | Pivot permukaan deterministik (Web Workspace WKWebView + DOM actions), routing gate di Ingress dengan log [ROUTING], pembersihan terledger dead code, dan bot automations terjadwal |
---

## Status Legenda

- [ ] `Belum Dimulai`: Tugas terdaftar tetapi belum dieksekusi.
- [ ] `Menunggu Persetujuan`: Analisis root cause dan rancangan solusi selesai, menunggu ACC pengguna.
- [/] `Sedang Dikerjakan`: Dalam proses implementasi kode atau pengujian.
- [x] `Selesai`: Terverifikasi via clean build (exit 0), proses PID aktif, dan log bersih.

---

## Riwayat Penyelesaian Terbaru
- Milestone 310: Complete Screencapture Eradication & Virtual Sandbox HID Gating (2026-10-10).
- Milestone 309: Zero External Screencapture Invocations & Specific Item Navigation Targeting (2026-10-10).
- Milestone 298: Dimmer Backdrop Exclusion, Modal Sheet Compositing & Deterministic CUA Enforcement (2026-10-10).
- Milestone 297: Unfiltered Modal Dialog Detection, Autonomous Sheet Dismissal & Button Protection (2026-10-10).
- Milestone 296: Strict S1 Ingress & S4 CUA Architectural Boundary & Conversational Intent Protection (2026-10-10).
- Milestone 295: Zero-Hardcoding Neural Intent Classification, Role-Contextualized Egress & Template Sanitization (2026-10-10).
- Milestone 294: Value Hijack Prevention, Clean Field Overwrite via Select All (⌘A) & Universal Text Erasure (2026-10-10).

- Milestone 293: Triad Architecture (Local Vision Eyes, Laya Fast Brain, Luna Truth Vision Pre-Terminal Gate & Physical Hands) (2026-10-10).
- Milestone 292: Universal Input Focus, Native Token Commit, Action-Aware Element Perception & Strict Form Sequencing (2026-10-10).
- Milestone 291: Penyelarasan Observasi Egress, Penutupan Celah Fake Completion, Eliminasi Subproses Sinkron MainActor & Sinkronisasi Dokumen Arsitektur (2026-10-10).
- Milestone 290: Universal Affordance Discovery, Strict Item Target Guard & Factual Preview Verification (2026-10-10).
- Milestone 289: Awaited Typing, Native AX Neighbor Traversal, Eliminasi Return Hardcoded & Dynamic Window Refresh (2026-10-10).
- Milestone 288: Form Input Grounding Protection, Dynamic Laya System 1 Choices, Autonomous ReAct Reasoning & Factual Egress Integrity (2026-10-10).
- Milestone 287: Separasi Arsitektur Observasi UI, Pemulihan Vision Luna 6, dan ReAct Error Recovery Loop (2026-10-10).
- Milestone 286: Adaptasi Ekosistem ECC, Living Docs Governance, dan Pemadatan Konstitusi AGENTS.md (2026-10-10).
- Milestone 285: Token Input Commit, Prioritas Jendela Aktif, Adaptive Field Offset, dan Guard Kegagalan Aksi (2026-10-10).
- Milestone 284: Perbaikan Penelusuran Native Role AXToolbar dan Proteksi Kontainer AXRow dari Pembajakan Aksi (2026-10-10).
- Milestone 283: Penegakan Deterministik Aturan Skema di Level System Harness, Pemangkasan Prompt Kebijakan AFM, dan Isolasi Persona Trading (2026-10-10).

- Milestone 278: Ekstraksi Dinamis Kontrol AXToolbar Universal, Dual-Layer IPC Click (AXPressAction), dan Normalisasi Relatif Default Window Center (2026-10-09).
- Milestone 277: Pembersihan Total Sisa Hardcoding (Kamus Sinonim Manual, Heuristik Koordinat Tetap, dan Daftar Kata Kunci Kontrol) serta Transisi Grounding Semantik Dinamis (2026-10-09).
- Milestone 276: Section-Aware Dynamic Grounding, Whole-Word Token Boundary Matching, Akses Langsung AXToolbar, dan Eliminasi Fake Completion di Egress Validator (2026-10-09).
- Milestone 275: Proteksi Universal Kontrol UI, Eliminasi Celah Fake Completion pada Action Tasks, Grounding Sinonim Semantik macOS HIG, dan Otomatisasi Lifecycle Laya Daemon di Background (2026-10-09).
- Milestone 274: Integrasi Non-Autoregressive Decision Engine (Laya Multilingual ~20ms), Pemisahan System 1 & System 2, dan Single-Responsibility Step Policies (2026-10-09).
- Milestone 273: Segmentasi Kartu Font-Height Dinamis Bebas-Ambang Statis, Penjangkaran Indeks Konsensus Multi-Kartu, dan Presisi Klik Baris Universal (2026-10-09).
- Milestone 271: Telemetri Viewport Spasial Otonom (`viewport.isAtTop`), Penomoran Kartu Sadar-Offset, dan Scroll-Up Dinamis Model 3B (2026-10-09).
- Milestone 270: Eliminasi Total String Hardcoded di Egress, Rekonsiliasi Ordinal Eksak Ingress, dan Pencegahan Repeated Click (2026-10-09).
- Milestone 269: Kursor CUA Efemeral Segitiga Tanpa Ekor, Grounding Semantik Teks Nyata & Fallback OCR, dan Perampingan In-Place Markdown (2026-10-08).
- Milestone 268: Perbaikan Proporsi Layar Workspace, Border Abu-abu, Resolusi Ordinal List, dan Presisi Kursor (2026-10-08).
- Milestone 267: Eliminasi Total Integrasi DeepSeek dari Aplikasi izaNotch (2026-10-08).
- Milestone 266: Konsolidasi Definitif Single Source of Truth & Eliminasi Duplikasi Packages/ClickyKit (2026-10-08).

---

## Delete-Zone (Zona Penghapusan Permanen)

Berikut adalah daftar file, paket, dan pendekatan yang telah dihapus secara sengaja dan **DILARANG DIBUAT ULANG** oleh agen coding:

| Path / Komponen | Alasan Dihapus | Pengganti Resmi | Kondisi Peninjauan Ulang |
|---|---|---|---|
| `Packages/ClickyKit/` | Duplikasi struktur package yang memicu konflik build (Milestone 266) | `izaNotch/Clicky/` (modul native internal) | Dilarang permanen; seluruh kode Clicky berada di dalam `izaNotch/Clicky/` |
| `izaNotch/managers/DeepSeekUsageManager.swift` | Eliminasi total ketergantungan API DeepSeek (Milestone 267) | On-device AFM (`LanguageModelSession`) & Luna | Dilarang permanen |
| `izaNotch/Assets.xcassets/deepseek.imageset/` | Aset ikon DeepSeek tidak lagi digunakan (Milestone 267) | Aset native / SFCG Symbols | Dilarang permanen |
| Kamus kata henti (`noiseWords: Set<String>`) | Hardcoding kata statis melanggar invariant semantik universal (Milestone 277) | Overlap token semantik alami & Laya Multilingual | Dilarang permanen |
| Rasio kolom tetap (`x >= 0.17`, `0.55`) | Pembatasan spasial statis per-aplikasi (Milestone 270) | Deteksi kontainer native Accessibility (`AXOutline`, `AXTable`) | Dilarang permanen |
| `izaNotch/Clicky/Services/Models/GeminiBridgeClient.swift` | Eliminasi total dependensi cloud Gemini (Milestone 311) | 100% On-Device Apple Foundation Models (AFM On-Device NPU, port 1976) | Dilarang permanen |
| String payload statis `"sistem berhasil dibuat"` di `CUATypeActionTool.swift` | Pelanggaran Zero Hardcoding; mengembalikan teks uji statis sebagai fallback pengetikan (ERR-109) | Ekstraksi payload dinamis murni dari kontrak tugas (`prompt` / `normalizedGoal`) | Dilarang permanen |
| Kamus `tokenHints` `["to","cc","bcc",...]` di `CUATypeActionTool.swift` | Hardcoding nama field statis untuk deteksi token field (ERR-109) | Deteksi subrole native Accessibility `AXTokenField` (Invariant 18) | Dilarang permanen |
| `izaNotch/Clicky/Services/Models/OpenAIAPI.swift` | Dead legacy cloud vision client (0 callers, external cloud dependency) | AFM On-Device & Web Workspace (Fase B TASK-046) | Dilarang permanen (2026-10-11) |
| `izaNotch/utils/Logger.swift` | Untracked dead code violating Zero Emoji rule (0 callers) | `ClickyLogger` | Dilarang permanen (2026-10-11) |
| `izaNotch/Clicky/Core/Contracts/CompanionSessionDelegate.swift` | Untracked dead protocol (0 callers) | `CompanionManager` internal actor state | Dilarang permanen (2026-10-11) |
| `AstronacciDeterministicEngine.swift` (`evaluateConfluence`, `evaluateVetoGate`, `AstronacciEvaluationResult`, `AstronacciScoreBreakdown`, `AstronacciVetoCheck`, `AstronacciTradePlan`) | Legacy dead confluence evaluator & data structures (380 baris kode mati, 0 caller eksternal) | `FuturesScoutCoreAnalyst` modular analyst pipeline | Dilarang permanen (2026-10-11) |
| `Astronacci*Engine.swift` (Cluster, Divergence, Quasimodo, Ephemeris, Calendar, Aspect) | Properti assign-only tak terpakai & modifier public redundan (43 temuan Periphery tuntas) | `FuturesScoutCoreAnalyst` data-driven interface | Dilarang permanen (2026-10-11) |
| `CuaActionCursorManager.swift` (`CuaActionCursorView`, `CuaActionCursorTriangle`) | Decommissioned stub shape & views (0 callers) | Native Cua Driver cursor overlay | Dilarang permanen (2026-10-11) |
| `CuaDriverClient.swift` (`CuaApp`, `CuaWindow`, `CuaElement`, `CuaWindowState`, `listApps()`, `listWindows()`, `getWindowState()`) | Dead prototype RPC structs & methods (0 callers) | Lean `CuaDriverClient` + direct MCP tool execution | Dilarang permanen (2026-10-11) |
