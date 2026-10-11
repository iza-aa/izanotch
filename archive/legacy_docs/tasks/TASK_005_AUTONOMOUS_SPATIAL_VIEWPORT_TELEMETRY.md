# TASK-005: Autonomous Spatial Viewport Telemetry & Model-Driven Scroll-Up (Pendekatan A)

## Metadata
- **Status:** Selesai
- **Dimulai:** 2026-10-09
- **Selesai:** 2026-10-09
- **Tujuan:** Memberikan affordance spasial nyata (`viewport.isAtTop`) kepada model 3B agar model dapat secara mandiri mendeteksi viewport yang ter-scroll dan merencanakan tindakan `scroll_up` tanpa manipulasi runtime tersembunyi (Clean Workspace Anchor tanpa invisible cheat).

---

## 1. Masalah & Latar Belakang (Root Cause)
- Ketika aplikasi (seperti Mail atau Notes) ditinggalkan pengguna dalam keadaan ter-scroll (misal indeks 11-20), pipeline observasi sebelumnya secara membabi buta menetapkan indeks 1..10 pada kartu yang terlihat di Step 1 karena `previousItems.isEmpty`.
- Model 3B menderita anchoring bias: ia mengira kartu teratas yang terlihat adalah email nomor 1 karena model tidak memiliki affordance sensorik untuk melihat posisi thumb scrollbar.
- Jika pengguna meminta "email terbaru" atau email ordinal tertentu, Anti-Spurious Scroll Guard salah mengira item target sudah ada di layar, memblokir scroll, dan langsung mengeklik kartu yang salah.
- Reset scroll otomatis diam-diam di level runtime (Pendekatan B) melanggar visi agen otonom jika dilakukan tanpa sepengetahuan model.

---

## 2. Solusi Arsitektur (Pendekatan A - Otonomi Berbasis Fakta Spasial)
1. **Deteksi Telemetri Spasial Universal (`CUAScrollActionTool.getScrollState`):**
   Membaca atribut `kAXValueAttribute` dari `AXVerticalScrollBar` via Accessibility IPC. Mengembalikan status `isAtTop: Bool` (`value <= 0.05` atau tidak ada scrollbar) dan `scrollValue: Float?`.
2. **Injeksi Fakta Spasial ke Observasi (`readStructuredObservation`):**
   Menyertakan field `"viewport": {"isAtTop": true/false}` ke dalam representasi JSON terstruktur.
3. **Penomoran Kartu yang Sadar Viewport (`resolveCardIndices`):**
   Jika `previousItems` kosong dan `isAtTop == false`, kartu tidak diasumsikan sebagai indeks 1..N dari puncak, melainkan ditandai sebagai unanchored/offset sehingga target index 1 tidak muncul secara keliru.
4. **Penalaran Spasial di Planner (`InspectStepPolicy`):**
   Menambahkan aturan eksplisit bagi AFM Planner: jika target adalah item terbaru (index 1) dan `viewport.isAtTop == false`, model wajib merencanakan `actionType: "scroll_up"`, `targetElement: "item list"`, `subGoal: "Scroll up to reach top of list"`.
5. **Guard Awareness di Agent Loop (`CompanionVMAgentLoop`):**
   Anti-Spurious Scroll Guard tidak memblokir `scroll_up` jika `isAtTop == false`, mengizinkan model bergerak ke atas secara otonom.

---

## 3. Rencana Pengujian (TDD Verification)
- Buat skrip verifikasi otomatis `scripts/test_taskT_spatial_viewport_telemetry.swift`:
  1. Memverifikasi implementasi `getScrollState` pada `CUAScrollActionTool`.
  2. Memverifikasi injeksi `viewport` ke dalam observasi di `CompanionVMAgentLoop`.
  3. Memverifikasi aturan penalaran spasial di `InspectStepPolicy`.
  4. Memverifikasi izin scroll-up saat `isAtTop == false` di `CompanionVMAgentLoop`.
- Jalankan seluruh rangkaian skrip pengujian `scripts/test_task*.swift`.
- Kompilasi `xcodebuild` bersih (exit code 0).
- Verifikasi biner berjalan dan log bersih.

---

## 4. Bukti Hasil Verifikasi (Verification Evidence)
1. **Runner Pengujian Otomatis:**
   - `scripts/test_taskT_spatial_viewport_telemetry.swift`: Lulus 4/4 assertions (100%).
   - Seluruh 8 runner pengujian `scripts/test_task*.swift`: Lulus 42/42 assertions (100%).
2. **Kompilasi Bersih:**
   - `xcodebuild -project izaNotch.xcodeproj -scheme izaNotch -configuration Debug build`: Exit code 0 (`** BUILD SUCCEEDED **`).
3. **Proses Aktif:**
   - `izaNotch` aktif berjalan di PID 86937 (`IzaNotchXPCHelper` PID 86955, daemon Siri AI PID 86946).
4. **Log Runtime Bersih:**
   - `~/Library/Logs/Izanotchy/clicky.log`: Initialized cleanly, all permissions OK, zero unhandled exceptions.

