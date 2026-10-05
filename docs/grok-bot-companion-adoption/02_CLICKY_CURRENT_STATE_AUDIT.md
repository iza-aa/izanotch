# 02. Clicky Current State Audit: Audit Faktual & Analisis Celah Arsitektur

<!-- Status: Critical Honest Audit -->
<!-- Target: boringNotch / Clicky Module in Izanotchy -->
<!-- Date: September 2026 -->

---

## 🔍 1. Anatomi Clicky Saat Ini di Izanotchy

Clicky di dalam repositori `iza-3` berakar dari penggabungan dua proyek dunia:
1. **BoringNotch**: Antarmuka Dynamic Island di atas MacBook Notch (kontrol media, baterai, kalender, drop shelf).
2. **Clicky (Farza's Concept)**: Maskot AI di dekat kursor mouse yang mendengarkan via push-to-talk, merespons dengan suara ElevenLabs, dan melakukan Computer Use di layar macOS.

Selama evolusi Milestone 1 hingga 154, berbagai subsistem canggih telah dibangun di `boringNotch/Clicky`:
- `CompanionRosterStore.swift` & `CompanionProfile.swift`: Pengelola profil multi-maskot (Research Buddy, Shippy, Market Scout, dll.) dengan palet warna dan mood.
- `HomeSpaceRootView.swift`: Studio UI besar (900×580pt) yang menempel mulus di bawah notch dengan sidebar dan workspace chat.
- `CuaDriverClient.swift` & `TradingViewActionDispatcher.swift`: Klien RPC Unix Domain Socket ke daemon `cua-driver` untuk menggerakkan kursor native, mengetik hotkey, dan mengklik elemen UI.
- `FuturesScoutCoreAnalyst.swift` & `BingXMarketDataEngine.swift`: Engine kuantitatif deterministik untuk analisa pasar, Golden Pocket, dan Pine Script.

---

## ⚖️ 2. Kekuatan Faktual (What Works Well Today)

Sebelum menyoroti kelemahan, kita harus mencatat aset berharga yang sudah berfungsi prima:
1. **Performa Native macOS**: Ditulis dalam Swift murni, SwiftUI, dan AppKit, memberikan respons instan tanpa beban runtime berat.
2. **Koneksi CUA Berkecepatan Tinggi**: `cua-driver` berkomunikasi via Unix Domain Socket (`/tmp/cua-izanotchy-*.sock`) dengan latensi sub-milidetik, didukung auto-heal session revive.
3. **Pipeline Analisa Pasar Deterministik SSOT**: Menggabungkan data OHLCV BingX, Ephemeris planet, kluster Fibonacci, dan deteksi divergensi secara matematis sebelum menyentuh chart fisik.
4. **Desain Visual & Sound Engine**: Animasi awan maskot, palet 12 tema warna, suara pop/chime kustom, dan ears attachment yang menyatu ke lekukan fisik MacBook notch.

---

## 🛑 3. Celah Fundamental & Masalah Nyata (The Brutal Truth)

Meskipun komponen di atas sudah kaya fitur, terdapat **5 kelemahan konseptual besar** yang membuat pengguna merasa *"Clicky kita belum jelas konsep per companion-nya"*:

### ❌ Celah 1: Ketiadaan Lingkungan Kerja Mandiri (No Companion Workspace Isolation)
- **Kondisi Saat Ini**: Di `CompanionWorkspaceManager.swift`, yang dibuat hanyalah sebuah direktori `~/.izanotchy/companions/<slug>/` yang berisi berkas markdown `<slug>.md` dan folder kosong `output/`.
- **Dampaknya**: Tidak ada pemisahan lingkungan eksekusi. Ketika pengguna beralih dari *Research Buddy* ke *Market Scout*, kedua maskot ini sama sekali tidak memiliki sesi browser yang berbeda, tidak memiliki cookies terisolasi, dan tidak memiliki "ruang komputer" sendiri. Keduanya hanyalah sekadar label profil kosmetik dengan histori chat terpisah.

### ❌ Celah 2: Pembajakan Kursor Fisik Pengguna (Single-Cursor Screen Hijacking)
- **Kondisi Saat Ini**: Seluruh aksi Computer Use (`cua-driver`) menggerakkan **kursor mouse fisik sistem macOS**.
- **Dampaknya**:
  - Saat Clicky menjalankan otomasi (misalnya membuka TradingView, mengetik simbol, menghapus drawing, menempelkan Pine Script), pengguna **tidak bisa menyentuh laptopnya sama sekali**. Jika pengguna menggerakkan mouse, koordinat CUA meleset dan eksekusi rusak.
  - Sangat mustahil menjalankan dua companion sekaligus. Jika satu companion bekerja, seluruh komputer pengguna terkunci.
  - Ini sangat bertolak belakang dengan Grok Bot di Foto 1, di mana bot bekerja di layarnya sendiri di latar belakang tanpa mengganggu kursor fisik pengguna.

### ❌ Celah 3: Ketiadaan Kartu Chat Interaktif "Computer" (Missing Foto 1 in Chat)
- **Kondisi Saat Ini**: Di `HomeSpaceChatMessage`, pesan chat hanya berupa teks biasa:
  ```swift
  public struct HomeSpaceChatMessage: Identifiable, Codable, Equatable {
      public let id: UUID
      public let isUser: Bool
      public let text: String
      public let timestamp: Date
  }
  ```
- **Dampaknya**: Ketika Clicky mengoperasikan TradingView, di dalam chat tidak ada representasi visual apa pun! Pengguna terpaksa memelototi jendela aplikasi TradingView secara manual. Kita belum memiliki komponen kartu chat `[Computer • Working / Done]` dengan frame streaming jendela aktif seperti pada Foto 1 Grok Bot.

### ❌ Celah 4: Eksekusi Tool Ad-Hoc Tanpa Standar Function Calling Resmi
- **Kondisi Saat Ini**: Setiap modul (BingX, TradingView, Vision OCR, Web Search) dipanggil melalui percabangan kode manual hardcoded di `CompanionManager` atau `FuturesScoutChartAnalyst`.
- **Dampaknya**: LLM (baik Claude, Gemini, maupun Grok API) tidak diberikan daftar deklarasi JSON Schema terstandarisasi. Akibatnya, kita tidak bisa memanfaatkan fitur mutakhir seperti *Parallel Function Calling*, *Tool-choice grammar validation*, atau *Remote MCP Connectors*.

### ❌ Celah 5: Ketiadaan Protokol Human Takeover (2FA & Login)
- **Kondisi Saat Ini**: Jika sebuah situs web atau aplikasi desktop meminta 2FA, verifikasi CAPTCHA, atau password, Clicky tidak tahu apa yang harus dilakukan. Clicky akan macet, timeout, atau memicu klik sembarangan.
- **Dampaknya**: Pengguna tidak memiliki mekanisme terstruktur di dalam kartu chat untuk "mengambil alih sejenak" (*takeover*), mengisi password dengan aman, lalu menyerahkan kontrol kembali ke companion.

### ❌ Celah 6: Visual Maskot Awan Flat Seragam (No Procedural Avatar Personalities)
- **Kondisi Saat Ini**: Semua companion menggunakan bentuk awan kartun yang sama (`AgentCloudFaceMood`), hanya berbeda warna tint.
- **Dampaknya**: Tidak ada kepribadian visual pembeda antar-peran (misal *Market Scout* terlihat sama dengan *Research Buddy*). Tidak ada kedipan prosedural alami, dan tidak ada tatapan mata (*gaze tracking*) yang interaktif terhadap kursor pengguna.

---

## 🎯 4. Matriks Perbandingan Arsitektur: Sekarang vs Target

| Komponen | Status Clicky Saat Ini | Target Adopsi xAI Grok Bot |
| :--- | :--- | :--- |
| **Model Data Chat** | Teks string statis (`text: String`) | Polymorphic Chat Items (Text, Visual Computer Card, Draft Card, Tool Execution Pill) |
| **Streaming Visual Aksi** | 0 visual di chat; pengguna harus melihat layar fisik | Kartu `[Computer]` interaktif di chat dengan snapshot window real-time |
| **Browser Workspace** | Berbagi browser sistem global Safari/Chrome milik pengguna | Sesi WKWebView / Chromium Profile terisolasi per-slug (`browser_data/<slug>`) |
| **Interaksi CUA** | Membajak mouse fisik pengguna secara global | Menargetkan jendela virtual / background window tanpa merebut fokus pengguna |
| **Protokol Tool Calling** | Hardcoded Swift methods | xAI Function Calling JSON Schema Registry & Dispatcher |
| **Kolaborasi Antar-Bot** | 0 komunikasi antar-maskot | Multi-bot mention (`@BotName`), Group Thread, dan async handoffs |
| **Sistem Maskot / Avatar** | Awan kartun flat seragam (`AgentCloudFaceMood`) | Procedural 2D/3D Avatars (Bible Strong Avatar Lab) dengan rigging mata, blinking, & gaze tracking |

