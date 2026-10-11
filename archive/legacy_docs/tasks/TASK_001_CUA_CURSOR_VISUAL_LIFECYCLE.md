# TASK-001: Kursor Visual CuaDriver & Siklus Hidup Efemeral

Dokumen spesifikasi detail untuk implementasi kursor maskot CUA di dalam kartu interaktif HomeSpace.

---

## 1. Latar Belakang & Masalah
- **Kondisi Saat Ini:**
  - Kursor di [`InteractiveVirtualDesktopView.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/izaNotch/Clicky/UI/Viewport/InteractiveVirtualDesktopView.swift) masih menggunakan bentuk panah klasik macOS 7-titik yang memiliki ekor diagonal (`stem`).
  - Warna kursor sebelumnya dipatok ke solid dark charcoal (`#111827`), bukan warna dinamis Buddy aktif (`buddyThemeColor`).
  - Kursor ditampilkan permanen di kanvas kartu, tidak meniru perilaku kursor `cua-driver` asli yang hanya muncul saat melakukan aksi (meluncur dan mengklik) lalu menghilang.
- **Tujuan:**
  - Mengubah bentuk kursor menjadi segitiga presisi tanpa ekor (*tailless triangle pointer*).
  - Menggunakan warna tema Buddy aktif (`buddyThemeColor`, misalnya oranye `#FF9800` untuk Inbox Buddy) dengan outline putih tegas `1.5pt`.
  - Mengaktifkan siklus hidup efemeral: kursor hanya terlihat selama fase gerak (`isReticleActive` / gliding) dan klik, kemudian memudar halus (*fade out*) saat aksi selesai.

---

## 2. Rencana Implementasi
1. **Bentuk Kursor Tanpa Ekor (`CursorArrowShape` / `CuaActionCursorTriangle`):**
   - Lokasi: [`InteractiveVirtualDesktopView.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/izaNotch/Clicky/UI/Viewport/InteractiveVirtualDesktopView.swift).
   - Mengubah path shape menjadi segitiga ramping dengan ujung tip di `(0, 0)` dan tanpa batang ekor diagonal.
2. **Warna Sesuai Buddy:**
   - Menggunakan parameter `buddyThemeColor` untuk mengisi shape kursor, dengan stroke luar berwarna putih `1.5pt` dan bayangan lembut untuk kontras tinggi.
3. **Siklus Hidup Efemeral (Opacity Transition):**
   - Menghubungkan opasitas kursor ke state aktivitas reticle maskot (`vdService.isClickingReticle || vdService.isReticleActive`).
   - Kursor beropasitas `1.0` saat sedang aktif bergerak atau mengklik, dan bertransisi halus ke `0.0` saat diam.

---

## 3. Kriteria Keberhasilan (Verification Checklist)
- [x] Kursor tidak memiliki ekor diagonal (berbentuk segitiga panah presisi).
- [x] Warna kursor otomatis sesuai dengan warna Buddy yang sedang aktif.
- [x] Kursor tidak terlihat statis saat idle; hanya muncul saat ada perintah pergerakan atau klik dari agent, lalu menghilang (dwell time ~1.0s).
- [x] Kompilasi `xcodebuild` berhasil tanpa error (** BUILD SUCCEEDED **).
