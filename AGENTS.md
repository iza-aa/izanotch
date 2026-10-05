# AGENTS.md — Agent Directives & Operational Invariants

<!-- Single Source of Truth for Agent Behavior, Rules, and Execution Invariants -->
<!-- Detail konteks produk, arsitektur, dan karakteristik model 3B ada di CONTEXT.md -->

---

## 🛑 1. Core Operational Directives (Aturan Mutlak Agent)

### 1. Protokol Persetujuan (Wajib Minta ACC Sebelum Sentuh Kode)
- **DILARANG LANGSUNG MENGUBAH KODE TANPA PERSETUJUAN PENGGUNA.**
- Setiap kali menemukan bug, kendala, atau merancang perbaikan, agen **WAJIB** menyajikan laporan ringkas dengan format:
  > **Root Cause:** Ini terjadi karena [penyebab faktual singkat beserta file/baris].  
  > **Solusi:** Saya akan memperbaikinya dengan [tindakan konkret & terukur].  
  > **Tolong di-acc.**
- Agen **HANYA BOLEH** menyentuh kode, membuat file baru, atau memodifikasi file setelah pengguna secara eksplisit memberikan persetujuan (misal: *"acc"*, *"oke"*, *"lanjut"*).

### 2. Komunikasi Ringkas & Padat (No Yap / No Fluff)
- Dilarang memberikan narasi bertele-tele, basa-basi panjang, atau penjelasan teoritis berulang.
- Langsung ajukan solusi terbaik yang paling tepat sasaran dan aman. Jangan menyajikan opsi-opsi alternatif yang membingungkan pengguna.
- Dilarang memanggil tools planning internal sistem. Jika butuh rencana tertulis, gunakan file Markdown (`.md`) di repositori.

### 3. Pikirkan Karakteristik Model 3B Sebelum Bertindak (Cognitive Empathy)
- Rujuk [CONTEXT.md](file:///Users/heizaaa/Desktop/cdev/iza-3/CONTEXT.md) Bagian 2 untuk detail kapasitas kognitif model kita.
- **Sebelum menulis prompt atau logika reasoning:**
  1. *Apakah prompt ini terlalu panjang atau memiliki multi-tanggung jawab?* Jika ya, **WAJIB dipecah** menjadi fungsi-fungsi terpisah (Single Responsibility).
  2. *Apakah ada angka atau data literal di prompt yang bisa memicu few-shot overfitting?* Jika ya, ganti 100% dengan placeholder tipe data abstrak (`<targetIndex>`, `<targetEntity>`).
  3. *Apakah observasi yang dikirim ke model terlalu besar (dump JSON satu layar)?* Jika ya, ganti dengan observasi terarah per item (*Targeted Item Observation*).

### 4. Larangan Mutlak Segala Bentuk Hardcoding (Zero Hardcoding)
- **Zero App-Specific Code:** Dilarang keras menulis percabangan if-else nama aplikasi (`if appName.contains("mail")`), shortcut cheat per-aplikasi, atau AppleScript manipulasi data aplikasi.
- **Zero Scripted Fallbacks:** Dilarang switch-case langkah AI palsu (`case 1: click A, case 2: click B`). Seluruh langkah wajib dipikirkan dinamis oleh model.
- **Zero Data Injections in Prompts:** Dilarang menyuntikkan data contoh nyata ke dalam prompt.

### 5. Konsultasi & Update Ledger Kesalahan (ERRORS.md)
- Dokumen [ERRORS.md](file:///Users/heizaaa/Desktop/cdev/iza-3/ERRORS.md) adalah buku catatan invariant pencegahan bug masa lalu.
- **Sebelum merancang solusi:** Periksa `ERRORS.md` agar solusi yang diajukan tidak mengulangi kesalahan masa lalu.
- **Setelah menyelesaikan pekerjaan:** Catat gejala, root cause, dan aturan pencegahan ke dalam `ERRORS.md`.

### 6. Larangan Klaim Palsu & Verifikasi Empiris (Anti-Fake Completion)
- **DILARANG MENYATAKAN SELESAI TANPA BUKTI NYATA.**
- Setiap klaim keberhasilan wajib disertai bukti faktual:
  1. Kompilasi bersih (`xcodebuild` exit code 0).
  2. Proses hidup terverifikasi (`ps aux` membuktikan PID baru berjalan).
  3. Log runtime bersih (`~/Library/Logs/Izanotchy/clicky.log`).
  4. Pengujian skrip otomatis di `scripts/` lulus 100%.

---

## 🏛️ 2. Architectural Invariants (Konsolidasi Inti)

1. **Dual-Layer Physical Mouse Interaction (`CUAClickActionTool`, `CUAScrollActionTool`, `MascotVirtualDesktopService`)**:
   - Seluruh interaksi menggunakan kursor fisik universal: `click`, `scroll`, `drag`, `type`.
   - Event mouse latar belakang wajib menggabungkan pergerakan kursor kinetik maskot (`glideReticleTo`) + ripple visual dengan manipulasi Accessibility IPC deterministik pada PID target.
   - Event scroll wajib membagi gerakan secara halus (multi-step kinematic) dan disesuaikan proporsional terhadap ukuran daftar (*row-proportional adaptive scroll*), bukan lompatan kasar persentase statis.

2. **Clean Workspace Anchor & Proactive Scroll Reset (`CUAScrollActionTool`, `CompanionVMAgentLoop`)**:
   - Setiap tugas inspeksi umum atau item pertama (`effectiveTargetIdx == 1`), loop CUA wajib memanggil `resetScrollToTop(pid:)` untuk menyetel `AXVerticalScrollBar` ke `0.0`.
   - Mencegah sisa scroll dari sesi sebelumnya menggeser item teratas keluar dari viewport.

3. **Anti-Spurious Scroll Guard & Strict Target Presence (`CompanionVMAgentLoop`, `TaskStepPlanner`)**:
   - Jika item target sudah tampak di dalam observasi (`sessionObservedListItems`), model WAJIB langsung merencanakan `click`. Loop CUA memiliki guard deterministik yang memblokir dan meng-override aksi scroll jika target sudah ada di layar.
   - Model dilarang merencanakan `click` pada item ke-N jika indeks tersebut belum muncul di layar; satu-satunya aksi yang sah adalah `scroll_down` pada kontainer daftar.

4. **Targeted Item Observations vs Raw Screen Dumps (`CompanionVMAgentLoop`)**:
   - Observasi langkah (`observationResult`) DILARANG memuat seluruh dump JSON mentah satu layar (topBar, sidebar, 9 item list, dll.).
   - Observasi langkah wajib ringkas dan terfokus pada item yang diinteraksikan (misal: item yang diklik + teks baru yang dimuat di preview pane).

5. **Modular Egress Validation (Pemisahan State vs Language) (`TaskEgressValidator`)**:
   - `TaskEgressValidator` wajib memisahkan dua tanggung jawab:
     - `evaluateTaskState(...)`: Evaluasi teknis murni (apakah `isDone`, `requiresTakeover`, dan ekstraksi fakta nyata dari reading pane).
     - `synthesizeUserResponse(...)`: Sintesis respons bahasa alami ke pengguna dalam `userLanguage` berdasarkan fakta yang sudah diekstrak.

6. **Synchronous Snapshot Persistence (`CompanionWindowStreamService`)**:
   - Penulisan frame jendela ke disk wajib selesai secara sinkron sebelum URL snapshot dikembalikan ke OCR atau pipeline observasi, mencegah *stale snapshot race condition*.

---

## 📜 3. Mandatory Session Completion Checklist

Sebelum melaporkan pekerjaan selesai kepada pengguna:
- [ ] `xcodebuild` selesai dengan kode 0 (`** BUILD SUCCEEDED **`).
- [ ] Biner lama dimatikan dan biner baru terverifikasi berjalan via `ps aux`.
- [ ] Skrip verifikasi di `scripts/` lulus 100%.
- [ ] Log `~/Library/Logs/Izanotchy/clicky.log` bersih tanpa unhandled exception.
- [ ] `CHANGELOG.md` diperbarui dengan milestone teknis.
- [ ] `ERRORS.md` diperbarui dengan nomor error baru jika ada bug yang diperbaiki.
