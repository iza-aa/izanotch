# ERRORS.md — Ledger Kesalahan & Invariant Pencegahan Bug

<!-- Dokumen Wajib: Single Source of Truth untuk semua kesalahan masa lalu, root cause, dan invariant agar tidak diulangi kembali. Terhubung langsung dengan AGENTS.md. -->

---

## 🛑 Protokol Penggunaan ERRORS.md (Wajib bagi Agent)

1. **Baca Sebelum Bertindak**: Sebelum mengajukan solusi atau mengubah kode pada suatu fitur, Agent **WAJIB** memeriksa entri terkait di `ERRORS.md` agar pendekatan yang diambil tidak mengulangi kesalahan yang sama.
2. **Catat Setiap Bug Baru**: Setiap kali menemukan atau memperbaiki bug baru, Agent **WAJIB** menambahkan entri baru ke dokumen ini dengan format baku:
   - **Fitur**: Nama fitur / komponen yang bermasalah.
   - **Gejala**: Apa yang salah atau dikeluhkan pengguna.
   - **Kesalahan (Root Cause Faktual)**: Penyebab kode/arsitektur spesifik yang memicu kegagalan (file, baris, logika).
   - **Aturan Pencegahan (Invariant)**: Hal yang mutlak DILARANG atau WAJIB dipatuhi di masa mendatang agar kesalahan tidak terulang.

---

## 📋 Daftar Kesalahan & Invariant Pencegahan

### ERR-001: Auto-Dismiss Agresif pada Panel Chat (HomeSpace)
- **Fitur:** `HomeSpace / Mascot Chat Panel`
- **Gejala:** Panel chat menutup sendiri secara tiba-tiba saat pengguna mengirim prompt (misal "coba check email saya") atau saat aplikasi latar belakang (Mail.app) mulai berjalan.
- **Kesalahan (Root Cause Faktual):** Monitor global/lokal (`NSEvent.addGlobalMonitorForEvents`) dan observer `didResignKeyNotification` di `HomeSpaceWindowManager.swift` langsung memanggil `self.hide()` saat mouse berada di luar jendela atau saat fokus jendela berpindah.
- **Aturan Pencegahan (Invariant):**
  - **DILARANG** memasang monitor klik luar auto-dismiss pada HomeSpace.
  - HomeSpace adalah **Persistent Mascot Workspace**: jendela HANYA boleh ditutup secara eksplisit via: (1) Tombol close `[ ✕ ]`, (2) Tap fisik lekukan notch, atau (3) Shortcut keyboard `Esc` / `⌘W`.

---

### ERR-002: Kanvas WindowServer Menelan Klik Aplikasi di Bawah Notch
- **Fitur:** `BoringNotchSkyLightWindow / WindowServer Hit-Testing`
- **Gejala:** Area di bawah notch (seperti tab IDE ZCode / browser) tidak bisa diklik sama sekali meskipun notch dalam kondisi tertutup rapi.
- **Kesalahan (Root Cause Faktual):** Jendela `BoringNotchSkyLightWindow` memiliki kanvas tetap 640×210 pt dengan `ignoresMouseEvents = false`. Meskipun SwiftUI `hitTest` mengembalikan `nil` di luar notch, kernel WindowServer tetap mencegat (*swallow*) event mouse dan tidak meneruskannya ke jendela di bawahnya.
- **Aturan Pencegahan (Invariant):**
  - Saat notch tertutup dan kursor mouse berada di luar `activeClosedNotchRect` (~185×32 pt), jendela **WAJIB** secara dinamis menyetel `window.ignoresMouseEvents = true`.
  - Hanya ubah ke `ignoresMouseEvents = false` saat kursor benar-benar menyentuh fisik notch.

---

### ERR-003: Alokasi Virtual Display Merusak Jendela Layar Utama Host
- **Fitur:** `MascotVirtualDesktopService / CGVirtualDisplay`
- **Gejala:** Setiap kali asisten membuat layar virtual terisolasi (`CGVirtualDisplay`), layar berkedip dan jendela MacBook notch hancur atau terduplikasi.
- **Kesalahan (Root Cause Faktual):** Alokasi display virtual memicu notifikasi sistem `NSApplication.didChangeScreenParametersNotification`, menyebabkan AppDelegate mengira monitor fisik dicabut/dipasang ulang dan membuat ulang jendela notch.
- **Aturan Pencegahan (Invariant):**
  - Pasang filter geometris `Self.physicalScreens()` yang mengabaikan layar virtual maskot (`origin.x >= 1500`, `1920x1080`).
  - Gunakan `isAllocatingVirtualDisplay` lock saat inisialisasi agar event notifikasi display virtual tidak memicu rekonfigurasi antarmuka layar utama host.

---

### ERR-004: Auto-Relaunch Aplikasi Target pada Polling Idle
- **Fitur:** `CompanionWindowStreamService / Workflow Apps`
- **Gejala:** Aplikasi Mail.app terus terbuka kembali secara otomatis saat pengguna sengaja menutupnya.
- **Kesalahan (Root Cause Faktual):** Timer streaming background memanggil `ensureWorkflowAppRunning` secara spekulatif pada saat loop idle, meskipun tidak ada tugas aktif yang sedang dieksekusi.
- **Aturan Pencegahan (Invariant):**
  - **DILARANG** meluncurkan aplikasi otomatis pada loop polling idle.
  - Aplikasi target HANYA boleh dibuka jika ada perintah tugas aktif yang sedang di-dispatch secara eksplisit oleh asisten.

---

### ERR-005: Suara Shutter Kamera Berulang-ulang (Spamming)
- **Fitur:** `CompanionWindowStreamService / CuaVisualGrounder`
- **Gejala:** Terdengar suara jepretan kamera macOS berulang kali setiap kali agen memproses frame.
- **Kesalahan (Root Cause Faktual):** Pemanggilan biner sistem `/usr/sbin/screencapture` dilakukan tanpa menyertakan flag `"-x"` (silent).
- **Aturan Pencegahan (Invariant):**
  - Prioritaskan pengambilan frame in-memory via `CGWindowListCreateImage` (0 disk I/O, 0 audio).
  - Jika biner `/usr/sbin/screencapture` terpaksa digunakan, **WAJIB** menyertakan flag `"-x"`.

---

### ERR-006: Pembuatan Antarmuka Tiruan Palsu (Fake Mockup Rule)
- **Fitur:** `Isolated VM Viewport / Connected Apps`
- **Gejala:** Agen menampilkan jendela HTML/WebKit dummy dengan data statis atau folder palsu alih-alih menjalankan aplikasi nyata.
- **Kesalahan (Root Cause Faktual):** Menggunakan komponen mockup tiruan daripada menghubungkan proses ke runtime aplikasi asli.
- **Aturan Pencegahan (Invariant):**
  - **DILARANG KERAS** membuat antarmuka tiruan palsu atau dummy folders.
  - Segala eksekusi wajib menggunakan aplikasi nyata di dalam Virtual Display atau sandbox WebKit persistent store asli.

---

### ERR-007: Intervensi Kursor Host Saat Menjalankan Tugas Terisolasi
- **Fitur:** `CompanionVMAgentLoop / CUA Execution`
- **Gejala:** Kursor mouse fisik pengguna di layar utama Mac bergerak sendiri dan mengganggu pekerjaan pengguna saat asisten mengeksekusi email di VM.
- **Kesalahan (Root Cause Faktual):** CUA daemon host Mac (`CuaDriverClient`) tetap aktif dan menembakkan event ke layar fisik utama, alih-alih dibatasi ke kanvas VM/Virtual Display.
- **Aturan Pencegahan (Invariant):**
  - Pada mode connected apps / virtual sandbox, CUA host Mac **WAJIB MATI TOTAL**.
  - Seluruh event klik dan ketik harus disimulasikan secara virtual pada Virtual Display atau kanvas viewport terisolasi.

---

### ERR-008: Salah Identifikasi Jendela Finder sebagai Aplikasi Mail
- **Fitur:** `CompanionWindowStreamService / Window Identification`
- **Gejala:** Asisten membuka dan menampilkan jendela folder Finder alih-alih membuka aplikasi Mail.
- **Kesalahan (Root Cause Faktual):** Pencocokan jendela menggunakan substring title matching sederhana, sehingga folder Finder yang dibuka dengan nama `"sent_emails"` dicocokkan sebagai jendela `"Mail"`.
- **Aturan Pencegahan (Invariant):**
  - Selalu gunakan pencocokan nama pemilik proses yang ketat (`ownerName.localizedLowercase == targetApp`).
  - Tolak secara eksplisit jendela Finder (`ownerName == "Finder"`) jika target aplikasi bukan Finder.

---

### ERR-009: Drag Gesture Menelan Tap Target Klik Langsung
- **Fitur:** `PanGesture / BoringNotch Click Interaction`
- **Gejala:** Mengklik lekukan notch tidak membuka menu notch karena klik tidak terdeteksi.
- **Kesalahan (Root Cause Faktual):** Komponen `DragGesture(minimumDistance: 0)` mencegat seketika event mouse down dan membatalkan `TapGesture`.
- **Aturan Pencegahan (Invariant):**
  - Gunakan `minimumDistance: 8` pada gesture drag agar tidak menelan klik instan.
  - Pasang `.simultaneousGesture(TapGesture())` agar klik langsung selalu dieksekusi tanpa delay.

---

### ERR-010: Polusi Format Markdown pada Narasi Suara TTS
- **Fitur:** `ElevenLabsTTSClient / Voice Feedback`
- **Gejala:** Suara asisten membacakan simbol-simbol markdown seperti `###`, `|`, `*`, dan `---` secara literal.
- **Kesalahan (Root Cause Faktual):** Naskah teks visual UI yang berformat tabel markdown disuplai langsung ke endpoint pemrosesan suara TTS.
- **Aturan Pencegahan (Invariant):**
  - Wajib memisahkan dual-payload: teks visual UI (markdown kaya) dan teks narasi suara TTS (teks polos murni $\le 300$ karakter tanpa sintaksis markdown).

---

### ERR-011: HomeSpace Hilang & Notch Terkunci Akibat Perubahan NSScreen.main ke Layar Virtual
- **Fitur:** `HomeSpaceWindowManager / Notch Lifecycle`
- **Gejala:** Saat pengguna mengirim prompt VM (misal "check email saya"), panel chat tiba-tiba hilang dari layar fisik, dan notch tidak bisa di-hover sebelum menekan `Esc`.
- **Kesalahan (Root Cause Faktual):** `HomeSpaceWindowManager.show()` menggunakan `NSScreen.main`. Ketika aplikasi di virtual display menjadi fokus, `NSScreen.main` beralih ke layar virtual sehingga panel chat berpindah ke koordinat off-screen. Karena HomeSpace masih berstatus `isVisible = true` di background, notch host sengaja ditahan pada `alphaValue = 0.0` (tidak bisa di-hover) sampai tombol `Esc` memanggil `hide()`.
- **Aturan Pencegahan (Invariant):**
  - HomeSpace **WAJIB** terikat pada layar fisik utama Mac (`hostScreen`), bukan `NSScreen.main`.
  - Pasang `.stationary` dan `.ignoresCycle` pada `HomeSpacePanel.collectionBehavior` agar tidak berpindah layar/space.

---

### ERR-012: Penggantungan Indikator Layar Ungu (Screen Sharing/Virtual Display) di Menu Bar
- **Fitur:** `MascotVirtualDesktopService / Frame Capture Lifecycle`
- **Gejala:** Muncul ikon ungu Screen Sharing / Virtual Display di menu bar yang tidak pernah hilang setelah asisten selesai memproses tugas.
- **Kesalahan (Root Cause Faktual):** Timer streaming dan objek `CGVirtualDisplay` tidak pernah di-stop/dismantle setelah tugas otonom selesai, sehingga macOS mempertahankan status virtual display dan screen capture secara permanen.
- **Aturan Pencegahan (Invariant):**
  - Segera setelah tugas selesai (`finishTask` dengan status `.done` atau `.failed`), **WAJIB** memanggil `stopStreaming()` dan `stopVirtualDesktop()` secara otomatis (kecuali mode takeover aktif).

---

### ERR-013: Pembalikan Status Pesan AI ke "Working" dan Teks Kosong Akibat Ketiadaan updateMessage di Roster Store
- **Fitur:** `CompanionManager / CompanionRosterStore Message Persistence`
- **Gejala:** Kartu chat macet di status `● Working` dan teks jawaban hasil asisten tidak muncul di feed percakapan.
- **Kesalahan (Root Cause Faktual):** `updateChatMessage` hanya memperbarui state in-memory `chatMessages` dan `sessions`, tanpa memperbarui `CompanionRosterStore`. Saat sinkronisasi otomatis roster berjalan, pesan tertimpa kembali oleh pesan lama dari store yang masih berstatus `Working` dengan teks kosong.
- **Aturan Pencegahan (Invariant):**
  - Setiap pembaruan pesan via `updateChatMessage` **WAJIB** memanggil `CompanionRosterStore.shared.updateMessage(...)` agar tersimpan persisten ke disk dan sinkron dengan seluruh siklus view.

---

### ERR-014: Inkonsistensi Visual Kartu Chat vs Modal Interaktif
- **Fitur:** `HomeSpaceComputerCardView & HomeSpaceInteractiveComputerModalView`
- **Gejala:** Tampilan pada kartu chat (Foto 3) berbeda dengan tampilan saat di-maximize ke modal (Foto 4).
- **Kesalahan (Root Cause Faktual):** Kartu chat mengambil snapshot seluruh monitor virtual (1920×1080) dengan border hitam kosong lebar, sedangkan modal mengambil potongan jendela aplikasi saja ditambah adanya floating mini-dock di bawah yang menutupi kanvas.
- **Aturan Pencegahan (Invariant):**
  - Samakan urutan prioritas snapshot (`streamService.activeSnapshot` terdepan) dan hilangkan elemen mini-dock yang mengobstruksi kanvas pada modal interaktif.

---

### ERR-015: NSPanel.hidesOnDeactivate Menghilangkan Panel Chat Secara Gaib Saat Meluncurkan Aplikasi
- **Fitur:** `HomeSpacePanel / Window Deactivation Lifecycle`
- **Gejala:** Panel chat langsung menutup/menghilang seketika saat user mengirim prompt (seperti "check email saya"), dan notch MacBook terkunci tidak bisa di-hover sebelum menekan `Esc`.
- **Kesalahan (Root Cause Faktual):**
  1. `HomeSpacePanel` merupakan subclass dari `NSPanel`. Pada AppKit bawaan Apple, properti `hidesOnDeactivate` bernilai default `true`. Ketika `CompanionVMAgentLoop` mengeksekusi `/usr/bin/open -g -a /System/Applications/Mail.app` atau AppleScript terhadap aplikasi target, macOS WindowServer memicu event deactivation pada `boringNotch`. AppKit secara otomatis memanggil Cocoa internal `orderOut:` pada `HomeSpacePanel` tanpa memanggil `HomeSpaceWindowManager.hide()`.
  2. Karena `hide()` tidak terpanggil, variabel `HomeSpaceWindowManager.shared.isVisible` tetap bernilai `true`. Akibatnya, `BoringNotchSkyLightWindow` mempertahankan `alphaValue = 0.0` dan `ignoresMouseEvents = true`, sehingga notch MacBook fisik terkunci dan tidak bisa di-hover sampai tombol `Esc` ditekan untuk memicu `cancelOperation`.
- **Aturan Pencegahan (Invariant):**
  - Pada `HomeSpacePanel`, properti `hidesOnDeactivate` **WAJIB** di-override secara permanen:
    ```swift
    override var hidesOnDeactivate: Bool {
        get { false }
        set { }
    }
    ```
  - Properti `newPanel.isFloatingPanel = true`, `newPanel.hidesOnDeactivate = false`, dan `newPanel.becomesKeyOnlyIfNeeded = false` wajib di-set saat instansiasi panel.
  - Panggil `HomeSpaceWindowManager.shared.ensureOrderFront()` pada saat submit prompt dan di setiap callback progress tugas untuk memastikan posisi jendela tetap berada di urutan depan host screen.

---

### ERR-016: Crash Fatal Unmanaged takeUnretainedValue pada Re-alokasi CGVirtualDisplay
- **Fitur:** `MascotVirtualDesktopService / CGVirtualDisplay Dynamic Creation`
- **Gejala:** Aplikasi langsung crash seketika (SIGTRAP / Trace/BPT trap: 5) saat pengguna mengirim prompt kedua (misal: "coba kirimkan email gitu") setelah tugas pertama selesai.
- **Kesalahan (Root Cause Faktual):**
  1. Pada `MascotVirtualDesktopService.swift:76`, pembuatan `CGVirtualDisplay` menggunakan `displayAlloc.perform(initSel, with: desc).takeUnretainedValue()` tanpa guard.
  2. Descriptor virtual display menggunakan nomor seri statis `serialNum = 0x0001`. Saat display virtual di-dismantle dan dibuat ulang dalam rentang waktu singkat, CoreGraphics WindowServer masih menahan entri perangkat lama di registri internal sehingga `initWithDescriptor:` mengembalikan `nil`.
  3. Memanggil `.takeUnretainedValue()` pada objek `nil` memicu `_assertionFailure` Swift runtime dan fatal crash.
  4. Komponen `InteractiveVirtualDesktopView` memanggil `assignAppToVirtualDesktop` di dalam `.onAppear`, memicu race condition alokasi display saat view SwiftUI me-render kartu chat.
- **Aturan Pencegahan (Invariant):**
  - Gunakan penghitung nomor seri dinamis (`displaySerialCounter &+= 1`) untuk setiap alokasi display baru.
  - **DILARANG KERAS** memanggil `.takeUnretainedValue()` tanpa `guard let` dan casting fungsi C `@convention(c)` yang aman.

---

### ERR-017: Pemanggilan Blokir Sinkron pada MainActor (Process.waitUntilExit & AXUIElement Recursive Scan) Memicu Watchdog RunningBoard SIGKILL(9)
- **Fitur:** `CompanionVMAgentLoop / ClickyHybridGroundingEngine (Anti-Hang & Anti-Watchdog)`
- **Gejala:** Aplikasi freeze total lalu mati secara mendadak (dihentikan oleh macOS watchdog dengan `SIGKILL(9)` / `RBSProcessExitContext` via spindump/audiomxd) saat user mengirimkan prompt untuk mengirim email ("coba kirimkan email gitu" / "bisa kirimkan email ke rezkyhaikal2@gmail.com...").
- **Kesalahan (Root Cause Faktual):**
  1. `CompanionVMAgentLoop.executeAutonomousTask` dipanggil dari SwiftUI `HomeSpaceRootView` di dalam konteks `@MainActor`.
  2. Pada baris 302-306 dan 458-464 di [CompanionVMAgentLoop.swift](file:///Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/Tools/CompanionVMAgentLoop.swift), skrip `/usr/bin/osascript` awalnya dijalankan menggunakan `Process()` sinkron dengan `p.waitUntilExit()`.
  3. Selanjutnya, di [ClickyHybridGroundingEngine.swift](file:///Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/Tools/ClickyHybridGroundingEngine.swift#L95-L168), fungsi `locateViaAXUIElement` berjalan sinkron di thread `@MainActor`. Fungsi ini memanggil `scanElementHierarchy` dengan rekursi hingga kedalaman 14 tanpa batas node dan tanpa `AXUIElementSetMessagingTimeout`. Pada aplikasi yang memiliki pohon UI kompleks seperti `Mail.app`, puluhan ribu panggilan IPC antar-proses memblokir event loop WindowServer selama lebih dari 30 detik sehingga RunningBoard mematikan proses dengan `SIGKILL(9)`.
- **Aturan Pencegahan (Invariant):**
  - **DILARANG KERAS** memanggil `p.waitUntilExit()` secara sinkron pada thread `@MainActor` untuk proses eksternal apa pun (`osascript`, command-line tool). Semua eksekusi subprocess eksternal wajib menggunakan `CompanionVMAgentLoop.runSubprocessAsync` yang dijalankan di background thread dengan batas waktu ketat (`DispatchSourceTimer`).
  - **DILARANG KERAS** menjalankan traversal Accessibility API (`AXUIElement`) secara sinkron di thread `@MainActor`. Seluruh pemindaian AX **WAJIB** menggunakan `locateViaAXUIElementAsync` di background queue (`DispatchQueue.global(qos: .userInitiated)`) dengan:
    - Pasang `AXUIElementSetMessagingTimeout(appElement, 0.2)` agar IPC tidak pernah menggantung.
    - Pasang timeout global (1.5 detik) dengan `DispatchSourceTimer`.
    - Batasi kedalaman traversal (`depth <= 4`) dan kuota maksimal elemen (`maxNodes <= 80`).
    - Lakukan fallback langsung ke Tier 2 (Vision 6 Luna) jika elemen tidak ditemukan cepat, tanpa menahan thread UI.

---

### ERR-018: Pipeline Prosedural Hardcoded pada Eksekusi CUA Melanggar Otonomi Model
- **Fitur:** `CompanionVMAgentLoop / CUA ReAct Loop Paradigm`
- **Gejala:** Interaksi CUA email kaku karena seluruh alur aksi (buka compose, ketik penerima, kirim) dikodekan secara statis via if-else `lowerPrompt.contains(...)` dan template skrip AppleScript bawaan, alih-alih dipikirkan dan divalidasi oleh model AI secara otonom.
- **Kesalahan (Root Cause Faktual):** Implementasi awal `CompanionVMAgentLoop` mengandalkan skrip prosedural hardcoded 4 langkah (`createDraftScript`, `dispatchSendScript`) dengan asumsi tetap, sehingga sistem tidak memiliki kemampuan ReAct otonom sejati (Think -> Act -> Observe) untuk beradaptasi terhadap layout antarmuka yang bervariasi.
- **Aturan Pencegahan (Invariant):**
  - **DILARANG KERAS** membuat pipeline prosedural hardcoded untuk aksi CUA antar-aplikasi.
  - Semua eksekusi CUA wajib menggunakan **Dual-Model Autonomous ReAct Loop**: AFM (on-device Apple Foundation Models via `FoundationModels` framework) bertindak sebagai Task Planner dan State Validator, berkoordinasi secara dinamis dengan Luna (6 Luna Medium / gpt-6-luna) sebagai sensor penglihatan resolusi tinggi untuk membumikan (grounding) elemen UI visual secara dinamis pada isolated workspace display.

---

### ERR-019: Fallback Switch-Case Peniru Penalaran AI (Fake Reasoning Shortcut) Melanggar Mandat Otonomi
- **Fitur:** `AFMLunaCoordinationBridge / AFM Task Planner`
- **Gejala:** Muncul kode fallback prosedural `fallbackPlanNextStep` dengan percabangan `switch currentStep { case 1: ... case 2: ... }` yang memuat teks dan target aksi statis yang ditulis manual oleh programmer.
- **Kesalahan (Root Cause Faktual):**
  - Pada `AFMLunaCoordinationBridge.swift:187-245`, programmer membuat jalan pintas fallback manual (`fallbackPlanNextStep`) yang mengembalikan `AFMStepDecision` statis jika pemanggilan `FoundationModels` gagal atau mengalami timeout.
  - Ini adalah pelanggaran serius terhadap kedaulatan ReAct otonom: tugas model AI adalah menalar secara independen, bukan menjalankan skrip drama buatan programmer.
- **Aturan Pencegahan (Invariant):**
  - **DILARANG KERAS** membuat fungsi fallback bertingkat switch-case, percabangan intent kaku, atau skrip statis yang mensimulasikan penalaran AI.
  - Semua keputusan langkah (`AFMStepDecision`) WAJIB bersumber murni dari output model (AFM / SiriAIEngine).
  - Jika model gagal memberikan respons JSON yang valid:
    1. Lakukan query ulang (retry) ke model dengan koreksi instruksi JSON.
    2. Jika tetap gagal setelah retry, kembalikan status error otonom nyata atau minta bantuan pengguna (Human Takeover), BUKAN menipu dengan skrip hardcode.


---

### ERR-020: Koordinat Virtual Display Off-By-Scale dan Ketiadaan Aksi Read pada CUA ReAct Loop
- **Fitur:** `CompanionVMAgentLoop / ClickyHybridGroundingEngine / AFMLunaCoordinationBridge (Perception & Read Flow)`
- **Gejala:** Saat pengguna menginstruksikan perintah pengecekan email ("tolong check email saya"), agen bingung, mencoba mengirim email draf, dan kursor mengklik ujung kanan layar secara acak.
- **Kesalahan (Root Cause Faktual):**
  1. **Prompt Biasing & Ketiadaan Aksi Read:** Prompt AFM sebelumnya hanya mengarahkan aksi `click`, `type`, dan `done` dengan contoh compose/send email, tanpa menyediakan kapabilitas membaca elemen antarmuka (`read`), sehingga model AFM salah mengasumsikan setiap instruksi email adalah pembuatan pesan baru.
  2. **Ketiadaan Handler Read pada Agent Loop:** Pada `CompanionVMAgentLoop.swift`, jika model mengembalikan tipe aksi `read`, loop tidak memiliki cabang penanganan dan jatuh ke blok `else` yang memanggil `performCuaClick`, alih-alih mengekstrak data dari aplikasi.
  3. **Normalisasi Koordinat Rusak:** `CompanionVMAgentLoop.swift` sebelumnya membagi koordinat AX dengan konstanta sembarangan (`targetPoint.x / 1000.0`). Karena koordinat global AX berada di rentang virtual display (`x = 1585`), nilai normalisasi ter-clamp ke `0.95`, yang kemudian diproyeksikan ulang oleh virtual display engine ke koordinat `3336` (tepi kanan layar luar).
  4. **Pencocokan Tombol Overly Broad di Grounding Engine:** `ClickyHybridGroundingEngine.swift:212` memuat klausa `|| role.contains("button")` ketika query memuat kata `"send"`, menyebabkan tombol apa pun (seperti sidebar toggle) salah teridentifikasi sebagai tombol "Send".
  5. **Array Tiruan Dummy:** `readElements` sebelumnya memiliki fallback hardcoded palsu `["Inbox (5 unread)", "Rezky: Project Update", ...]` yang melanggar aturan Zero Fake Mockups.
- **Aturan Pencegahan (Invariant):**
  - Normalisasi koordinat virtual display **WAJIB** menggunakan `MascotVirtualDesktopService.shared.displayBounds` (`relX = rawX >= vOriginX ? (rawX - vOriginX) : rawX; normX = min(max(relX / vWidth, 0.02), 0.98)`).
  - Aksi `read` wajib memanggil pembacaan data nyata (`readElements`) dan hasilnya diumpankan ke `lastObservation` dan `historySummary` agar model AFM dapat melihat isi data faktual untuk menyusun ringkasan (summary) bahasa Indonesia yang akurat.
  - Pencocokan elemen UI pada `ClickyHybridGroundingEngine` dilarang mencocokkan sembarang `role == "button"` tanpa memeriksa kesesuaian atribut `title`, `desc`, `value`, atau `identifier`.
  - Dilarang keras menggunakan array string palsu/dummy untuk mensimulasikan hasil pembacaan UI.

---

### ERR-021: MainActor Stall Mengunci Event Tap Kursor Host & Ketiadaan View-Only Mode Default
- **Fitur:** `CompanionWindowStreamService / MascotVirtualDesktopService / InteractiveVirtualDesktopView / HomeSpaceInteractiveComputerModalView (Non-Blocking Capture & Strict View-Only Takeover Protocol)`
- **Gejala:** Membuka modal proyeksi VM dari kartu chat menyebabkan kursor mouse fisik di macOS host macet/freeze selama beberapa detik. Selain itu, input klik/keyboard pengguna berpotensi saling bertabrakan atau merusak aksi AI yang sedang berlangsung.
- **Kesalahan (Root Cause Faktual):**
  1. `MediaKeyInterceptor.swift:68` mendaftarkan `CGEvent.tapCreate` bertipe `.cghidEventTap` pada runloop utama `CFRunLoopGetMain()`. Arsitektur Quartz Event Services menyatakan jika thread runloop utama terhambat, macOS menghentikan pengiriman pergerakan event kursor di seluruh sistem hingga runloop merespons kembali atau tap timeout.
  2. Saat modal dibuka, `startStreaming` dipanggil pada interval 0.8–1.0 detik. Di dalam `MascotVirtualDesktopService.captureSnapshot` dan `CompanionWindowStreamService.captureTargetWindow`, terdapat eksekusi subprocess CLI `/usr/sbin/screencapture` yang dipanggil sinkron dengan `p.waitUntilExit()` langsung pada thread `@MainActor`, serta kompresi PNG `bitmapRep.representation(using: .png)` pada thread utama untuk gambar Retina besar (100–250ms). Hal ini menyumbat `CFRunLoopGetMain()`, menyebabkan kursor mouse membeku secara fatal.
  3. Ketiadaan View-Only mode default: viewport sebelumnya selalu mengaitkan representasi `NSViewRepresentable` interaktif yang menangkap first-responder mouse/keyboard pengguna bahkan saat model AI sedang bekerja.
- **Aturan Pencegahan (Invariant):**
  1. **Strict View-Only Mode Secara Default:** Seluruh komponen live viewport (`InteractiveVirtualDesktopView`, `HomeSpaceComputerCardView`) wajib berada dalam View-Only mode (`isInteractive: false` dan `.allowsHitTesting(false)`) secara default saat AI bekerja. Pengguna dilarang berinteraksi langsung kecuali menekan tombol eksplisit `[ ✋ Take Over Screen ]`.
  2. **Zero Synchronous Subprocess on `@MainActor`:** Dilarang keras memanggil `/usr/sbin/screencapture` atau command line tools apa pun dengan `p.waitUntilExit()` pada thread `@MainActor`.
  3. **In-Memory-First Capture:** Pengambilan snapshot wajib mengutamakan `CGWindowListCreateImage` atau `CGDisplayCreateImage` (1–3ms) dalam memori tanpa fork subprocess.
  4. **Background Offloading:** Kompresi PNG dan penulisan file disk wajib dilempar ke `DispatchQueue.global(qos: .utility)`, dan fallback subprocess `screencapture` wajib dilempar ke `DispatchQueue.global(qos: .userInitiated)` dengan guard (`isCapturingFallback`) untuk mencegah tumpukan proses (process stacking).

---

### ERR-022: WindowServer Repatriation saat Display Dismantling Membagi Layar Host (Split View Intrusion)
- **Fitur:** `MascotVirtualDesktopService / CompanionWindowStreamService (Zero Host Screen Intrusion & Window Repatriation Guard)`
- **Gejala:** Setelah tugas asisten otonom selesai (misal cek email), layar laptop pengguna tiba-tiba berpindah atau terbagi dua (Split View / Window Tiling) antara aplikasi host (Safari) dan jendela Mail.
- **Kesalahan (Root Cause Faktual):**
  1. **WindowServer Repatriation saat Virtual Display Dihancurkan:** Pada `CompanionVMAgentLoop.swift:640`, tugas yang selesai segera memanggil `MascotVirtualDesktopService.shared.stopVirtualDesktop()`, yang langsung menghancurkan virtual display (`virtualDisplayObj = nil`). Ketika secondary display dicabut seketika oleh sistem, macOS WindowServer secara otomatis menarik paksa (*snap back*) jendela Mail yang berada di layar virtual kembali ke layar laptop utama tepat di atas Safari. Di macOS 15 Sequoia (fitur window tiling otomatis), WindowServer menyusunnya menjadi Split Screen 50:50.
  2. **Targeting Jendela Buta & Prioritas Sortir Terbalik:** Pada `CompanionWindowStreamService.swift:287-292`, urutan sortir jendela menempatkan `compose`/`message` di atas `inbox`. Akibatnya, draf lama yang tersisa dari sesi uji coba sebelumnya ("Update Laporan dari Izanotchy Companion") diprioritaskan sebagai jendela #1 dan dipindahkan ke display virtual alih-alih jendela utama "All Inboxes".
- **Aturan Pencegahan (Invariant):**
  1. **Aplikasi Wajib Disembunyikan Sebelum Virtual Display Dilepas:** Pada `MascotVirtualDesktopService.stopVirtualDesktop()`, fungsi `hideWorkflowApp(appName:)` wajib dipanggil sebelum `virtualDisplayObj = nil` agar WindowServer tidak memindahkan jendela aplikasi yang sedang berjalan ke layar fisik host pengguna.
  2. **Prioritas Utama pada Jendela Inbox/All Inboxes:** Logika pemilihan jendela kandidat wajib memprioritaskan jendela utama (`Inbox`, `All Inboxes`, `Kotak Masuk`) sebelum jendela draf/pesan (`compose`/`message`), dan AppleScript pemindahan jendela wajib secara spesifik menargetkan `item 1 of (every window whose name contains "Inbox" or name contains "All Inboxes")`.

---

### ERR-023: Ketiadaan Injeksi Deliverables pada Jalur Tanya-Jawab Memunculkan Halusinasi Host Window
- **Fitur:** `CompanionManager / ClickyDeterministicPipeline (Conversational Q&A Context Loss & Host Window Hallucination)`
- **Gejala:** Pengguna bertanya mengenai isi email ("apa isi email yang paling teratas?"), namun asisten menjawab bahwa Mail sedang di latar belakang dan meminta pengguna membawa jendela Mail ke layar laptop utama.
- **Kesalahan (Root Cause Faktual):**
  1. Pertanyaan `"apa isi email yang paling teratas?"` diklasifikasikan ke jalur `.tanya` (Q&A percakapan).
  2. Fungsi pembangun prompt percakapan (`CompanionManager.buildCompanionVoiceResponseSystemPrompt`) hanya menginjeksi konteks aplikasi aktif di layar depan host (`active frontmost app: Antigravity`), dan tidak membaca deliverable receipt atau observasi ReAct yang baru saja disimpan di sandbox companion (`~/.izanotchy/companions/inbox-buddy/workspace/deliverables/`).
  3. Karena model tidak diberikan data observasi email yang baru dibaca, model berasumsi bahwa ia harus melihat jendela Mail di layar fisik pengguna untuk dapat membaca isinya, sehingga memunculkan respons keliru yang meminta intervensi layar fisik host.
- **Aturan Pencegahan (Invariant):**
  1. **Injeksi Deliverable & Live Observations:** Untuk companion dengan domain `.virtualSandbox`, prompt percakapan WAJIB secara otomatis memuat isi deliverable terbaru dari direktori workspace sandbox dan daftar email terkini.
  2. **Larangan Meminta Menampilkan Jendela ke Layar:** Prompt sistem dan `persona.md` wajib menegaskan bahwa asisten beroperasi secara mandiri di workspace terisolasi dan DILARANG meminta pengguna membawa aplikasi ke layar utama (`Zero Host Screen Intrusion`).

---

### ERR-024: Jalan Pintas Hardcoded AppleScript Khusus Aplikasi & Ketiadaan Goal Decomposition Engine
- **Fitur:** `CompanionVMAgentLoop / AFMLunaCoordinationBridge / HomeSpaceRootView (Anti-Hardcoded Application Scripting & Dynamic Goal Decomposition)`
- **Gejala:** Asisten "buta" terhadap email urutan ke-3 ("Stockbit Community") yang terpampang jelas di layar; kode ditemukan berisi jalan pintas hardcoded per-aplikasi (`if appName.contains("mail") { tell application "Mail" ... }`) dan pencocokan regex kata kunci kaku (`isEmailAction`).
- **Kesalahan (Root Cause Faktual):**
  1. Di `CompanionVMAgentLoop.swift` dan `CompanionManager.swift`, terdapat blok `tell application "Mail"` kaku dengan batasan `maxCount to 4` yang mem-bypass sistem persepsi CUA. Pada setup multi-akun (iCloud + Google), script hanya membaca akun default iCloud dan tidak membaca pesan dari akun Google (Stockbit Community) yang muncul di "All Inboxes" pada UI fisik.
  2. Ketiadaan fase dekonstruksi tugas (*Goal Decomposition Phase*): Prompt pengguna langsung dilempar ke loop eksekusi tanpa analisis awal oleh model mengenai apa yang diinginkan pengguna (*user intent*), aplikasi apa yang dibutuhkan, dan sub-goal terstruktur apa saja yang harus dicapai.
  3. `HomeSpaceRootView.swift` menggunakan regex kata kunci kaku (`isEmailAction`, `isSafariAction`) yang bertentangan dengan prinsip otonom model.
- **Aturan Pencegahan (Invariant):**
  1. **Larangan Mutlak Skrip Khusus per Aplikasi (Zero App-Specific Hardcode):** DILARANG KERAS menyisipkan AppleScript kaku per-aplikasi (`tell application "..."`) atau percabangan if-else nama aplikasi (`if appName == ...`) untuk mensimulasikan pembacaan data.
  2. **Universal Perception Only (AXUIElement + Vision OCR):** Seluruh pembacaan konten UI WAJIB agnostik 100%, menggunakan hirarki Accessibility (`AXUIElement` table rows, cells, text fields) dan Vision OCR dari snapshot window aktif, berlaku untuk SEMUA aplikasi macOS tanpa terkecuali.
  3. **Mandatory Goal & Task Decomposition:** Setiap instruksi pengguna WAJIB didekonstruksi secara otonom oleh model melalui `AFMLunaCoordinationBridge.deconstructTaskGoalWithAFM` untuk merumuskan intent, aplikasi target, lingkup aksi, dan sub-goals dinamis sebelum eksekusi dimulai.

---

### ERR-025: Kegagalan Capture Sinkron CGWindowListCreateImage & Status Fake Done Saat Validasi Gagal
- **Fitur:** `CompanionWindowStreamService / CompanionVMAgentLoop / AFMLunaCoordinationBridge (Real Window Capture & Anti-Fake State Machine)`
- **Gejala:** Viewport kartu chat menampilkan placeholder *"Initializing virtual desktop space..."* tanpa menampilkan jendela aplikasi target (Mail tidak terlihat), persepsi membaca 0 item, dan asisten mengklaim tugas selesai (`Done`) padahal model AFM validator menyatakan `isDone=false`.
- **Kesalahan (Root Cause Faktual):**
  1. **CGWindowListCreateImage Gagal/Nil di macOS Sequoia:** Pada macOS 15 Sequoia, API warisan `CGWindowListCreateImage` mengembalikan `nil` untuk jendela yang berada di layar virtual/latar belakang.
  2. **Fallback Asinkron Mengembalikan Nil Sinkron:** Di `CompanionWindowStreamService.captureTargetWindow`, saat Method A gagal, Method B melempar perintah `/usr/sbin/screencapture` ke background thread tanpa `await`, lalu fungsi langsung mengembalikan `nil`. Akibatnya, `currentSnap` bernilai `nil` di seluruh langkah loop agen, membuat model persepsi visual buta (confidence 0.0) dan `readElements` membaca 0 item.
  3. **Fake Done State Machine Bug:** Di `CompanionVMAgentLoop.swift`, variabel `isTaskSuccessful` diinisialisasi `true`. Meskipun model validator AFM berulang kali mencatat `isDone=false` ("Tidak berhasil menemukan email yang diharapkan..."), loop keluar karena batas langkah maksimum habis dan tetap mengembalikan `isSuccess: true` dengan status `.done` dan chime `agent-done`.
  4. **Ketiadaan Tier 3 Fallback pada AFM Planner/Validator:** `planNextStepWithAFM` dan `validateWithAFM` tidak memiliki fallback ke Claude API saat daemon on-device tidak aktif, sehingga penalaran gagal jika model lokal macet.
- **Aturan Pencegahan (Invariant):**
  1. **Awaited Async Frame Capture (`captureTargetWindowAsync`):** Seluruh loop agen dan streaming timer WAJIB menggunakan metode asinkron yang menunggu hasil `/usr/sbin/screencapture -x -l <id>` secara non-blocking di luar `@MainActor`, menjamin file snapshot dan `activeSnapshot` tersedia nyata sebelum persepsi dijalankan.
  2. **Strict Anti-Fake State Machine:** `isTaskSuccessful` WAJIB diinisialisasi `false`. Status `.done` HANYA boleh diberikan jika model AFM secara eksplisit memvalidasi bahwa `isDone == true`. Jika langkah habis atau validasi gagal, status WAJIB `.failed` dengan ringkasan jujur dari model.
  3. **Universal App Window Reopen Guard:** Jika aplikasi terdeteksi berjalan di background tetapi tidak memiliki jendela yang terbuka (`findCandidateWindows` kosong), `ensureWorkflowAppRunning` wajib mengirimkan perintah universal `tell application "<appName>" to reopen` tanpa mengganggu fokus host.
  4. **Tri-Tier Model Resilience:** `planNextStepWithAFM` dan `validateWithAFM` wajib memiliki rantai fallback 3 lapis: FoundationModels -> SiriAIEngine Daemon -> Claude API.

---

### ERR-026: Viewport Blank Gray Canvas, Pipe Deadlock, dan Kegagalan Posisi Virtual Display
- **Fitur:** `CompanionWindowStreamService / MascotVirtualDesktopService / CompanionVMAgentLoop (ScreenCaptureKit In-Memory Engine & Virtual Space Alignment)`
- **Gejala:** Viewport kartu chat menampilkan kanvas persegi panjang abu-abu kosong dengan reticle di tengah (tanpa isi jendela aplikasi), reticle membidik koordinat default, dan persepsi model membaca 0 item.
- **Kesalahan (Root Cause Faktual):**
  1. **POSIX Pipe Sharing/Deadlock pada Subprocess Capture:** Pada `CompanionVMAgentLoop.runSubprocessAsync`, satu objek `Pipe()` yang sama di-assign ke kedua `process.standardOutput` dan `process.standardError`. Standar Cocoa POSIX melarang hal ini karena memicu deadlock dan race condition pada buffer pembacaan.
  2. **Race Overwrite Snapshot oleh Virtual Display Capture:** `MascotVirtualDesktopService.captureSnapshot()` mengambil gambar display virtual secara keseluruhan (`CGDisplayCreateImage`) dan menimpa file `active_frame.png` dengan tangkapan layar display kosong (1920x1080 abu-abu), menimpa frame jendela aplikasi nyata yang diambil oleh `CompanionWindowStreamService`.
  3. **Asinkronitas Penempatan DisplayBounds WindowServer:** `CGDisplayBounds(dID)` mengembalikan `(0, 0, 0, 0)` tepat setelah alokasi `CGVirtualDisplay`, menyebabkan fallback koordinat statis `1512` digunakan, padahal WindowServer macOS menempatkan layar virtual di koordinat `3432`. Akibatnya, jendela Mail dipindahkan ke ruang hampa di antara monitor fisik dan monitor virtual.
  4. **Aplikasi Tersembunyi Tetap Hidden:** Saat tugas sebelumnya selesai, `hideWorkflowApp` memanggil `app.hide()`. Pada tugas berikutnya, `ensureWorkflowAppRunning` hanya memanggil `reopen` AppleScript, yang pada macOS tidak membatalkan status `app.hide()`.
- **Aturan Pencegahan (Invariant):**
  1. **Modern ScreenCaptureKit-First (`SCScreenshotManager.captureImage`):** Pengambilan snapshot jendela aplikasi pada macOS 14+ wajib menggunakan `ScreenCaptureKit` in-memory langsung dari target `SCWindow`. Berjalan dalam 2–5ms, zero subprocess overhead, dan tidak terpengaruh status window di secondary display.
  2. **Prioritas Frame Jendela Asli di Viewport:** `MascotVirtualDesktopService.captureSnapshot` dilarang menimpa file frame jika `CompanionWindowStreamService.shared.activeSnapshot` sudah memiliki frame jendela aplikasi yang valid.
  3. **Penyelarasan Koordinat Berbasis `NSScreen.screens`:** Koordinat `displayBounds` wajib diverifikasi dari `NSScreen.screens` untuk mendapatkan koordinat fisik WindowServer yang sebenarnya.
  4. **Pemeriksaan Eksplisit `app.unhide()`:** `ensureWorkflowAppRunning` wajib memeriksa `matchingApp.isHidden` dan memanggil `app.unhide()` sebelum jendela dipindahkan atau diakses.

---

### ERR-027: Pencemaran Halusinasi Perintah pada Respons Pengguna & Premature Exit Akibat Ketiadaan Pemisahan Variabel
- **Fitur:** `AFMLunaCoordinationBridge / CompanionVMAgentLoop / HomeSpaceRootView (Separation of Concerns: System State vs User-Facing Response)`
- **Gejala:** Kartu chat menampilkan teks halusinasi berupa instruksi/anjuran aneh (*"Ubahkan format teks email terakhir dan melihatnya secara detail dalam kotak masuk."*) dan loop CUA berhenti prematur di Langkah 1 padahal baris email belum diklik dan belum dibuka (preview masih *"No Message Selected"*).
- **Kesalahan (Root Cause Faktual):**
  1. **Dual-Role Confusion pada Variabel `summary`:** Variabel `summary` difungsikan ganda sebagai status transisi audit internal *sekaligus* teks chat ke pengguna.
  2. **Ketiadaan Batasan Kriteria Penyelesaian pada Validator AFM:** Pada `AFMLunaCoordinationBridge.swift:330-340`, prompt validator tidak memiliki batasan kelengkapan data. Karena preview masih kosong (*"No Message Selected"*), model on-device 3B bingung dan malah mengarang kalimat instruksi format teks.
  3. **Premature Intermediate Loop Break:** Pada `CompanionVMAgentLoop.swift:402`, loop intermediate dihentikan seketika di Langkah 1 saat `validation.isDone == true` tanpa memvalidasi apakah ada data faktual yang telah diekstrak.
  4. **Vision OCR Dilewati oleh Batas Kuota AX:** Pada `CompanionVMAgentLoop.swift:619`, `readElements` melewati Vision OCR karena `elements.count < 6`, padahal teks nama pengirim dan subjek ("OpenAI", "New sign-in to your OpenAI account", "18:16") terpampang jelas di kanvas jendela.
- **Aturan Pencegahan (Invariant):**
  1. **Pemisahan Mutlak Variabel Sistem vs Pengguna (Separation of Concerns):**
     - `systemState`: Catatan teknis khusus untuk internal state machine / audit receipt.
     - `extractedData`: Fakta data konkret yang diekstrak dari layar.
     - `responseToUser`: Jawaban bahasa alami ke pengguna yang digenerate khusus berdasarkan `extractedData`. DILARANG KERAS menghasilkan kalimat perintah atau tutorial kepada pengguna.
  2. **Anti-Premature Intermediate Loop Exit:** Jika langkah planner bukan `done`, loop DILARANG berhenti kecuali data faktual non-kosong telah terverifikasi di `extractedData`.
  3. **Vision OCR Selalu Aktif:** Pengambilan teks visual dari screenshot jendela aktif wajib selalu dijalankan tanpa filter kuota AX agar teks fisik yang terlihat di kanvas layar selalu terangkut ke dalam observasi.

---

### ERR-028: Kesalahan Semantik Antarmodel (Indeks Bawah vs Terbaru & Query Pencarian Kata Ganti Posesif)
- **Fitur:** `AFMLunaCoordinationBridge / CompanionVMAgentLoop (Structured Inter-Model JSON Task Contract & Ingress/Egress Gateway)`
- **Gejala:** 
  1. Prompt *"check email saya"* membuat agen melaporkan: *"Tidak dapat menemukan teks 'saya' dalam email pertama yang dipilih. Tidak ada pesan terpilih di daftar email."* (agen secara keliru mencari kata literal "saya" di subject email).
  2. Prompt *"check email terakhir"* membuat agen mengeklik baris 1, 2, 3, 4 secara berurutan hingga batas langkah habis dan melaporkan: *"Anda sedang mengunduh isi email keempat dari daftar terbaru."* (agen salah menafsirkan kata "terakhir" sebagai indeks terbawah daftar email).
- **Kesalahan (Root Cause Faktual):**
  1. **Ketiadaan Ingress Gateway Normalization:** Loop otonom melempar string prompt mentah bahasa Indonesia ("check email saya") langsung ke on-device AFM Planner dan Validator yang di-tokenisasi dan dilatih dominan bahasa Inggris. Token kata ganti posesif ("saya", "ku") diinterpretasikan secara keliru sebagai filter pencarian teks spesifik.
  2. **Ambiguitas Semantik Temporal vs Posisi:** Dalam bahasa Indonesia, kata "terakhir" memiliki arti ganda: *paling baru/terkini* (temporal / baris 1 teratas di inbox) atau *paling akhir* (posisi urutan / baris terbawah). Karena ketiadaan Normalisasi Kontrak JSON ke Canonical English (`targetEntity: "topmost_inbox_item"`), model planner berasumsi "terakhir" adalah baris terbawah daftar dan mengeklik turun ke baris 4.
  3. **Ketiadaan Kontrak JSON Terstruktur Antarmodel:** Hasil dekomposisi tugas awal (`taskPlan`) tidak diteruskan ke `planNextStepWithAFM` dan `validateWithAFM` di dalam `CompanionVMAgentLoop`, membuat setiap langkah kehilangan konteks entitas target yang baku.
  4. **Ketiadaan Pembaruan Observasi Pasca-Aksi:** Setelah aksi `click` atau `type`, observasi layar (`actionObsResult`) hanya mencatat string statis `"Executed click on 'topmost email row'"` tanpa membaca kembali elemen visual jendela baru, sehingga validator tidak mengetahui teks isi email yang telah terbuka.
- **Aturan Pencegahan (Invariant):**
  1. **Anti-Linguistic Prompt Injection:** DILARANG menyuntikkan teks kamus/panduan kata kaku (seperti "kata saya artinya...") ke dalam prompt interaksi.
  2. **Ingress Gateway Normalization (AFM Decomposer):** Decomposer WAJIB bertindak sebagai Ingress Gateway yang menerjemahkan bahasa alami pengguna ke dalam Canonical English JSON Task Contract (`intentType`, `targetEntity`, `searchQuery: null`, `normalizedGoal`, `userLanguage`).
  3. **Operasi 100% Berbasis Kontrak Kanonikal bagi Internal Agents:** Planner dan Luna Grounder WAJIB 100% beroperasi menggunakan Canonical English JSON Task Contract (`targetEntity: "topmost_inbox_item"`). Dilarang mencari kata ganti posesif sebagai string pencarian teks, dan target item terbaru selalu baris 1 teratas.
  4. **Egress Gateway Normalization (Validator & Synthesizer):** Validator mengonsumsi data observasi faktual dan merumuskan `responseToUser` kembali ke bahasa asal pengguna (`userLanguage`).
  5. **Pembaruan Layar Pasca-Aksi (Post-Action Screen Refresh):** Setelah aksi click/type selesai, loop agen WAJIB segera memanggil `readElements` pada snapshot terbaru untuk memperbarui observasi yang diterima oleh validator dan planner langkah berikutnya.

---

### ERR-029: Hardcoding Level Prompt (Few-Shot Data Leaks & Regurgitasi Contoh Literal)
- **Fitur:** `AFMLunaCoordinationBridge (Prompt Engineering & Dynamic Reasoning Engine)`
- **Gejala:** Saat pengguna menanyakan *"email ketiga dari atas apa ya?"*, agen menjawab dengan data email pertama: *"Email terakhir yang masuk ke kotak masuk Anda berasal dari OpenAl dengan subjek 'New sign-in to your OpenAl account' yang diterima pada pukul 18:19."*
- **Kesalahan (Root Cause Faktual):**
  1. **Injeksi Data Literal di System Prompt:** Pada `validateWithAFM` (`AFMLunaCoordinationBridge.swift:469-474`) dan `deconstructTaskGoalWithAFM` (`L155-L158`), instruksi prompt memuat contoh literal konkret seperti `"OpenAI / New sign-in / 18:19"`, `"targetEntity": "topmost_inbox_item"`, dan kalimat contoh jawaban Bahasa Indonesia.
  2. **Few-Shot Overfitting & Prompt Regurgitation pada Model On-Device 3B:** Model lokal berukuran ringkas menelan teks contoh tersebut dan menyalinnya ke output alih-alih mengekstrak baris email ke-3 yang sebenarnya di layar.
  3. **Penguncian Persepsi Model:** Kalimat instruksi seperti *"The newest/latest email is ALWAYS row 1"* membuat model tidak fleksibel saat pengguna meminta baris ke-2, ke-3, atau kriteria ordinal lainnya.
- **Aturan Pencegahan (Invariant):**
  1. **Zero Prompt-Level Hardcoding:** DILARANG KERAS menyertakan nama data spesifik, nilai default kaku, atau kalimat contoh jawaban konkret ke dalam prompt.
  2. **Abstract Placeholder Schemas:** Seluruh skema contoh WAJIB menggunakan placeholder abstrak (misal: `<intentType>`, `<targetEntity>`, `<factualData>`, `<responseInUserLanguage>`).
  3. **Universal Positional Reasoning:** Model penalaran WAJIB membaca posisi ordinal apa pun ("pertama", "kedua", "ketiga", "terakhir", dll.) secara dinamis dari kata-kata pengguna dan mencocokkannya ke indeks baris observasi yang sesuai.

---

### ERR-030: Inkonsistensi Status Kartu "Failed" Saat Data Faktual Terjawab & Pembauran OCR Tanpa Pengelompokan Baris
- **Fitur:** `TaskEgressValidator / CompanionVMAgentLoop (Status Reconciliation & Spatial Y-Band OCR Clustering)`
- **Gejala:** Kartu asisten di chat ditandai merah `● Failed`, padahal teks jawaban di chat bubble di bawahnya berhasil menampilkan isi email (`"Anda dapat melihat pesan berikut dalam kotak inbox pertama: ..."`), serta isi subjek email baris 2 (Chess.com) tertukar dengan baris 1 (OpenAI).
- **Kesalahan (Root Cause Faktual):**
  1. **Egress Validator Menunggu Panel Preview:** Ketika jendela Mail menampilkan daftar email di sisi kiri namun panel preview di sisi kanan masih bertuliskan *"No Message Selected"*, model AFM menganggap tugas belum tuntas (`isDone: false`) meskipun data pengirim, waktu, dan subjek sudah terbaca jelas pada daftar baris email.
  2. **Inkonsistensi State Machine Loop:** Di `CompanionVMAgentLoop.swift:279`, variabel `isTaskSuccessful` terikat kaku pada nilai boolean `validation.isDone`. Ketika validator mengembalikan `isDone: false` namun menyertakan data faktual (`extractedData: "OpenAI..."`), `finishTask` tetap menandai status kartu sebagai `.failed`.
  3. **Vision OCR Flat-Dump Tanpa Pengelompokan Spasial:** Pada `CompanionVMAgentLoop.swift:readElements`, hasil deteksi `VNRecognizeTextRequest` digabungkan secara mentah menjadi string datar tanpa pengelompokan baris horizontal Y-band, menyebabkan model bingung membedakan teks Baris 1 (OpenAI) dengan Baris 2 (Chess.com).
- **Aturan Pencegahan (Invariant):**
  1. **Kecukupan Data Baris Daftar untuk Inspeksi:** Detail baris daftar (pengirim, waktu, subjek/cuplikan) resmi dinyatakan sah dan memadai untuk memenuhi tujuan inspeksi (`isDone: true`) tanpa mewajibkan panel preview tubuh email terbuka penuh.
  2. **Rekonsiliasi Status Keberhasilan (Factual Extraction Consistency Guard):** Jika `extractedData` berisi fakta konkret dan bukan placeholder, `effectiveIsDone` pada validator dan `isTaskSuccessful` pada loop agen WAJIB otomatis bernilai `true` (kartu berstatus `.done`).
  3. **Spatial Y-Band Clustering:** Seluruh hasil teks OCR dari Vision wajib dikelompokkan secara horizontal berdasarkan koordinat `boundingBox.midY` (Y-band proximity `< 0.035`), diurutkan dari atas ke bawah (Y descending) dan kiri ke kanan (X ascending), menghasilkan struktur baris `[Row 1] Pengirim | Waktu | Subjek` yang rapi dan bebas ambiguitas.

---

### ERR-031: Ketidakakuratan Indeks Ordinal Akibat Ketiadaan Pemisahan Section UI Layar
- **Fitur:** `CompanionVMAgentLoop / TaskStepPlanner / TaskEgressValidator (Structured Section-Based Observation JSON)`
- **Gejala:** Pengguna meminta *"pesan keempat dari atas apa ya?"*, namun asisten membaca pesan kedua (Chess.com) alih-alih pesan keempat sebenarnya (Steam).
- **Kesalahan (Root Cause Faktual):**
  1. **Pencampuran Kolom Lebar Penuh (Sidebar & Message List):** Deteksi visual Y-band sebelumnya mengambil seluruh lebar layar (`x: 0.0 .. 1.0`), sehingga item sidebar kiri (`All Drafts`, `All Sent`) tercampur ke dalam daftar baris observasi.
  2. **Multi-Line per Pesan Dilabeli sebagai `[Row N]` Terpisah:** Setiap satu kartu email terdiri dari 2–3 baris teks (pengirim, subjek, cuplikan). Melabeli setiap baris visual tipis sebagai `[Row 1]`, `[Row 2]`, `[Row 3]`, `[Row 4]`, `[Row 5]` membuat Email #1 memakan Row 2–3, sidebar memakan Row 4, dan Email #2 (Chess.com) memakan Row 5.
  3. **Penjajaran Literal Target Index ke Label Row:** Model on-device menyamakan target index `4` dengan teks label `[Row 4]` / `[Row 5]` (yang memuat Chess.com), padahal pesan visual ke-4 sebenarnya (Steam) berada di Row 9.
  4. **Ketiadaan Observasi Awal di Langkah 1:** Loop agen memulai langkah 1 dengan `lastObservation = nil`, memaksa perencana menebak aksi (scroll) padahal item target sudah terpampang di layar.
- **Aturan Pencegahan (Invariant):**
  1. **Structured Section-Based Observation JSON:** Seluruh observasi visual layar WAJIB dipartisi ke dalam section spasial yang tegas:
     - `topBar`: Tombol toolbar, judul jendela, jumlah pesan, kotak pencarian.
     - `sidebar`: Kategori navigasi, folder, mailbox, akun di sebelah kiri (`x <= 0.17`).
     - `listItems`: Array kartu pesan terurut dengan field eksplisit `index` (1, 2, 3...) dan `content` (pengirim + waktu + subjek + cuplikan) dalam rentang satu kartu (`Δy ≈ 0.085`).
     - `previewPane`: Penampil detail isi pesan di sebelah kanan (`x >= 0.55`).
  2. **Initial Observation Injection:** Langkah 1 pada loop CUA WAJIB menyuntikkan `Initial screen state` terstruktur sebelum model planner dipanggil, sehingga perencana mengetahui kondisi layar nyata sejak awal.
  3. **Explicit Index Matching:** Perencana dan validator WAJIB mengarahkan pencocokan target indeks ke elemen `listItems[index: N]`, menjamin indeks ordinal selalu 100% konsisten dengan kartu fisik di layar.

---

### ERR-032: Jendela Compose Tertinggal di Layar Luar & Penumpukan Kartu Komputer di Feed Chat
- **Fitur:** `MascotVirtualDesktopService / CompanionWindowStreamService / HomeSpaceRootView (xAI Grok Bot Paradigm & Multi-Window Streaming)`
- **Gejala:** 
  1. Saat pengguna meminta kirim/tulis email, workspace gagal menampilkan form "New Message" dan tetap menayangkan "All Inboxes" karena jendela compose tertahan di luar layar host.
  2. Setiap turn CUA membuat kartu komputer baru raksasa di dalam feed chat, menyebabkan kartu komputer bertumpuk saat scroll.
- **Kesalahan (Root Cause Faktual):**
  1. `MascotVirtualDesktopService.swift` memiliki AppleScript hardcoded `if "\(appName)" is "Mail" then set inboxWins to (every window whose name contains "Inbox"...)` yang hanya memindahkan jendela Inbox ke virtual display, meninggalkan jendela baru ("New Message") di koordinat luar layar host (`X: 7312`).
  2. `CompanionWindowStreamService.swift` memiliki pengurutan kaku `aIsInbox != bIsInbox` yang memprioritaskan jendela Inbox dibanding jendela depan aktif.
  3. `HomeSpaceRootView.swift` merender `HomeSpaceComputerCardView` di dalam `ForEach(displayedMessages)` di setiap pesan asisten, sehingga setiap aksi menghasilkan satu kanvas desktop baru yang menumpuk.
- **Aturan Pencegahan (Invariant):**
  1. **Universal Multi-Window Relocation:** AppleScript & AXUIElement WAJIB memindahkan seluruh jendela aplikasi aktif (`repeat with win in windows`) ke koordinat virtual display tanpa filter string nama "Inbox".
  2. **Natural Z-Order Window Streaming:** Streamer WAJIB mempertahankan urutan z-order alami WindowServer dan menangkap jendela depan aktif (`window 1` / frontmost) tanpa pengurutan hardcoded.
  3. **Single Anchored Workspace (xAI Grok Bot Paradigm):** Chat feed HANYA memiliki 1 kartu workspace komputer tunggal yang ter-anchor di bagian atas (dapat di-collapse/expand). Riwayat chat hanya menampilkan bubble tanda terima ringkas (`HomeSpaceComputerReceiptView`), menjamin feed chat tetap bersih dan kanvas tidak pernah bertumpuk.

---

### ERR-033: Kartu Komputer Beku di Atas Feed Saat Scroll, Kegagalan Routing Jendela Inbox, & Draf Tanpa Notifikasi Human-in-the-Loop
- **Fitur:** `HomeSpaceRootView / CompanionWindowStreamService / TaskStepPlanner / TaskEgressValidator (Scrollable In-Feed Workspace & Window Intent Routing & Send Protocol)`
- **Gejala:** 
  1. Kartu komputer tetap membeku di atas jendela chat dan tidak ikut bergerak saat feed di-scroll, serta tetap memakan 70% layar walaupun tugas sudah `.done`.
  2. Saat pengguna meminta memeriksa email ("coba check email saya"), layar tidak berpindah ke jendela daftar email utama ("All Inboxes") melainkan tetap menayangkan jendela draf ("Test") yang terbuka dari sesi sebelumnya, menyebabkan AI salah membaca isi draf sebagai email inbox.
  3. Pada tugas kirim email, AI hanya membuat draf dan tidak menekan tombol Send, namun langsung mengklaim selesai tanpa memberi tahu pengguna bahwa draf memerlukan konfirmasi/tindakan pengiriman (Human-in-the-Loop).
- **Kesalahan (Root Cause Faktual):**
  1. `HomeSpaceComputerCardView` diletakkan di luar `ScrollView` dan terus dirender selama ada pesan riwayat masa lalu, bukannya digate pada status `.working` / `.takeoverNeeded` di dalam `ScrollView`.
  2. `findCandidateWindows` dan `assignAppToVirtualDesktop` tidak memperhitungkan `intentType` tugas, sehingga jendela draf yang kebetulan berada di depan tetap dijadikan target stream untuk tugas inspeksi inbox.
  3. `TaskStepPlanner` tidak menginstruksikan klik tombol "Send" setelah pengisian form pesan selesai, dan `TaskEgressValidator` tidak memverifikasi apakah pesan benar-benar terkirim atau hanya tersimpan sebagai draf yang belum dikirim.
- **Aturan Pencegahan (Invariant):**
  1. **In-Feed Scrollable Workspace:** Kartu workspace komputer WAJIB berada di dalam `ScrollView` dan HANYA aktif saat status `.working` atau `.takeoverNeeded`. Saat `.done`, kartu otomatis digantikan oleh tanda terima ringkas `HomeSpaceComputerReceiptView` yang dapat di-tap untuk membuka modal.
  2. **Window Intent Routing:** Saat intent adalah `inspect` / `read` / `search`, sistem WAJIB mengarahkan dan memprioritaskan jendela viewer/inbox utama (`index 1`). Saat intent adalah `compose` / `send`, jendela compose yang diprioritaskan.
  3. **Explicit Send & Human-in-the-Loop Transparency:** AI wajib mengeksekusi klik tombol "Send" jika diminta mengirim email. Jika pengiriman tertahan sebagai draf atau memerlukan konfirmasi pengguna, AI WAJIB secara transparan memberitahukan pengguna di chat bahwa draf telah disiapkan dan belum dikirim.

---

### ERR-034: Layar Komputer Terpisah di Paling Atas Chat, Langkah Terputus, dan Crash textunderstandingd / dyld
- **Fitur:** `HomeSpaceRootView / HomeSpaceComputerStepsView / TaskStepPlanner / TaskEgressValidator / MascotVirtualDesktopService (Single Dynamic Inline Computer Viewport & Crash Resiliency)`
- **Gejala:** 
  1. Aplikasi mengalami crash berulang (`ExcUserFault_textunderstandingd` / dyld library mismatch) saat tugas CUA dipicu.
  2. Layar komputer dirender di bagian paling atas chat di atas pesan lama ("halo") terpisah jauh dari prompt pengguna ("check email saya tolong") yang berada di bawah.
  3. Step kerja tidak berada di bawah layar komputer, dan saat aksi baru dipicu, layar komputer tidak berpindah ke bawah mengikuti aksi baru sementara aksi lama tidak meninggalkan step kerja yang selesai.
- **Kesalahan (Root Cause Faktual):**
  1. `HomeSpaceComputerCardView` diletakkan di luar dan sebelum `ForEach(displayedMessages)` di dalam `ScrollView`, sehingga selalu tampil di urutan teratas feed di atas pesan lama.
  2. Ketiadaan komponen `HomeSpaceComputerStepsView` yang membedakan giliran aktif (`latestComputerMessageId`) dan giliran masa lalu (`isPastTurn`), sehingga step kerja terputus dari kartu komputer.
  3. Instruksi system prompt dan payload `lastObservation` pada `TaskStepPlanner` dan `TaskEgressValidator` terlalu panjang (>2 KB) dan tanpa batas ukuran, menyebabkan assertion user fault pada daemon Apple Foundation Models on-device (`textunderstandingd`).
  4. Penggunaan blocking `usleep` di dalam `performCuaType` pada MainActor memblokir thread UI.
  5. Peluncuran binary tanpa skrip `scripts/launch_app.sh` memicu kegagalan dyld akibat perbedaan signature Team ID pada `boringNotch.debug.dylib`.
- **Aturan Pencegahan (Invariant):**
  1. **Single Dynamic Inline Computer Viewport:** Layar komputer WAJIB diletakkan di dalam giliran pesan asisten yang aktif (`message.id == latestComputerMessageId`). Saat perintah baru masuk, layar komputer otomatis berpindah ke bawah ke giliran baru, sementara giliran sebelumnya meninggalkan daftar langkah kerja yang telah selesai (`HomeSpaceComputerStepsView(isPastTurn: true)`).
  2. **Bounded AFM Context Length:** String observasi layar visual WAJIB dipotong maksimal 1000 karakter, dan system instruction dibuat ringkas (<600 karakter) untuk mencegah crash user-fault pada daemon on-device.
  3. **Non-Blocking CUA Virtual Action:** Seluruh virtual type dan virtual click WAJIB dieksekusi secara asynchronous di background thread tanpa memblokir MainActor dengan `usleep`.
  4. **Strict Launch & Sign Protocol:** Selalu gunakan `./scripts/launch_app.sh` yang menjalankan codesign deep entitlement untuk memastikan dyld link valid.

---

### ERR-035: Kegagalan Prioritas Jendela Inbox Mail Terhalang Jendela Draf & Langkah Kerja Kosong di Bawah Layar
- **Fitur:** `CompanionWindowStreamService / MascotVirtualDesktopService / HomeSpaceComputerCardView (All Inboxes Priority & Unified Inline Step Queue)`
- **Gejala:** 
  1. Saat pengguna meminta memeriksa email ("coba check email saya"), layar komputer menangkap dan menampilkan jendela draf ("Test") alih-alih daftar email utama ("All Inboxes").
  2. Langkah-langkah aksi (steps) tidak muncul di bawah kanvas komputer di dalam kartu, sehingga kartu tampak kosong di bawah layar.
- **Kesalahan (Root Cause Faktual):**
  1. Logika fallback `(!title.contains("new message") && !title.contains("pesan baru") && !title.contains("draf"))` di `CompanionWindowStreamService.swift` mengevaluasi `true` untuk jendela draf yang memiliki subjek "Test", sehingga langsung dipilih mendahului "All Inboxes" yang berada di antrean berikutnya.
  2. Di `MascotVirtualDesktopService.swift`, AppleScript mengeksekusi loop `set bounds` SETELAH `set index of item 1 of inboxWins to 1`, yang mereset kembali urutan z-order WindowServer sehingga jendela draf tetap duduk di depan.
  3. Di `HomeSpaceComputerCardView.swift`, antrean langkah kerja (steps) sebelumnya tidak di-embed di bawah kanvas kanvas komputer di dalam kartu, dan di `HomeSpaceRootView.swift` langkah kerja terpisah di luar kartu hanya dirender jika `queueItems` tidak kosong. Jika AFM tidak menyediakan subgoals awal, langkah tidak tertampil sama sekali.
- **Aturan Pencegahan (Invariant):**
  1. **Strict Inbox Window Priority:** Untuk intent `inspect` / `read` / `search` pada aplikasi Mail, kandidat jendela WAJIB mencocokkan judul kanonikal inbox ("inbox", "all inboxes", "kotak masuk", "semua kotak masuk") secara ketat sebelum mempertimbangkan jendela lain.
  2. **Post-Bounds Window Stacking:** AppleScript WAJIB mengeksekusi `set index of item 1 of inboxWins to 1` SETELAH loop penetapan bounds selesai agar jendela inbox dipastikan menjadi frontmost di WindowServer.
  3. **Embedded In-Card Steps Queue:** Antrean langkah kerja WAJIB di-embed langsung di dalam `HomeSpaceComputerCardView` persis di bawah kanvas layar komputer ("stepnya itu tetap dibawah computernya"). Ketika aksi baru dimulai, kanvas komputer berpindah ke giliran berikutnya sementara giliran sebelumnya meninggalkan receipt langkah kerja yang telah selesai (`HomeSpaceComputerStepsView(isPastTurn: true)`).
  4. **Fallback Sub-goals Invariant:** `CompanionVMAgentLoop` WAJIB menginisialisasi sub-goals terstruktur berbasis intent jika parser tidak menghasilkan sub-goals, sehingga antrean langkah tidak pernah kosong.

---

### ERR-036: Hardcoding Seleksi Jendela & Fallback Sub-goals Berbasis Nama Aplikasi
- **Fitur:** `CompanionWindowStreamService / MascotVirtualDesktopService / CompanionVMAgentLoop (Universal Dynamic Entity Grounding)`
- **Gejala:** Kode logika mengandalkan pengecekan spesifik `if cleanTarget == "mail"` dan AppleScript `if "\(appName)" is "Mail"`, serta fallback langkah kerja hardcoded dengan string bahasa Indonesia ("kotak masuk"), yang melanggar invariant kedaulatan non-hardcoding untuk aplikasi lain (Safari, Notes, Terminal, TradingView, dll.).
- **Kesalahan (Root Cause Faktual):**
  1. `CompanionWindowStreamService.swift` memiliki blok percabangan kaku `if cleanTarget == "mail"` dengan string statis `"inbox"`, `"all inboxes"`, `"kotak masuk"`, `"new message"`, `"draf"`.
  2. `MascotVirtualDesktopService.swift` memiliki skrip AppleScript khusus `if "\(appName)" is "Mail"` yang hanya memeriksa string nama jendela Mail.
  3. `CompanionVMAgentLoop.swift` memiliki fallback antrean langkah kerja dengan teks literal `"kotak masuk"`.
- **Aturan Pencegahan (Invariant):**
  1. **Zero App-Specific Branching:** DILARANG KERAS menyisipkan percabangan nama aplikasi statis (`if appName == "Mail"`) di level layanan streaming jendela atau AppleScript.
  2. **Universal Dynamic Entity Token Matching:** Seleksi kandidat jendela WAJIB 100% menggunakan token matching dinamis antara `activeTargetEntity` dari dekomposisi AFM terhadap judul jendela WindowServer (`CGWindowListCopyWindowInfo`).
  3. **Universal Window Raising by ID:** AppleScript WAJIB menaikkan jendela ke index 1 menggunakan ID jendela numerik kanonikal (`every window whose id is \(firstCandidate.windowId)`), berlaku seragam untuk semua aplikasi macOS.
  4. **Dynamic Abstract Sub-goals:** Seluruh sub-goals WAJIB berasal dari dekomposisi dinamis AFM (`plannedSubGoals`) atau fallback abstrak murni berbasis `normalizedGoal` dan `appName` tanpa string bahasa atau aplikasi spesifik.

---

### ERR-037: Prompt Tag Leak, Pemotongan Langkah Draf Tanpa Send, dan Penutupan Daftar Inbox oleh Draf Terbengkalai
- **Fitur:** `TaskEgressValidator / TaskStepPlanner / CompanionWindowStreamService / HomeSpaceComputerCardView (Prompt Tag Stripping, Direct Send & Takeover Gate, Collection Window Priority)`
- **Gejala:** 
  1. Teks respons pengguna diawali dengan tag literal `<answer in Bahasa Indonesia>`.
  2. Respons "check email saya" menyajikan audit evaluasi diri internal teknis ("Tidak, tujuan untuk membaca email di indeks 1 belum tercapai...") alih-alih menyajikan langsung isi email kepada pengguna.
  3. Perintah "kirim email" berhenti di pembuatan draf tanpa mengeksekusi klik Send dan tanpa tombol Take Over Screen untuk memaksimalkan workspace.
  4. Perintah berikutnya ("check email kedua dari atas") gagal kembali ke daftar email karena terhalang jendela draf yang belum terkirim/terhapus, dan AI berhalusinasi mengklaim memeriksa email kedua padahal tampilan layar masih berupa jendela draf.
- **Kesalahan (Root Cause Faktual):**
  1. Di `TaskEgressValidator.swift:39`, skema prompt menggunakan contoh literal `"responseToUser":"<answer in \(targetLanguageName)>"` yang ditiru mentah-mentah oleh model ringkas on-device (AFM 3B parameter), dan ketiadaan regex sanitasi untuk membersihkan tag kurung sudut.
  2. Model diminta mengevaluasi pemenuhan target, sehingga model mengisi `responseToUser` dengan kalimat evaluasi audit internal dan mengabaikan penyajian data faktual yang sebenarnya sudah tersimpan di `extractedData`.
  3. `TaskEgressValidator` langsung mengembalikan `isDone: true` begitu kolom draf terisi, sehingga `CompanionVMAgentLoop` keluar dari loop sebelum `TaskStepPlanner` merencanakan klik tombol "Send". Selain itu status disetel `.done` (bukan `.takeoverNeeded`), sehingga tombol Take Over Screen tidak ditampilkan.
  4. Di `CompanionWindowStreamService.swift`, seleksi jendela kandidat untuk intent `inspect` / `read` tidak memprioritaskan jendela koleksi ("All Inboxes") di atas jendela compose/draft ("Test"), sehingga jendela draf yang berada di depan terus dijadikan target stream.
- **Aturan Pencegahan (Invariant):**
  1. **Zero Prompt Tag Placeholders & Aggressive Sanitization:** Dilarang menggunakan kurung sudut `<...>` dalam contoh nilai string JSON skema. Sanitasi `responseToUser` wajib menghapus tag `<...>` sebelum dikembalikan.
  2. **User-Facing Direct Factual Synthesis:** `responseToUser` WAJIB berupa kalimat ramah langsung ke pengguna menyajikan fakta temuan. DILARANG mengekspos evaluasi audit internal ("tujuan belum tercapai"). Jika `extractedData` memiliki fakta, sajikan fakta tersebut secara positif.
  3. **Strict Send Goal Execution & Takeover Gate:** Jika intent adalah `send` / kirim email, pembuatan draf BUKAN penanda selesai. Agen wajib melanjutkan langkah hingga tombol "Send" diklik, ATAU jika memerlukan konfirmasi pengguna, status WAJIB menjadi `.takeoverNeeded` dengan tombol **[ ✋ Take Over ]** langsung di baris langkah untuk memaksimalkan workspace.
  4. **Strict Collection Viewer Priority:** Untuk intent `inspect` / `read` / `search`, jendela viewer koleksi ("inbox", "kotak masuk", "all inboxes") WAJIB diprioritaskan di atas jendela compose/draft, dan dinaikkan ke index 1 agar daftar item tidak terhalang draf lama.

---

### ERR-038: Language Slip ke Bahasa Inggris, Viewport Mail Tertinggal Scroll Lama, dan Kursor CUA Tanpa Gliding / Mengintervensi Takeover
- **Fitur:** `TaskIngressGateway / TaskEgressValidator / MascotVirtualDesktopService / InteractiveVirtualDesktopView (Language Anchoring, Auto-Scroll-to-Top, Animated CUA Cursor & Takeover Sovereignty)`
- **Gejala:** 
  1. Prompt bahasa Indonesia dengan kata serapan ("oke batalkan coba check email yang ketiga dari atas") menghasilkan respons bahasa Inggris ("The third email in your inbox is from Instagram... The operation has been cancelled.").
  2. Saat memeriksa email, tampilan daftar pesan di Mail tertinggal di posisi scroll jauh ke bawah (tahun 2020), sehingga tidak menampilkan email paling baru pengguna (UNIQLO hari ini).
  3. Pengguna tidak melihat kursor mouse yang bergerak di workspace virtual saat AI beroperasi (hanya lingkaran statis yang mendadak muncul), dan saat Takeover diaktifkan kursor AI reticle `⚡` muncul di bawah klik mouse pengguna alih-alih memberikan kedaulatan kursor fisik pengguna.
- **Kesalahan (Root Cause Faktual):**
  1. Di `TaskIngressGateway.swift`, kata serapan ("oke", "check", "email") menyebabkan model mengklasifikasikan `userLanguage` sebagai `"en"`. Di `TaskEgressValidator.swift`, `targetLanguageName` menjadi `"English"` dan menghasilkan respons bahasa Inggris.
  2. Mail.app pada sistem pengguna memiliki 20.892 pesan dengan posisi scroll tabel yang tertinggal di bawah. Tanpa penyeleksian pesan teratas terprogram, Mail tidak menggeser scroll position ke pesan terbaru.
  3. Di `MascotVirtualDesktopService.swift`, `performCuaClick` hanya menyetel koordinat `virtualReticle` statis tanpa komponen panah kursor macOS dan tanpa jeda glide visual sebelum aksi. Saat Human Takeover, `handleUserViewClick` memanggil `performCuaClick` yang mengeset `self.virtualReticle = normalizedPoint`, memicu reticle AI muncul di bawah kursor asli pengguna.
- **Aturan Pencegahan (Invariant):**
  1. **Deterministic Indonesian Language Anchor:** Jika prompt pengguna mengandung kata fungsi/partikel/kosakata bahasa Indonesia (`yang`, `dari`, `di`, `ke`, `ini`, `itu`, `saya`, `kamu`, `bisa`, `tolong`, `coba`, `batalkan`, `ketiga`, `kedua`, dll.), `userLanguage` WAJIB secara deterministik dikunci ke `"id"`. Validator wajib memiliki guard terhadap slip bahasa Inggris.
  2. **Automatic Snap-to-Top on List Inspection:** Saat intent `inspect` / `read` / `search` dijalankan pada Mail, sistem WAJIB secara otomatis memilih pesan terbaru teratas (`set selected messages of message viewer 1 to {newestMsg}`) agar antarmuka segera melakukan scroll ke email paling mutakhir.
  3. **Visual CUA Cursor Gliding vs Takeover Sovereignty:**
     - Saat AI bekerja (`!isInteractive`): Tampilkan kursor panah macOS nyata (`MascotAgentCursorView`) dengan aksen neon biru `#38BDF8` yang meluncur secara halus (`easeInOut 0.35s`) ke elemen target sebelum aksi, lengkap dengan efek click ripple ring.
     - Saat Human Takeover (`isInteractive == true`): Sembunyikan 100% kursor AI (`virtualReticle = nil`), gunakan `NSCursor.arrow` asli macOS, dan kirim klik via `handleUserDirectClick` langsung ke PID tanpa menyentuh `virtualReticle`.


---

### ERR-039: Pintasan Per-Aplikasi (Snap-to-Top AppleScript), Kursor Menghilang Sesaat, dan Hardcoding Prompt/Dock/Path
- **Fitur:** `MascotVirtualDesktopService / CompanionVMAgentLoop / TaskStepPlanner / HomeSpace (Pure Physical CUA Cursor Hands Paradigm & Zero App-Specific Cheats / Hardcodes)`
- **Gejala:** Interaksi UI mengandalkan pintasan spesifik per-aplikasi (seperti snap-to-top AppleScript di Mail), kursor CUA hanya muncul sesaat dan hilang, prompt dan logic membocorkan aturan khusus Mail ("All Inboxes", "To/Subject/Body", "Send button", fallback `?? "Mail"`), serta dock takeover yang di-hardcode ke 2 tombol statis ("mail", "safari").
- **Kesalahan (Root Cause Faktual):**
  1. Adanya skrip AppleScript `snapToTopMail` di `MascotVirtualDesktopService.swift` untuk memotong proses scroll fisik.
  2. Ketiadaan primitif tangan fisik CUA universal (`right_click`, `scroll_up`, `scroll_down`, `press_and_hold`, `drag`) dan `virtualReticle` bernilai opsional yang disembunyikan saat idle.
  3. Instruksi prompt di `TaskStepPlanner.swift` berisi aturan literal spesifik Mail ("All Inboxes", "compose or draft window is open blocking the inbox", dll.).
  4. Penemuan URL aplikasi dan penutupan jendela di `CompanionWindowStreamService.swift` dan `MascotVirtualDesktopService.swift` memiliki percabangan statis `if clean == "mail"`.
  5. Antarmuka dock di `HomeSpaceInteractiveComputerModalView.swift` memiliki tombol statis `dockAppButton(appName: "mail")` dan `dockAppButton(appName: "safari")`.
  6. String literal fallback `?? "Mail"` tersebar di berbagai view.
- **Aturan Pencegahan (Invariant):**
  1. **Universal Pure Physical Mouse Hands:** Interaksi UI WAJIB 100% menggunakan tangan fisik mouse: `left_click`, `right_click` (2-finger click), `mouse_down` / `mouse_up` (`press_and_hold`), `scroll_up` / `scroll_down` (2-finger swipe wheel), `drag`, dan `type`. DILARANG KERAS menggunakan pintasan keyboard per-aplikasi atau AppleScript manipulasi data untuk menyelesaikan masalah UI.
  2. **Cursor Always Stay & Ready:** Kursor virtual maskot di workspace terisolasi SELALU hadir (stay and ready, non-optional `CGPoint(0.5, 0.5)` default) di kanvas, meluncur halus dari posisinya ke elemen target, bukan muncul dan hilang sesaat.
  3. **Strict See ➔ Plan ➔ Act Cycle:** Setiap langkah dalam loop CUA WAJIB mengambil snapshot observasi layar segar terlebih dahulu sebelum memanggil perencana langkah (Planner). Model AI merencanakan aksi fisik dinamis berdasarkan apa yang dilihatnya di layar.
  4. **Universal Dynamic App Discovery & Window Matching:** Penemuan aplikasi wajib menggunakan `NSWorkspace` dan `InstalledAppsDiscoveryService`. Pencocokan proses dan jendela menggunakan nama target dinamis tanpa `if-else` nama aplikasi.
  5. **Dynamic Dock & Zero Literal App Fallbacks:** Dock modal takeover wajib me-looping `companion.activeBuddy.workflowAppNames`. Seluruh fallback aplikasi wajib menggunakan `companion.activeBuddy.workflowAppNames.first ?? "Workspace"`.
  6. **Abstract Canonical Prompts:** Dilarang menyebutkan nama elemen atau skenario spesifik aplikasi tertentu di system prompt Planner atau Validator. Gunakan tipe aksi abstrak dan aturan navigasi visual universal.


---

### ERR-040: Bubble Chat Kosong, Loop Redundan 6x `listItems[1].content`, dan Dead Mock Storage
- **Fitur:** `TaskEgressValidator / CompanionVMAgentLoop / CUAPhysicalActionDispatcher (Empty Chat Response, Redundant Loop, Modular CUA Action Tools & Dead Mock Cleanup)`
- **Gejala:** 
  1. Pengguna melihat pesan chat bot berupa bubble kosong (hanya timestamp tanpa teks jawaban).
  2. Asisten mengulang-ulang langkah `listItems[1].content` hingga batas maksimum 6 langkah meskipun di langkah 1 email sudah berhasil diobservasi.
  3. Kursor fisik AI jatuh di pojok kiri atas kanvas karena menargetkan nama teknis `listItems[1].content` alih-alih elemen visual manusia.
  4. Kode memuat dead mock storage `SandboxedEmailRecord` dengan email dummy hardcoded `rezkyhaikal2@gmail.com`.
- **Kesalahan (Root Cause Faktual):**
  1. Di `TaskEgressValidator.swift:124`, parser `parseValidationJSON` hanya mengekstrak key `responseToUser`, padahal model on-device meletakkan ringkasan hasil email pada `systemState`. Karena `responseToUser` kosong dan tidak memiliki fallback, nilainya tetap `""`.
  2. Di `CompanionVMAgentLoop.swift:496`, kondisi pemutusan loop mensyaratkan `!validation.responseToUser.isEmpty`. Karena kosong, loop tidak berhenti di langkah 1 dan terus berputar hingga 6 langkah. Pada rekonsiliasi akhir (baris 513), `finalResponseToUser = lastVal.responseToUser` menyalin string kosong tersebut ke chat (`Report finding: ""`).
  3. `TaskStepPlanner.swift` tidak memiliki panduan larangan menjiplak format JSON (`listItems[...]`), dan tidak memiliki instruksi untuk menandai `done` ketika informasi target telah terlihat di layar.
  4. Eksekusi CUA fisik tertumpuk dalam blok `else-if` raksasa di dalam file loop orchestrator, serta memuat sisa kode eksperimen dummy email `loadSandboxEmails`.
- **Aturan Pencegahan (Invariant):**
  1. **Guaranteed Non-Empty Response Fallback:** `TaskEgressValidator` dan `CompanionVMAgentLoop` WAJIB menjamin respon ke pengguna tidak pernah string kosong jika `systemState` atau `extractedData` memiliki informasi faktual.
  2. **Early Loop Exit on Verified Fact:** Jika validator menyatakan `isDone: true` atau data faktual telah terekstraksi, loop CUA WAJIB segera berhenti tanpa membuang langkah ekstra.
  3. **No Internal JSON Path as Target Element:** Planner dilarang keras menggunakan identifier kode/JSON path sebagai `targetElement`. Wajib menggunakan nama visual manusia.
  4. **Strict Modular CUA Action Tool Separation:** Seluruh aksi kursor fisik (`click`, `scroll`, `type`, `read`) WAJIB dipisahkan ke tool file mandiri di bawah `Clicky/Tools/Actions/` dengan `CUAPhysicalActionDispatcher`. DILARANG menyatukan seluruh logika eksekusi fisik ke dalam blok `else-if` file loop.
  5. **Absolute Zero Dead Mockups:** Dilarang menyimpan file/fungsi dummy mock data di dalam file produksi.

---

### ERR-041: Biner Kadaluarsa (Stale Binary) & Nil-Coalescing pada String Kosong (`"" ?? fallback`)
- **Fitur:** `Build Pipeline / HomeSpaceRootView / CompanionVMAgentLoop (Stale Binary & Empty String Chat Bubble)`
- **Gejala:** Asisten tetap menjalankan 6 langkah berulang (`listItems[1]`, `listItems[2]`, `listItems[1].content`) dan bubble chat bot tetap kosong di 8.03 meskipun kode perbaikan sudah ditulis di source file.
- **Kesalahan (Root Cause Faktual):**
  1. **Stale Binary:** Perubahan file `CompanionVMAgentLoop.swift`, `TaskStepPlanner.swift`, dan `TaskEgressValidator.swift` di sesi sebelumnya tidak dikompilasi ulang menggunakan `xcodebuild`. File objek `.o` di DerivedData (`CompanionVMAgentLoop.o`, `TaskStepPlanner.o`, `TaskEgressValidator.o`) masih bertanggal 07:30 / 07:56, sehingga biner yang berjalan di 07:59 (PID 53449) masih mengeksekusi logika lama yang mensyaratkan `!validation.responseToUser.isEmpty` untuk break.
  2. **Nil-Coalescing `"" ?? fallback`**: Di `HomeSpaceRootView.swift:1473`, kode menggunakan `finalPayload.responseToUser ?? finalPayload.deliverableSummary ?? finalPayload.instructionText`. Di Swift, string kosong `""` adalah nilai String valid (BUKAN `nil`), sehingga operator `??` mengembalikan `""` tanpa mengevaluasi fallback di kanannya.
- **Aturan Pencegahan (Invariant):**
  1. **Strict Recompilation & Timestamp Assertion:** Setiap modifikasi file Swift WAJIB diikuti dengan `xcodebuild` bersih dan verifikasi timestamp file objek `.o` di DerivedData sebelum melaporkan ke pengguna.
  2. **Explicit Empty String Inspection:** DILARANG mengandalkan `??` untuk fallback nilai String. Selalu gunakan `if let s = str?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty` agar string kosong tidak pernah lolos ke antarmuka chat.

---

### ERR-042: Observasi Kosong Disalurkan ke Validator pada Selesai Dini Langkah 1
- **Fitur:** `CompanionVMAgentLoop / TaskEgressValidator (Early Finish Observation & Factual Response Synthesis)`
### ERR-043: Ketiadaan Cognitive Provenance Menempel pada Draf Lama & Residual Hardcoding String/Koordinat
- **Fitur:** `TaskStepPlanner / TaskEgressValidator / CompanionWindowStreamService / ClickyHybridGroundingEngine (Cognitive Provenance, Clean Workspace Anchor & Residual Hardcoding Eradication)`
- **Gejala:** 
  1. Saat pengguna meminta kirim email baru, asisten langsung membuka draf lama ("Test") yang sudah terisi di latar belakang dan langsung meminta Take Over Screen di langkah 1 alih-alih mengetik kolom satu per satu dari formulir baru yang bersih.
  2. Kode memuat residual hardcoding: `.contains("Sedang")`, `.contains("Menunggu konfirmasi")`, magic coordinate `CGPoint(x: 240, y: 160)`, kamus kata kunci email (`"to"`, `"subject"`, `"compose"`), dan fallback bundle ID `com.apple.mail`.
- **Kesalahan (Root Cause Faktual):**
  1. **Ketiadaan Kesadaran Riwayat (Zero Cognitive Provenance):** Model (AFM) tidak memiliki instruksi penalaran untuk membandingkan teks yang ada di layar dengan riwayat aksi sesi aktif (`Previous Steps`). Karena draf lama sudah ada sejak sebelum sesi dimulai, model menganggap draf itu adalah tugas yang sedang dikerjakannya, dan validator langsung mengira draf sudah selesai dibuat.
  2. **Prioritas Jendela Draf Usang:** Di `CompanionWindowStreamService.swift`, logika pemilihan jendela memprioritaskan token `"draft"` / `"draf"` dan jendela terdepan WindowServer alih-alih mengunci jendela utama workspace (`All Inboxes`).
  3. **Residual Hardcoding:** Filter teks kaku `.contains("Sedang")` dan koordinat tebakan buta (240, 160) dipasang untuk menambal kelemahan sensor, melanggar Rule 7 AGENTS.md.
- **Aturan Pencegahan (Invariant):**
  1. **Universal Cognitive Provenance:** Model wajib mengevaluasi apakah teks pada antarmuka merupakan hasil ketikan di `Previous Steps`. Jika ada formulir terisi yang bukan hasil ketikan sesi aktif, model wajib mengabaikannya dan membuat kanvas baru (*New/Create*).
  2. **Clean Workspace Window Anchor:** Tugas baru WAJIB berjangkar pada jendela utama workspace (`All Inboxes` / viewer utama). Luncurkan aplikasi dengan `-ApplePersistenceIgnoreState YES` agar macOS tidak memulihkan draf kotor dari masa lalu.
  3. **Strict Zero Hardcoding:** Evaluasi status WAJIB berbasis properti tipe `isDone` / `requiresTakeover`, koordinat fallback menggunakan titik tengah dinamis jendela aktif (`candidateWindows.first?.bounds`), dan pencocokan grounding menggunakan tokenisasi dinamis universal tanpa kamus kata kunci per-aplikasi.

---

### ERR-044: Residu Hardcoding Kata Kerja, Kamus Bahasa Manual, & Bypass Egress Validator di Loop Limit
- **Fitur:** `TaskIngressGateway / TaskEgressValidator / CompanionVMAgentLoop (ML Language Resolution, Zero-Verb-List Ingress & Unified Egress Delegation)`
- **Gejala:**
  1. Perintah pengguna yang memuat kata kerja tertentu dievaluasi secara kaku dengan daftar statis `actionVerbs = [...]`. Jika model AI gagal menghasilkan JSON dekomposisi, fallback-nya memaksakan dekomposisi asumtif `targetEntity: "inbox_item_1"` dan `targetIndex: 1` terlepas dari apa yang sebenarnya diminta pengguna (misal: "kirim email ke Doni" atau "tulis catatan").
  2. Deteksi bahasa mengandalkan set statis 40+ kata bahasa Indonesia dan 25+ kata bahasa Inggris di `resolveLanguage`, serta array statis `pureGreetings`.
  3. Saat loop mencapai batas langkah maksimum (`maxSteps`), `CompanionVMAgentLoop` membuat pesan sendiri menggunakan ternary kaku `(userLang == "id") ? "Langkah kerja pada \(appName) mencapai batas maksimum..." : "Task steps..."` alih-alih mendelegasikan ke model AI melalui `TaskEgressValidator`.
  4. `TaskEgressValidator` memiliki nama bahasa biner `(lang == "id") ? "Bahasa Indonesia" : "English"`, array ordinal statis `["pertama", "kedua", ...]`, dan template ganda `if lang == "id" { ... } else { ... }`.
- **Kesalahan (Root Cause Faktual):**
  1. `TaskIngressGateway.swift:145` menggunakan filter kata kerja statis dan memaksakan asumsi `inbox_item_1` pada kegagalan parsing model.
  2. `CompanionVMAgentLoop.swift:508` mengabaikan peran `TaskEgressValidator` sebagai AI Response Synthesizer dan membypass-nya dengan string ternary manual.
  3. `TaskEgressValidator.swift:32, 201` memuat percabangan bahasa biner dan array ordinal statis.
- **Aturan Pencegahan (Invariant):**
  1. **Dynamic ML Language Recognition:** DILARANG membuat kamus kata/marker bahasa statis atau salam statis. Gunakan Apple `NaturalLanguage` framework (`NLLanguageRecognizer`) on-device yang mendukung ratusan bahasa secara dinamis.
  2. **Abstract Ingress Fallback:** Fallback dekomposisi saat model gagal WAJIB netral dan abstrak (`targetEntity: "main_window"`, `targetIndex: nil`, `normalizedGoal: userPrompt`), tanpa asumsi entitas atau nomor urut tertentu.
  3. **Single Source of Truth for Egress (No Loop Bypass):** Seluruh status akhir tugas (termasuk batas langkah) WAJIB dialirkan ke `TaskEgressValidator` agar model AI yang menyusun pesan ramah langsung dalam bahasa pengguna (`userLanguage`).
  4. **Universal Locale Naming & Direct Factual Presentation:** Gunakan `Locale.localizedString(forLanguageCode:)` untuk nama bahasa universal, sajikan `extractedData` faktual secara langsung tanpa pembungkus template kaku, dan format nomor urut secara dinamis `#\(targetIdx)` tanpa array ordinal statis.

---

### ERR-045: Celah Kontradiksi AGENTS.md, Injeksi Token Literal di Prompt, & Residu Ternary Biner Bahasa
- **Fitur:** `TaskIngressGateway / TaskEgressValidator / CompanionVMAgentLoop / CompanionVMBackgroundWatcher (Injected Token List & Binary Ternaries Eradication)`
- **Gejala:** 
  1. Prompt sistem di `TaskIngressGateway.swift` memuat injeksi literal kata bahasa Indonesia (`'saya', 'yang', 'dari', 'coba', 'batalkan', 'ketiga', 'kedua', 'tolong', 'di', 'ke', 'ini', 'itu', 'atas', 'bawah'`).
  2. Pesan error izin bot (`CompanionVMAgentLoop.swift:186`), pesan takeover dialog sistem (`CompanionVMAgentLoop.swift:219, 262`), dan notifikasi proaktif (`CompanionVMBackgroundWatcher.swift:110`) menggunakan ternary biner `(userLang == "id") ? ... : ...` atau teks statis bahasa Indonesia.
  3. Pengguna menanyakan mengapa pelanggaran terus berulang dan apakah ada celah di `AGENTS.md`.
- **Kesalahan (Root Cause Faktual):**
  1. **Celah Kontradiksi Invariant di `AGENTS.md`:** Pada Bagian 6 (Invariant 1) `AGENTS.md`, aturan masa lalu secara eksplisit menuliskan: *"Jika prompt pengguna mengandung kata fungsi/partikel/kosakata bahasa Indonesia (`yang`, `dari`, `di`, `ke`, `ini`, `itu`, `saya`, `kamu`, dll.), userLanguage WAJIB dikunci ke 'id'"*. Aturan masa lalu ini bertentangan 180 derajat dengan Aturan 7 & 8 (Zero Hardcoding & Zero Literal Token Injection) dan membuat agen-agen sebelumnya mengira penyalinan daftar kata tersebut ke dalam prompt adalah instruksi wajib!
  2. **Bypass Model pada Kasus Pengecualian / Edge-Cases:** Pengembang menulis ternary biner `(userLang == "id") ? ... : ...` pada pesan error izin dan dialog sistem karena menganggap ini pesan sistem sepele yang tidak memerlukan panggilan model, sehingga mengabaikan arsitektur Egress Synthesis.
  3. **Teks Notifikasi Statis:** `CompanionVMBackgroundWatcher.swift:110` meng-hardcode kalimat alert email bahasa Indonesia.
- **Aturan Pencegahan (Invariant):**
  1. **Harmonisasi AGENTS.md Tanpa Injeksi Kata:** `AGENTS.md` Invariant 1 telah diperbarui total: dilarang mencantumkan daftar kata literal apa pun di dokumen aturan maupun prompt. Deteksi bahasa wajib 100% menggunakan Apple `NaturalLanguage` framework (`NLLanguageRecognizer`) dan model AI (ISO 639-1).
  2. **Universal Notice Synthesizer (`synthesizeNotice`):** Semua dialog peringatan sistem, penolakan akses izin bot, batas langkah, dan notifikasi proaktif latar belakang WAJIB memanggil `TaskEgressValidator.shared.synthesizeNotice(noticeSummary:appName:userGoal:userLanguage:)` secara asinkron agar model AI merumuskannya secara dinamis dan alami dalam bahasa pengguna (`userLanguage`), baik Indonesia, Inggris, Jepang, Prancis, dll.
  3. **Zero Binary Ternaries:** Dilarang keras menggunakan `(userLang == "id") ? ... : ...` di seluruh baris kode.

---

### ERR-046: Halo Memicu Computer Use, Residu String Matching `contains("send")`, & Campur Aduk Folder UI/Logic
- **Fitur:** `Clean Architecture Restructuring & Ingress Intent Gate (Frontend vs Logic Isolation & Autonomous Contract)`
- **Gejala:** 
  1. Pengguna mengetik sapaan "halo", namun asisten langsung membuka kartu Computer Use pada Mail.app dengan status Working alih-alih merespons sebagai obrolan ramah di chat.
  2. Folder `Clicky/Tools/` dan root `Clicky/` menampung lebih dari 60 file campur aduk antara UI view, virtual display, audio provider, dan reasoning pipeline.
  3. Logika pengecekan tugas pengiriman email mengandalkan string matching manual `(taskPlan?.intentType == "send") || (taskPlan?.normalizedGoal.contains("send"))` dan `contains("kirim")`.
- **Kesalahan (Root Cause Faktual):**
  1. `TaskIngressGateway.swift` tidak membekali model AFM on-device dengan Ingress Intent Principles pemisah yang tegas (Conversational vs Computer Action). Akibatnya, model mengira "halo" adalah query pencarian di Mail (`targetAppName: "Mail"`, `normalizedGoal: "Search for 'halo'..."`, `requiresCUA: true`).
  2. Kontrak kanonikal `AFMTaskDecomposition` belum memuat atribut first-class boolean `requiresTakeoverOnCompletion: Bool` sehingga kode di `CompanionVMAgentLoop.swift` dan `TaskEgressValidator.swift` terpaksa menggunakan hardcoded string matching `contains("send")` dan `contains("kirim")`.
  3. Ketiadaan struktur domain berlapis menyebabkan file presentasi UI dan engine CUA tercampur tanpa batas modular yang jelas.
- **Aturan Pencegahan (Invariant):**
  1. **Strict Domain Layering (UI vs Logic Isolation)**: Seluruh komponen visual SwiftUI WAJIB di `Clicky/UI/`. Semua engine reasoning AI di `Clicky/Reasoning/`. Seluruh CUA loop/actions/grounding di `Clicky/CUA/`. Seluruh isolasi display di `Clicky/Workspace/`. DILARANG membuat folder generic campur aduk seperti `Tools/`.
  2. **Autonomous Intent Gate (Zero String Matching)**: Intent sapaan/obrolan ("halo", "hi", "siapa kamu") WAJIB diklasifikasikan model menjadi `requiresCUA: false` & `isConversational: true` sehingga langsung dijawab via `companion.askViaText`.

---

### ERR-047: Kursor Segede Gaban, Blink Kinematika CUA, Token Pool Expired Luna, dan Egress Meta-Label
- **Fitur:** `MascotAgentCursorView / MascotVirtualDesktopService / ChatGPTAccountPoolManager / TaskEgressValidator`
- **Gejala:** 
  1. Kursor virtual asisten di viewport tampak raksasa ("segede gaban") dan di-hardcode dengan warna cyan `#38BDF8` alih-alih warna maskot aktif.
  2. Kursor meloncat patah-patah (*blink-blink / teleport*) alih-alih meluncur mulus seperti mouse/touchpad manusia.
  3. Grounding visual Luna memicu error `401 Unauthorized (token expired)` sehingga klik fisik jatuh ke titik tengah jendela (`defaultCenter`) dan gagal membuka baris email.
  4. Hasil akhir di bubble chat hanya menampilkan label status singkat `hasil analisis email pertama` tanpa menyajikan rincian pengirim, subjek, jam, dan isi email yang telah diekstrak.
- **Kesalahan (Root Cause Faktual):**
  1. `InteractiveVirtualDesktopView.swift:277` merender ukuran fixed 16×20 pt dengan stroke 1.8 pt dan warna cyan statis.
  2. `MascotVirtualDesktopService.swift:401` meng-assign koordinat reticle seketika tanpa interpolasi kurva kinematik dan jeda pergerakan hanya 200 ms sebelum klik.
  3. `ChatGPTAccountPoolManager.swift:168` mengarahkan `CODEX_HOME` ke folder akun pool yang tokennya kadaluarsa tanpa sinkronisasi otomatis dari `~/.codex/auth.json`, dan `ClickyHybridGroundingEngine.swift:236` mengecualikan penelusuran `axrow`.
  4. `TaskEgressValidator.swift:188` meloloskan `responseToUser` yang hanya berupa meta-label status tanpa memprioritaskan data faktual kaya yang ada di `extractedData`.
### ERR-048: Kegagalan Klik Item Daftar (Master-Detail Sequencing), Mismatch Normalisasi Koordinat, & Jitter Kursor
- **Fitur:** `TaskStepPlanner / CompanionVMAgentLoop / MascotVirtualDesktopService / InteractiveVirtualDesktopView`
- **Gejala:** 
  1. Asisten tidak mengklik baris pertama di inbox (`UNIQLO`) saat diminta memeriksa email, sehingga panel baca di kanan tetap menampilkan email lama (`Chess.com`).
  2. Kursor CUA di render viewport melenceng jauh (~100 pixel) dari elemen yang dituju dan tampak tersentak/berkedip (*blink*).
  3. Saat tugas selesai, kursor mendadak melompat kembali ke titik tengah layar `(0.5, 0.5)`.
- **Kesalahan (Root Cause Faktual):**
  1. `TaskStepPlanner.swift:40`: Aturan visual navigation AFM terlalu prematur mengizinkan `actionType: "read"` atau `"done"` jika teks ringkasan terlihat sekilas di daftar, sehingga AI tidak pernah merencanakan `click` untuk membuka email ke panel baca.
  2. `CompanionVMAgentLoop.swift:362`: Koordinat dari Luna (berbasis snapshot jendela 1260×800) dinormalisasi dengan membagi resolusi layar virtual (1920×1080), bukan dimensi snapshot jendela aktual.
  3. `MascotVirtualDesktopService.swift:394`: `targetDisplayCoordinate` menghitung titik klik fisik dari origin layar virtual tanpa memperhitungkan offset origin dan ukuran jendela target aktual (`currentWindowBounds`).
  4. `InteractiveVirtualDesktopView.swift:77, 96`: Kursor di-render tanpa memperhitungkan aspect-fit letterbox rect, dan modifier `.animation(.interpolatingSpring)` bertabrakan dengan perulangan 45 FPS dari `glideReticleTo` sehingga kursor bergetar dan melompat. Di `MascotVirtualDesktopService.swift:165`, pembongkaran virtual display mereset paksa `virtualReticle = (0.5, 0.5)`.
- **Aturan Pencegahan (Invariant):**
  1. **Master-Detail Navigation Sequence:** Pada navigasi master-detail (daftar item ke panel baca), AI WAJIB merencanakan `actionType: "click"` pada baris item target terlebih dahulu untuk membukanya sebelum menjalankan `actionType: "read"` atau `"done"`. DILARANG menyimpulkan tugas selesai hanya dari teks ringkasan sepintas di daftar.
  2. **Window-Relative Coordinate Normalization:** Seluruh koordinat persepsi visual (Luna & AX) WAJIB dinormalisasi terhadap dimensi snapshot jendela aktual (`snapWidth x snapHeight`), bukan resolusi virtual display global.
  3. **Window-Bound Physical Event Target:** `targetDisplayCoordinate` WAJIB mengonversi titik normalisasi menggunakan origin dan ukuran `currentWindowBounds` jendela target di WindowServer.
  4. **Aspect-Fit Cursor Projection & Zero Spring Stutter:** Kursor di viewport WAJIB diproyeksikan di dalam `drawRect` aspect-fit, ujung panah (*arrow tip*) `(0, 0)` di-offset tepat ke titik target, dan DILARANG memasang spring animation di atas loop pergerakan kursor 45 FPS `glideReticleTo`. Posisi kursor terakhir WAJIB dipertahankan saat virtual display dibongkar (DILARANG mereset ke 0.5, 0.5).

---

### ERR-049: Kegagalan Registrasi Klik pada Aplikasi Latar Belakang (AppKit First-Mouse Rejection & postToPid Filtering)
- **Fitur:** `CUAClickActionTool / MascotVirtualDesktopService (Background Element Click & Event Synthesis)`
- **Gejala:** Kursor AI maskot sudah meluncur tepat ke baris email pertama (`UNIQLO`) dan lingkaran ripple klik muncul di kanvas, namun item tidak terpilih di aplikasi Mail (`Chess.com` di baris 4 tetap terpilih dan panel baca tidak berubah).
- **Kesalahan (Root Cause Faktual):**
  1. Di macOS, `CGEvent.postToPid(pid)` pada `MascotVirtualDesktopService.swift` memiliki limitasi arsitektural Quartz di mana event mouse sintetik difilter/diabaikan oleh AppKit Cocoa jika aplikasi berjalan di latar belakang (background/inactive window).
  2. View native AppKit (`NSTableView` / `NSOutlineView`) mengembalikan `acceptsFirstMouse: NO`, sehingga event klik mouse sintetis ditolak tanpa aktivasi WindowServer.
  3. Pemanggilan `CGEvent` mouse down/up tidak menyertakan `.mouseEventClickState = 1` dan event source session, serta tidak memiliki eksekusi aksi elemen via Accessibility IPC sebagai jaminan deterministik.
- **Aturan Pencegahan (Invariant):**
  1. **Dual-Layer Background Click Execution:** Setiap eksekusi klik CUA pada workspace terisolasi WAJIB menggabungkan pergerakan kursor fisik + ripple visual dengan eksekusi seleksi elemen latar belakang via Accessibility IPC (`AXUIElementCopyElementAtPosition` ➔ `kAXSelectedAttribute` / `kAXPressAction` / `kAXPickAction`) pada PID target.
  2. **Proper CGEvent Source & ClickState:** Event sintetis mouse down/up WAJIB menggunakan `CGEventSource(stateID: .combinedSessionState)` dan menyetel field `.mouseEventClickState` bernilai minimal `1`.
  3. **Zero Host Screen Intrusion:** Eksekusi latar belakang murni berkomunikasi melalui IPC proses target, dilarang keras memindahkan kursor mouse perangkat keras host pengguna atau merebut fokus aplikasi aktif host.

---

### ERR-050: Perencanaan Prematur Aksi Read pada Baris Daftar & Kesimpulan Selesai Tanpa Pembukaan Preview Pane
- **Fitur:** `TaskStepPlanner / TaskEgressValidator (Master-Detail Enforcement & Non-Premature Validation)`
- **Gejala:** Asisten melaporkan berhasil memeriksa email pertama hanya dari teks ringkasan judul di daftar, kursor mengarah ke baris pertama tapi tidak pernah mengklik baris tersebut, dan layar preview pane di sebelah kanan tetap menampilkan email lama (`Chess.com`).
- **Kesalahan (Root Cause Faktual):**
  1. `TaskStepPlanner.swift:42`: Model AFM memilih `actionType: "read"` pada target `'first item in list'` (bukan `"click"`) karena instruksi mengizinkan aksi `read` jika teks ringkasan tampak di observasi list. Akibatnya CUA loop mengeksekusi `CUAReadActionTool` tanpa pernah mengklik baris email (`CUAClickActionTool` tidak terpanggil).
  2. `TaskEgressValidator.swift:37`: Memuat instruksi prematur *"If target item details are visible in listItems, mark isDone: true"*, sehingga validator mengakhiri sesi di Langkah 1 hanya karena judul tampak di daftar tanpa menunggu konten dibuka di preview pane.
- **Aturan Pencegahan (Invariant):**
  1. **Mandatory Click Before Read:** DILARANG merencanakan `actionType: "read"` pada baris item daftar. Untuk memeriksa item dari daftar/inbox, model AFM WAJIB merencanakan `actionType: "click"` pada baris target terlebih dahulu jika belum terekam di `Previous Steps`.
  2. **Reading Pane Prerequisite for Task Completion:** Pemeriksaan/pembacaan email HANYA boleh dinyatakan selesai (`isDone: true`) setelah baris email diklik dan konten pesan pada reading/preview pane telah terbaca.

---

### ERR-051: Spekulasi Evaluasi Tanggal OCR & Pengabaian Target Index Kontrak (Contract Index Deviation)
- **Fitur:** `TaskStepPlanner / TaskIngressGateway (Contract Index Fidelity & Zero Speculative Re-Ranking)`
- **Gejala:** Saat pengguna meminta *"halo tolong check email terakhir saya"*, Ingress menetapkan `targetIndex: 1`, namun AFM Planner malah merencanakan `targetElement: "second item in list"` dan mengklik baris email kedua (`UNIQLO - Comfy moments start in sweats`), mengabaikan email teratas (`UNIQLO - Shirts for layering season`).
- **Kesalahan (Root Cause Faktual):**
  1. `TaskStepPlanner.swift:40`: Ketiadaan prinsip *Contract Index Fidelity* di system prompt membuat AFM Planner mencoba mengevaluasi ulang status keterkinian email dari string mentah teks OCR di dalam `content`.
  2. Teks baris 1 memuat jam dalam format titik macOS (`06.23`), sedangkan baris 2 memuat kata `Yesterday`. Model on-device menafsirkan `06.23` sebagai tanggal kalender lama (*June 23 / 23 Juni*) dan menganggap `Yesterday` lebih baru, sehingga salah memilih baris kedua (`index: 2`).
- **Aturan Pencegahan (Invariant):**
  1. **Contract Index Fidelity:** Planner WAJIB menyelaraskan target secara deterministik dengan `targetIndex` yang telah diputuskan oleh Ingress Task Contract (index 1 ➔ item pertama, index 2 ➔ item kedua, index N ➔ item ke-N).
  2. **Zero Speculative Re-Ranking:** DILARANG mencoba menyortir ulang ranking item dari teks mentah OCR. Evaluasi maksud pengguna adalah kedaulatan Ingress Gateway; tugas Planner murni mengeksekusi penargetan visual sesuai kontrak.
  3. **Zero App-Specific Bias:** Aturan wajib murni abstrak dan universal untuk seluruh aplikasi macOS (Mail, Notes, Finder, Safari, dll.) tanpa menyisipkan kata khusus "email" atau asumsi kaku bahwa "terbaru selalu baris 1".

---

### ERR-052: Kegagalan Scroll Koordinat Tepi, Penghentian Prematur Pasca-Scroll, & Reset Indeks Viewport (Visual Anchor Chaining)
- **Fitur:** `CUAScrollActionTool / MascotVirtualDesktopService / CompanionVMAgentLoop (Background Scroll Execution & Visual Anchor Chaining)`
- **Gejala:** Saat pengguna meminta *"kalau email yang ke 10 tentang apa ya?"*, asisten melakukan aksi `scroll_down`, namun daftar email tidak bergerak sama sekali, item ke-10 tidak pernah diklik, loop selesai prematur di Langkah 1, dan asisten berhalusinasi menyatakan email ke-10 berjudul `"WOMEN"` (mengambil sisa teks di preview pane email pertama).
- **Kesalahan (Root Cause Faktual):**
  1. `MascotVirtualDesktopService.swift`: `performCuaScroll` mengirim event scroll mouse dengan `scrollWheelEvent2Source: nil` dan satuan pixel tanpa event source aktif, yang diabaikan oleh AppKit pada jendela aplikasi latar belakang (background/inactive window).
  2. `CUAScrollActionTool.swift`: Menghitung koordinat scroll dari penargetan Luna pada item ke-10 yang berada di luar layar ($Y: 749$), menghasilkan koordinat WindowServer ($Y: 779$) yang berada di luar batas kontainer/jendela target (tinggi 742 pt).
  3. `TaskEgressValidator.swift` & `CompanionVMAgentLoop.swift`: Validator mengevaluasi tugas setelah aksi scroll langkah 1 dan menyatakan `isDone: true` karena melihat teks preview lama (`WOMEN`), memutus loop sebelum kursor sempat mengklik item target.
  4. `readStructuredObservation`: Penomoran item daftar murni berbasis kartu yang tampak di viewport (`cards.enumerated()`), sehingga pada scroll berikutnya nomor urut kartu ter-reset kembali ke 1 dan kehilangan jejak nomor urut absolut (item 10).
- **Aturan Pencegahan (Invariant):**
  1. **Dual-Layer Scroll & Container Clamping:** Aksi scroll CUA WAJIB ditargetkan pada badan kontainer daftar yang aman ($X \approx 0.35, Y \in [0.30, 0.70]$), menggunakan `CGEventSource(stateID: .combinedSessionState)` dengan satuan `.line`, disertai fallback Accessibility IPC (`AXScrollDown` / `AXScrollUp` pada `AXScrollArea` / `AXTable`).
  2. **Non-Terminating Scroll Actions:** Aksi scroll murni bersifat persiapan navigasi dan DILARANG mengakhiri tugas (`isDone` wajib `false`). Loop CUA WAJIB melanjutkan ke langkah observasi dan klik berikutnya.
  3. **Visual Anchor Chaining:** Penomoran item daftar antar-langkah scroll WAJIB menggunakan pelacakan tumpang-tindih kartu (*visual anchor chaining*) agar indeks absolut item (1, 2, ..., 10) tetap konsisten dan tidak ter-reset saat layar bergulir.

---

### ERR-053: Kegagalan Routing Scroll CGEventPostToPid, Race Condition Snapshot Disk Asinkron, & Halusinasi Validator Lintas Item
- **Fitur:** `CUAScrollActionTool / MascotVirtualDesktopService / CompanionWindowStreamService / TaskStepPlanner / TaskEgressValidator`
- **Gejala:** 
  1. Asisten mengeksekusi 3 langkah `scroll_down`, namun layar tidak bergulir sama sekali. Asisten kemudian mengklik item ke-9 (`Apple`), tetapi mengklaim itu adalah item ke-10.
  2. Panel baca di sebelah kanan menampilkan tanda terima Apple (eFootball Rp 100k), namun asisten berhalusinasi menyatakan bahwa email ke-10 adalah tentang *"pakaian musim gugur dan tautan terkait"* (mengambil ringkasan dari email 1 UNIQLO).
- **Kesalahan (Root Cause Faktual):**
  1. `MascotVirtualDesktopService.swift:589`: Menggunakan `lineScroll.postToPid(pid)` untuk event scroll wheel. Pada macOS Quartz Event Services, `CGEventPostToPid` tidak merutekan event scroll wheel ke jendela latar belakang (silent drop).
  2. `CUAScrollActionTool.swift:59`: Mencoba memanggil aksi `"AXScrollDown"` pada `AXScrollArea`, padahal aksi tersebut tidak ada dalam spesifikasi AppKit Accessibility macOS.
  3. `CompanionWindowStreamService.swift:81,147`: Penulisan gambar PNG hasil tangkapan layar ke disk (`targetFilePath`) dijalankan secara asinkron di `DispatchQueue.global(qos: .utility).async`, sementara fungsi langsung mengembalikan URL file ke `readStructuredObservation`. Akibatnya, OCR membaca file PNG basi (stale) dari langkah sebelumnya yang masih memuat preview pane email 1 (UNIQLO pakaian musim gugur).
  4. `TaskStepPlanner.swift`: Model AFM merencanakan `actionType: "click"` pada `"10th item in list"` padahal `listItems` hanya memuat item 1 sampai 9, menyebabkan Luna terpaksa memilih elemen terbawah di layar (item 9 Apple).
  5. `TaskEgressValidator.swift` & `CompanionVMAgentLoop.swift`: Validator menyimpulkan `isDone: true` tanpa memvalidasi kehadiran `targetIndex: 10` di `listItems`, dan membaca data lama di preview pane sehingga mensintesis informasi pakaian musim gugur dari email 1.
- **Aturan Pencegahan (Invariant):**
  1. **Dual-Layer Scroll Execution:** Event scroll fisik WAJIB diposting ke `.cgSessionEventTap` dan `.cghidEventTap` (satuan `.pixel`), dipadukan dengan manipulasi Accessibility IPC pada `AXVerticalScrollBar` (`kAXValueAttribute` delta adjustment & `AXIncrement` action).
  2. **Synchronous Snapshot Persistence:** Seluruh penulisan file gambar frame jendela ke disk WAJIB diselesaikan secara sinkron sebelum URL dikembalikan ke pipeline observasi/OCR untuk mencegah *stale image race condition*.
  3. **Strict Target Index Presence & Non-Premature Click:** AFM Planner DILARANG merencanakan `click` pada item ke-N jika nomor indeks tersebut belum muncul di `listItems`. Selama item target belum tampak di layar, satu-satunya aksi yang sah adalah `scroll_down:message list`.
  4. **Target Index Presence in Validator:** Validator DILARANG menandai `isDone: true` jika item dengan `targetIndex` belum tampak di `listItems` dan belum diklik. Response ke pengguna WAJIB mencerminkan data aktual dari reading pane item yang terpilih.
  5. **targetIndexNotReached Guard:** Loop eksekusi CUA wajib memiliki guard `targetIndexNotReached` yang memblokir loop keluar secara prematur sebelum target index spesifik berhasil diklik.

---

### ERR-054: Lompatan Scroll Kasar Persentase Statis (Fixed 0.20 Step), Terlempar 4.000 Email ke Tahun 2015, & Ketiadaan Proporsionalitas Baris
- **Fitur:** `CUAScrollActionTool / MascotVirtualDesktopService (Adaptive Kinematic Scroll & Row-Proportional Resolution)`
- **Gejala:** 
  1. Saat asisten melakukan `scroll_down` untuk mencari email ke-10, daftar email melompat ribuan baris dari Oktober 2026 langsung ke November 2024 (Langkah 1), lalu ke 2022 (Langkah 2), dan akhirnya mentok di tahun 2015 pada Langkah 5 (`AXValue: 1.0`).
  2. Kebutuhan scroll yang bervariasi (micro-scroll untuk memunculkan item target yang tepat di luar layar vs page-scroll untuk membaca cepat) tidak terakomodasi karena nilai scroll bersifat kaku (*one-size-fits-all*).
- **Kesalahan (Root Cause Faktual):**
  1. `CUAScrollActionTool.swift`: Nilai penyesuaian scroll bar di-hardcode ke `let step: Float = 0.20` (20% dari seluruh panjang dokumen). Pada inbox berisi 20.897 email, satu lompatan 20% menggeser **4.179 email sekaligus**, melompati item ke-10 yang hanya berjarak 2-3 baris dari viewport.
  2. `MascotVirtualDesktopService.swift`: Mengabaikan besaran parameter `deltaY` dan menggantinya dengan `pixelDelta: Int32 = deltaY > 0 ? 120 : -120` tanpa pembagian bertahap yang halus, serta tidak memposting event langsung ke PID target.
- **Aturan Pencegahan (Invariant):**
  1. **Dynamic Row-Proportional Scroll Step:** Nilai penyesuaian `kAXValueAttribute` pada `AXScrollBar` DILARANG KERAS menggunakan persentase statis kaku. Wajib dihitung secara adaptif terhadap ukuran riil tabel/daftar:
     $$\text{adaptiveStep} = \frac{\text{rowsToScroll}}{\max(\text{totalRows}, 1)}$$
     - Untuk **Micro-Scroll (Target Reveal)**: `rowsToScroll = 2.5` (menggeser tepat 2.5 baris agar item target muncul di layar sambil mempertahankan 4-5 baris tumpang tindih sebagai jangkar visual). Pada 20.897 email, $\text{adaptiveStep} = 0.0001196$.
     - Untuk **Page-Scroll (Browsing)**: `rowsToScroll = \max(\text{visibleRows} - 1, 4.0)` (menggeser satu layar penuh menyisakan 1 baris orientasi).
     - Untuk non-tabel generik: fallback mikro-step lembut 1.5% (`0.015`) dan page-step 8% (`0.08`).
  2. **Multi-Step Smooth Kinematic Distribution & Direct PID Posting:** Event scroll fisik roda mouse WAJIB membagi `deltaY` secara proporsional ke 3 event bertahap dengan jeda 20ms, dan memposting event ke PID target (`ev.postToPid(pid)`), session tap, dan HID tap secara bersamaan.

---

### ERR-055: Prompt Few-Shot Overfitting (Literal Index 10 Leak), Spurious Scroll pada Cek Inbox Umum, & Kehilangan Clean Workspace Anchor
- **Fitur:** `TaskStepPlanner / TaskEgressValidator / TaskIngressGateway / CompanionVMAgentLoop / CUAScrollActionTool`
- **Gejala:** 
  1. Saat pengguna hanya meminta cek inbox umum (*"tolong check email saya"*), asisten secara tidak perlu mengeksekusi `scroll_down` pada Langkah 1, menggulir email teratas keluar dari viewport, lalu mengklik email ke-3 (*"UNIQLO Masterpiece: Merino Sweater"*).
  2. Asisten berhalusinasi menyatakan bahwa email UNIQLO adalah *"pesan pertama"*, padahal pesan pertama yang sebenarnya berada di urutan paling atas sebelum digulir.
- **Kesalahan (Root Cause Faktual):**
  1. `TaskStepPlanner.swift` & `TaskEgressValidator.swift`: System prompt memuat contoh angka literal `(e.g. target index 10)` dan `(e.g. listItems only contains indices 1 to 9)`. Model on-device 3B (Apple Foundation Models) mengalami *few-shot overfitting* parah, mengira setiap tugas bertujuan mencari item ke-10 dan menganggap tampilan 9 item selalu membutuhkan scroll.
  2. `TaskIngressGateway.swift`: Untuk permintaan cek/baca umum tanpa nomor urut spesifik, Ingress menetapkan `targetIndex: nil` alih-alih `1`.
  3. Residual Scrolled State: Aplikasi Mail tertinggal dalam kondisi tergulir ke bawah dari pengujian sebelumnya tanpa ada reset posisi scroll bar ke posisi awal (0.0).
  4. Ketiadaan Anti-Spurious Scroll Guard: Loop eksekusi CUA tidak memverifikasi apakah target yang dicari sebetulnya sudah tampak di layar sebelum menyetujui aksi scroll yang diajukan model.
- **Aturan Pencegahan (Invariant):**
  1. **Zero Prompt Literal Number Leaks & Abstract Placeholders:** System prompt DILARANG memuat contoh angka spesifik (`10`, `9`, dll.). Wajib murni menggunakan placeholder abstrak `<targetIndex>`.
  2. **Clean Workspace Anchor (Scroll Reset on Task Start):** Saat memulai tugas inspeksi umum atau item pertama (`effectiveTargetIdx == 1`), loop CUA WAJIB memanggil `CUAScrollActionTool.resetScrollToTop(pid:)` untuk memastikan `AXVerticalScrollBar` berada tepat di nilai `0.0`.
  3. **Default Target Index 1 on General Ingress:** Permintaan inspeksi umum tanpa indeks wajib secara eksplisit didekomposisi dengan `targetIndex: 1`.
  4. **Anti-Spurious Scroll Guard:** Jika item target (`effectiveTargetIdx`) sudah terdeteksi di dalam `sessionObservedListItems`, loop CUA WAJIB memblokir dan meng-override aksi scroll menjadi `click` langsung pada item target.

---

### ERR-057: Monolithic File Bloat, Claude API Legacy Leak, & Domain Logic Intermingled with CUA Core
- **Fitur:** `CuaVisualGrounder / ClickyDeterministicPipeline / SiriAIEngine / ComputerUsePhysicalExecutor / AppleSpeechTranscriptionProvider / HomeSpaceRootView`
- **Gejala:** 
  1. Kode khusus TradingView (Pine Editor, Symbol Search dialog tabs, crypto token parser `/analisa`) tercampur di dalam engine universal CUA Core (`CuaVisualGrounder.swift` dan `ClickyDeterministicPipeline.swift`).
  2. Berkas lama `ClaudeAPI.swift` dan model cloud usang masih tersisa di codebase meskipun proyek telah beralih ke Siri Intelligence AFM (on-device) + Gemini (bridge) + OpenAI Luna (grounding visual).
  3. Berkas `HomeSpaceRootView.swift` membengkak hingga 3.888 baris, mencampuradukkan geometri shape notch, rendering tabel markdown yang rumit, dan tombol tema.
  4. Berbagai layer (`ComputerUsePhysicalExecutor`, `AppleSpeechTranscriptionProvider`, `SiriAIEngine`) masih memiliki tuple/array hardcoded nama-nama aplikasi (`commonApps`) dan kata kerja bahasa.
- **Kesalahan (Root Cause Faktual):**
  1. Pelanggaran Single Responsibility & batas domain: Logika khusus TradingView disatukan dengan OCR universal CUA.
  2. Ketiadaan modul kebijakan terpisah untuk Ingress, Siri AI, dan Onboarding Interview, menyebabkan prompt raksasa tertanam di berkas kelas runtime.
- **Aturan Pencegahan (Invariant):**
---

### ERR-058: Cacat Geometri Kurva Sudut Kanan Atas (Slanted Border 20pt) & Artefak Shadow Bocor pada Panel HomeSpace
- **Fitur:** `NotchUnifiedHuggingShape / HomeSpaceRootView / HomeSpacePanel`
- **Gejala:** 
  1. Panel HomeSpace terlihat miring / slanted di sisi kanan, di mana lebar atas kartu lebih sempit 20 piksel dibanding lebar bawahnya.
  2. Muncul tonjolan melengkung di sudut kanan atas dan artefak bayangan hitam buram yang terpotong kaku di tepi luar border kartu.
- **Kesalahan (Root Cause Faktual):**
  1. Di `NotchUnifiedHuggingShape.swift`, kurva kuadratik sudut kanan atas diakhiri dengan `to: CGPoint(x: rect.width - cornerRadius, y: notchHeight + cornerRadius)` alih-alih `x: rect.width`. Hal ini menyebabkan titik akhir sudut menjorok ke dalam di $x = 880$, dan garis sisi kanan ditarik diagonal dari $x = 880$ ke $x = 900$ (kemiringan konstan 1:27).
  2. Di `HomeSpaceRootView.swift`, view diberi modifier `.shadow(radius: 18)`. Karena ukuran window `NSPanel` pas berukuran $900 \times \text{totalHeight}$, bayangan jatuh ke celah kosong transparan di samping notch dan celah miring 20 piksel, lalu terpotong kaku (*hard-clipped*) di batas window.
- **Aturan Pencegahan (Invariant):**
  1. **Symmetric Corner Geometry:** Setiap kurva sudut kanan atas wajib berakhir di `x: rect.width`, simetris dengan sudut kiri atas yang berawal di `x: 0`. Tepi kanan kartu WAJIB berupa garis vertikal tegak lurus sempurna 90°.
  2. **Zero Leaky Window-Edge Shadows:** Pada panel yang mengisi seluruh bingkai `NSPanel` tanpa padding luar, DILARANG menggunakan `.shadow(...)` yang merembes ke luar frame karena akan terpotong kaku oleh batas canvas window. Gunakan `.overlay(shape.stroke(...))` dengan hairline border halus (`Color.white.opacity(0.10)`) untuk pembatas yang tajam dan bersih.



