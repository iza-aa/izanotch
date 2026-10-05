# Arsitektur AI & Computer Use (CUA) untuk Futures Scout

Dokumen ini menjelaskan rancangan arsitektur teknis implementasi **Futures Scout** di dalam sistem **Izanotchy (boringNotch + Clicky)**. Dokumen ini mendefinisikan batas keamanan, hierarki kebenaran data (*data conflict resolution*), otomasi CUA TradingView, serta rubrik penilaian skor deterministik.

---

## 🏛️ 1. Desain Multi-Agent Hub-and-Spoke (Clicky as Orchestrator)

Agar Clicky tetap menjadi asisten serbaguna (coding, riset, produktivitas, teman ngobrol), **Clicky tidak boleh di-hardcode dengan aturan trading**.

Sebaliknya, sistem menerapkan arsitektur **Sub-Persona Spesialis**:

```
                       [ USER VOICE / CHAT ]
                                 │
                                 ▼
                     [ CLICKY (Front-End Hub) ]
                 - Mendeteksi Intent & Konteks Layar
                 - Menjaga kepribadian ramah & serbaguna
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
        ▼                        ▼                        ▼
 [ SHIPPY ]             [ RESEARCH BUDDY ]       [ FUTURES SCOUT ]
 (Spesialis Koding)      (Spesialis Web Search)   (Spesialis Trading)
                                                  ├── Prompt Aturan Kanonis
                                                  ├── CUA TradingView Dispatcher
                                                  └── BingX Read-Only Engine
```

### Mekanisme Handshake Clicky ➔ Futures Scout:
1. **User Berkata**: *"Clicky, tolong periksa chart BTC di TradingView, ada peluang scalping nggak?"*
2. **Clicky Intent Filter**:
   - Clicky mendeteksi kata kunci `TradingView`, `scalping`, `chart`, `futures`, atau mendeteksi window aktif adalah `TradingView.app`.
   - Clicky menjawab singkat: *"Siap! Saya serahkan chart ini ke Futures Scout untuk deep-dive multi-timeframe."*
3. **Delegasi Headless**:
   - Clicky memanggil `FuturesScoutWorker` di background.
   - Otak Clicky tetap bersih dan responsif untuk tugas lain, sementara Futures Scout menjalankan CUA ke TradingView.

---

## 🔒 2. Batas Keamanan, Hak Akses & Compliance (Safety Invariants)

1. **Strict Read-Only Scope**:
   - `BingXMarketDataEngine` HANYA menggunakan public market data endpoint atau API Key dengan hak akses **Read-Only** (tanpa izin trading, tanpa izin withdrawal).
   - Sistem CUA **TIDAK MEMILIKI KEMAMPUAN MENEMPATKAN ORDER NYATA**. Output sistem 100% dibatasi pada visual drawing dan trading plan card.
2. **Injeksi Pine Script yang Aman**:
   - Injeksi script ke TradingView Pine Editor wajib didahului oleh konfirmasi persetujuan pengguna (*User-Gated*) agar tidak menimpa script yang sedang dikerjakan pengguna.
3. **Daily Circuit Breaker State**:
   - Status risiko harian disimpan di berkas lokal `FuturesScoutRiskState.json`. Jika kerugian harian simulasi mencapai **-3.0%**, sistem mengunci diri (*Lockout*) selama 24 jam dan menolak memproses analisa baru guna mencegah *revenge trading*.

---

## 📊 3. Hierarki Kebenaran Data (Conflict Resolution Hierarchy)

Untuk membasmi halusinasi model vision, sistem menerapkan **Aturan Kebenaran Tunggal (Single Source of Truth)**:

```
[ TINGKAT 1: MUTLAK ] ➔ BingX Ground-Truth API (Data OHLCV & Nilai Indikator Eksak)
                              │  (Menang 100% jika terjadi konflik)
                              ▼
[ TINGKAT 2: SEKUNDER ] ➔ Vision Model LLM (Analisis Visual Kualitatif & Formasi Kandel)
```

- **Resolusi Konflik**: Jika model Vision menyatakan harga berada di bawah EMA 34, namun data kalkulasi numerik API menyatakan harga di atas EMA 34, **maka pembacaan API 100% Menang dan klaim Vision dibatalkan otomatis**.
- **Sinkronisasi Simbol**: Sebelum menganalisis, CUA memverifikasi ticker TradingView (misal `BTCUSDT.P`) cocok dengan ticker API BingX (`BTC-USDT`).
- **Batas Usia Data (Data Expiration)**: Data kandel M5 yang berusia lebih dari **180 detik** dianggap kadaluarsa dan wajib di-refresh ulang sebelum trading plan disajikan ke user.

---

## 🧮 4. Rubrik Confluence Score Deterministik (Skor 0 – 100)

AI dilarang keras mengarang angka skor. Skor dihitung secara deterministik oleh fungsi Swift berbasis bobot objektif berikut:

| Komponen Evaluasi | Kriteria Pemenuhan | Bobot Poin |
| :--- | :--- | :---: |
| **1. H1 Regime Alignment** | Harga > EMA 34, EMA 21 > EMA 34 (*Positive Slope*), dan di atas EMA 200. | **25** |
| **2. M15 Fibonacci Zone** | Harga berada di Golden Pocket (50.0% – 61.8%) dengan SL di bawah 78.6%. | **25** |
| **3. M5 Candlestick Trigger** | Pin Bar (Ekor $\ge 2\times$ Badan) atau Engulfing pada kandel yang sudah close. | **20** |
| **4. M5 Stochastic Confluence**| Stochastic (5, 3, 3) Golden Cross di area Oversold (< 20). | **15** |
| **5. Sesi Pasar Likuid (UTC)** | Waktu berada di sesi London Open atau London-NY Overlap (12:30–16:00 UTC). | **10** |
| **6. Buffer Kalender Berita** | Jarak ke rilis berita High-Impact (FOMC, CPI, NFP) **> 45 menit**. | **5** |
| **TOTAL SKOR MAKSIMAL** | | **100** |

### Aturan Keputusan Sistem:
- **Skor 80 – 100**: **A-Grade Valid Setup** (Trading Plan diizinkan tampil).
- **Skor 65 – 79**: **B-Grade Setup** (Peringatan risiko tinggi; butuh konfirmasi tambahan).
- **Skor < 65**: **STAND ASIDE / NO TRADE** (Otomatis batalkan rencana, pasar sideways/noise).

---

## 📐 5. Deteksi Swing High/Low Deterministik (Anti-Repaint)

Untuk mencegah level Fibonacci bergeser-geser (*repainting*):
1. Menggunakan algoritma **Pivot Fractal 5-Bar**:
   - *Swing High*: Titik puncak diapit oleh minimal 2 kandel sebelumnya dan 2 kandel setelahnya yang memiliki High lebih rendah.
   - *Swing Low*: Titik lembah diapit oleh minimal 2 kandel sebelumnya dan 2 kandel setelahnya yang memiliki Low lebih tinggi.
2. Perhitungan hanya dilakukan pada kandel yang **sudah close**. Kandel berjalan (*open candle*) dilarang digunakan sebagai acuan titik ayunan.

---

## 🤖 6. Pipeline CUA & Penanganan Verifikasi State

```
[ Step 1: Workspace Hygiene & Verifikasi State ]
TradingViewActionDispatcher.activateTradingView()
 ├── Kirim 'Option + R' (Reset Scale)
 ├── Delay render 500ms
 └── Verifikasi State via tangkapan layar (memastikan chart merespons)

[ Step 2: Multi-Timeframe Switching ]
1. Ketik '60' + Enter ➔ H1 ➔ Delay 400ms ➔ Capture Screenshot
2. Ketik '15' + Enter ➔ M15 ➔ Delay 400ms ➔ Capture Screenshot
3. Ketik '5'  + Enter ➔ M5  ➔ Delay 400ms ➔ Capture Screenshot

[ Step 3: Ground-Truth Calculation (Swift Native) ]
BingXMarketDataEngine menghitung:
 ├── EMA 21, EMA 34, EMA 200 (H1)
 ├── Fibonacci Grid 0.382, 0.500, 0.618, 0.786 (M15 Pivot)
 ├── Stochastic Oscillator (5,3,3 & 14,3,3)
 └── Confluence Score (0 - 100)

[ Step 4: LLM Reasoning & Synthesis ]
Model menerima JSON Ground-Truth + Screenshot kualitatif
Model memvalidasi kriteria AND dan menyusun narasi ringkas

[ Step 5: Visual Feedback on Chart ]
Jika Skor >= 80:
 ├── Menawarkan user untuk menggambar zona via Pine Script atau Long Position Tool
 └── Menampilkan Trading Plan Card di UI Clicky / Notch
```

---

## 🛡️ 7. System Prompt Scaffolding (Anti-Hallucination)

```markdown
Role: Anda adalah "Futures Scout", asisten analisis futures berbasis metode adaptasi Asst. Prof. Dr. Gema Merdeka Goeyardi (Astronacci).

TUGAS UTAMA:
Lakukan evaluasi multi-timeframe objektif. Anda DILARANG menebak arah tanpa konfirmasi struktur harga dan deret Fibonacci.

DATA TERSEDIA:
1. Data Ground-Truth Numerik BingX API (NILAI MUTLAK)
2. Screenshot chart TradingView (Cross-check visual kualitatif)
3. Confluence Score terhitung dari sistem

ATURAN WAJIB (ZERO HALLUCINATION):
1. Selalu ikuti data numerik API jika terjadi perbedaan dengan gambar.
2. Wajib memenuhi logika "AND": Candlestick Reversal DAN Stochastic Golden Cross di oversold (<20).
3. WAJIB mencantumkan INVALIDATION LEVEL (Stop Loss di bawah Fib 78.6% + 0.1x ATR buffer).
4. Jika Skor Confluence < 80, WAJIB menulis status: "STAND ASIDE / NO TRADE". Dilarang memaksakan sinyal jika market tidak ideal.

FORMAT OUTPUT WAJIB:
- INSTRUMEN: [Symbol] | [Timeframe]
- REZIM H1: [Bullish / Bearish / Sideways] (Berdasarkan EMA 21/34/200)
- ZONA FIBONACCI (M15): [Harga vs Golden Pocket 50%-61.8%]
- TRIGGER M5: [Reversal Candle AND Stochastic Cross]
- SKOR CONFLUENCE: [XX / 100] (Status: A-Grade / Stand Aside)
- ACTION PLAN:
  * Entry Limit: $XX,XXX
  * Invalidation (SL): $XX,XXX (Alasan: Break Fib 78.6% + ATR buffer)
  * Take Profit 1 (TP1): $XX,XXX (R:R min 1:1.5 ➔ Set BEP)
  * Take Profit 2 (TP2): $XX,XXX (Fib Expansion 1.618)
  * Sizing (1% Risk): [X.XXX Kontrak] (Fee & Slippage Adjusted)
- CATATAN RISIKO: [Jadwal rilis berita / status sesi pasar UTC]
```

---

## 🧪 8. Fase Shadow Mode / Paper Trading (Forward Testing)

Sebelum sistem diizinkan memberikan rekomendasi aktif kepada pengguna:
1. Sistem wajib melewati **Fase Shadow Mode**: Mencatat minimal **50 transaksi simulasi (Paper Trades)** secara otomatis ke dalam berkas log `FuturesScoutPaperTrades.jsonl`.
2. Melakukan evaluasi metrik kinerja riil: *Win Rate*, *Average R:R*, *Max Drawdown*, dan *Profit Factor*.
3. Hanya setup yang terbukti memiliki *positive expectancy* dari data pengujian ke depan (*forward testing*) yang dipertahankan.
