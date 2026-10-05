# Fitur F-08: Live Window Frame Streaming & Interactive Semi-Fullscreen Modal (1:1 Foto Baru)

> **Date:** 2026-10-02  
> **Status:** Approved (Opsi 2 + Full Visual Modal 1:1 Foto Baru)  
> **Reference Image:** `media_1790936424964.png`

---

## 🎯 1. Objective & Scope

1. **Backend (Fungsi Live Streaming & Window Capture)**:
   - Membangun service `CompanionWindowStreamService.swift` yang mendeteksi jendela aplikasi target (Mail, Safari, TradingView, dll) via `CGWindowListCopyWindowInfo`.
   - Mengambil frame snapshot berkala atau on-demand via `CGWindowListCreateImage` tanpa membebani CPU (throttled 1–2 FPS).
   - Menyimpan frame ke direktori sandbox companion: `~/.izanotchy/companions/<slug>/workspace/snapshots/active_frame.png`.
   - Menyediakan interface pemanggilan langsung saat companion bekerja (`status = .working`).

2. **Frontend (Visual Interaktif 1:1 Foto Baru)**:
   - Membuat modal semi-fullscreen `HomeSpaceInteractiveComputerModalView.swift` yang terbuka saat kartu chat `HomeSpaceComputerCardView` diklik:
     * **Dimmed Backdrop**: Latar belakang transparan gelap (`Color.black.opacity(0.65)`) dengan smooth blur.
     * **Tombol Close [✕]**: Di pojok kanan atas modal untuk menutup kembali ke alur chat.
     * **Enlarged Canvas Frame**: Kanvas yang diperbesar tajam dengan live frame / desktop wallpaper.
     * **Kursor Label `"You"`**: Indikator kursor pengambilalihan kontrol pengguna (Human Takeover cursor).
     * **Mini Floating macOS Dock**: Di bagian bawah kanvas, menampilkan dock semi-transparan dengan ikon aplikasi aktif (Safari, Mail, TradingView) dengan efek hover interaktif.
   - Mengintegrasikan interaksi klik pada `HomeSpaceComputerCardView` di `HomeSpaceRootView.swift` sehingga kartu chat langsung memicu modal pop-up semi-fullscreen ini.

---

## 🛠️ 2. Architectural Decomposition & File Structure

| Step | Target File | Responsibility |
| :---: | :--- | :--- |
| **Backend** | `boringNotch/Clicky/Tools/CompanionWindowStreamService.swift` | Pencarian window target (PID/app name), capture CGImage, caching snapshot di disk & memory, throttling. |
| **Frontend Modal** | `boringNotch/Clicky/HomeSpace/HomeSpaceInteractiveComputerModalView.swift` | Komponen modal semi-fullscreen 1:1 Foto Baru (`[✕]`, enlarged canvas, kursor `"You"`, mini floating dock). |
| **Frontend Card** | `boringNotch/Clicky/HomeSpace/HomeSpaceComputerCardView.swift` | Menambahkan aksi tap/klik pada kartu untuk membuka modal interaktif. |
| **Integrasi Chat** | `boringNotch/Clicky/HomeSpace/HomeSpaceRootView.swift` | State manager `@State private var selectedComputerPayload: ComputerCardPayload? = nil` untuk merender modal di atas chat view. |
| **Scaffolding** | `boringNotch.xcodeproj/project.pbxproj` | Mendaftarkan 2 berkas baru ke target `boringNotch`. |
| **Verification** | `scripts/test_revisions_f08_window_streaming.swift` | Unit & integration TDD test suite validating stream service, modal layout, close action, and mini dock. |

---

## 📋 3. Step-by-Step Execution Plan

### Step 1: Write TDD Test Suite (Red State)
- Buat `scripts/test_revisions_f08_window_streaming.swift`.
- Tulis pengujian untuk:
  1. `CompanionWindowStreamService` singleton, capture method, dan target app resolution.
  2. `HomeSpaceInteractiveComputerModalView.swift` struktur visual (close button `✕`, kursor `"You"`, mini dock dengan Safari & Mail).
  3. Integrasi kartu chat `HomeSpaceComputerCardView` dengan callback buka modal.
  4. Pendaftaran file di `project.pbxproj`.
- Jalankan test dan konfirmasi status RED (gagal karena berkas belum dibuat).

### Step 2: Implement `CompanionWindowStreamService.swift` (Backend)
- Implementasikan engine penangkap jendela `CompanionWindowStreamService`:
  - `captureTargetWindow(appName:slug:) -> String?`
  - Menyimpan file ke `~/.izanotchy/companions/<slug>/workspace/snapshots/active_frame.png`.
  - Mengembalikan path gambar untuk diumpankan ke `ComputerCardPayload.snapshotImagePath`.

### Step 3: Implement `HomeSpaceInteractiveComputerModalView.swift` (Frontend)
- Bangun modal semi-fullscreen 1:1 Foto Baru:
  - Header/Close bar: Tombol `[✕]` di pojok kanan atas.
  - Large Viewport Canvas: Menampilkan live window snapshot atau wallpaper desktop sinematik.
  - Kursor Pill `"You"`: Indikator kursor takeover di atas kanvas jendela.
  - Floating Mini macOS Dock: Menampilkan icon Safari, Mail, dan aplikasi pendukung dengan kapsul glass blur.

### Step 4: Hook Click Action on `HomeSpaceComputerCardView` & `HomeSpaceRootView`
- Di `HomeSpaceComputerCardView.swift`, tambahkan callback `onCardTapped: (() -> Void)?`.
- Di `HomeSpaceRootView.swift`, tambahkan state `@State private var activeModalPayload: ComputerCardPayload? = nil`.
- Tampilkan modal dengan animasi spring transisi saat `activeModalPayload != nil`.

### Step 5: Register in `boringNotch.xcodeproj`
- Daftarkan `CompanionWindowStreamService.swift` dan `HomeSpaceInteractiveComputerModalView.swift` ke PBXBuildFile, PBXFileReference, PBXGroup, dan Sources Build Phase.

### Step 6: Verify Tests (Green State), Compile & Visual Verification
- Jalankan `swift scripts/test_revisions_f08_window_streaming.swift` -> konfirmasi 100% PASS.
- Jalankan `xcodebuild` -> konfirmasi `** BUILD SUCCEEDED **`.
- Relaunch app dengan `./scripts/launch_app.sh`.
- Tangkap window HomeSpace saat modal terbuka via `screencapture -l <WindowID>` untuk membuktikan 1:1 identik dengan Foto Baru.
- Update `CHANGELOG.md`, `AGENTS.md`, dan `09_FEATURE_BY_FEATURE_TRACKER.md`.
