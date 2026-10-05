# Executive Summary: Adopting xAI Grok Bot Architecture & Function Calling into Izanotchy (Clicky)

<!-- Status: Approved Architectural Blueprint -->
<!-- Target: Native macOS Multi-Companion System with Isolated Workspaces & Unified Function Calling -->
<!-- Date: September 2026 -->

---

## 🎯 1. Latar Belakang & Visi Proyek

Pengguna mengidentifikasi kesenjangan konseptual mendasar pada sistem companion Clicky di dalam **Izanotchy**:
> *"Clicky kita belum jelas konsep per companion-nya... kalau saya lihat pokoknya 1 bot itu bisa buka aplikasi seperti di foto 1, terus dia bisa kerja di workspace tersebut. Saya ingin mengadopsi ilmu, fitur, dan function-calling dari xAI Grok Bot dengan kejujuran penuh dan track yang jelas dari awal."*

Peluncuran **xAI Grok Bot** (September 2026, kemitraan xAI × Cursor) memperkenalkan standar baru untuk AI Teammates:
1. **Bukan Sekadar Chatbot**: Setiap Bot adalah rekan kerja otonom yang memiliki identitas, tugas terdefinisi (*job role*), memori jangka panjang, dan batasan persetujuan (*approval boundary*).
2. **Setiap Bot Memiliki Workspace / "Computer" Sendiri**: Bot dapat membuka aplikasi, bernavigasi di peramban (browser), mengelola berkas lokal, dan menjalankan perintah terminal di lingkungan kerjanya sendiri.
3. **Visual Streaming Card di Chat Thread (Foto 1)**: Ketika Bot bekerja di komputernya, ia menyajikan kartu interaktif `[Computer • Working / Done]` lengkap dengan tangkapan layar/stream visual jendela aplikasi yang sedang dikerjakan, dan dapat meminta pengguna mengambil alih (*takeover*) untuk login sensitif (2FA, CAPTCHA).
4. **Dual-Engine Execution**: Memadukan **Function Calling** terstruktur (API/Connectors dengan JSON Schema) untuk operasi deterministik cepat, dan **Computer Use** visual untuk antarmuka yang tidak memiliki API.
5. **Multi-Bot Teammate Collaboration**: Beberapa Bot dapat bekerja paralel, berbagi berkas di `/workspace`, saling bertukar pesan di *Group Chat*, atau menyerahkan tugas (*handoff*) tanpa pengguna harus menjadi perantara manual.

---

## 🧭 2. Prinsip Kejujuran Teknik (Brutal Honesty & Reality Check)

Sebelum menulis sebaris kode pun, kita menetapkan prinsip kejujuran mutlak:

| Dimensi | xAI Grok Bot (Cloud SaaS) | Clicky di Izanotchy (Saat Ini) | Target Adopsi Izanotchy (Native macOS) |
| :--- | :--- | :--- | :--- |
| **Infrastruktur Eksekusi** | Linux Cloud Virtual Machine terisolasi di server Cursor/xAI per akun. | Langsung di macOS host pengguna; hanya ada 1 kursor fisik mouse dan 1 layar aktif. | **Hybrid Local Sandbox**: Workspace filesystem per-slug (`~/.izanotchy/companions/<slug>/workspace`), session browser per-slug (WKWebView / Chromium profile terisolasi), dan background headless app window targeting. |
| **Konsep "Computer / Workspace"** | X11/Wayland virtual display terpisah di cloud, tidak mengganggu layar fisik pengguna. | **Belum ada**. Interaksi CUA (`cua-driver`) membajak layar fisik pengguna dan merebut kontrol mouse macOS secara global. | **Dedicated Companion Workspace**: Setiap companion memiliki direktori kerja mandiri, tab peramban terisolasi, dan render kartu visual `[Computer • Working / Done]` di HomeSpace Chat (seperti Foto 1). |
| **Tool Calling / Function Calling** | Standar resmi xAI Function Calling (OpenAI-compatible JSON Schema dengan Pydantic, parallel calling, built-in search). | Ad-hoc Swift classes (`FuturesScoutChartAnalyst`, `TradingViewActionDispatcher`, `BingXMarketDataEngine`) yang di-hardcode per skenario. | **Unified Tool Engine**: Engine function-calling generik berbasis JSON Schema yang kompatibel dengan xAI Grok API, Claude Tool Use, dan Gemini API. |
| **Interaksi UI Chat (Foto 1)** | Kartu visual `Computer` dengan frame desktop streaming, status pill (`Working`/`Done`), dan tombol takeover. | Bubble teks biasa (`HomeSpaceChatMessage`), progress drawer sederhana, dan popup consent CUA terpisah. | **Interactive Computer Card**: Komponen SwiftUI di dalam chat stream yang menampilkan frame jendela aplikasi yang sedang dikerjakan companion, status real-time, dan kontrol human takeover. |
| **Multi-Companion / Kolaborasi** | Group chat, `@mentions`, asynchronous handoffs, memori peran terpisah tapi berbagi `/workspace`. | Profil terdaftar di Roster (`CompanionProfile`), tetapi berjalan bergantian sebagai tab tunggal; tidak ada komunikasi antar-companion. | **Multi-Companion Mesh**: Group thread di HomeSpace, delegasi `@BotName`, dan pipeline handoff berbasis event/message queue. |

---

## 📚 3. Struktur Dokumen Perencanaan (Modular Planning Index)

Folder ini (`docs/grok-bot-companion-adoption/`) menyusun peta jalan lengkap, terukur, dan transparan:

- [**00_EXECUTIVE_SUMMARY.md**](file:///Users/heizaaa/Desktop/cdev/iza-3/docs/grok-bot-companion-adoption/00_EXECUTIVE_SUMMARY.md): Ringkasan eksekutif, prinsip kejujuran, dan peta jalan tingkat tinggi.
- [**01_GROK_BOT_DECONSTRUCTION.md**](file:///Users/heizaaa/Desktop/cdev/iza-3/docs/grok-bot-companion-adoption/01_GROK_BOT_DECONSTRUCTION.md): Bedah tuntas arsitektur xAI Grok Bot berdasarkan dokumentasi resmi dan produk rilis.
- [**02_CLICKY_CURRENT_STATE_AUDIT.md**](file:///Users/heizaaa/Desktop/cdev/iza-3/docs/grok-bot-companion-adoption/02_CLICKY_CURRENT_STATE_AUDIT.md): Audit faktual kode Clicky di `boringNotch` (apa yang sudah ada, apa yang rapuh, dan celah yang harus dijembatani).
- [**03_FUNCTION_CALLING_SPECIFICATION.md**](file:///Users/heizaaa/Desktop/cdev/iza-3/docs/grok-bot-companion-adoption/03_FUNCTION_CALLING_SPECIFICATION.md): Spesifikasi teknis adopsi xAI Function Calling (JSON Schema, tool registry, parser, tool loop, dan parallel calls).
- [**04_COMPANION_WORKSPACE_ARCHITECTURE.md**](file:///Users/heizaaa/Desktop/cdev/iza-3/docs/grok-bot-companion-adoption/04_COMPANION_WORKSPACE_ARCHITECTURE.md): Arsitektur ruang kerja per companion & implementasi kartu chat `[Computer]` 1:1 Foto 1 (isolated browser profiles, window targeting, takeover 2FA/login).
- [**05_MULTI_COMPANION_COLLABORATION_SPEC.md**](file:///Users/heizaaa/Desktop/cdev/iza-3/docs/grok-bot-companion-adoption/05_MULTI_COMPANION_COLLABORATION_SPEC.md): Spesifikasi kolaborasi multi-companion (group chat, `@mentions`, delegasi tugas, shared memory).
- [**06_IMPLEMENTATION_ROADMAP_MILESTONES.md**](file:///Users/heizaaa/Desktop/cdev/iza-3/docs/grok-bot-companion-adoption/06_IMPLEMENTATION_ROADMAP_MILESTONES.md): Rencana fase implementasi bertahap (Milestone 155–160) dengan kriteria uji TDD dan perlindungan zero-regression.
- [**07_AVATAR_LAB_CHARACTER_SYSTEM.md**](file:///Users/heizaaa/Desktop/cdev/iza-3/docs/grok-bot-companion-adoption/07_AVATAR_LAB_CHARACTER_SYSTEM.md): Desain adopsi Bible Strong Avatar Lab (procedural 2D/3D avatars, rigging mata, kedipan prosedural, gaze tracking, menggantikan ikon awan).
- [**08_CLICKY_CODEBASE_REFACTOR_PLAN.md**](file:///Users/heizaaa/Desktop/cdev/iza-3/docs/grok-bot-companion-adoption/08_CLICKY_CODEBASE_REFACTOR_PLAN.md): Rencana refaktorisasi 5 kategori terstruktur (Dihapus, Di-edit, Dipindahkan, Ditambah, Diperbaiki) untuk seluruh berkas Clicky.
- [**09_FEATURE_BY_FEATURE_TRACKER.md**](file:///Users/heizaaa/Desktop/cdev/iza-3/docs/grok-bot-companion-adoption/09_FEATURE_BY_FEATURE_TRACKER.md): Master tracker eksekusi per fitur kecil dengan siklus terstruktur 4 langkah: Backend ➔ Frontend ➔ Cara Ngetest ➔ Lanjut/Revisi.


