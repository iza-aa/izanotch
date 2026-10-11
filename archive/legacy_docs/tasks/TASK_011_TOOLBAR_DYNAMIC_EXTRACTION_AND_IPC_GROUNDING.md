# TASK-011: Ekstraksi Dinamis AXToolbar Universal & Dual-Layer IPC Click

## 1. Masalah & Gejala
Pengguna melaporkan bahwa saat mencoba mengirim email, agen gagal membuka jendela baru compose.
Berdasarkan investigasi mendalam terhadap log runtime dan perbandingan visual:
1. Tombol toolbar di macOS (seperti ikon SF Symbol "New Message" di Mail) merupakan ikon grafis murni tanpa teks tercetak. Vision OCR tidak mendeteksi teks apa pun pada tombol tersebut sehingga `topBar` observasi terstruktur kosong dari kontrol toolbar.
2. Prompt `ComposeStepPolicy` memuat contoh literal `(e.g. "compose button", ...)` yang menyebabkan model 3B mengalami few-shot overfitting menargetkan frasa buatan alih-alih kontrol nyata.
3. Koordinat fallback `Default Window Center` tidak dinormalisasi secara relatif sehingga terlempar ke tepi kanan layar (0.98, 0.537).
4. Jendela di layar virtual berstatus inactive di AppKit sehingga kontrol toolbar redup (*dimmed*) dan event mouse fisik `CGEvent.postToPid` diserap/diabaikan oleh WindowServer.

## 2. Solusi yang Diterapkan
1. **Dynamic AXToolbar Control Discovery**:
   - `CompanionVMAgentLoop.swift` kini memindai `AXToolbar` pada jendela aktif saat `readStructuredObservation`.
   - Mengambil label deskripsi Accessibility (`kAXDescriptionAttribute` / `kAXTitleAttribute`) dan koordinat fisik kontrol tombol/field.
   - Memasukkannya ke `topBarItems` dan `sessionObservedElements` dengan bounding box terisolasi.
2. **Pembersihan Prompt Planner**:
   - Menghapus seluruh contoh string buatan di `ComposeStepPolicy.swift`. Model diarahkan untuk menargetkan kontrol nyata yang terdaftar di `topBar`.
3. **Perbaikan Normalisasi Titik Tengah**:
   - Menyertakan `"Default Window Center"` dalam kalkulasi offset relatif jendela (`relX = rawX - targetWinBounds.origin.x`) menghasilkan tepat (0.50, 0.50).
4. **Dual-Layer IPC Click & Main Window State**:
   - `MascotVirtualDesktopService.swift` kini memicu `AXUIElementPerformAction(hitElem, kAXPressAction)` pada kontrol tombol (`AXButton`, `AXPopUpButton`) saat klik CUA dikirim.
   - Jendela kandidat disetel sebagai Main Window (`kAXMainAttribute = true`) saat pemindahan ke virtual desktop.

## 3. Bukti Verifikasi Empiris
1. Kompilasi: Clean build via `xcodebuild` berhasil dengan status exit code 0 (`** BUILD SUCCEEDED **`).
2. Proses Aktif: Proses `izaNotch` berjalan segar di PID 68486 bersama `IzaNotchXPCHelper` di PID 68508.
3. Test Suites:
   - `scripts/test_task011_toolbar_and_ipc_grounding.swift` lulus 100%.
   - Seluruh test regression (`test_task007` sampai `test_task011`) lulus 100%.
4. Log Runtime: `~/Library/Logs/Izanotchy/clicky.log` mencatat inisialisasi bersih tanpa unhandled runtime exceptions.
