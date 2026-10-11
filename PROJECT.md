# PROJECT.md — Izanotchy Roadmap & Current Status

## Fokus Saat Ini
TASK-046 Deterministic Surface Pivot (`tasks/TASK_046_DETERMINISTIC_SURFACE_PIVOT.md`):
- Routing gate `executionTier` (web | native_cua) di Ingress — connected apps → permukaan deterministik; tanpa connected apps → Clicky mode.
- Fase B: pembersihan kode liar terledger (periphery scan + Delete-Zone).
- Fase C: Web Workspace (WKWebView, observasi/aksi via DOM).
- Fase D: Automations (bot hidup terjadwal).
Referensi arsitektur: `github-reference/grok-bot/` (REA evidence di `rea-evidence/`).

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
