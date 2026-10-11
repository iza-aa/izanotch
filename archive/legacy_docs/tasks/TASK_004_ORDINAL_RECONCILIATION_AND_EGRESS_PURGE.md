# TASK-004: Eliminasi Hardcoding Egress, Rekonsiliasi Ordinal Ingress, dan Pencegahan Repeated Click

## 1. Deskripsi Singkat
Menghapus seluruh daftar kata kunci hardcoded bahasa Indonesia dari `TaskEgressValidator.swift`, menambahkan rekonsiliasi deterministik angka ordinal eksplisit di `TaskIngressGateway.swift` (mencegah off-by-one arithmetic 10 menjadi 11), mengunci `requiresTakeoverOnCompletion = false` pada tugas inspeksi/baca, dan menambahkan guard pencegah loop klik berulang pada `CompanionVMAgentLoop.swift`.

## 2. Latar Belakang & Gejala Masalah
1. Ditemukan array kata kunci bahasa Indonesia (`contains("analisis")`, `contains("pemeriksaan")`, `hasPrefix("silakan")`, `negativeCritiquePhrases`) di `TaskEgressValidator.swift` yang melanggar direktif mutlak Zero Hardcoding.
2. Pada tugas `"coba check email ke 10"`, model on-device 3B mengalami off-by-one error dan menghasilkan `targetIndex: 11`, sehingga sistem salah mengklik email ke-11 (Chess.com) alih-alih email ke-10 (Emergent).
3. Model 3B menyetel `requiresTakeoverOnCompletion = true` pada tugas inspeksi, menyebabkan validator menahan penyelesaian (`effectiveIsDone = false`).
4. `CompanionVMAgentLoop` mengeksekusi 5x klik berulang pada target yang sama karena anti-spurious scroll guard memaksakan klik ulang meski target sudah terbuka.

## 3. Komponen yang Dimodifikasi
- `izaNotch/Clicky/Reasoning/Validator/TaskEgressValidator.swift`: Menghapus seluruh array kata kunci bahasa Indonesia dan menggantinya dengan fallback struktural murni (`isEmpty` dan non-empty `extractedData`).
- `izaNotch/Clicky/Reasoning/Ingress/Policies/IngressPolicy.swift`: Mempertegas instruksi bahwa `requiresTakeoverOnCompletion` mutlak `false` untuk tugas inspeksi dan targetIndex wajib sama dengan angka eksplisit pengguna.
- `izaNotch/Clicky/Reasoning/Ingress/TaskIngressGateway.swift`: Menambahkan `reconcileTargetIndex` universal berbasis digit prompt dan mengunci `requiresTakeover = false` untuk tugas `inspect`/`read`.
- `izaNotch/Clicky/CUA/Loop/CompanionVMAgentLoop.swift`: Menambahkan pengecekan `hasAlreadyClickedTarget` pada Anti-Spurious Scroll Guard sehingga jika target sudah pernah diklik dan preview pane termuat, sistem menyelesaikan langkah ke validasi tanpa klik berulang.

## 4. Checklist Verifikasi
- [x] Skrip uji otomasi `scripts/test_taskS_ordinal_and_takeover_guards.swift` lulus 100%.
- [x] Seluruh 7 runner pengujian `scripts/test_task*.swift` lulus 100%.
- [x] Kompilasi bersih `xcodebuild` berhasil tanpa error (`** BUILD SUCCEEDED **`).
- [x] Biner baru aktif berjalan di PID 84158 (IzaNotchXPCHelper di PID 84175).
- [x] Log runtime bersih tanpa exception (`~/Library/Logs/Izanotchy/clicky.log`).
- [x] Zero Emojis Policy terverifikasi di semua berkas dan teks respons.
