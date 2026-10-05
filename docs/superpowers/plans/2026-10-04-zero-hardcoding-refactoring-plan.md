# 🛠️ Rencana Kerja: Refaktorisasi Zero Hardcoding, Kursor Fisik CUA Murni, & Siklus See-Plan-Act

> **Status:** Siap Dieksekusi  
> **Target:** Menghapus seluruh residu hardcoding, menghapus trik shortcut per-aplikasi, menerapkan tangan kursor fisik murni (klik kiri, klik kanan 2 jari, scroll, tekan, drag, ketik) yang selalu stay & ready, serta menegakkan siklus otonom **See ➔ Plan ➔ Act**.

---

## 🔍 1. Analisis Akar Masalah & Celah Regulasi

1. **Shortcut Cheat Workaround vs Kursor Fisik**:
   - Sebelumnya sempat terpikirkan menggunakan shortcut keyboard (`⌘↑` / Home) untuk mengatasi posisi scroll daftar email/aplikasi yang tertinggal di bawah.
   - **Evaluasi Kritis Pengguna**: Memberikan ilmu shortcut per-aplikasi membuat arah pengujian tidak jelas dan rapuh saat berpindah aplikasi. Asisten harus bekerja layaknya manusia: memiliki tangan fisik universal (mouse kursor dan ketikan), dan AI model yang melihat layar lalu memutuskan apakah harus scroll, klik, atau ketik.
2. **Kursor CUA Hilang-Timbul vs "Always Stay & Ready"**:
   - `cua-driver` bawaan hanya menampilkan overlay kursor saat ada aksi dipanggil.
   - Di antarmuka isolated workspace (`InteractiveVirtualDesktopView`), pengguna menginginkan kursor maskot **selalu standby di kanvas** (stay & ready), meluncur halus (*glide*) dari posisinya ke target, memberikan feedback visual nyata. Saat user takeover, kursor AI disembunyikan 100% dan kursor fisik pengguna berdaulat mutlak.
3. **Siklus "See ➔ Plan ➔ Act"**:
   - Pada loop sebelumnya, asisten bisa merencanakan langkah sebelum mengamati kondisi layar terkini (atau hanya memakai ringkasan teks histori sebelumnya).
   - Prinsip mutlak: **Pengguna memberi instruksi ➔ Asisten melihat layar (See) ➔ AI merencanakan langkah (Plan) ➔ Asisten mengeksekusi aksi kursor fisik (Act) ➔ Asisten melihat kembali hasil perubahannya (See)**.
4. **Residu Hardcoding Terhadap 1 Aplikasi (Mail.app)**:
   - AppleScript snap-to-top Mail di `MascotVirtualDesktopService.swift:247`.
   - Resolusi path statis `if clean == "mail"` di `CompanionWindowStreamService.swift:288`.
   - Pencocokan nama proses `cleanTarget == "mail"` di `CompanionWindowStreamService.swift:373`.
   - Legacy AppleScript `MailWorkflowOperationTool` di `ClickyFunctionTool.swift:246` & `ClickyFunctionToolRegistry.swift:21`.
   - Dock statis (hanya tombol Mail dan Safari) di `HomeSpaceInteractiveComputerModalView.swift:15, 324`.
   - Fallback literal `?? "Mail"` di berbagai view.
   - Prompt instruksi di `TaskStepPlanner.swift:40` yang secara spesifik menyebut logika Mail.

---

## 📋 2. Rencana Tindakan Bedah (Surgical Refactoring Plan)

### Task 1: Bangun Tangan Kursor Fisik Universal & Persistent Cursor di `MascotVirtualDesktopService.swift`
- **File:** `boringNotch/Clicky/Tools/MascotVirtualDesktopService.swift`
- **Tindakan:**
  1. Hapus seluruh blok AppleScript snap-to-top Mail (`if appName.lowercased() == "mail"` lines 247–282).
  2. Jadikan kursor persisten:
     - Ganti `@Published public var virtualReticle: CGPoint? = nil` menjadi `@Published public var virtualReticle: CGPoint = CGPoint(x: 0.5, y: 0.5)`. Kursor selalu ada di kanvas (stay & ready).
  3. Implementasikan fungsi-fungsi primitif tangan mouse CUA universal:
     - `performCuaMove(normalizedPoint: CGPoint)`: Gliding kursor ke koordinat target.
     - `performCuaLeftClick(normalizedPoint: CGPoint)`: Klik kiri standar dengan pulse ring.
     - `performCuaRightClick(normalizedPoint: CGPoint)`: Klik kanan / 2-finger click macOS (`mouseButton: .right`).
     - `performCuaScroll(normalizedPoint: CGPoint, deltaY: Int32, deltaX: Int32)`: Scroll roda mouse / 2-finger swipe via `CGEvent(scrollWheelEvent2Source:nil, units:.pixel, wheelCount:2, wheel1:deltaY, wheel2:deltaX, wheel3:0)`.
     - `performCuaPressAndHold(normalizedPoint: CGPoint, durationMs: Int)`: Tekan dan tahan (`leftMouseDown`, delay, `leftMouseUp`).
     - `performCuaDrag(from: CGPoint, to: CGPoint)`: Klik dan geser (drag & drop) dengan interpolasi lintasan.
     - `performCuaType(text: String)`: Ketik teks virtual ke PID.

### Task 2: Implementasi Siklus Murni "See ➔ Plan ➔ Act" di `CompanionVMAgentLoop.swift`
- **File:** `boringNotch/Clicky/Tools/CompanionVMAgentLoop.swift`
- **Tindakan:**
  1. Pada setiap langkah (step 1 s/d maxSteps):
     - **SEE (Lihat Layar Dulu):** Tangkap snapshot layar terkini (`captureTargetWindowAsync`) dan ekstrak observasi terstruktur (`readStructuredObservation`) dari frame tersebut SEBELUM memanggil planner. Jangan pernah merencanakan aksi dari histori buta.
     - **PLAN (Model AI Menentukan Aksi):** Kirimkan observasi visual nyata ke AFM/model. Model memutuskan aksi generik: `click`, `right_click`, `scroll_up`, `scroll_down`, `press_and_hold`, `drag`, `type`, atau `done`.
     - **ACT (Eksekusi Kursor Fisik):**
       - Ground target koordinat (x, y) menggunakan `AXUIElement` (sebagai sensor koordinat) atau Luna Vision.
       - Geser kursor maskot secara halus ke koordinat target (`virtualReticle = targetPoint`).
       - Jalankan aksi tangan fisik yang dipilih model (`performCuaLeftClick`, `performCuaRightClick`, `performCuaScroll`, `performCuaType`, dll.).
     - **SEE LAGI (Validasi Perubahan):** Tangkap frame baru dan baca observasi untuk memvalidasi apakah tujuan tercapai.

### Task 3: Sinkronisasi Kursor "Always Stay & Ready" di `InteractiveVirtualDesktopView.swift`
- **File:** `boringNotch/Clicky/Tools/InteractiveVirtualDesktopView.swift`
- **Tindakan:**
  1. Pastikan `MascotAgentCursorView` dirender terus-menerus selama `!isInteractive`:
     - Menampilkan kursor panah macOS dengan cyan glow `#38BDF8` pada posisi `vdService.virtualReticle`.
     - Menghapus logika yang menyembunyikan kursor saat diam. Kursor tetap diam di posisi terakhir dan siap beraksi (*stay and ready*).
  2. Saat Human Takeover (`isInteractive == true`):
     - Kursor AI disembunyikan total (`virtualReticle` tidak dirender).
     - Kursor fisik pengguna mengambil alih kanvas secara berdaulat.

### Task 4: Resolusi Path Universal via NSWorkspace (Hapus Hardcoded Paths)
- **File:** `boringNotch/Clicky/Tools/CompanionWindowStreamService.swift`
- **Tindakan:**
  1. Hapus percabangan `if clean.lowercased() == "mail"` dan `else if clean.lowercased() == "safari"`.
  2. Gunakan `NSWorkspace.shared.urlForApplication` dan `InstalledAppsDiscoveryService.shared.findAppURL`:
     ```swift
     let workspace = NSWorkspace.shared
     if let appURL = workspace.urlForApplication(withBundleIdentifier: "com.apple.\(clean)") ??
                     InstalledAppsDiscoveryService.shared.findAppURL(appName: clean) {
         appPath = appURL.path
     }
     ```
  3. Buka aplikasi apapun secara universal tanpa `if-else` nama aplikasi.

### Task 5: Universal Process & Window Matching
- **File:** `boringNotch/Clicky/Tools/CompanionWindowStreamService.swift`
- **Tindakan:**
  1. Hapus `(cleanTarget == "mail" && ownerName.contains("mail"))`.
  2. Gunakan pencocokan nama proses universal:
     ```swift
     let matchesApp = ownerName == cleanTarget ||
                      ownerName.hasPrefix(cleanTarget) ||
                      ownerName.contains(cleanTarget)
     ```

### Task 6: Hapus Dead Code `MailWorkflowOperationTool`
- **Files:** `boringNotch/Clicky/Tools/ClickyFunctionTool.swift`, `ClickyFunctionToolRegistry.swift`
- **Tindakan:**
  1. Hapus definisi `MailWorkflowOperationTool` yang berisi hardcoded AppleScript Mail.
  2. Hapus registrasi `MailWorkflowOperationTool` di `ClickyFunctionToolRegistry`.
  3. Seluruh interaksi aplikasi berjalan murni melalui CUA loop otonom.

### Task 7: Dynamic Connected Apps Dock di Modal Takeover
- **File:** `boringNotch/Clicky/HomeSpace/HomeSpaceInteractiveComputerModalView.swift`
- **Tindakan:**
  1. Ganti dock statis dengan perulangan `ForEach` terhadap `companion.activeBuddy.workflowAppNames`:
     ```swift
     let connectedApps = companion.activeBuddy.workflowAppNames
     ForEach(connectedApps, id: \.self) { appName in
         dockAppButton(appName: appName)
     }
     ```
  2. Ganti state `selectedDockApp` agar default ke aplikasi aktif atau `workflowAppNames.first`.

### Task 8: Generalisasi Prompt Instruksi di `TaskStepPlanner.swift`
- **File:** `boringNotch/Clicky/Tools/TaskStepPlanner.swift`
- **Tindakan:**
  1. Hapus kalimat instruksi khusus yang menyebut Mail atau All Inboxes (`When inspecting: if a compose or draft window is open...`).
  2. Ganti dengan panduan aksi kanonikal universal:
     - Available actions: `click`, `right_click`, `scroll_up`, `scroll_down`, `press_and_hold`, `drag`, `type`, `done`.
     - Aturan navigasi: Amati observasi layar (topBar, sidebar, listItems, previewPane). Jika item belum terlihat atau daftar perlu digeser, gunakan `scroll_up` atau `scroll_down`. Jika perlu berinteraksi dengan elemen, gunakan `click` atau `type`.

### Task 9: Eliminasi Fallback Literal String `?? "Mail"`
- **Files:** Berbagai file yang memuat `?? "Mail"`
- **Tindakan:**
  1. Ganti seluruh fallback kaku `?? "Mail"` dengan membaca aplikasi terhubung pertama dari persona:
     `payload.targetAppName ?? companion.activeBuddy.workflowAppNames.first ?? "Workspace"`.

---

## 🛡️ 3. Rencana Verifikasi & Bukti Empiris

1. **Kompilasi Bersih**: `xcodebuild -scheme boringNotch build` berakhir dengan exit code 0.
2. **Proses Hidup**: Restart binary dan verifikasi PID baru aktif via `ps aux`.
3. **Log & Sinyal CUA**: Periksa `clicky.log` untuk memastikan event kursor (`performCuaLeftClick`, `performCuaScroll`, `performCuaRightClick`) terpanggil tanpa error.
4. **Verifikasi Visual Kursor**: Kursor maskot selalu tampak di viewport kanvas dan meluncur mulus saat beraksi; kursor AI hilang saat takeover.
5. **Update Dokumentasi**: Perbarui `CHANGELOG.md` dan `ERRORS.md`.
