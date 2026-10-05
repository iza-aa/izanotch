# 📊 Laporan Hasil Uji Out-of-Sample (OOS 30%) H1 BTCUSDT (Evaluasi Gerbang 2)

> **Status**: OUT-OF-SAMPLE EVALUATION COMPLETED (ZERO RETROFITTING / ZERO DATA SNOOPING)  
> **Instrumen**: `BTCUSDT` (Jalur Kualifikasi Aset Tunggal yang Diratifikasi Auditor Agent 1 & Agent 2)  
> **Periode OOS**: 16 Februari 2026 – 26 September 2026 (5.347 Kandel H1 / ~7,3 Bulan)  
> **Pre-Warm**: 250 Kandel Terakhir In-Sample (Zero Signal Leakage)  
> **Piagam Acuan**: [`docs/futures-scout/07-pilar-3-h1-pre-registration-charter.md`](file:///Users/heizaaa/Desktop/cdev/iza-3/docs/futures-scout/07-pilar-3-h1-pre-registration-charter.md) (Rev 2.1)

---

## 🎯 1. Ringkasan Eksekutif & Status Gerbang 2

Sesuai piagam pre-registrasi Rev 2.1 dan lampu hijau dari **Auditor Agent 1** dan **Agent 2**, simulasi Out-of-Sample (OOS 30%) telah dieksekusi secara steril dengan parameter beku 100%. Hasil evaluasi terhadap tiga kriteria Gerbang 2 adalah sebagai berikut:

| Kriteria Evaluasi Gerbang 2 | Ambang Batas Piagam Rev 2.1 | Hasil Aktual OOS (Arm B Taker) | Status Faktual |
| :--- | :--- | :--- | :--- |
| **1. Gross Profit Factor OOS** | **$\ge 1.25$** | **$1.13$** | ❌ **GAGAL (FAILED)** |
| **2. Net Expectancy OOS (Taker Penuh)** | **$> 0.0\text{ USDT}$** | **$-\$5.56\text{ / trade}$** | ❌ **GAGAL (FAILED)** |
| **3. Max Drawdown OOS (Basis Sizing 0.5%)** | **$< 6.0\%$** | **$4.79\%$** *(Basis 1.0%: $9.46\%$)* | ✅ **LOLOS (PASSED)** |

> 🛑 **PUTUSAN RESMI GERBANG 2**: **GAGAL (FAILED) — STOP-RULE TERPICU SECARA OTOMATIS.**  
> Sesuai klausul integritas ilmiah pada Piagam Rev 2.1: Karena Kriteria 1 dan Kriteria 2 tidak terpenuhi pada baseline Arm B (Taker), **sistem TIDAK LOLOS untuk deployment live execution otomatis**. Tidak ada modifikasi parameter sepihak (*zero curve-fitting*), dan hasil dilaporkan apa adanya kepada dewan auditor.

---

## 📊 2. Matriks Kinerja Lengkap Out-of-Sample (OOS)

Simulasi dijalankan pada 5.347 kandel H1 (16 Feb 2026 s/d 26 Sep 2026) dengan saldo awal $\$10.000$:

| Lengan Simulasi (Arm) | Trades ($n$) | Win Rate | Gross PF | Gross Exp | Net PF | Net Exp | MaxDD (1.0%) | MaxDD (0.5% Basis) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **ARM_A_MAKER** (Maker Optimis) | 40 | 37.5% | 1.13 | +$8.18 | 0.98 | -$1.17 | 8.52% | **4.30%** |
| **ARM_B_TAKER** (Taker Baseline) | 40 | 37.5% | 1.13 | +$8.11 | 0.92 | **-$5.56** | 9.46% | **4.79%** |
| **ARM_C_RUNNER5050** (Runner TP2) | 40 | 37.5% | 1.17 | +$10.55 | **1.01** | **+$0.64** | 7.64% | **3.88%** |

### 🔍 Rincian Finansial & Friksi Biaya (40 Trade OOS)
* **ARM_B_TAKER**:
  - Gross Profit: $\$2.823,03$ | Gross Loss: $\$2.498,69$ | **Gross Alpha**: **$+\$324,34$** ($+\$8.11\text{/trade}$)
  - Total Fee Dibayar: $\$546,57$ (**Rata-rata $\$13.66\text{/trade}$**)
  - Net PnL Akhir: $\$324,34 - \$546,57 = \mathbf{-\$222,23}$ ($\mathbf{-\$5.56\text{/trade}}$)
  - Distribusi Exit: 13 TP1 Retest ($32.5\%$), 25 Stop Loss ($62.5\%$), 2 Max Hold Expired ($5.0\%$).
* **ARM_A_MAKER**:
  - Gross Profit: $\$2.844,64$ | Gross Loss: $\$2.517,61$ | **Gross Alpha**: **$+\$327,03$** ($+\$8.18\text{/trade}$)
  - Total Fee Dibayar: $\$373,91$ (**Rata-rata $\$9.35\text{/trade}$**)
  - Net PnL Akhir: $\$327,03 - \$373,91 = \mathbf{-\$46,88}$ ($\mathbf{-\$1.17\text{/trade}}$)
* **ARM_C_RUNNER5050**:
  - Gross Profit: $\$2.957,20$ | Gross Loss: $\$2.535,36$ | **Gross Alpha**: **$+\$421,84$** ($+\$10.55\text{/trade}$)
  - Total Fee Dibayar: $\$396,31$ (**Rata-rata $\$9.91\text{/trade}$**)
  - Net PnL Akhir: $\$421,84 - \$396,31 = \mathbf{+\$25,53}$ ($\mathbf{+\$0.64\text{/trade}}$)
  - Distribusi Exit: 25 Stop Loss ($62.5\%$), 10 Chandelier Runner Profit ($25.0\%$), 3 TP2 1.618 Expansion ($7.5\%$), 2 Max Hold Expired ($5.0\%$).

---

## 🔬 3. Perbandingan Faktual: In-Sample (IS) vs Out-of-Sample (OOS)

| Metrik Kunci | In-Sample (16.5 Bulan) | Out-of-Sample (7.3 Bulan) | Delta / Pembusukan (*Decay*) |
| :--- | :--- | :--- | :--- |
| **Frekuensi Trade** | $6.18\text{ trade/bulan}$ ($102\text{ trades}$) | $5.48\text{ trade/bulan}$ ($40\text{ trades}$) | $-11.3\%$ (Konsistensi sinyal sangat tinggi) |
| **Win Rate** | $38.2\%$ ($39\text{ W} / 63\text{ L}$) | $37.5\%$ ($15\text{ W} / 25\text{ L}$) | $\mathbf{-0.7\%}$ **(Hampir identik, nol overfitting pola)** |
| **Gross Profit Factor** | $1.19$ | $1.13$ | $-0.06$ (Gross edge tetap bertahan $>1.0$) |
| **Gross Expectancy** | **$+\$11.69\text{ / trade}$** | **$+\$8.11\text{ / trade}$** | $\mathbf{-30.6\%}$ (Degradasi wajar out-of-sample) |
| **Beban Fee per Trade** | $\$11.19\text{ / trade}$ | $\$13.66\text{ / trade}$ | $+22.1\%$ (Karena harga rata-rata BTC lebih tinggi) |
| **Net Expectancy (Arm B)** | **$+\$0.50\text{ / trade}$** | **$-\$5.56\text{ / trade}$** | **Tertekan di bawah nol akibat beban fee** |
| **MaxDD (Basis 0.5%)** | $5.01\%$ | $4.79\%$ | **Terkendali stabil di bawah $6.0\%$** |
| **MaxDD (Basis 1.0%)** | $10.03\%$ | $9.46\%$ | **Sangat stabil di kisaran $9-10\%$** |

---

## 🧭 4. Pemecahan Dua Arah (Directional Breakdown — Arm B Taker)

Sesuai arahan Auditor Agent 1, performa dipilah secara independen antara posisi LONG dan SHORT:

| Arah Posisi | Jumlah Trade ($n$) | Win Rate | Gross PnL ($) | Gross Exp ($) | Net PnL ($) | Net Exp ($) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **LONG** | 21 | 33.3% (7W / 14L) | +$51.48 | +$2.45 | -$238.94 | **-$11.38** |
| **SHORT** | 19 | 42.1% (8W / 11L) | +$272.86 | +$14.36 | +$16.70 | **+$0.88** |

### 📈 Konteks Market Drift & Asimetri Arah
* **Konteks Drift Pasar OOS**: Sepanjang periode OOS, Bitcoin mengalami reli naik yang sangat kuat ($+\$68.797,70 \to +\$83.989,20$ atau **$+22.08\%$**).
* **Fenomena Kontra-Intuitif**: Meskipun pasar mengalami *bullish drift* $+22\%$, posisi **SHORT justru berkinerja jauh lebih baik** (Gross $+\$272,86$, Net $+\$16,70$) dibandingkan LONG (Gross $+\$51,48$, Net $-\$238,94$).
* **Root Cause Asimetri**:
  1. Pada fase ekspansi bull impulsif yang agresif, *pullback* ke Golden Pocket (50%–61.8%) seringkali diwarnai *shakeout* volatilitas tinggi yang menusuk level invalidasi 78.6% sebelum harga berbalik naik, memicu SL prematur pada posisi LONG.
  2. Sebaliknya, ayunan korektif ke arah bawah setelah reli *overbought* menghasilkan pembalikan tajam terukur menuju level Retest TP1 tanpa koreksi dalam, memungkinkan posisi SHORT mencapai target lebih konsisten.

---

## 💡 5. Analisis Fenomena Arm C (Runner 50/50)

Meskipun Gerbang 2 diputuskan pada Arm B sesuai piagam, data OOS Arm C menghasilkan temuan yang signifikan:
* **Arm C berhasil membukukan Net Positif di OOS**: Gross Expectancy $+\$10.55\text{/trade}$, Net Expectancy $+\$0.64\text{/trade}$, Net PF $1.01$, dan MaxDD $3.88\%$ pada basis $0.5\%$.
* **Mekanisme Penyelamat**: Berbeda dengan Arm B yang menutup seluruh posisi di TP1 (Retest Swing High/Low), Arm C membiarkan $50\%$ posisi berlari dengan trailing stop Chandelier $2.0\times\text{ATR}$ dan target ekspansi 1.618 Fib. Pada kandel H1, keuntungan ekor kanan (*right-tail expansion*) dari 13 trade runner mampu mengompensasi beban biaya komisi.
* **Integritas Metodologi**: Sesuai prinsip *anti-snooping*, kita **TIDAK MENGUBAH** aturan main secara retroaktif untuk meloloskan Arm C sebagai pemenang dadakan. Status Gerbang 2 tetap dinyatakan GAGAL pada baseline Arm B.

---

## 📁 6. Berkas Bukti & Artefak Data Berversi

1. **Arsip Data H1 OOS (Terverifikasi 100% Bebas Celah & Monotonik)**:
   - [`data/h1_archive_OOS_BTCUSDT.json`](file:///Users/heizaaa/Desktop/cdev/iza-3/data/h1_archive_OOS_BTCUSDT.json) (5.347 bar H1)
2. **Log Trade Eksekusi OOS Berversi**:
   - [`data/h1_trades_oos_armA.jsonl`](file:///Users/heizaaa/Desktop/cdev/iza-3/data/h1_trades_oos_armA.jsonl) (40 trade)
   - [`data/h1_trades_oos_armB.jsonl`](file:///Users/heizaaa/Desktop/cdev/iza-3/data/h1_trades_oos_armB.jsonl) (40 trade)
   - [`data/h1_trades_oos_armC.jsonl`](file:///Users/heizaaa/Desktop/cdev/iza-3/data/h1_trades_oos_armC.jsonl) (40 trade)
3. **Log Sinyal Ditolak Veto OOS**:
   - [`data/h1_vetoed_signals_oos.jsonl`](file:///Users/heizaaa/Desktop/cdev/iza-3/data/h1_vetoed_signals_oos.jsonl) (707 sinyal veto)

---

## 🏛️ 7. Kesimpulan & Opsi Rekomendasi untuk Auditor (Agent 1 & Agent 2)

### Kesimpulan Ilmiah Faktual:
1. **Model Tidak Overfit**: Pola struktur harga H1 sangat stabil antara In-Sample dan Out-of-Sample: Win Rate stabil di $37.5\% - 38.2\%$, frekuensi sinyal stabil di $5.5 - 6.2\text{ trade/bulan}$, dan Gross Profit Factor tetap berada di atas $1.10$.
2. **Keterbatasan Friksi Biaya Taker Penuh pada Ayunan H1 Standar**: Degradasi natural dari gross edge ($+\$11.69 \to +\$8.11$) membuat margin keuntungan kotor tidak cukup lebar untuk menelan biaya taker penuh $0.10\%$ bolak-balik ($\$13.66\text{/trade}$) pada Arm B.
3. **Stop-Rule Berhasil Melindungi Modal**: Protokol pre-registrasi membuktikan nilainya — mencegah kita menggelontorkan modal nyata ke bot otomatis yang secara matematis berada pada *razor-thin edge* yang rentan tergerus komisi exchange.

### Tiga Opsi Arah Lanjutan yang Diajukan:

* **Opsi 1: Hormati Stop-Rule & Bekukan Izanotchy sebagai "On-Demand Chart Analyst" (Opsi B)**
  - Menegaskan bahwa peran sejati Izanotchy adalah sebagai asisten analitis interaktif cerdas (*co-pilot*) di layar pengguna yang menyediakan peta Fibonacci objektif, kalkulasi risk-reward, dan bimbingan visual instan di TradingView.
  - Eksekusi trading riil tetap berada di tangan pengguna (*human-in-the-loop*) yang dapat memilih entri *maker limit order* dengan fee rendah dan seleksi diskresioner.
* **Opsi 2: Kualifikasi Khusus Arm C (Studi Lanjutan Ekstensi Ekor Kanan)**
  - Mengkaji apakah struktur trailing runner Arm C (yang membukukan Net Positif di kedua segmen IS dan OOS) layak dirumuskan dalam Piagam Pre-Registrasi Baru yang berfokus pada strategi *trend-following expansion* murni daripada *mean-reversion retest*.
* **Opsi 3: Pengujian Limit Maker & Fee-Tier Optimization**
  - Menguji arsitektur eksekusi yang mewajibkan 100% *post-only maker* (menghilangkan fee taker $0.05\%$ per sisi menjadi $0.02\%$ atau rabat VIP) untuk melihat kelayakan hidup sistem otomatis berbiaya ultra-rendah.
