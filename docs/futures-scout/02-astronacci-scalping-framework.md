# Framework Scalping Berbasis Astronacci & Fibonacci (SOP Futures Scout)

Dokumen ini menyusun prosedur operasi standar (**Standard Operating Procedure / SOP**) untuk teknik **Scalping Futures** yang diadaptasi dari prinsip-prinsip trading Asst. Prof. Dr. Gema Merdeka Goeyardi (khususnya konsep *The 70 PIPS Trading System* dan *The Art of Fibonacci Trading*).

---

## 🎯 1. Filosofi & Karakteristik Scalping Profesional

Scalping bukanlah *"menebak kandel 1 menit secara acak"*. Scalping ala profesional adalah teknik **Sniping Momentum** pada saat terjadi re-test (*pullback*) di zona kritis tren besar dengan asimetri Risk-to-Reward yang menguntungkan.

| Parameter | Karakteristik Scalping Astronacci (Evolusi Opsi A) |
| :--- | :--- |
| **Durasi Posisi** | **Intraday Scalp-Swing (Hingga 6 Jam / 72 Bar M5)** — Mengakomodasi waktu tempuh gelombang impuls struktural ke target Fibonacci Expansion / Swing High 1.0, dengan perlindungan time-stop 72 bar dan deteksi Market Structure Shift (MSS). |
| **Tujuan** | Menangkap gelombang impuls (*Dominant Impulsive Leg* $\ge 4.0\text{x ATR}$) setelah koreksi Golden Pocket terkonfirmasi selesai. |
| **Prinsip Utama** | *Trend Following on Retracement* (Dilarang melawan tren HTF). |
| **Disiplin Stop Loss** | Terkunci di bawah/atas batas struktural Swing Low / High $\pm 0.25\text{x ATR}$; **Nol Toleransi Averaging Down**. |
| **Target R:R** | Minimal **1 : 1.0** (Re-test Swing High 1.0) s/d **1 : 2.0+** (Fibonacci Expansion 1.272). |
| **Funding & Sesi** | Entry diprioritaskan pada sesi likuid (London/NY Overlap 12:30–16:00 UTC), posisi berdurasi lintas-sesi memperhitungkan biaya *Funding Rate* (0.01% per interval 8 jam). |

---

## 🧭 2. The Multi-Timeframe Triad (Hierarki 3 Timeframe Kanonis)

Scalping terstruktur wajib menggunakan hierarki 3 lapis untuk menyaring *noise* pasar:

```
       [ 1. H1 - THE COMPASS (Arah Rezim Tren Utama) ]
       - Menentukan arah bias (Bullish / Bearish / Choppy)
       - Aturan Kanonis: Stack EMA 21 > EMA 34 dan Baseline EMA 200
                          │
                          ▼
       [ 2. M15 - THE ROADMAP (Peta Zona Fibonacci Dominan) ]
       - Menarik Fibonacci Retracement pada Dominant Impulsive Swing Leg (Lookback 48 bar, Kedalaman >= 4.0x ATR)
       - Mengeliminasi false micro-swings (5-bar fractal noise)
       - Menandai Golden Pocket (50.0% - 61.8%) dan Level Struktural Swing Low / High
       - Filter Momentum: Stochastic (14, 3, 3)
                          │
                          ▼
       [ 3. M5 - THE SNIPER (Pemicu / Trigger Entry) ]
       - Menunggu kandel rejection di Golden Pocket
       - Konfirmasi Trigger: Stochastic (5, 3, 3) Golden Cross di Oversold (<20)
```

---

## 📐 3. Grid Fibonacci Retracement & Expansion

### A. Level Retracement (Mencari Area Diskon / Entry)
Ditarik dari titik awal impuls (*Swing Low*) ke puncak impuls (*Swing High*) untuk posisi Long:
1. **0.382 (38.2%)**: *Shallow Pullback* (Terjadi saat tren sangat kuat; dihindari untuk scalping konservatif).
2. **0.500 (50.0%)**: *Equilibrium Level* (Batas awal area diskon).
3. **0.618 (61.8%)**: **THE GOLDEN RATIO** (Zona probabilitas tinggi pembalikan arah).
   - *Definisi Numerik Golden Pocket*: Rentang **50.0% s/d 61.8%** (Astronacci Core Pullback), dengan area jepit klasik di **61.8% s/d 65.0%**.
4. **0.786 (78.6%)**: **LAST DEFENSE / STRUCTURAL INVALIDATION** (Batas toleransi penutupan kandel terakhir; dihitung dari $\sqrt{0.618} \approx 0.786$).

### B. Level Expansion (Menentukan Target Take Profit Objektif)
1. **1.000 (100.0%)**: Re-test titik puncak sebelumnya (*Previous High*).
2. **1.272 (127.2%)**: *Target Take Profit 1 (TP1)* — Target konservatif scalping ($\sqrt{1.618} \approx 1.272$).
3. **1.618 (161.8%)**: *Target Take Profit 2 (TP2)* — Golden Target ekspansi penuh.
4. **2.618 (261.8%)**: *Extended Climax Target* (Khusus kondisi *Price Discovery*).

---

## ⚡ 4. Aturan Baku Eksekusi (Step-by-Step SOP)

### Langkah 1: Validasi Arah Rezim di Timeframe H1
- **Kondisi Long Valid**:
  - Harga berada di atas EMA 34.
  - EMA 21 berada di atas EMA 34 (*Positive Slope*).
  - Harga berada di atas baseline EMA 200.
- **Kondisi Short Valid**:
  - Harga berada di bawah EMA 34.
  - EMA 21 berada di bawah EMA 34 (*Negative Slope*).
  - Harga berada di bawah baseline EMA 200.
- *Jika harga memotong EMA 34 bolak-balik atau tren mendatar: **STATUS = NO TRADE / STAND ASIDE**.*

### Langkah 2: Pemetaan di Timeframe M15
- Identifikasi *Swing High* dan *Swing Low* yang jelas pada kandel yang **sudah close** (bukan kandel berjalan).
- Tarik garis Fibonacci Retracement dari Low ke High (untuk Long).
- Tandai zona **Golden Pocket (50.0% – 61.8%)**.
- Pastikan Stochastic (14, 3, 3) di M15 tidak menunjukkan divergensi berlawanan.

### Langkah 3: Konfirmasi Trigger di Timeframe M5 (Logika AND Ketat)
Masuk posisi **HANYA JIKA KEDUA KONDISI INI TERPENUHI SECARA BERSAMAAN (AND)** di M5:
1. **Candlestick Reversal Terkonfirmasi (Kandel Close)**:
   - *Pin Bar / Hammer*: Ekor penolakan (*lower shadow*) $\ge 2\times$ panjang badan kandel (*body*), dengan toleransi ujung ekor $\le 0.1 \times \text{ATR}(14)$.
   - *Bullish Engulfing*: Badan kandel hijau menelan penuh badan kandel merah sebelumnya (toleransi $\le 0.05 \times \text{ATR}(14)$).
2. **DAN Konfirmasi Oscillator**:
   - Stochastic Oscillator (5, 3, 3) berada di area jenuh jual (*Oversold* < 20) dan membentuk *Golden Cross* ke atas saat penutupan kandel.

---

## 🛡️ 5. Manajemen Risiko & Stop Loss (Aturan Tanpa Kompromi)

### A. Penempatan Stop Loss Struktural
- **Stop Loss Wajib** dipasang di bawah level **Fibonacci 78.6%** atau di bawah ujung ekor terendah (*lowest wick*) kandel konfirmasi dengan bantalan toleransi $0.1 \times \text{ATR}(14)$.
- **Logika**: Jika harga ditutup di bawah 78.6%, premis bahwa kandel tersebut adalah koreksi sehat telah terbantahkan secara objektif.

### B. Rumus Ukuran Posisi dengan Penyesuaian Biaya (Fee & Slippage Adjusted)
Ukuran posisi dihitung presisi agar total kerugian riil (termasuk taker fee dan estimasi slippage) tidak melebihi **1.0% modal**:

$$\text{Position Size} = \frac{\text{Account Equity} \times \text{Risk Percentage (0.01)}}{|\text{Entry} - \text{Stop Loss}| + (\text{Entry} \times \text{Fee \& Slippage Buffer})}$$

*Parameter Standar:*
- Buffer Fee & Slippage = $0.001$ ($0.1\%$ untuk taker fee futures + buffer slippage kandel volatil).
- Contoh: Modal \$10,000, Risiko 1% = \$100.
  - Entry BTC = \$65,000, Stop Loss = \$64,600 (Jarak = \$400).
  - Buffer per BTC = $\$65,000 \times 0.001 = \$65$.
  - Total Risk per Unit = $\$400 + \$65 = \$465$.
  - Ukuran Posisi = $\frac{\$100}{\$465} \approx 0.215 \text{ BTC}$.

### C. Strategi Exit Bertahap (Dual-Take Profit)
- **TP1 (50% Posisi)**: Diambil di level *Previous Swing High* (Re-test Swing High 1.0) dengan syarat R:R minimal **1 : 1.0**.
  - *Aksi Otomatis*: Begitu TP1 tercapai, geser Stop Loss sisa posisi ke titik Entry (**Break-Even Point / BEP**). Posisi berubah menjadi *Risk-Free*.
- **TP2 (50% Sisa)**: Dibiarkan berjalan menuju level **Fibonacci Expansion 1.618**.

---

## 🚫 6. Daftar Pantangan Mutlak (Checklist Pembatalan Sinyal)

Sebuah rencana trade **BATAL OTOMATIS (STAND ASIDE)** jika:
- ❌ **Buffer Berita**: Berada dalam rentang **< 45 menit sebelum atau sesudah** rilis berita *High-Impact* (FOMC, CPI, NFP).
- ❌ Rasio Risk-to-Reward (R:R) ke TP1 kurang dari **1 : 1.0** (Re-test Swing High minimal sebanding dengan risiko stop loss).
- ❌ Terjadi penutupan kandel (*body close*) di bawah Fibonacci 78.6%.
- ❌ Terjadi divergensi reguler berlawanan arah pada timeframe H1.
- ❌ Daily Drawdown akun telah mencapai batas darurat **-3.0%** (Circuit Breaker aktif).
