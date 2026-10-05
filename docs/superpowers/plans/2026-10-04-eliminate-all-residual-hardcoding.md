# Plan: Eradicate All Residual Hardcoding Across the Codebase

**Date:** 2026-10-04  
**Target:** Full Compliance with AGENTS.md (Zero Hardcoding in Code, Logic, & Prompts)

---

## 🔍 Temuan Audit: 5 Titik Hardcoding yang Masih Tersisa

### 1. Hardcoded String Filtering di Loop (`CompanionVMAgentLoop.swift`)
- **Kode:**
  - `validation.responseToUser.contains("Sedang")`
  - `lastVal.responseToUser.contains("Menunggu konfirmasi")`
  - `validation.extractedData.lowercased() != "none"`
  - `fallbackGround?.method.rawValue ?? "Hybrid Grounding"`
- **Masalah:** Menggunakan pencarian substring literal dari teks bahasa Indonesia tertentu. Jika respon berbahasa Inggris atau jika kalimat alami mengandung kata "sedang", kondisi ini rapuh dan melanggar prinsip generalisasi.
- **Solusi:** Ganti dengan status enum eksplisit atau boolean flag pada `AFMValidationResult`, dan gunakan `fallbackGround?.method.displayName` atau domain enum.

### 2. Magic Numbers / Koordinat Tebakan Buta (`CompanionVMAgentLoop.swift`)
- **Kode:**
  - `CGPoint(x: 240, y: 160)` (baris 324)
  - `CGPoint(x: 240, y: 150)` (baris 560)
  - `CGPoint(x: 100, y: 100)` (baris 571)
- **Masalah:** Jika sensor grounding gagal menemukan koordinat elemen target, kursor dipaksa meluncur ke koordinat tebakan buta (240, 160), menyebabkan kursor nyasar di pojok kiri atas jendela.
- **Solusi:** Hitung titik tengah jendela aplikasi aktif secara dinamis (`window.midX, window.midY`) atau tandai bahwa grounding gagal agar planner dapat mencoba melihat kembali (See ➔ Plan).

### 3. Hardcoded Keyword Dictionary di Grounding Engine (`ClickyHybridGroundingEngine.swift`)
- **Kode (baris 210–214):**
  - `query.contains("to") && (title == "to" ...)`
  - `query.contains("subject") && ...`
  - `query.contains("send") && ...`
  - `query.contains("inbox") && ...`
  - `query.contains("compose") && ...`
- **Masalah:** Kamus kata kunci email yang di-hardcode ke dalam engine grounding umum. Merusak generalisasi ketika asisten bekerja pada aplikasi lain (Safari, Terminal, Notes, Slack, dll.).
- **Solusi:** Ganti dengan pencocokan token dinamis universal (token query pengguna dicocokkan dengan kemiripan atribut UI `AXTitle`, `AXDescription`, `AXIdentifier` tanpa daftar kata kunci statis).

### 4. Hardcoded Phrase Blacklists di Validator (`TaskEgressValidator.swift`)
- **Kode (baris 168 & 200):**
  - `badPhrases = ["ubahkan", "silakan klik", "buka kotak masuk", "lihat secara detail", "lakukan perubahan", "format teks", "format email"]`
  - `englishSlipTokens = ["the third email", "the second email", "the first email", "in your inbox is", "the operation has been", "cancelled", ...]`
  - `contains("siap untuk pengiriman") || contains("draft") || contains("draf")`
- **Masalah:** Daftar string literal kaku yang mencoba mencegat keluaran model alih-alih mengandalkan kontrak JSON dan pemfilteran bahasa berbasis deteksi karakter/kamus bahasa alami.
- **Solusi:** 
  - Gunakan `requiresTakeover` langsung dari JSON `dict["requiresTakeover"]` tanpa regex teks "draft".
  - Gunakan deteksi bahasa berbasis tokenizer / `TaskIngressGateway.resolveLanguage` yang bersih.

### 5. Residual Hardcoded App Names & SF Symbols (`TaskIngressGateway.swift` & `AppSystemIconView.swift`)
- **Kode:**
  - `TaskIngressGateway.swift:147`: `(lower.contains("mail") ? "Mail" : "Safari")`
  - `AppSystemIconView.swift:24-51`: `Image(systemName: appName.lowercased().contains("safari") ? "safari.fill" : "envelope.fill")`
- **Masalah:** Asumsi kaku bahwa aplikasi selalu Mail atau Safari.
- **Solusi:** 
  - Ingress: Ambil `connectedApps.first ?? "Workspace"`.
  - Icon View: Ambil icon aplikasi macOS native asli melalui `NSWorkspace.shared.icon(forFile:)` via `InstalledAppsDiscoveryService`.

---

## 📅 Rencana Eksekusi TDD Bertahap

- [ ] **Task 1**: Bersihkan string checks (`contains("Sedang")`, `contains("none")`) dan gunakan typed validation di `CompanionVMAgentLoop.swift` & `TaskEgressValidator.swift`.
- [ ] **Task 2**: Hapus magic numbers `CGPoint(x: 240, y: 160)` di `CompanionVMAgentLoop.swift` dan ganti dengan geometri dinamis jendela target.
- [ ] **Task 3**: Refaktor `ClickyHybridGroundingEngine.swift` untuk membuang kamus email statis (`"to"`, `"subject"`, `"compose"`) dan ganti dengan pencocokan token universal.
- [ ] **Task 4**: Bersihkan `badPhrases` dan `englishSlipTokens` di `TaskEgressValidator.swift`.
- [ ] **Task 5**: Ganti fallback icon `AppSystemIconView.swift` dan fallback Ingress agar 100% membaca dari `InstalledAppsDiscoveryService` / `connectedApps`.
- [ ] **Task 6**: Verifikasi suite test TDD, kompilasi bersih `xcodebuild`, dan uji coba runtime.
