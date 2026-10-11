# TASK-010: Pembersihan Total Hardcoding & Grounding Semantik Murni

## 1. Latar Belakang & Masalah
Setelah evaluasi ketat terhadap basis kode, ditemukan beberapa residu hardcoding dan heuristik manual:
1. `ClickyHybridGroundingEngine.swift`: Memuat kamus sinonim manual `semanticEquivalents` ("compose" <-> "new message", "kepada", "isi", "kirim") dan switch-case ordinal 1-5 di `extractListOrdinal`.
2. `CompanionVMAgentLoop.swift`: Memuat heuristik koordinat tetap `Toolbar Action Heuristic` (`x = width * 0.35, y = 40`) serta daftar kata kunci kontrol ("button", "compose", "field", "new", "search") untuk membedakan klik item vs kontrol.
3. `CompanionWindowStreamService.swift`: Memuat kamus judul jendela statis `primaryWorkspaceTokens` ("inbox", "kotak masuk", "all inboxes") dan daftar kata kunci kata sandi.
4. `TaskIngressGateway.swift`: Memuat pengecekan manual kata string `"kirim"` / `"send"`.
5. `HomeSpaceComputerCardView.swift`: Menyisakan variabel tak terpakai `isSafari`.

## 2. Tindakan Solusi yang Diterapkan
1. **Pembersihan Kamus Sinonim & Regex Ordinal Universal**:
   - Menghapus kamus sinonim manual `semanticEquivalents`.
   - Mengganti ekstraksi ordinal dengan regex universal `(?:item|row|index|baris|ke-?)\s*(\d+)` yang mendukung sembarang bilangan ordinal $N$ tanpa batas 1-5.
   - Grounding kontrol mengandalkan token matching langsung dan seleksi semantik model Laya Multilingual via `selectElement`.
2. **Eliminasi Heuristik Koordinat Tetap & Pemisahan Dinamis**:
   - Menghapus 100% heuristik koordinat tetap `Toolbar Action Heuristic` (`width * 0.35, y + 40`).
   - Menghapus daftar kata kunci string kontrol.
   - Membedakan klik baris item vs tombol kontrol secara dinamis: memeriksa apakah `targetElement` cocok dengan entri nyata pada `sessionObservedListItems`.
3. **Eliminasi Kamus Judul Jendela & Kata Sandi Statis**:
   - Menghapus kamus judul statis `primaryWorkspaceTokens` dan kamus kata sandi.
   - Pemeringkatan jendela kini mengandalkan urutan alami WindowServer dan penilaian token dinamis `targetEntity` dari kontrak kanonikal Ingress.
4. **Eliminasi Pencocokan Substring Manual Ingress**:
   - Menghapus pengecekan manual kata string `"kirim"` / `"send"`, murni percaya pada skema model (`direct.intentType.lowercased() == "send"`).
   - Menghapus variabel tak terpakai `isSafari`.

## 3. Bukti Verifikasi Empiris
1. Kompilasi: Clean build via `xcodebuild` berhasil dengan status exit code 0 (`** BUILD SUCCEEDED **`).
2. Proses Aktif: Proses `izaNotch` berjalan segar di PID 61466 bersama `IzaNotchXPCHelper` di PID 61492.
3. Test Suites:
   - `scripts/test_task010_complete_hardcode_purge.swift` lulus 100%.
   - `scripts/test_task009_section_grounding_and_no_fake_completion.swift` lulus 100%.
   - `scripts/test_task008_action_intent_grounding_and_daemon_lifecycle.swift` lulus 100%.
   - `scripts/test_task007_laya_integration.swift` lulus 100%.
4. Runtime Log: `~/Library/Logs/Izanotchy/clicky.log` bersih tanpa unhandled runtime exception.
