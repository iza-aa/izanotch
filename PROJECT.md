# PROJECT.md — Izanotchy Roadmap & Current Status

## Fokus Saat Ini
TASK-046 Fase C gerbang (8 skenario fasec) → lalu TASK-047 Parity Build (`tasks/TASK_047_PARITY_MICROTASKS.md`): 22 micro-task dalam 6 fase (paritas I/O, skills & routines, connectors & API tier, memori & multi-companion, governance, model capability check) dengan protokol review otomatis per micro-task. Sumber bacaan agent+reviewer: `github-reference/grok-bot/` (S1-S7: HOW_IT_WORKS, 4 PRD_NOTES, REA evidence, app.asar source).
- Routing gate `executionTier` (web | native_cua) di Ingress — connected apps → permukaan deterministik; tanpa connected apps → Clicky mode.
- Fase B: pembersihan kode liar terledger (periphery scan + Delete-Zone).
- Fase C: Web Workspace (WKWebView, observasi/aksi via DOM).
- Fase D: Automations (bot hidup terjadwal).
Referensi arsitektur: `github-reference/grok-bot/` (REA evidence di `rea-evidence/`), studi cara kerja: `github-reference/grok-bot/HOW_IT_WORKS.md`.
Skill review UI proyek: `.zcode/skills/swiftui-pro-iza/` (diadaptasi dari twostraws/swiftui-agent-skill, MIT) — muat saat mengerjakan/mereview kode SwiftUI.

## Arsitektur CUA (mode native, companion tanpa connected apps)
Membangun dan menstabilkan alur kerja CUA (Computer Use Agent) di isolated virtual display agar dapat menjalankan tugas sehari-hari secara handal, cepat, dan 100% bebas dari intrusi layar utama pengguna.

## Komponen Utama
- `izaNotch/Clicky/CUA/Loop/CompanionVMAgentLoop.swift`: Siklus eksekusi agen (See -> Plan -> Act -> Validate).
- `izaNotch/Clicky/CUA/Grounding/`: Persepsi visual (OCR, Accessibility hierarchy, dan koordinat elemen UI).
- `izaNotch/Clicky/CUA/Actions/`: Aksi kursor fisik (klik, ketik, scroll).
- `izaNotch/Clicky/Workspace/`: Pengelolaan display virtual dan streaming frame ke kartu antarmuka.

## Target Verifikasi
- Pengoperasian aplikasi di latar belakang tidak mengganggu jendela fullscreen pengguna di layar host.
- Eksekusi aksi pengetikan dan klik mendarat di elemen input yang tepat.
- Selesai dengan laporan yang akurat sesuai kondisi nyata aplikasi.
