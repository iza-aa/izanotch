# TASK-006: Universal UI Container Navigation & Zero Hardcoding Ingress

## Metadata
- **Status:** Selesai
- **Dimulai:** 2026-10-09
- **Selesai:** 2026-10-09
- **Tujuan:** Menghapus seluruh asumsi hardcoded layout 3-kolom statis dan injeksi buta targetIndex = 1, menggantikannya dengan abstraksi navigasi kontainer UI universal berbasis semantik murni tanpa kamus kata kunci.

---

## 1. Masalah & Latar Belakang (Root Cause)
1. **Injeksi Buta targetIndex = 1 (`TaskIngressGateway.swift` & `TaskStepPlanner.swift`):**
   Setiap kali intent adalah `inspect` dan tidak ada digit angka, sistem secara otomatis memaksa `targetIndex = 1`. Ini membajak perintah pengguna yang sebenarnya menargetkan wadah/folder/kategori (seperti "coba check junk mail", "buka folder invoices", "cek tab pull requests") menjadi sekadar "klik baris 1 di daftar aktif saat ini".
2. **Partisi Koordinat Spasial Statis (`CompanionVMAgentLoop.swift`):**
   Pengelompokan OCR saat ini menggunakan rasio persentase lebar layar tetap (`maxX <= 0.17` untuk sidebar, `0.16...0.55` untuk list, dan `>= 0.55` untuk preview). Ini adalah asumsi kaku tata letak Apple Mail yang rusak pada aplikasi 1-kolom atau 2-kolom (Finder, Notes, Slack, Safari, Settings).
3. **Ketiadaan Penalaran Navigasi Wadah (`InspectStepPolicy.swift`):**
   Aturan inspeksi saat ini mendikte bahwa aksi pertama selalu mengeklik item baris di `listItems`, mengabaikan bahwa pengguna mungkin menginginkan kontainer data yang berbeda dari yang sedang aktif di layar.

---

## 2. Definisi Zero Hardcoding vs Lexical Cheat
- **Yang Termasuk Hardcoding (DILARANG KERAS):**
  - Menulis kamus kata kunci di Swift (misal: `let keywords = ["junk", "drafts", "sent", "trash", "inbox"]`).
  - Menulis contoh kata benda nyata di prompt LLM (misal: "Extract folders like Junk or Drafts").
  - Menulis percabangan khusus per-aplikasi (misal: `if appName == "Mail"`).
- **Pendekatan Universal Sejati (Zero Hardcoding):**
  - **Dynamic Slot Extraction:** Ingress prompt hanya mendefinisikan placeholder abstrak:
    `targetContainer`: string atau null, yaitu *frasa wadah/kategori/seksi/folder navigasi spesifik yang diminta pengguna, jika ada*. Model ekstraksi teks bebas yang mengisi slot ini secara dinamis dari bahasa apa pun.
  - **Dynamic Topology Observation:** Observasi UI mengekspos elemen-elemen navigasi yang nyata terdeteksi di antarmuka (`navigationElements`) dari Accessibility API native (`AXOutline`, `AXSplitView`, atau area navigasi aktif), bukan dari potongan persentase rasio koordinat statis.
  - **Two-Tier Model Reasoning:** Model membandingkan: jika `targetContainer` terisi dan terdapat elemen di `navigationElements` yang cocok secara semantik serta belum aktif, model merencanakan aksi `click` pada elemen navigasi tersebut terlebih dahulu. Jika sudah sesuai, model melanjutkan ke inspeksi konten.

---

## 3. Rencana Implementasi Bertahap

### Tahap 1: Ingress Contract & Schema Refactor (Zero Hardcoding)
- Perbarui `TaskIngressGateway.swift` dan `IngressPolicy.swift`:
  - Hapus fallback `resolvedIndex = 1` otomatis jika ada indikasi entitas wadah/kategori.
  - Tambahkan field kontrak `targetContainer: String?` secara generik pada `AFMTaskDecomposition`.
  - Pastikan prompt bebas dari contoh kata benda spesifik (Zero Exemplars).

### Tahap 2: Dynamic Observation Surface
- Perbarui `CompanionVMAgentLoop.swift`:
  - Hapus pembagian rasio koordinat kaku (`0.17`, `0.55`).
  - Gunakan deteksi kontainer dinamis berbasis peran native Accessibility (`AXOutline` / area kontrol navigasi vs `AXTable` / data list vs preview pane).
  - Sertakan `navigationElements: [String]` yang berisi label elemen navigasi nyata yang tampak di layar.

### Tahap 3: Universal Two-Tier Step Policy
- Perbarui `InspectStepPolicy.swift`:
  - Jika `targetContainer` terisi dan cocok dengan salah satu entitas di `navigationElements` yang belum aktif: model merencanakan `click` pada elemen navigasi tersebut.
  - Jika kontainer sudah aktif atau `targetContainer` tidak dispesifikasikan: model merencanakan inspeksi item di daftar.

---

## 4. Rencana Pengujian (TDD Verification)
1. Buat skrip verifikasi unit `scripts/test_taskU_universal_container_navigation.swift`:
   - Memverifikasi dekomposisi ingress tidak memaksakan `targetIndex = 1` saat pengguna menyebutkan wadah.
   - Memverifikasi bahwa ekstraksi `targetContainer` murni dinamis tanpa kamus kata kunci.
   - Memverifikasi `InspectStepPolicy` menghasilkan rencana klik navigasi kontainer ketika wadah belum aktif.
2. Jalankan seluruh rangkaian skrip pengujian `scripts/test_task*.swift` untuk mencegah regresi.
3. Kompilasi bersih dengan `xcodebuild` (exit code 0).
4. Verifikasi biner berjalan aktif via `ps aux`.
5. Verifikasi log runtime `~/Library/Logs/Izanotchy/clicky.log` bebas dari unhandled exception.

---

## 5. Bukti Hasil Verifikasi (Verification Evidence)
1. **Runner Pengujian Otomatis:**
   - `scripts/test_taskU_universal_container_navigation.swift`: Lulus 15/15 assertions (100%).
   - Seluruh 9 suite pengujian `scripts/test_task*.swift`: Lulus 58/58 assertions (100%).
2. **Kompilasi Bersih:**
   - `xcodebuild -project izaNotch.xcodeproj -scheme izaNotch -configuration Debug build`: Exit code 0 (`** BUILD SUCCEEDED **`).
3. **Proses Aktif Terverifikasi:**
   - `izaNotch` PID 94231 aktif berjalan (`IzaNotchXPCHelper` PID 94249, daemon Siri AI PID 94237).
4. **Log Runtime Bersih:**
   - `~/Library/Logs/Izanotchy/clicky.log`: Initialized cleanly, all permissions OK, zero unhandled exceptions.
