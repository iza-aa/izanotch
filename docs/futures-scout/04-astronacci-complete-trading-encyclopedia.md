# Ensiklopedia Lengkap Ilmu Trading & Scalping: Metode Asst. Prof. Dr. Gema Merdeka Goeyardi (Astronacci)

Dokumen ini merupakan kompilasi dan riset teknis mendalam (**Deep Scientific Encyclopedia**) mengenai spektrum keilmuan analisis teknikal dan manajemen risiko yang diadaptasi dari metode **Asst. Prof. Dr. Gema Merdeka Goeyardi, S.E., M.M., MFTA, CFTe** (Founder & CEO Astronacci International). Dokumen ini dirancang sebagai manual pengetahuan komprehensif bagi agen AI (**Futures Scout**) agar memiliki logika analisis yang presisi, bebas bias, dan layak dikodekan secara deterministik.

---

## 📖 DAFTAR ISI
1. [Landasan Teori Pasar & Struktur Harga (Market Structure)](#1-landasan-teori-pasar--struktur-harga)
2. [Anatomi Candlestick & Price Action Presisi](#2-anatomi-candlestick--price-action-presisi)
3. [Ilmu Fibonacci Lengkap: Retracement, Expansion, & Cluster](#3-ilmu-fibonacci-lengkap)
4. [Dimensi Waktu (Time Dimension) & Market Timing (Anchor UTC)](#4-dimensi-waktu-time-dimension--market-timing)
5. [Sistem Indikator Matematis & Konfigurasi Parameter](#5-sistem-indikator-matematis--konfigurasi-parameter)
6. [Pola Reversal & Continuation Khas Astronacci](#6-pola-reversal--continuation-khas-astronacci)
7. [The 70 PIPS & Golden Ratio Scalping SOP (Aturan Kanonis)](#7-the-70-pips--golden-ratio-scalping-sop)
8. [Manajemen Modal Institusional & Protokol Anti-Bangkrut](#8-manajemen-modal-institusional--protokol-anti-bangkrut)

---

## 1. Landasan Teori Pasar & Struktur Harga

Pasar keuangan tidak bergerak secara acak (*random walk*). Pasar bergerak dalam gelombang yang mencerminkan pertarungan penawaran (*supply*) dan permintaan (*demand*), dipandu oleh prinsip Dow Theory dan Auction Market.

### A. Dow Theory & Tiga Fase Tren
1. **Fase Akumulasi (*Smart Money Inflow*)**: Institusi besar mulai menyerap likuiditas secara bertahap di rentang harga dasar tanpa menciptakan lonjakan mencolok.
2. **Fase Partisipasi Publik (*Mark-Up Phase / Trend*)**: Tren terbentuk dengan jelas dan terkonfirmasi. Di sinilah scalper dan trend-follower menangkap momentum ekspansi tercepat.
3. **Fase Distribusi (*Smart Money Outflow*)**: Institusi besar mendistribusikan posisi mereka kepada publik yang mengalami *FOMO*, diikuti fase penurunan tajam (*Mark-Down*).

### B. Hierarki Struktur Ayunan Harga (Swing Structure)
- **Uptrend (Bullish)**:
  $$\text{Struktur} = \text{Higher High (HH)} \longrightarrow \text{Higher Low (HL)}$$
  *Kondisi Valid*: Tren bullish utuh selama harga tidak ditutup kandel penuh (*body close*) di bawah titik Higher Low terakhir.
- **Downtrend (Bearish)**:
  $$\text{Struktur} = \text{Lower Low (LL)} \longrightarrow \text{Lower High (LH)}$$
  *Kondisi Valid*: Tren bearish utuh selama harga tidak ditutup kandel penuh di atas titik Lower High terakhir.
- **Break of Structure (BOS) vs Market Structure Shift (MSS/CHoCH)**:
  - *BOS*: Penembusan titik HH (pada uptrend) yang menandai kelanjutan tren impulsif.
  - *MSS / CHoCH*: Penembusan HL terakhir oleh gelombang impulsif berlawanan. Ini adalah sinyal peringatan dini bahwa struktur pasar mulai bertransisi menuju pembalikan arah (*reversal alert*).

---

## 2. Anatomi Candlestick & Price Action Presisi

Candlestick adalah rekaman visual pertarungan antara pembeli (*bulls*) dan penjual (*bears*).

```
          [ ANATOMI CANDLESTICK REJECTION ]
                      High ──┬── Upper Shadow (Wick)
                             │   (Selling Pressure / Penolakan Atas)
                 ┌───────────┴┐
                 │    BODY   │   Open / Close
                 └───────────┬┘
                             │
                             │   Lower Shadow (Tail)
                             │   (Buying Pressure / Penolakan Bawah)
                      Low ───┴──
```

### A. Rasio Ekor vs Badan (Shadow-to-Body Ratio)
Dalam sistem deteksi algoritmik Futures Scout, kandel pembalikan arah (*reversal candle*) disaring menggunakan **heuristik geometris**:
1. **Ekor Penolakan (Tail / Shadow)**: Minimal **2x panjang badan kandel (200% Body Height)**.
2. **Badan Kandel (Real Body)**: Maksimal sepertiga (33.3%) dari total rentang High-Low kandel.
3. **Penutupan Kandel (Close)**:
   - *Bullish Rejection*: Wajib ditutup di sepertiga atas rentang harga kandel (*upper third*).
   - *Bearish Rejection*: Wajib ditutup di sepertiga bawah rentang harga kandel (*lower third*).
4. **Toleransi Volatilitas (ATR-Based)**: Ujung ekor penolakan diizinkan memiliki selisih toleransi $\le 0.1 \times \text{ATR}(14)$ dari level support/resistance kunci.

### B. Pola Candlestick Utama dalam Sistem Scalping
1. **Hammer & Inverted Hammer**: Terbentuk di akhir koreksi gelombang turun (*pullback*), menandakan pembeli mulai menyerap seluruh pasokan penjual.
2. **Shooting Star & Hanging Man**: Terbentuk di puncak koreksi gelombang naik, menandakan penjual memukul mundur upaya pembeli.
3. **Bullish / Bearish Engulfing**: Kandel kedua memiliki badan yang menelan badan kandel sebelumnya (toleransi overlap $\le 0.05 \times \text{ATR}(14)$) dengan volume meningkat.
4. **Tweezer Bottom & Tweezer Top**: Dua kandel berurutan yang titik High atau Low-nya sejajar dalam rentang toleransi $\le 0.1 \times \text{ATR}(14)$, menandakan level harga tersebut ditolak dua kali berturut-turut.

---

## 3. Ilmu Fibonacci Lengkap

Dalam *The Art of Fibonacci Trading*, deret Fibonacci diposisikan sebagai cerminan matematis psikologi kerumunan (*mass psychology*) di pasar modal.

```
       Impulse High (1.000 / 100%) ──────────────────────────────
                                  \
                                   \  Koreksi / Pullback
       0.382 (38.2%) ───────────────\────────────────────────────
                                     \
       0.500 (50.0%) ─────────────────\── [ EQUILIBRIUM ] ───────
                                       \
       0.618 (61.8%) ───────────────────★ [ GOLDEN RATIO ENTRY ]
                                         \
       0.786 (78.6%) ───────────────────── [ LAST DEFENSE / SL ]
                                           \
       Impulse Low (0.000 / 0%) ────────────┴────────────────────
```

### A. Deret Fibonacci Retracement (Mencari Area Diskon / Entry)
Digunakan untuk mengukur kedalaman koreksi dari gelombang impuls utama:
- **0.236 & 0.382**: *Shallow Retracement*. Merupakan ciri khas **tren yang sangat kuat (*strong momentum trend*)**. Jarang diambil dalam scalping konservatif karena ruang nafas stop loss yang terlalu sempit.
- **0.500 (50.0%)**: *The Median / Equilibrium*. Level psikologis Dow Theory di mana harga kembali ke nilai wajar tengah.
- **0.618 (61.8%)**: **THE GOLDEN RATIO**. Level matematis terpenting di mana algoritma institusi bersiap melakukan eksekusi.
  - *Rentang Golden Pocket*: Didefinisikan secara operasional pada rentang **50.0% s/d 61.8%** (Astronacci Core Pullback), dengan area jepit klasik di **61.8% s/d 65.0%**.
- **0.786 (78.6%)**: Dihitung dari $\sqrt{0.618} \approx 0.786$. Ini adalah **Batas Pertahanan Terakhir (*Last Line of Defense*)**. Jika harga ditutup kandel penuh di bawah 0.786, struktur tren dianggap rusak total (*Trend Invalidation*).

### B. Deret Fibonacci Expansion / Extension (Mencari Target Take Profit)
Digunakan untuk memproyeksikan target kelanjutan gelombang setelah koreksi selesai:
- **1.000 (100.0%)**: Proyeksi setara gelombang impuls awal (*Measured Move* / Re-test Previous High).
- **1.272 (127.2%)**: *Target Take Profit 1 (TP1)* ($\sqrt{1.618} \approx 1.272$). Target konservatif probabilitas tinggi bagi scalper.
- **1.618 (161.8%)**: **THE GOLDEN EXTENSION (TP2)**. Target ekspansi penuh di mana gelombang impuls baru biasanya mengalami kejenuhan.
- **2.618 (261.8%)**: *Extended Climax Target* (Khusus kondisi *Price Discovery* atau breakout All-Time High).

### C. Teori "Fibonacci Cluster" (Key Reversal Zone / KRZ)
Sebuah level pembalikan arah menjadi sangat solid jika terjadi **Fibonacci Cluster**:
- Terjadi pertemuan antara level **Retracement 61.8%** dari gelombang besar (H1) dengan level **Retracement 50.0% atau 78.6%** dari gelombang mikro (M15).
- **Toleransi Dinamis (Bukan Persentase Statis)**: Dua level dianggap membentuk satu Cluster jika rentang selisih harganya berada di dalam batas toleransi $\le 0.25 \times \text{ATR}(14)$. Area ini disebut **Key Reversal Zone (KRZ)**.

---

## 4. Dimensi Waktu (Time Dimension) & Market Timing (Anchor UTC)

### A. Atribusi Teori & Scoping Adaptasi
Filosofi dasar konvergensi harga dan waktu berakar dari **W.D. Gann** (*"When time and price come together, change is imminent"*), yang diadaptasi oleh Astronacci dengan memadukan siklus astronomi dan deret waktu.

Dalam sistem AI **Futures Scout**, dimensi waktu makro astronomis **diadaptasi secara operasional** menjadi dua filter deterministik:
1. **Sesi Jam Pasar Likuid Dunia (Anchor UTC)**.
2. **Hitungan Kandel Deret Fibonacci (Fibonacci Time Zones)**.

### B. Karakteristik Sesi Jam Pasar (Terjangkar ke UTC Bebas Efek DST)
Agar sistem tidak meleset saat pergantian musim dingin (*Daylight Saving Time*), jadwal sesi di-anchor secara permanen ke waktu **UTC**:

| Sesi Pasar | Rentang Waktu (UTC) | Ekuivalen WIB (UTC+7) | Karakteristik Likuiditas |
| :--- | :--- | :--- | :--- |
| **Asia (Tokyo/HK)** | 00:00 – 07:00 UTC | 07:00 – 14:00 WIB | Volume moderat, sering membentuk rentang konsolidasi. |
| **London Open** | 07:00 – 16:00 UTC | 14:00 – 23:00 WIB | Volume ekspansi tinggi, awal pembentukan tren harian. |
| **New York Open** | 12:30 – 21:00 UTC | 19:30 – 04:00 WIB | Puncak likuiditas global komoditas dan kripto. |
| **London-NY Overlap** | **12:30 – 16:00 UTC** | **19:30 – 23:00 WIB** | **PUNCAK VOLATILITAS UTAMA**. Setup M15/M5 memiliki likuiditas eksekusi paling bersih. |

### C. Fibonacci Time Zones (Kalkulasi Kandel Waktu)
Di dalam platform TradingView, rasio deret waktu dihitung berdasarkan kandel dari titik ayunan awal (*swing pivot*):
- Deret Bar: **1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144 bar**.
- *Heuristik Timing*: Jika gelombang impuls awal memakan waktu 21 bar, maka fase koreksi sehat umumnya terjadi dalam rentang **8 bar s/d 13 bar**. Bar ke-13 adalah kandel pengawasan utama untuk mencari konfirmasi trigger (*Time Window Alert*).

---

## 5. Sistem Indikator Matematis & Konfigurasi Parameter

Indikator teknikal digunakan sebagai **penapis noise matematis**, bukan peramal masa depan.

```
[ INDIKATOR STACK ASTRONACCI ]
├── 1. Trend Filter : EMA 21, EMA 34, dan Baseline EMA 200
├── 2. Oscillator   : Stochastic (5, 3, 3 untuk Trigger M5; 14, 3, 3 untuk Filter M15)
└── 3. Momentum     : MACD (12, 26, 9) untuk deteksi Divergensi Struktural
```

### A. Exponential Moving Average (EMA Ribbon)
- **EMA 21 & EMA 34 (Dynamic Support / Resistance)**:
  - Posisi Bullish: Harga berada di atas EMA 34, dan EMA 21 berada di atas EMA 34 (*Positive Slope*).
  - Posisi Bearish: Harga berada di bawah EMA 34, dan EMA 21 berada di bawah EMA 34 (*Negative Slope*).
- **EMA 200 (Major Trend Baseline)**:
  - Filter rezim absolut. Scalper dilarang membuka posisi Long jika harga berada di bawah EMA 200 pada timeframe H1.

### B. Stochastic Oscillator
- **Konfigurasi Trigger M5 (Scalping Mikro)**: `%K = 5`, `%D = 3`, `Slowing = 3`.
  - *Golden Cross*: %K memotong %D ke atas di area Oversold (< 20).
- **Konfigurasi Filter M15 (Roadmap)**: `%K = 14`, `%D = 3`, `Slowing = 3`.
  - Digunakan untuk memastikan kandel M15 tidak berada dalam kondisi overbought ekstrem saat ingin entry long.

### C. Teori Divergensi (Peringatan Pelemahan Momentum)
1. **Regular Bullish Divergence (Peringatan Reversal)**:
   - Harga membentuk **Lower Low (LL)**, namun MACD/Stochastic membentuk **Higher Low (HL)**.
   - *Catatan Kritis*: Regular divergence adalah tanda kelelahan tren (*exhaustion warning*), bukan sinyal waktu instan. Pembalikan arah bisa membutuhkan 1–3 swing tambahan sebelum terealisasi.
2. **Hidden Bullish Divergence (Kelanjutan Tren / Continuation)**:
   - Harga membentuk **Higher Low (HL)** (koreksi sehat), namun Stochastic merosot ke area **Lower Low (LL)**.
   - Menandakan koreksi telah usai dan tren impulsif siap melanjutkan kenaikan.

---

## 6. Pola Reversal & Continuation Khas Astronacci

1. **Quasimodo Pattern (QM Pattern) / Over-Under**:
   - **Bearish QM**: Harga membuat Higher High (HH), lalu menukik tajam menyapu Low sebelumnya membentuk Lower Low (LL), kemudian re-test kembali ke bahu kiri (*Left Shoulder*). Re-test di bahu kiri yang bertepatan dengan Fibonacci 61.8% adalah area entri short premium.
     - *Invalidasi*: Penutupan kandel penuh (*body close*) di atas titik tertinggi Head.
   - **Bullish QM**: Harga membuat Lower Low (LL), melonjak tajam menyapu High sebelumnya membentuk Higher High (HH), kemudian re-test ke bahu kiri (*Left Shoulder*).
     - *Invalidasi*: Penutupan kandel penuh di bawah titik terendah Head.
2. **Double Bottom (W) & Double Top (M)**:
   - Penolakan ganda pada level horizontal yang sejajar (toleransi $\le 0.1 \times \text{ATR}(14)$).
3. **Bullish & Bearish Flag**:
   - Tiang bendera impulsif diikuti saluran koreksi miring berlawanan tren dengan volume transaksi mengecil (*volume dry-up*).

---

## 7. The 70 PIPS & Golden Ratio Scalping SOP (Aturan Kanonis)

Berikut adalah **Checklist Eksekusi Deterministik** tanpa toleransi deviasi:

```
[ CHECKLIST PRE-TRADE SCALPING ]
[ ] 1. Rezim H1: Harga > EMA 34, EMA 21 > EMA 34, dan di atas EMA 200? (Wajib YA)
[ ] 2. Buffer Berita: Jarak ke rilis berita High-Impact (FOMC/CPI/NFP) > 45 menit? (Wajib YA)
[ ] 3. Peta M15: Harga berada di dalam Golden Pocket (50.0% - 61.8%)? (Wajib YA)
[ ] 4. Trigger M5: Terbentuk Candlestick Reversal (Pin Bar / Engulfing terkonfirmasi close)? (Wajib YA)
[ ] 5. Trigger M5: Stochastic (5,3,3) Golden Cross di area < 20? (Wajib YA)
[ ] 6. Rasio R:R: Risk-to-Reward ke TP1 minimal 1 : 1.0 (Re-test Swing High) dan ke TP2 menuju Expansion 1.618? (Wajib YA)
[ ] 7. Invalidation: Stop Loss terpasang di bawah level Fibonacci 78.6% + 0.1x ATR buffer? (Wajib YA)
══════════════════════════════════════════════════════════════════════════════════
JIKA SALAH SATU SYARAT = "TIDAK", KEPUTUSAN MUTLAK: STAND ASIDE / NO TRADE.
```

### Rencana Eksekusi Dua Tahap (Split Position Execution)
- **Lot A (50% Alokasi)**:
  - Target: **Take Profit 1 (TP1)** di level *Previous Swing High* (Re-test 1.0) dengan syarat R:R minimal **1 : 1.0**.
  - Begitu TP1 tercapai: Stop Loss sisa posisi **langsung digeser ke titik Entry (Break-Even Point / BEP)**. Posisi menjadi *Zero Risk*.
- **Lot B (50% Sisa Alokasi)**:
  - Target: Dibiarkan berjalan menuju level **Fibonacci Expansion 1.618**.

---

## 8. Manajemen Modal Institusional & Protokol Anti-Bangkrut

### A. Rumus Batas Risiko 1% dengan Penyesuaian Biaya
Total risiko kerugian riil (termasuk biaya taker fee bursa dan slippage) tidak boleh melebihi **1.0% modal akun**:

$$\text{Position Size} = \frac{\text{Account Equity} \times 0.01}{|\text{Entry} - \text{Stop Loss}| + (\text{Entry} \times 0.001)}$$

### B. Daily Drawdown Circuit Breaker (Rem Darurat 3%)
- **Batas Maksimal Rugi Harian**: **-3.0% dari saldo akun**.
- Jika akumulasi kerugian harian menyentuh -3.0% (3 kekalahan beruntun):
  - **SISTEM WAJIB LOCKOUT**: Sistem mengunci diri selama 24 jam dan menolak memproses trading plan baru untuk mencegah *revenge trading*.

### C. Larangan Mutlak: Zero Tolerance Averaging Down
- Dilarang keras menambah lot pada posisi yang sedang floating minus (*Martingale*). Jika Stop Loss tersentuh, akui kekalahan sebagai biaya operasional bisnis trading yang wajar.
