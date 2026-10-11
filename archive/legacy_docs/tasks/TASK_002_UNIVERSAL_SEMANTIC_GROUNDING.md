# TASK-002: Grounding Universal Bebas Hardcoding

Dokumen spesifikasi detail untuk perbaikan resolusi target CUA secara universal tanpa kode spesifik aplikasi atau batasan koordinat buatan.

---

## 1. Latar Belakang & Masalah
- **Kondisi Saat Ini:**
  - Saat pengguna meminta "coba check email yang paling atas", perencana AFM menghasilkan target abstrak `"first item in list"`.
  - Mesin pencari Accessibility di [`ClickyHybridGroundingEngine.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/izaNotch/Clicky/CUA/Grounding/ClickyHybridGroundingEngine.swift) mencari elemen secara generik dan menemukan baris teratas dari sidebar navigasi kiri (`AXOutline`, "All Inboxes" di koordinat `0.083, 0.077`), bukan daftar email di kolom tengah.
  - Usulan sebelumnya untuk membatasi `X >= 0.18` atau memfilter `AXOutline` secara hardcoded ditolak karena melanggar etika **Zero App-Specific Code**.
- **Tujuan:**
  - Menyelesaikan penargetan elemen secara universal murni menggunakan informasi semantik yang nyata dari observasi layar.
  - Mengarahkan perencana agar menargetkan teks nyata hasil observasi (misal judul item `"UNIQLO Masterpiece"`) atau titik tengah bounding box item yang terdeteksi visual OCR, bukan frasa generik.

---

## 2. Rencana Implementasi
1. **Targeting Berbasis Teks Observasi Nyata:**
   - Lokasi: [`InspectStepPolicy.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/izaNotch/Clicky/Reasoning/Planner/Policies/InspectStepPolicy.swift).
   - Menginstruksikan perencana untuk menyertakan cuplikan teks nyata dari item yang diobservasi ke dalam `targetElement` (misalnya `"UNIQLO Masterpiece"`), bukan frasa generik seperti `"first item in list"`.
2. **Pencarian Teks Universal di AX UI Element:**
   - Mesin pencari AX di [`ClickyHybridGroundingEngine.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/izaNotch/Clicky/CUA/Grounding/ClickyHybridGroundingEngine.swift) mencari elemen yang memuat teks tersebut. Karena teks hanya ada pada baris item konten (bukan di folder sidebar), kursor secara otomatis dan universal membidik baris data yang tepat di aplikasi apa pun.
3. **Penyelarasan Koordinat Visual Bounding Box:**
   - Di [`CompanionVMAgentLoop.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/izaNotch/Clicky/CUA/Loop/CompanionVMAgentLoop.swift), saat kartu item pertama terdeteksi di observasi terstruktur (`listItems[0]`), koordinat visual bounding box-nya dapat digunakan sebagai jangkar referensi presisi.

---

## 3. Kriteria Keberhasilan (Verification Checklist)
- [x] Kursor mendarat di baris email pertama di kolom tengah, bukan di folder sidebar kiri.
- [x] Baris email pertama berhasil terseleksi dan konten email pertama terbuka di panel pembacaan.
- [x] Kode 100% bebas dari if-else nama aplikasi, filter koordinat statis, atau heuristik khusus satu aplikasi.
- [x] Kompilasi `xcodebuild` berhasil tanpa error (** BUILD SUCCEEDED **).
