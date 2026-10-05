# Master Plan Arsitektur Dual-Cursor: CursorAssist Clicky vs CuaDrive Action Cursor & Workflow Closed-Loop /analisa

> **Status Saat Ini:**
> - **Fase 1 (Pre-Flight Gate & Kesiapan Jendela Layer-0):** ✅ **SUDAH DI-ACC OLEH PENGGUNA & KEDUA AUDITOR** (Terbukti 100% lolos di Window ID 36807, bounds `1152 x 864`, status frontmost `true`, capture fisik `/tmp/phase1_verified_window.png`).
> - **Fase 2 s/d Fase 5:** Menunggu persetujuan (ACC) bertahap dari pengguna sesuai User Consent Protocol.

---

## 🔍 I. Hasil Analisis Forensik Berkas Kode Saat Ini

Dari audit menyeluruh terhadap berkas kode:

1. **`OverlayWindow.swift`**:
   - Saat ini hanya memiliki satu tampilan kursor utama, yaitu `BlueCursorView`.
   - Di dalamnya terdapat dua logika yang saling berebut kursor:
     - Logika pendamping (*companion*): mengikuti kursor mouse asli pengguna secara terus-menerus (`mouse.x + 35, mouse.y + 25`).
     - Logika navigasi elemen (`startNavigatingToElement`): saat ada target visual, kursor pendamping ini ditarik paksa menjauhi mouse pengguna untuk terbang ke elemen target via `animateBezierFlightArc`.
   - **Masalah:** Hal ini membuat pengguna kehilangan "Clicky buddy" di samping kursor mouse aslinya ketika ada aksi! Belum ada entitas kursor aksi (`CuaDriveActionCursor`) yang berdiri sendiri.

2. **`TradingViewInputSupport.swift` & `TradingViewNavigationTool.swift`**:
   - Fungsi `moveMouseSmoothly(to:)` dan `clickMouse(at:)` saat ini memanggil `CGEvent(mouseType: .mouseMoved).post(tap: .cghidEventTap)`.
   - **Masalah:** Ini secara harfiah **membajak kursor mouse fisik perangkat keras pengguna**. Kursor mouse asli tersentak dan crosshair TradingView menempel di chart.

3. **`CuaDriverClient.swift` & `CuaMotionEngine.swift`**:
   - `CuaDriverClient.swift` telah terhubung ke daemon CUA via socket `/tmp/cua-izanotchy-<PID>.sock` dengan dukungan mode background (`delivery_mode: "background"`).
   - `CuaMotionEngine.swift` telah memuat porting fisika gerak lengkap: kurva Dubins, busur Cubic Bezier, kecepatan *smootherstep* (300 $\rightarrow$ 900 $\rightarrow$ 200 pt/s), rotasi dinamis (*banking*), dan *spring-damper settling*.
   - **Peluang:** Mesin fisika ini siap digunakan langsung oleh kursor aksi CUA visual murni pada layer overlay tanpa menyentuh mouse fisik pengguna!

---

## 🎯 II. Penegasan Peran Kursor: CursorAssist vs CuaDrive Cursor

Menjawab pertanyaan pengguna:
> *"berarti anda untuk mengesekusi fase" selanjutnya itu pakai cursor assist clicky atau cua drive cursor?"*

**JAWABAN KANONIS:**
Untuk mengeksekusi aksi CUA pada TradingView (klik pill simbol, ganti timeframe, tutup sidebar, injeksi overlay, dan tunjuk Golden Pocket), kita **100% MENGGUNAKAN CUA DRIVE CURSOR (Action / Worker Cursor)**!

| Atribut | 🟦 CursorAssist Clicky (Companion) | ⚡ CuaDrive Cursor (Action / Worker) |
| :--- | :--- | :--- |
| **Posisi Dasar** | Selalu di samping mouse asli (`mouse.x + 35, mouse.y + 25`) | Muncul di area kerja jendela target (TradingView) |
| **Siklus Hidup** | **Permanen** (selalu ada mendampingi pengguna) | **Ephemeral** (HANYA muncul saat ada aksi, lalu menghilang) |
| **Peran Utama** | - Menampilkan status HUD ("Menganalisis ETH...")<br>- Audio Waveform saat Push-to-Talk<br>- Spinner saat AI berpikir<br>- Narasi suara (ElevenLabs TTS)<br>- Balon teks percakapan | - Terbang secara visual dengan kurva fisika `CuaMotionEngine`<br>- Mengklik tombol/pill toolbar TradingView secara visual<br>- Menunjuk zona Golden Pocket dengan cincin target berdenyut (`GuidedTargetHaloView`) |
| **Interaksi Mouse Fisik** | Mengikuti mouse fisik pengguna secara pasif | **NOL event mouse fisik** (kursor virtual murni, mouse fisik bebas 100%) |
| **Saat Aksi Selesai** | Kembali tenang di samping mouse pengguna | **Fade out** (`opacity -> 0`) dan hilang sepenuhnya dari layar |

---

## 📋 III. Rencana Kerja Per Fase (User ACC Protocol)

Alur verifikasi bertahap: Setiap fase memiliki skrip uji mandiri (`scripts/probe_phase<N>.swift`), tangkapan layar bukti fisik, dan wajib mendapatkan ACC dari Anda sebelum fase berikutnya dikerjakan.

---

### 🔹 FASE 1: Pre-Flight Gate & Kesiapan Jendela Layer-0 (STATUS: ✅ SELESAI & ACC)
* **Hasil:** 
  - `TradingViewInputSupport.activateTradingView()` memanggil `waitForTradingViewReady` di kedua jalur (warm & cold).
  - Jendela TradingView terverifikasi di WindowServer: ID 36807, Layer 0, dimensi $1152 \times 864$ pt, status frontmost `true`.
  - Bukti tangkapan layar tersimpan di `/tmp/phase1_verified_window.png`.
  - Skrip uji mandiri lolos 100%: `swift scripts/probe_phase1.swift`.

---

### 🔹 FASE 2: Closed-Loop Symbol Switching dengan CuaDrive Action Cursor & Pill Primer
* **Tujuan Visual:** 
  Ketika perintah `/analisa eth` dijalankan, kursor **CuaDrive Action Cursor** muncul, terbang ke Pill Pencarian Simbol TradingView `[ BTCUSDT.P v ]`, mengkliknya secara visual dengan animasi ripple, mengetik simbol `ETHUSDT.P`, dan memverifikasi perubahan judul jendela secara closed-loop tanpa membajak mouse fisik Anda.
* **Mekanisme 3-Tier Terisolasi:**
  1. **Tier 1 (Pill Search Primer via CuaDrive Action Cursor):**
     - Kursor CuaDrive muncul di layar (fade-in), meluncur secara visual menggunakan kurva Bezier/Dubins `CuaMotionRunner` ke koordinat pill `(origin.x + 108, origin.y + 53)`.
     - Kursor CuaDrive memicu animasi visual click ripple.
     - Klik dikirim ke sistem secara terisolasi (background delivery / targeted event) tanpa memindahkan kursor fisik Anda.
     - Buka search field $\rightarrow$ ketik `ETHUSDT.P` $\rightarrow$ jeda 750ms autocomplete $\rightarrow$ tekan `Return`.
     - Kursor CuaDrive memudar (*fade out*) sementara verifikasi berjalan.
     - Jalankan polling `verifySymbolTitle(targetSymbol: "ETHUSDT", timeout: 2.0s)`.
     - Jika terkonfirmasi $\rightarrow$ SUKSES, lanjut ke langkah berikutnya.
  2. **Tier 2 (Fallback Command Palette `Cmd + K`):**
     - Jika judul belum berubah setelah 2.0s: kirim `Escape` $\rightarrow$ kirim `Cmd + K` $\rightarrow$ ketik `ETHUSDT` $\rightarrow$ `Return`.
  3. **Tier 3 (Fallback OCR/Vision Inspection & Mutasi Nol / Hard Abort):**
     - Jika judul tetap tidak cocok:
       - **BATALKAN SELURUH AKSI MUTASI BERIKUTNYA (Zero Mutation)**:
         Tidak ada ganti timeframe, tidak ada injeksi Pine Script, chart Anda steril 100%.
       - CursorAssist Clicky (di mouse Anda) menyuarakan peringatan:
         *"Gagal memverifikasi simbol ETH di TradingView. Analisa dihentikan demi keamanan."*
* **Cara Uji untuk Anda:**
  1. Jalankan `swift scripts/probe_phase2.swift`.
  2. Amati layar: Kursor CuaDrive virtual meluncur dan mengklik pill simbol; kursor mouse fisik Anda tetap diam di tempat Anda menaruhnya.
  3. Simbol di TradingView berganti dari BTC ke ETH.
  4. Skrip menghasilkan tangkapan layar `/tmp/phase2_verified_window.png` yang membuktikan chart telah berganti ke ETH.

---

### 🔹 FASE 3: Timeframe Switching (15m), Auto-Fit (⌥+R), & Idempotent Sidebar Collapse
* **Tujuan Visual:** 
  Kursor CuaDrive berpindah mengonfigurasi chart ke timeframe 15 menit, mereset skala agar kandel proporsional (*Auto-Fit*), dan menutup sidebar Watchlist jika sedang terbuka (tanpa flip-flop).
* **Mekanisme:**
  1. Kursor CuaDrive mengarahkan fokus ke kanvas $\rightarrow$ ketik `"15"` $\rightarrow$ jeda 180ms $\rightarrow$ tekan `Return`.
  2. Reset skala harga kanvas via `resetChartScale()` (`⌥+R`) dengan jaminan fokus kanvas terlebih dahulu (mencegah karakter `®` tertempel di chart).
  3. **Idempotent Sidebar Collapse:** Periksa status sidebar via `AXUIElement` (`isWatchlistSidebarOpen()`). Jika SUDAH TERTUTUP, sistem diam (0 klik). Jika masih terbuka, kursor CuaDrive mengklik tombol penutupnya sehingga kanvas grafik melebar penuh 100%.
* **Cara Uji untuk Anda:**
  1. Jalankan `swift scripts/probe_phase3.swift`.
  2. Amati timeframe berganti ke 15m.
  3. Sidebar kanan tertutup rapi dan kandel terlihat proporsional di layar penuh.

---

### 🔹 FASE 4: Evaluasi Astronacci & Gerbang Injeksi Skrip Pine (Trade Plan Box)
* **Tujuan Visual:** 
  Menampilkan kotak area risiko dan target (Golden Pocket, Entry Limit, TP, SL) langsung di atas grafik TradingView jika setup valid (A-Grade / In GP waiting), dan 100% STERIL jika pasar choppy / ada buffer berita ekonomi 45 menit.
* **Mekanisme Gerbang Ganda (Dual-Condition Gate):**
  1. Injeksi HANYA dieksekusi jika:
     `isActionableSetup == true` **DAN** `Fase 2 Verifikasi Simbol == SUCCESS`.
  2. Jika salah satu gagal $\rightarrow$ **ZERO MUTATION** (tidak ada Pine Editor yang dibuka, nol kode ditempel).
  3. **Siklus Non-Destruktif:**
     - Cadangkan skrip lama Anda di Pine Editor via `Cmd+A -> Cmd+C`.
     - Tempel skrip Trade Plan Box ber-tag unik $\rightarrow$ kompilasi `Cmd+Return`.
     - Pulihkan kembali skrip lama Anda ke editor via `Cmd+V`.
     - Tutup kembali panel split Pine Editor agar grafik tetap lebar penuh.
* **Cara Uji untuk Anda:**
  1. Jalankan `swift scripts/probe_phase4.swift`.
  2. Kotak Trade Plan semi-transparan (hijau untuk TP, merah untuk SL, oranye untuk GP) muncul rapi di chart tanpa merusak skrip pribadi Anda di Pine Editor.

---

### 🔹 FASE 5: Esensi CuaDrive Action Cursor — Virtual Worker Flight & Pulsating Halo
* **Tujuan Visual:** 
  Kursor CuaDrive terbang melintasi kanvas grafik menuju level harga Golden Pocket yang dihitung secara matematis, mendarat dengan cincin target berdenyut (`GuidedTargetHaloView`), sementara CursorAssist Clicky tetap setia di samping mouse asli Anda menyampaikan narasi suara objektif.
* **Mekanisme Dual-Cursor Koordinatif:**
  1. **CursorAssist Clicky (Di samping mouse Anda):**
     - Tetap mendampingi mouse fisik Anda tanpa berpindah tempat.
     - Menampilkan teks status HUD ("Menganalisis Golden Pocket...") dan menyuarakan narasi audio TTS objektif (< 300 karakter).
  2. **CuaDrive Action Cursor (Di kanvas TradingView):**
     - Muncul di atas kanvas TradingView.
     - Menghitung koordinat piksel layar dari level harga Golden Pocket ($P_{\text{target}}$):
       $$Y_{\text{screen}} = Y_{\text{bottom}} - \left(\frac{P_{\text{target}} - P_{\min}}{P_{\max} - P_{\min}}\right) \times H_{\text{canvas}}$$
       $$X_{\text{screen}} = X_{\text{right}} - 60\,\text{pt}$$
     - Meluncur mulus menggunakan fisika `CuaMotionRunner` (60fps, 300 $\rightarrow$ 900 $\rightarrow$ 200 pt/s).
     - Mendarat dan bergoyang lembut (*spring-damper settling*).
     - Menampilkan cincin halo berdenyut (`GuidedTargetHaloView`) dan badge level ("Golden Pocket: $X").
     - Menetap selama 2.5 detik untuk verifikasi visual yang jelas.
     - **Fade Out**: Memudar mulus dan menghilang sepenuhnya dari layar setelah selesai.
  3. **Garansi Nol Pembajakan Mouse Fisik:**
     - Mouse fisik pengguna **bebas 100%** sepanjang seluruh proses.
* **Cara Uji untuk Anda:**
  1. Jalankan `swift scripts/probe_phase5.swift` (atau panggil `/analisa eth` dari chat).
  2. Amati kursor CuaDrive terbang dan menunjuk level Golden Pocket di chart dengan halo berdenyut.
  3. Kursor mouse asli Anda tetap di tangan Anda, dan Clicky buddy tetap berada di samping kursor mouse Anda.
  4. Laporan markdown lengkap tersaji rapi di kartu chat HomeSpace.

---

## 🛡️ IV. Komitmen Eksekusi Sesuai Permintaan Anda

1. **Persetujuan Bertahap (User ACC Protocol):** Tidak ada kode Fase 2, 3, 4, atau 5 yang akan dimodifikasi tanpa persetujuan eksplisit dari Anda per fase.
2. **Skrip Uji Mandiri Setiap Fase:** Setiap fase yang selesai akan langsung disertai perintah CLI `swift scripts/probe_phase<N>.swift` sehingga Anda dapat melihat langsung hasilnya di layar TradingView Anda.
3. **Pemberian Bukti Fisik:** Setiap laporan penyelesaian fase akan menyertakan foto tangkapan layar jendela TradingView terverifikasi di `/tmp/phase<N>_verified_window.png`.
