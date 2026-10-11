# TASK-044: Ground-Truth Oracle E2E Runner (Test Boleh Gagal, Sistem yang Dibenahi)

Dokumen ini adalah spesifikasi teknis mengikat untuk membangun runner E2E yang asersinya berbasis keadaan dunia nyata (oracle independen), menggantikan verifikasi tautologis ERR-108. Disusun setelah ACC pengguna (2026-10-11).

---

## 1. Konteks & Mandat

- `scripts/test_task042_halo_tanya_afm_stream.swift` dan `scripts/test_task043_connected_apps_sandbox_and_multitask_e2e.swift` adalah tautologi: tidak mengimpor kode aplikasi, semua skenario menguji re-implementasi logika di dalam file test sendiri (lihat ERR-108).
- Bukti kegagalan sistem yang lolos dari test lama: `clicky.log` 2026-10-11 11:36 — skenario "kirim email" berakhir `isDone=false` ("Body field remains empty"), loop menyimpulkan tugas tanpa konfirmasi validasi (`Task concluded without validation confirmation`), deliverable receipt tetap tersimpan, dan storm `ScreenCaptureKit error` berulang tiap 0.8 detik.
- Mandat: satu runner E2E dengan tiga oracle independen + negative control. Ketika runner gagal, yang dibenahi adalah KODE SISTEM, bukan test-nya (Fail-Fix Loop, Bagian 6).

## 2. Arsitektur Runner

```
scripts/e2e/
  run_e2e.swift              -- driver: build check, relaunch biner, kirim skenario, kumpulkan bukti, exit code
  scenarios.json             -- deklaratif: prompt, expectedState, mustFailIf, timeout, quarantine
  oracles.swift              -- AXOracle, LogOracle, VisualOracle
  artifacts/<timestamp>/     -- hasil JSON + screenshot per skenario (wajib tersimpan, lulus maupun gagal)
```

- Runner dieksekusi: `swift scripts/e2e/run_e2e.swift [--scenario <id>]`.
- Exit code: 0 hanya jika seluruh skenario non-quarantine lulus SELURUH oracle. Satu oracle gagal = run gagal.
- Output per skenario: `artifacts/<timestamp>/<scenario>.json` (status per oracle, durasi, kutipan log) + `artifacts/<timestamp>/<scenario>.png`.

## 3. Kontrak Injeksi Perintah (Debug-Only)

- Tambahkan observer `DistributedNotificationCenter` di `izaNotchApp.swift` di dalam blok `#if DEBUG`, mengikuti pola observer yang sudah ada (baris 848-883).
- Nama notifikasi masuk: `iza.e2e.task`, payload `userInfo["text"] = prompt`, `userInfo["runId"] = <uuid>`.
- Prompt diteruskan ke entry point yang SAMA dengan input chat pengguna (jalur normal Ingress) — dilarang membuat jalur eksekusi khusus test.
- Notifikasi balik: `iza.e2e.done` dengan `userInfo["runId"]`, `userInfo["concluded"]` (bool), `userInfo["validatorIsDone"]` (bool), `userInfo["deliverableSaved"]` (bool) — dari state loop yang sama yang dipakai chat.
- Dilarang keras menyisakan cabang test di build rilis: seluruh kode injeksi di dalam `#if DEBUG`.

## 4. Skema scenarios.json

```json
{
  "version": 1,
  "scenarios": [
    {
      "id": "kirim-email-presisi",
      "prompt": "kirim email ke <penerima> bahwa sistem berhasil dibuat",
      "targetApp": "Mail",
      "timeoutSeconds": 180,
      "expected": {
        "ax": [
          { "role": "AXTextField", "labelHint": "To",     "valueContains": "<penerima>" },
          { "role": "AXTextField", "labelHint": "Subject","valueContains": "sistem berhasil dibuat" },
          { "role": "AXTextArea",  "labelHint": "Body",   "valueContains": "sistem berhasil dibuat" }
        ],
        "log": {
          "requireIsDone": true,
          "mustNotContain": [
            "Task concluded without validation confirmation",
            "ScreenCaptureKit error"
          ]
        },
        "visual": { "capture": "virtualDisplay", "assert": "ocrContains", "value": "sistem berhasil dibuat" }
      },
      "mustFailIf": ["validatorIsDone == false dan deliverableSaved == true"],
      "quarantine": false
    }
  ]
}
```

- Skenario wajib mencakup matriks TASK-040: sapaan ("halo"), inspeksi ("check email saya"), ordinal ("check email yang ketiga"), navigasi kontainer ("buka all inboxes"), komposisi ("kirim email"), dan penolakan sandbox (aplikasi di luar izin bot aktif).
- Skenario sandbox negatif: asersi adalah TIDAK ADA jendela aplikasi di luar izin yang terbuka di layar host (verifikasi via `CGWindowList`) dan respons menolak.
- Data penerima/isi email memakai alamat test milik pengguna; dilarang mengirim email sungguhan ke pihak luar — skenario komposisi berhenti sebelum tombol Send, atau memakai draf yang dibuang di akhir run.
- `quarantine: true` hanya untuk skenario flaky terkonfirmasi; skenario quarantine tidak menghitung ke gagal run tetapi tetap menghasilkan artifact.

## 5. Tiga Oracle Independen (sumber kebenaran, bukan laporan sistem)

1. **AXOracle** — kueri langsung Accessibility tree aplikasi target (`AXUIElementCopyAttributeValue`, role + labelHint + nilai). Ini kanal yang memutus kebohongan `isDone`: nilai Subject/Body dibaca dari aplikasi, bukan dari klaim loop.
2. **LogOracle** — segmentasi `~/Library/Logs/Izanotchy/clicky.log` dari timestamp mulai run hingga selesai. Predikat `expected.log` dievaluasi pada segmen itu saja. `requireIsDone: true` berarti wajib ada `TASK_VALIDATOR ... isDone=true` dan dilarang ada penanda penyimpangan tanpa validasi. `deliverableOnlyIfDone` adalah negative control inti: `isDone=false` + deliverable tersimpan = FAIL otomatis (bug ERR-108).
3. **VisualOracle** — capture akhir in-memory `CGWindowListCreateImage` pada Virtual Display (biner `/usr/sbin/screencapture` DILARANG — ERR-105), lalu asersi OCR berisi teks yang diharapkan.

Ketiga oracle dibaca SETELAH loop menyatakan selesai (atau timeout). Keputusan lulus/gagal adalah AND dari ketiganya plus `mustFailIf`.

## 6. Fail-Fix Loop (WAJIB — inti mandat pengguna)

1. Jalankan runner. Jika exit 0 dan seluruh oracle hijau, tugas selesai.
2. Jika gagal: GAGAL ITU ADALAH BUG SISTEM. Langkah wajib:
   - Root-cause di kode sistem dengan mengikuti `systematic-debugging`: baca segmen log artifact, inspeksi file terkait, konsultasi ERRORS.md agar tidak mengulang regresi.
   - Ajukan perbaikan ke pengguna memakai format ACC AGENTS.md (Root Cause / Solusi / Hasil yang Diharapkan / Tolong di-acc), lalu perbaiki KODE SISTEM.
   - Rebuild (`xcodebuild` exit 0), jalankan ulang runner penuh (bukan hanya skenario yang gagal, kecuali saat iterasi cepat dengan `--scenario`).
   - Ulangi sampai exit 0.
3. DILARANG KERAS test tailoring: mengubah oracle, expected state, atau memindahkan asersi agar run lulus. Satu-satunya pengecualian: expected terbukti faktual salah (misal typo pada nilai yang diharapkan) — perubahan wajib dicatat di CHANGELOG dengan alasannya.
4. Setiap iterasi meninggalkan artifact; artifact tidak boleh ditimpa run berikutnya (folder timestamp baru).
5. Keberagaman diagnosis: dua kegagalan berturut dengan akar berbeda wajib menghasilkan dua entri ERRORS.md berbeda, bukan satu entri gabungan.

## 7. Kebersihan Suite Lama

- `scripts/test_task041_zero_screencapture_and_legacy_event_tap_isolation.swift`: tetap hidup sebagai static lint (audit grep sumber), label "E2E" dicabut.
- `scripts/test_task042_halo_tanya_afm_stream.swift` dan `scripts/test_task043_connected_apps_sandbox_and_multitask_e2e.swift`: status "E2E" dicabut permanen (Delete-Zone ERR-108). Jika ingin mempertahankan cakupannya, tulis ulang sebagai unit/integration test yang mengimpor modul sistem nyata — dilarang kembali ke pola re-implementasi.
- Klaim verifikasi di CHANGELOG mulai kini wajib menyitir path artifact runner (`artifacts/<timestamp>/...`), bukan narasi manual.

## 8. Definition of Done

- [ ] `xcodebuild -project izaNotch.xcodeproj -scheme izaNotch -configuration Debug build` exit 0.
- [ ] `swift scripts/e2e/run_e2e.swift` exit 0, seluruh skenario non-quarantine lulus tiga oracle.
- [ ] Negative control teruji: satu run disengaja dengan `isDone=false` menghasilkan exit non-zero (dibuktikan artifact), lalu kondisi dikembalikan.
- [ ] Log runtime pasca-run tanpa `ScreenCaptureKit error` berulang (LogOracle membuktikannya).
- [ ] Tidak ada kode injeksi di luar `#if DEBUG`; `grep -r "iza.e2e" izaNotch/` hanya menyentuh file ber-gard DEBUG.
- [ ] `CHANGELOG.md` (milestone baru), `TASKS.md` (status TASK-044), `ERRORS.md` (bug sistem yang ditemukan runner) diperbarui.

## 9. Invariant Global yang Mengikat (dari AGENTS.md)

- Zero Hardcoding: dilarang if-else nama aplikasi, kamus judul jendela, koordinat statis, `/usr/sbin/screencapture`, `.cghidEventTap`/`.cgSessionEventTap` untuk virtual workspace.
- Zero Emojis pada seluruh kode, komentar, dan log.
- Protokol ACC: setiap perubahan kode sistem wajib persetujuan pengguna dengan format Root Cause / Solusi / Hasil yang Diharapkan.
- Cognitive Empathy: prompt ke model AFM tetap ramping; runner dilarang menyuntikkan data literal ke prompt sistem.
