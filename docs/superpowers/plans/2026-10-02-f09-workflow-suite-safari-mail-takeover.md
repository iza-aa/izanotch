# Plan F-09: Alur Kerja Email & Web (Safari + Mail.app) dengan Live Window Projection & Human Takeover

<!-- Status: Approved by User (Option A) -->
<!-- Date: 2026-10-02 -->
<!-- Governance: Superpowers + ECC + User Consent Protocol -->

---

## 🎯 1. Objective & Scope

Mengimplementasikan **Alur Kerja Email & Web (Safari + Mail.app)** untuk companion `inbox-buddy`:
1. **Workflow App Suite**: Menghubungkan maskot dengan kumpulan aplikasi alur kerja terpadu (**Safari** dan **Mail**).
2. **Eliminasi Total Mockup Bukit Sonoma**: Mengganti gambar pemandangan Sonoma dan jendela CRM palsu dengan **Live Window Projection aplikasi nyata di Mac pengguna** (Safari atau Mail).
3. **Interactive Workflow Dock (App Switcher)**: Mini dock di bagian bawah modal secara aktif menampilkan ikon Safari dan Mail, dengan highlight pada aplikasi yang sedang aktif, dan klik untuk berpindah pantauan jendela secara instan.
4. **Tool Otomasi Mail & Safari**: Menyediakan `MailWorkflowOperationTool` (baca header inbox, buat draf pesan di Mail) dan `SafariWorkflowOperationTool` di `ClickyFunctionToolRegistry`.
5. **Protokol Human Takeover (2FA & Login)**: Menampilkan status amber `• Takeover Needed`, tombol `[ ✋ Take Over Screen ]` untuk login/sandi, dan tombol `[ ▶️ Resume Bot ]` untuk melanjutkan pekerjaan otonom bot.

---

## 🛠️ 2. Architectural Blueprint

### Komponen 1: Data Models & Workflow Suites (`ClickyEnums.swift`)
- Tambahkan properti `public var workflowAppNames: [String]` pada `BuddySession`:
  - `inbox-buddy`: `["Safari", "Mail"]`
  - `futures-scout`: `["TradingView", "Safari"]`
  - `dev-buddy`: `["Terminal", "Xcode"]`
- Tambahkan properti `public var activeWorkflowApp: String?` dan `public var takeoverReason: String?` pada `ComputerCardPayload`.

### Komponen 2: Engine Multi-App Target & Switcher (`CompanionWindowStreamService.swift`)
- Metode `public func switchTargetApp(appName: String, slug: String)`
- Metode `public func resolveRunningAppWindows(appNames: [String]) -> [String: CGWindowID]`
- Streaming frame jendela aktif ter-throttle ke `snapshots/\(appName.lowercased())_frame.png`.

### Komponen 3: Tool Otomasi Mail & Safari (`ClickyFunctionTool.swift` & Registry)
- `MailWorkflowOperationTool`:
  - Aksi: `read_inbox`, `create_draft(to:subject:body:)`, `request_takeover(reason:)`.
  - Eksekusi via AppleScript native di background (tidak menggerakkan mouse pengguna).

### Komponen 4: Modal Semi-Fullscreen Live Projection (`HomeSpaceInteractiveComputerModalView.swift`)
- Hapus `mockupDesktopCanvas` / `scenicNatureWallpaper`.
- Ganti dengan `liveWindowProjectionCanvas`:
  - Jika jendela target terdeteksi: render `streamService.activeSnapshot` dengan rasio pas dan border kaca gelap.
  - Jika jendela belum terbuka: tampilkan status kartu koneksi bersih dengan tombol `[ Open Safari / Mail ]`.
- Mini dock bawah menampilkan ikon aktif dengan indikator titik/glow, dan tombol `onTapGesture` memanggil `streamService.switchTargetApp`.
- Banner & Tombol `[ ✋ Take Over Screen ]` / `[ ▶️ Resume Inbox Buddy ]` saat status `.takeoverNeeded`.

---

## 🧪 3. Verification Plan
- **TDD Script**: `scripts/test_revisions_f09_workflow_safari_mail.swift` (5 test assertions).
- **Compile**: `xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug build`.
- **Relaunch**: `./scripts/launch_app.sh`.
- **Physical Proof**: `screencapture -l <WindowID>` memverifikasi live projection jendela nyata, dock switcher, dan takeover card.
