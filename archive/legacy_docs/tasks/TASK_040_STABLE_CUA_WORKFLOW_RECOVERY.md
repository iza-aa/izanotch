# TASK-040: Stable CUA Workflow Recovery & Zero-Flicker Execution

Dokumen ini adalah rencana teknis komprehensif untuk menuntaskan seluruh masalah eksekusi CUA yang berulang selama 1 hari terakhir, mengintegrasikan pelajaran dari `ERRORS.md` (ERR-092 hingga ERR-104) dan `CHANGELOG.md`.

---

## 1. Analisis Masalah Faktual & Gejala Kegagalan

Berdasarkan pengujian langsung dan log runtime `clicky.log`, sistem mengalami 5 gejala kegagalan yang saling terkait:

1. **Layar Mac Berkedip / Freeze Berulang-Ulang:**
   - **Gejala:** Setiap 0.8 detik layar monitor pengguna berkedip/freeze sesaat saat asisten beroperasi.
   - **Penyebab Faktual:** `CompanionWindowStreamService.swift` memiliki fallback Method B yang mengeksekusi biner eksternal `/usr/sbin/screencapture -x -l <windowID>` berulang kali. Di macOS, proses ini membekukan frame WindowServer untuk mengambil screenshot.

2. **Jendela Tergeser ke Kiri-Atas dengan Area Hitam Lebar:**
   - **Gejala:** Tampilan aplikasi Mail di kartu chat HomeSpace tampak kecil di pojok kiri-atas, dengan area hitam kosong lebar (~660 pt di kanan dan ~280 pt di bawah).
   - **Penyebab Faktual:** Virtual Display dialokasikan 1920×1080 pt, tetapi jendela Mail diposisikan dengan offset statis 1260×800 pt tanpa mengisi kanvas secara proporsional.

3. **Kursor Fisik Pengguna Melompat / Ter-Warp ke Kanan Layar:**
   - **Gejala:** Saat agen mengeklik elemen di ruang virtual, kursor mouse fisik pengguna di layar Mac tiba-tiba tersentak dan melompat ke tepi kanan layar.
   - **Penyebab Faktual:** `MascotVirtualDesktopService.swift` memiliki fallback `post(tap: .cgSessionEventTap)` saat PID bernilai nil, dan `glideReticleTo` mem-posting 18 event `mouseMoved` per aksi ke WindowServer global pada koordinat virtual display (X >= 1552).

4. **Teks Email Masuk ke Badan Pesan, Bukan ke Kolom "To:":**
   - **Gejala:** Alamat penerima `rezkyhaikal10@gmail.com` berhasil terketik, tetapi masuk ke isi/badan email, sedangkan kolom "To:" tetap kosong.
   - **Penyebab Faktual:** Klik fisik pada "To:" tidak memindahkan keyboard focus native (`kAXFocusedAttribute`) ke elemen input teks penerima, sehingga kursor keyboard tetap berada di default jendela (area body).

5. **Tombol Toolbar ("New Message") Harus Diklik 5 Kali Baru Terbuka, atau Malah Mengeklik Toggle Sidebar:**
   - **Gejala:** Agen berkali-kali mencoba mengeklik "New Message" tapi gagal (baru berhasil di langkah ke-5). Pada perintah "coba klik all inboxes di sidebar", agen malah mengeklik tombol penutup sidebar.
   - **Penyebab Faktual:**
     - Elemen yang diklik adalah label teks anak (`AXStaticText`). Di AppKit macOS, `kAXPressAction` pada teks statis diabaikan.
     - Penargetan container umum ("sidebar") mengenai tombol "Toggle Sidebar" di toolbar alih-alih item mailbox "All Inboxes" di panel navigasi.

---

## 2. Rencana Eksekusi Bertahap (4 Fase Terukur)

### Fase 1: Kestabilan Streaming Layar & Eliminasi Total Kedipan (Zero Flicker)
- **Tindakan:**
  1. Hapus 100% seluruh pemanggilan subprocess `/usr/sbin/screencapture` di seluruh berkas (`CompanionWindowStreamService.swift` dan `MascotVirtualDesktopService.swift`).
  2. Gunakan murni in-memory Quartz API: `CGWindowListCreateImage` dan `CGDisplayCreateImage(displayID)`.
  3. Setel dimensi jendela Mail secara dinamis (`targetX2 = originX + dW - 20`, `targetY2 = originY + dH - 20`) agar mengisi kanvas Virtual Display secara simetris, melenyapkan area hitam di kanan dan bawah.
- **Kriteria Keberhasilan:** Layar Mac 100% tenang tanpa kedipan, dan tampilan Mail di HomeSpace terpusat rapi tanpa ruang hitam kosong.

### Fase 2: Kedaulatan Kursor & Isolasi Host Penuh (Zero Host Screen Intrusion)
- **Tindakan:**
  1. Hapus seluruh panggilan `.cgSessionEventTap` dan `.cghidEventTap` di seluruh aksi CUA (`performCuaMove`, `performCuaLeftClick`, `performCuaRightClick`, `performCuaScroll`, `performCuaPressAndHold`, `performCuaDrag`).
  2. Ubah `glideReticleTo` agar murni menggerakkan kursor visual di layer SwiftUI kanvas (`self.virtualReticle = currentNorm`), dilarang mengirim event `mouseMoved` ke sistem operasi.
  3. Semua event mouse dan keyboard wajib dikirim langsung ke target PID via `postToPid(pid)`.
- **Kriteria Keberhasilan:** Kursor fisik mouse pengguna 100% diam di tempatnya saat asisten beroperasi di virtual display.

### Fase 3: Presisi Grounding & Fokus Keyboard (Input Text & Button Traversal)
- **Tindakan:**
  1. Di `CUAClickActionTool.swift`: Jika elemen di koordinat klik bertipe `AXStaticText` atau `AXImage`, sistem wajib menelusuri hierarki ke atas (`kAXParentAttribute`) untuk menemukan dan mengeklik `AXButton` induknya.
  2. Di `CUATypeActionTool.swift`: Saat mengeklik input field, wajib mengeksekusi `AXUIElementSetAttributeValue(curr, kAXFocusedAttribute as CFString, kCFBooleanTrue)` untuk mengunci keyboard focus ke kolom input ("To:", "Subject:") sebelum pengetikan dimulai.
  3. Di `StepPolicyRegistry.swift` & `InspectStepPolicy.swift`: Tegaskan aturan bahwa penargetan navigasi wajib menargetkan nama item spesifik ("All Inboxes", "Notes", "Trash"), dilarang menargetkan nama kontainer ("sidebar", "toolbar").
- **Kriteria Keberhasilan:** Tombol "New Message" terbuka pada klik pertama; teks alamat `rezkyhaikal10@gmail.com` masuk tepat 100% ke dalam kolom "To:"; perintah navigasi sidebar mengeklik baris mailbox "All Inboxes".

### Fase 4: Penanganan Modal Dialog & Lifecycle Teardown (Zero Loop & Clean Workspace)
- **Tindakan:**
  1. Di `CompanionVMAgentLoop.swift`: Tempatkan penanganan modal alert (`obsService.latestHasModalOrError == true`) sebagai Prioritas 1. Jika muncul dialog seperti *"Unable to Load Window"* atau *"Save this message as a draft?"*, agen langsung melokalisasi tombol konfirmasi (`[OK]`, `[Don't Save]`, `[Close]`) dan mengekliknya secara fisik via CUA untuk membersihkan jendela.
  2. Kunci `isFormActive` agar mutlak `false` pada tugas inspeksi/baca (`inspect`/`read`), mencegah perencana keliru memilih aksi kirim pesan.
  3. Di `MascotVirtualDesktopService.swift`: Tutup seluruh jendela draf/balasan sementara sebelum virtual display dimatikan (`close (every window whose name contains "New Message" or name contains "Re:") saving no`), mencegah jendela tertinggal di layar pengguna.
- **Kriteria Keberhasilan:** Dialog ditutup secara alami oleh CUA kursor; tidak ada looping klik; tidak ada jendela yang tertinggal di layar kerja pengguna saat sesi berakhir.

---

## 3. Matriks Verifikasi Empiris
1. Uji unit regresi menyeluruh (Task 018 hingga Task 039) lulus 100%.
2. Kompilasi bersih via `xcodebuild` (exit code 0).
3. Verifikasi runtime 4 skenario pengguna:
   - Skenario 1: `"Halo"` -> Jawaban percakapan instan tanpa membuka aplikasi.
   - Skenario 2: `"check email saya"` -> Membuka dan membaca email 1.
   - Skenario 3: `"coba klik all inboxes di sidebar"` -> Mengeklik baris "All Inboxes" di panel navigasi.
   - Skenario 4: `"kirim email ke rezkyhaikal10@gmail.com bahwa sistem berhasil dibuat"` -> Membuka draf, mengetik To, Subject, Body secara presisi, dan mengirim hingga selesai tanpa kedipan layar dan tanpa kebocoran jendela ke desktop host.
