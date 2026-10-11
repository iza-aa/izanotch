# PROJECT.md — Izanotchy Roadmap & Current Status

## Fokus Saat Ini
Membangun dan menstabilkan alur kerja CUA (Computer Use Agent) di isolated virtual display agar dapat menjalankan tugas sehari-hari (seperti mengelola email) secara handal, cepat, dan 100% bebas dari intrusi layar utama pengguna.

## Komponen Utama
- `izaNotch/Clicky/CUA/Loop/CompanionVMAgentLoop.swift`: Siklus eksekusi agen (See -> Plan -> Act -> Validate).
- `izaNotch/Clicky/CUA/Grounding/`: Persepsi visual (OCR, Accessibility hierarchy, dan koordinat elemen UI).
- `izaNotch/Clicky/CUA/Actions/`: Aksi kursor fisik (klik, ketik, scroll).
- `izaNotch/Clicky/Workspace/`: Pengelolaan display virtual dan streaming frame ke kartu antarmuka.

## Target Verifikasi
- Pengoperasian aplikasi di latar belakang tidak mengganggu jendela fullscreen pengguna di layar host.
- Eksekusi aksi pengetikan dan klik mendarat di elemen input yang tepat.
- Selesai dengan laporan yang akurat sesuai kondisi nyata aplikasi.
