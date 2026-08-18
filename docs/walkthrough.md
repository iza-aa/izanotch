# 🚀 NotchDeck macOS — Development Walkthrough & Architecture Report

**Project:** NotchDeck (macOS Dynamic Island & Developer Multi-AI Command Center)  
**Target Platform:** macOS 14.0+ (Sonoma), macOS 15.0+ (Sequoia), macOS 26.0+ (Tahoe)  
**Status:** 🏆 **ALL AUDIT REMEDIATIONS COMPLETED & MERGED TO `main`**

---

## 1. Arsitektur Multi-AI Bridge & Event-Driven Engine

NotchDeck berfungsi sebagai **HUD Interaktif & Notification Hub Aktual**:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                NOTCHDECK HUD                                │
│ [✨ Antigravity ▾]  [ ⚠️ Need Approval: "Pilih DB?" ]  [ 🔍 Prompt ]        │
│                     [ Postgres ]  [ SQLite ] (Interactive Option Pills)    │
└──────────────────────────────▲──────────────────────────────┬───────────────┘
                               │                              │
          1. Observasi Transkrip & Session Aktif       2. Kirim Respon / Jawaban
                               │                              │
        ┌──────────────────────┴───────────────────────┐      │
        │  macOS FSEvents & Brain Directory Watcher    │      ▼
        │ (Line Buffer + Active Session Directory URL) │ ┌───────────────────┐
        │        (LiveTranscriptWatcher.swift)         │ │ActiveSessionBridge│
        └──────────────────────▲───────────────────────┘ │ (Atomic Pre-Flight│
                               │                         │ + JSON Escaping)  │
 ┌─────────────────────────────┴────────────────────────┐└─────────┬─────────┘
 │                  SISTEM AGENT AKTIF                  │          │
 │                                                      │          │
 │ • Antigravity: `~/.gemini/antigravity/brain/<sess>/` │◄─────────┘
 │ • Claude Code: `claude -p "<prompt>"`                │
 │ • OpenAI / Codex: `codex exec "<prompt>"`            │
 └──────────────────────────────────────────────────────┘
```

---

## 2. Analisis Akar Masalah (Root Cause) & Solusi Teknis

### 🔴 Masalah: Notch Terbuka-Tutup Terus-Menerus (Hover Infinite Loop Oscillation)

* **Root Cause:**
  1. Modifier `.onHover` sebelumnya ditempelkan di dalam `case .collapsed` (pada Button collapsed).
  2. Saat kursor mouse masuk ke area pill collapsed $\rightarrow$ `mouseEntered()` berjalan $\rightarrow$ state berubah menjadi `.expanded`.
  3. Saat view berganti ke `.expanded`, view `case .collapsed` **dihancurkan/dihapus** dari hierarki SwiftUI.
  4. SwiftUI mendeteksi bahwa view collapsed telah hilang dan secara otomatis memicu event `.onHover(false)` (`mouseExited()`).
  5. Fungsi `mouseExited()` langsung memanggil `stateController.transition(to: .collapsed)`.
  6. Notch menyusut kembali menjadi `.collapsed` tepat di bawah posisi kursor mouse user $\rightarrow$ memicu kembali `mouseEntered()`.
  7. Siklus ini berulang terus menerus tanpa henti setiap 200–400ms sehingga HUD mengalami flicker/terbuka-tutup terus-menerus.

* **Solusi Tuntas:**
  1. **Pemindahan `.onHover` ke Root Container:** `.onHover` dipindahkan ke `ZStack` terluar di [`NotchRootView.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/UI/Views/NotchRootView.swift) sehingga lifecycle hover tetap stabil dan tidak dihancurkan saat state berganti.
  2. **Pemisahan Task Debounce Masuk & Keluar:** [`NotchHoverMonitor.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/UI/Window/NotchHoverMonitor.swift) memisahkan `enterTask` (0.20s) dan `exitTask` (0.35s grace period). Jika kursor kembali masuk sebelum masa tenggang exit habis, task collapse langsung dibatalkan.

---

## 3. Matriks Hasil Perbaikan Audit Lengkap

| # | Temuan Audit | Solusi Teknis | Status |
|---|---|---|:---:|
| 1 | **Root Cause Notch Terbuka-Tutup (Oscillation)** | [`NotchHoverMonitor.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/UI/Window/NotchHoverMonitor.swift) & [`NotchRootView.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/UI/Views/NotchRootView.swift): `.onHover` dipindahkan ke root ZStack & debouncing masuk/keluar dipisahkan. | ✅ **Fixed** |
| 2 | **Sinkronisasi Ekspektasi Test Geometri** | [`NotchGeometryCalculatorTests.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Tests/NotchDeckTests/NotchGeometryCalculatorTests.swift): Nilai uji diselaraskan (`200x36pt` notch fisik, `180x32pt` layar eksternal). | ✅ **Fixed** |
| 3 | **Visual Clipping (Screenshot Pengguna)** | [`NotchRootView.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/UI/Views/NotchRootView.swift): Menambahkan `.clipped()` pada root `ZStack` agar tidak ada view yang bocor. | ✅ **Fixed** |
| 4 | **Routing Argumen Biner Codex CLI** | [`MultiAIClient.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/AIBridge/MultiAIClient.swift): Mengirimkan `["exec", text]` via helper terisolasi. | ✅ **Fixed** |
| 5 | **Error Stdin Ditutup / Tidak Tersedia** | [`AISubprocessBridge.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/AIBridge/AISubprocessBridge.swift): Melempar `AISubprocessError.stdinNotAvailable` secara eksplisit. | ✅ **Fixed** |
| 6 | **Metrik Repositori Terverifikasi** | Aktual terverifikasi **28 `@Suite`** dan **54 `@Test`** di repositori. | ✅ **Verified** |

---

## 4. Hasil Validasi & Pengujian

* **`swift build`** $\rightarrow$ **Succeed (0 error, 0 warning)**
* **`swift test`** $\rightarrow$ **100% PASS** (**28 Test Suites, 54 Unit Tests lulus semua**).
* **Git Status:** Merged cleanly into `main` (commit `6ddda07`).
* **App Process:** Berjalan aktif di background (`swift run NotchDeck`).
