# Laporan Verifikasi Pilar 3: Historical Backtest Opsi A & Opsi 2 (6 Bulan)

**Instrumen**: `BTCUSDT` Perpetual Futures (BingX / Binance Archive)  
**Periode Data**: 1 April 2026 – 26 September 2026 (51.417 Bar M5, 17.139 Bar M15, 4.285 Bar H1)  
**Mesin Eksekusi**: [`AstronacciDeterministicEngine.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/AstronacciDeterministicEngine.swift) (Swift Native Pure Math)  
**Metodologi**: Pre-registered Dominant Impulsive Swing + Runner 50/50 Chandelier 2.0x ATR + Single Source Veto Gate

---

## 🔬 1. Hasil Studi Ablasi Bertingkat (Isolasi Efek Komponen Opsi A & Opsi 2)

| Tahap Pengujian | Trades | Win Rate | Gross PF | Gross Exp | Net PF | Net PnL | Fast SL (<=2 bar) | Reachability (MFE>=TP1) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **0. Baseline (Fix Akuntansi D)** | 143 | 38.5% | 0.89 | -$2.19 | 0.46 | -$2.290,63 | 4.9% | 10.5% |
| **1. Tahap 1 (Dominant Swing)** | 91 | 34.1% | 0.70 | -$7.06 | 0.36 | -$2.081,54 | 1.1% | 6.6% |
| **2a. Tahap 2a (TP Swing High 1.0)** | 75 | 48.0% | 0.87 | -$4.56 | 0.51 | -$1.777,24 | 1.3% | 20.0% |
| **2b. Tahap 2b (TP Exp 1.272)** | 143 | 47.6% | 1.17 | +$4.60 | 0.75 | -$1.271,93 | 0.7% | 18.9% |
| **3. Tahap 3 (Blended Fee 2a)** | 75 | 48.0% | 0.88 | -$4.60 | 0.63 | -$1.237,54 | 1.3% | 20.0% |
| **4a. PRIMER (Chandelier + Maker + MaxHold 6h)** | **88** | **46.6%** | **0.97** | **-$0.90** | **0.69** | **-$1.163,04** | **2.3%** | **19.3%** |
| **4b. Sensitivitas Taker** | 88 | 46.6% | 0.97 | -$0.89 | 0.56 | -$1.761,53 | 2.3% | 19.3% |
| **4c. Sensitivitas Sesi ON** | 75 | 48.0% | 0.87 | -$4.91 | 0.62 | -$1.288,48 | 1.3% | 20.0% |
| **4d. Sensitivitas Split 30/70** | 88 | 46.6% | 0.99 | -$0.36 | 0.70 | -$1.124,47 | 2.3% | 19.3% |

---

## 🛡️ 2. Validasi Out-of-Sample Anti-Overfitting (Konfigurasi Primer 4a)

*Evaluasi ketat pada 34 trade Out-of-Sample (1 Agustus 2026 – 26 September 2026 holdout beku):*

| Parameter Validasi | In-Sample (Apr–Jul 2026) | Out-of-Sample (Agu–Sep 2026) | Target Gerbang Auditor | Status Faktual |
| :--- | :--- | :--- | :--- | :--- |
| **Ukuran Sampel** | 54 trade | 34 trade | >= 10 per split | ✅ **PASSED** |
| **Win Rate** | **44.4%** | **50.0%** | >= 45.0% | ✅ **PASSED** |
| **Gross Expectancy per Trade** | **-$3.85** | **+$3.77** | > 0.0 USDT (Gerbang IS) | ❌ **FAIL (IS Negatif -$3.85; Gugur di Gerbang 1)** |
| **Gross Profit Factor** | **0.90** | **1.13** | >= 1.25 | ❌ **FAIL** (1.13 vs 1.25) |
| **Net Expectancy per Trade** | **-$15.66** | **-$9.33** | > 0.0 USDT | ❌ **FAIL** (Net Negatif) |
| **Net Profit Factor** | **0.66** | **0.75** | > 1.20 | ❌ **FAIL** |
| **Maximum Drawdown** | **11.19%** | **6.61%** | < 6.00% | ❌ **FAIL** (6.61% vs 6.00%) |

---

## 🏃 3. Analisis Distribusi Runner & Payoff (Mengapa Tail Tidak Membayar?)

Sesuai hipotesis **Agent 2**, data empiris membuktikan bahwa **ekor kanan (tail) ekspansi gelombang tidak membayar biaya transaksi**:

- **Total Trade Dieksekusi**: 88 trade (Full Dataset) / 34 trade (OOS).
- **Target Reachability TP1 (Bank Triggered)**: 56 trade (63.6%) / 23 trade (67.6% OOS).
- **Distribusi Perjalanan Sisa 50% Posisi (Runner)**:
  - 🚀 **Mencapai TP2 (Exp 1.618)**: **2 trade (3.6%)** pada Full Dataset, dan **0 trade (0.0%)** pada OOS!
  - 🛡️ **Kena Trailing Stop Chandelier**: 12 trade (21.4%) pada Full Dataset / 5 trade (21.7%) pada OOS.
  - 🔄 **Pullback ke BEP Murni**: 0 trade.
  - ⏳ **Max Hold Expired (6 Jam Terombang-ambing)**: **42 trade (75.0%)** pada Full Dataset / **18 trade (78.3%)** pada OOS!

> **Temuan Kunci Karakter Pasar**: Setelah harga menyentuh Swing High 1.0 (mean reversion), pasar Bitcoin intraday M5/M15 **TIDAK** melanjutkan ekspansi impulsif ke 1.618, melainkan terkonsolidasi (*choppy*) hingga batas waktu 6 jam habis. Runner yang ditahan 6 jam tidak menghasilkan *fat right tail*, melainkan hanya tergerus biaya funding rate dan exit fee.

---

## ⚡ 4. Sweep Sensitivitas Fill-Rate Post-Only & Breakeven Fill Rate

Pengujian ketahanan strategi terhadap asumsi eksekusi maker post-only pada data Out-of-Sample:

| Fill Rate Asumsi | Ukuran Sampel OOS | Net PnL OOS | Net Expectancy / Trade | Net Profit Factor |
| :---: | :---: | :---: | :---: | :---: |
| **100% Fill** | 34 trade | -$317.28 | -$9.33 / trade | 0.75 |
| **90% Fill** | 32 trade | -$309.96 | -$9.69 / trade | 0.75 |
| **80% Fill** | 28 trade | -$337.97 | -$12.07 / trade | 0.70 |
| **70% Fill** | 24 trade | -$291.08 | -$12.13 / trade | 0.68 |

- **Breakeven Fill Rate**: **> 100%** (Pada 100% fill rate sekalipun, strategi masih net-negatif -$9.33/trade). Tidak ada tingkat keterisian order limit yang dapat mengubah strategi menjadi net profitabel pada struktur biaya saat ini.

---

## 🎯 5. Diagnostik Desil Skor Konfluensi (Status Selektivitas Skor)

Pemeriksaan ulang korelasi skor konfluensi terhadap Gross & Net PnL pada dataset pasca-harmonisasi Single Source of Truth (`evaluateVetoGate` bersama, 75 trade):

| Grade Konfluensi | Ambang Skor | Trades | Gross WR | Gross Expectancy / Trade | Net Expectancy (Taker) | Evaluasi Auditor (Agent 2) |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **A-Grade** | $\ge 80$ | 17 | 52.9% | **+$11.13** | -$1.76 | Positif, namun $n=17$ terlalu tipis |
| **B-Grade** | $65 - 79$ | 58 | 46.6% | **-$9.15** | -$25.68 | Negatif |

> **Koreksi Substantif & Penarikan Obituari Paket B (Audit Agent 2)**: Laporan sebelumnya yang menyatakan skor $\ge 80$ berkorelasi negatif dihitung dari artefak lama sebelum harmonisasi gate. Pada data baru dengan gate bersama, A-Grade berbalik menghasilkan gross positif (+$11.13/trade). Namun, ukuran sampel $n=17$ terlalu tipis untuk dijadikan dasar keputusan produksi. **Status Paket B dinyatakan INKONKLUSIF (obituari resmi ditarik)**. Selektivitas skor konfluensi tetap menjadi pertanyaan riset terbuka untuk kerangka kerja timeframe lebih tinggi (HTF).

---

## 🛑 6. Evaluasi Stop-Rule Auditor & Putusan Faktual

Mengacu pada kriteria stop-rule pre-registered yang disepakati secara aklamasi oleh **Agent 1** dan **Agent 2**:
1. **Gerbang Sekuensial 1 (In-Sample Gross Expectancy > 0)**: In-Sample Gross = **-$3.85 / trade** ➔ **GAGAL** (Strategi secara sah harus berhenti sejak tahap In-Sample).
2. **Net Expectancy OOS (Maker)**: **-$9.33 / trade** ➔ **GAGAL** (Target: > 0.0 USDT).
3. **Out-of-Sample Gross PF $\ge 1.25$ ATAU Net Expectancy $\ge -\$5.00$**: Gross PF 1.13, Net Exp -$9.33 ➔ **GAGAL**.
4. **Out-of-Sample Max Drawdown**: **6.61%** ➔ **GAGAL** (Target: < 6.00%).

### 🏛️ Putusan Resmi Konsensus (Agent 1, Agent 2, & Worker):
**STATUS PILAR 3: CLOSED — UNMONETIZABLE.**  
- **Falsifikasi Empiris M5**: Kerangka kerja scalping intraday M5 pada BTCUSDT terfalsifikasi secara empiris — edge kotor (+0.08R) tidak mampu menutup friksi komisi bursa (8–18 bps).
- **Pembekuan Parameter**: Dilarang keras melakukan tuning lanjutan, parameter sweeping, atau opsi modifikasi tambahan pada BTC M5 karena tergolong *overfitting* berlapis.
- **Pilar 4 Shadow Mode Live**: **TIDAK DIAKTIFKAN** pada M5 guna mencegah pembakaran modal atau kerugian semu.
- **Protokol Higiene Data Permanen**: Seluruh eksekusi/re-run simulasi di masa depan **WAJIB menulis berkas baru yang berversi unik**, dan **DILARANG KERAS menimpa berkas JSONL yang sudah ada**.

---

## 📁 7. Daftar Berkas Bukti & Artefak Data Berversi

1. **Konfigurasi Primer 4a**: [`data/FuturesScoutPaperTrades_stage4_primary.jsonl`](file:///Users/heizaaa/Desktop/cdev/iza-3/data/FuturesScoutPaperTrades_stage4_primary.jsonl) (88 trade).
2. **Sensitivitas Taker 4b**: [`data/FuturesScoutPaperTrades_stage4_taker.jsonl`](file:///Users/heizaaa/Desktop/cdev/iza-3/data/FuturesScoutPaperTrades_stage4_taker.jsonl) (88 trade).
3. **Sensitivitas Sesi ON 4c**: [`data/FuturesScoutPaperTrades_stage4_sessionOn.jsonl`](file:///Users/heizaaa/Desktop/cdev/iza-3/data/FuturesScoutPaperTrades_stage4_sessionOn.jsonl) (75 trade).
4. **Sensitivitas Split 30/70 4d**: [`data/FuturesScoutPaperTrades_stage4_30_70.jsonl`](file:///Users/heizaaa/Desktop/cdev/iza-3/data/FuturesScoutPaperTrades_stage4_30_70.jsonl) (88 trade).
5. **Baseline & Stage Lama**:
   - [`data/FuturesScoutPaperTrades_baseline.jsonl`](file:///Users/heizaaa/Desktop/cdev/iza-3/data/FuturesScoutPaperTrades_baseline.jsonl) (143 trade)
   - [`data/FuturesScoutPaperTrades_stage1.jsonl`](file:///Users/heizaaa/Desktop/cdev/iza-3/data/FuturesScoutPaperTrades_stage1.jsonl) (91 trade)
   - [`data/FuturesScoutPaperTrades_stage2a.jsonl`](file:///Users/heizaaa/Desktop/cdev/iza-3/data/FuturesScoutPaperTrades_stage2a.jsonl) (75 trade)
   - [`data/FuturesScoutPaperTrades_stage2b.jsonl`](file:///Users/heizaaa/Desktop/cdev/iza-3/data/FuturesScoutPaperTrades_stage2b.jsonl) (143 trade)
   - [`data/FuturesScoutPaperTrades_stage3.jsonl`](file:///Users/heizaaa/Desktop/cdev/iza-3/data/FuturesScoutPaperTrades_stage3.jsonl) (75 trade)
6. **Sinyal Ditolak Veto**: [`data/FuturesScoutVetoedSignals.jsonl`](file:///Users/heizaaa/Desktop/cdev/iza-3/data/FuturesScoutVetoedSignals.jsonl) (1.392 sinyal ditolak kontrafaktual).
7. **Engine Produksi Terkalibrasi**: [`boringNotch/Clicky/AstronacciDeterministicEngine.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/AstronacciDeterministicEngine.swift).