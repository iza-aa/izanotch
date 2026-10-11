# TASK-046: Deterministic Surface Pivot — Routing Gate, Pembersihan Terledger & Web Workspace

Spesifikasi teknis mengikat. Disusun setelah ACC pengguna (2026-10-11). Latar bukti: 44 task perang variansi native CUA, dan reverse engineering Grok Bot (`github-reference/grok-bot/`, REA evidence di `rea-evidence/`) yang membuktikan keandalan agent lahir dari permukaan deterministik (browser/exec), bukan dari menaklukkan GUI native macOS.

---

## 0. Prinsip Pengikat (baca sebelum menulis kode)

1. **Clicky tidak dihapus — didemosi.** Mode native CUA tetap utuh untuk companion TANPA connected apps, membawa seluruh perbaikan hari ini (form-card grounding, post-click focus verification, orphan sweep, hide-first, tanpa AppleScript relocation) sebagai fondasi.
2. **Routing gate, bukan kondisi tersebar:** satu sumber keputusan `executionTier`, bukan if-else nama aplikasi tersebar. Zero Hardcoding tetap berlaku mutlak.
3. **Penghapusan wajib terledger** (Fase B): setiap file/simbol dihapus dicatat di CHANGELOG + daftar penghapusan pada catatan task ini (path + alasan); dilarang menghapus apa pun di luar daftar audit.
4. **Garis merah hukum:** Grok Bot adalah kode proprietary Anysphere/Cursor. Dilarang menyalin kode, aset, atau mendistribusikan dmg-nya. Yang boleh: pola arsitektur (dokumen ini yang merumuskannya).
5. Zero emoji. Semua pemanggilan AX di background queue. Dilarang `/usr/sbin/screencapture`, `.cghidEventTap`/`.cgSessionEventTap` untuk virtual workspace, `tell application` pada app workflow.

---

## 1. Fase A — Routing Gate (eksekusiTier di Ingress)

- Tambahkan field `executionTier: "web" | "native_cua"` pada `CanonicalTaskContract` (Ingress).
- Aturan deterministik: companion memiliki connected apps yang tersedia permukaan webnya → `web`; selain itu → `native_cua`. Untuk fase awal, permukaan web tersedia untuk task webmail (compose/read email) dan task browser umum.
- Konsekuensi routing: `web` → task dieksekusi di Web Workspace (Fase C), CompanionVMAgentLoop native TIDAK menyala. `native_cua` → jalur Clicky saat ini (lengkap dengan semua guard hari ini).
- Telemetri: log `[ROUTING]` per task memuat tier + alasan (field apa yang menentukan).
- **Gerbang:** unit test routing; skenario "kirim email" pada buddy connected → tier=web, nol panggilan AX virtual display di log; skenario buddy tanpa connected → tier=native_cua.

## 2. Fase B — Pembersihan Kode Liar (Terledger)

Metode audit wajib, berurutan:

1. **Periphery scan** (`brew install periphery; periphery scan --project izaNotch.xcodeproj`): daftar simbol/dead code. Simpan output ke `tasks/TASK046_periphery_baseline.txt`.
2. **Audit referensi silang:** setiap kandidat dihapus dilarang langsung — verifikasi nol referensi (`grep -rn <symbol> izaNotch/`), kecuali dikecualikan di daftar KEEP (Bagian 2b).
3. **Kandidat awal untuk diverifikasi** (bukanvonis final — verifikasi dulu):
   - Jalur eksekusi fisik legacy ganda (`ComputerUsePhysicalExecutor` tap-global yang sudah di-gate; evaluasi apakah masih ada pemanggil hidup setelah routing gate).
   - Sisa kebijakan/pipeline tanpa pemanggil pasca-routing (cek `ComposeStepPolicy` lama, script test tanpa status).
   - File Swift terdaftar di project.pbxproj tapi nol referensi, dan sebaliknya (file di disk tak terdaftar).
   - Sisa aset/konstanta fitur yang sudah dimusnahkan (DeepSeek, Gemini — pastikan bersih total).
4. **Batch kecil:** hapus maksimal satu kelompok logis per iterasi → build → jalankan kedua suite regresi → baru lanjut. Dilarang menghapus besar-besaran sekaligus.
5. Setiap penghapusan: entri TASKS.md Delete-Zone (path + alasan + tanggal) dan catat di CHANGELOG.

### 2b. Daftar KEEP — DILARANG DIHAPUS (simpanan hari ini)
- `ClickyUIObservationService` (termasuk form field boxes), `LayaDecisionEngine` + `scripts/laya_daemon.py`, `SiriAIEngine`/AFM (port 1976) + `TaskStepPlanner`, Luna/Codex vision (`ChatGPTCodexVisionService` + health flag), `TaskEgressValidator` + completion gate, Post-Click Focus Verification, Filled-Field Re-Target Guard, JSON repair layer, `sweepOrphanWindowsOnStartup`, hide-first lifecycle, in-memory capture (`CGWindowListCreateImage`), kanal `iza.e2e` (#if DEBUG), `scripts/e2e/` + `scripts/test_afm_capability.swift` + `scripts/test_system_noninvasive.swift`, grok-bot reference folder (dokumentasi, bukan kode jalan).

### 2c. Peran Model per Tier (jangan terbalik saat pembersihan)
- **AFM (System 2)**: tetap jantung di KEDUA tier — Ingress decomposition, planner langkah (native: aksi koordinat; web: aksi DOM), Egress validation/synthesis.
- **Laya (System 1)**: tetap untuk klasifikasi intent di Ingress + triage/element-pick di tier native_cua. Di tier web perannya mengecil (DOM menggantikan persepsi) — tetap hidup, jangan dihapus.
- **Luna (truth vision)**: hanya tier native_cua — mata fallback + gerbang pra-terminal. Tier web tidak memakainya (DOM adalah kebenaran). Health flag wajib agar kegagalannya tidak melumpuhkan apa pun di luar native.

## 3. Fase C — Web Workspace (permukaan deterministik)

- **Wadah:** WKWebView embedded di HomeSpace (reuse pola `CompanionVMViewportView/Controller` yang sudah memakai WebKit). Bukan virtual display, bukan SCK, bukan capture — DOM adalah matanya.
- **Observasi:** snapshot DOM via `evaluateJavaScript` (form fields: selector → label/value/editable) — format JSON sama dengan observasi Clicky agar planner/Egress tidak berubah.
- **Aksi:** fill/click via DOM (JS injection), bukan koordinat. Keyboard fokus adalah properti DOM — tidak ada masalah caret.
- **Sesi & kredensial:** login manual sekali per provider, sesi dipersistenkan (`WKWebsiteDataStore`); kredensial via 1Password/OAuth mengikuti pola Grok Bot (dilarang simpan password mentah). Impor cookie dari browser pengguna = fase lanjutan.
- **Adapter per situs** (pola `agentmail`): registry adapter — pertama: webmail (Gmail atau Outlook yang user punya). Adapter memuat selector map per situs — data deklaratif, bukan branch kode.
- **Generik semantik sebagai DEFAULT (wajib)**: situs TAK terdaftar wajib tetap bisa dioperasikan — model membaca DOM semantik via standar web universal (`[role]`, `aria-label`, teks terlihat; pemindaian generik `button, a, [role="button"]` sudah ada sebagian di loop) tanpa selector map. Adapter = override presisi untuk alur frekuensi tinggi, BUKAN prasyarat. Situs tanpa adapter jatuh ke jalur generik, bukan default adapter yang salah.
- **Kursor hidup tier web**: saat loop beraksi (fill/click DOM), ambil rect elemen target via `evaluateJavaScript` dan animasikan `vmCursorPosition` meluncur ke sana (kinematika sama dengan reticle native). Kursor adalah identitas companion di kedua tier — dilarang meninggalkannya statis.
- **Gerbang:** skenario "kirim email" lewat jalur web: To/Subject/Body terisi terverifikasi DOM + terkirim; nol panggilan AX; layar host tenang.

## 4. Fase D — Automations (bot hidup)

- Definisi automation: JSON (prompt/trigger: interval atau waktu; enabled; target buddy) — disimpan via actor store yang ada.
- Scheduler: naikkan `VM_WATCHER` 60-detik yang ada menjadi evaluator trigger → saat trigger menyala, injeksikan task via kanal `iza.e2e.task` yang sudah ada (#if DEBUG tetap; kanal produksi: internal API internal app, bukan distributed notification).
- Lifecycle: automation lulus routing gate yang sama (tier web/native).
- **Gerbang:** automation "check email tiap N menit" terbukti menyala sendiri tanpa interaksi pengguna, lulus oracle, tercatat di log dengan runId.

## 5. Fase E — Gerbang Bukti Akhir (Definition of Done)

- [ ] `xcodebuild` exit 0; biner baru aktif (`ps aux`).
- [ ] Routing gate: minimal 2 skenario (buddy connected → web; buddy tanpa → native_cua) dengan log `[ROUTING]`.
- [ ] Web workspace: kirim email via webmail lulus (DOM-verified), nol AX.
- [ ] Automations: satu automation terjadwal menyala otonom dan lulus.
- [ ] Clicky mode: buddy tanpa connected apps tetap lulus skenario native (bukti demosi tidak mematikan).
- [ ] Periphery re-scan pasca-pembersihan: jumlah temuan turun; seluruh penghapusan terledger.
- [ ] Kedua suite regresi lulus; `scripts/e2e` oracle ketat (assertion kosong = gagal).
- [ ] CHANGELOG.md (milestone), TASKS.md (status + Delete-Zone), ERRORS.md (bug baru saat pembersihan) diperbarui.

## 6. Disiplin Fail-Fix Loop

Gagal = bug sistem → root-cause (konsultasi arsip `archive/legacy_docs/ERRORS.md` bila perlu) → perbaiki sistem, bukan test/oracle → rebuild → ulangi sampai gerbang lulus. Dilarang test tailoring; expected yang faktual salah hanya boleh diubah dengan justifikasi di CHANGELOG.

---

## 7. Rekonsiliasi Realitas & Disposisi Audit (Reviewer Verification 2026-10-11)

Dua deviasi dari rencana awal disetujui reviewer berbasis verifikasi dependensi nyata pada codebase:

1. **Domain Astronacci (Preservasi Parsial Komponen Hidup)**:
   - **Fakta**: Seluruh domain Astronacci tidak dapat dihapus mutlak karena memiliki rantai pemanggil aktif yang vital pada modul analitik pasar (`FuturesScoutMarketDataService`, `CompanionReportPresenter`, `FuturesScoutCoreAnalyst`, `FuturesScoutChartAnalyst`).
   - **Tindakan Terledger**: Hanya simbol mati yang dipangkas:
     - 380 baris evaluasi lama (`evaluateConfluence`, `evaluateVetoGate`, struktur data evaluasi kuno).
     - 43 temuan Periphery tuntas (properti assign-only, model internal tak terpakai seperti `AstronacciFibonacciGrid`, dan aksesibilitas `public` redundan).
   - **Hasil**: Peringatan Periphery untuk domain Astronacci turun dari 43 menjadi **0** tanpa merusak fungsi live `FuturesScout`.

2. **CuaDriverClient (Status: Komponen Domain yang Disanksi)**:
   - **Fakta**: `CuaDriverClient` bukan dead code, melainkan klien eksekusi fisik resmi untuk domain TradingView (Invariant 17) yang menangani perpindahan kursor canvas, snapshot grafis, dan eksekusi shortcut.
   - **Tindakan Terledger**: Membersihkan modul prototipe RPC usang yang tidak pernah dipanggil (`CuaApp`, `CuaWindow`, `CuaElement`, `CuaWindowState`, `listApps()`, `listWindows()`, `getWindowState()`), serta mengisolasi transport ke scope internal package.

---

## 8. Inventaris Pembersihan Kode Liar Berikutnya (Pasca-TASK-047)

Berdasarkan audit Periphery pasca-TASK-046 (1.017 temuan tersisa dari baseline 1.148):

| Target Domain / File | Jumlah Temuan | Rincian Dead Code & Potensi Reduksi | Disposisi Rencana |
|---|---|---|---|
| `DesignSystem.swift` | 51 temuan | Palet warna statis, token tipografi, dan view modifier yang tidak pernah dirujuk oleh UI modern Home Space. | Batch 1 Pembersihan Pasca-TASK-047 |
| Avatar Domain (`CompanionProceduralAvatarView.swift` [33], `CompanionAvatarLabCatalog.swift` [25]) | 58 temuan | State animasi prosedural tak terpakai, preset bentuk katalog lab lama yang ditinggalkan. | Batch 2 Pembersihan Pasca-TASK-047 |
| CUA & Kinematika (`CuaMotionEngine.swift` [31], `CompanionVMAgentLoop.swift` [32]) | 63 temuan | Metode spline/motion math usang dan cabang loop dekomposisi legacy yang digantikan Web Workspace. | Batch 3 Pembersihan Pasca-TASK-047 |
| `components/Shelf/` | 34 temuan | Subview rak legacy notch yang tidak aktif pada arsitektur Home Space notch-wrapped baru. | Batch 4 Pembersihan Pasca-TASK-047 |
| `private/CGSSpace.swift` & `DataTypes+Extensions.swift` | 39 temuan | Binding fungsi privat CoreGraphics/CGS tak terpakai dan utility extensions yang telah memiliki padanan di Swift standard library. | Batch 5 Pembersihan Pasca-TASK-047 |
