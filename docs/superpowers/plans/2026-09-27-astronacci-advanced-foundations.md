# Rencana Implementasi: 5 Fondasi Lanjutan Metodologi Prof. Dr. Gema Goeyardi (Astronacci Time & Price)

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Membangun 5 pilar fondasi lanjutan dari metode orisinil Prof. Dr. Gema Goeyardi (Astronacci International) ke dalam Izanotchy Futures Scout: Fibonacci Time Zones, Siklus Astrologi Finansial Deterministik (Meeus Ephemeris: Mercury Retrograde & Fase Bulan), Fibonacci Cluster (Key Reversal Zone / KRZ), Pola Quasimodo (QM Pattern), dan Divergensi Struktural Matematis.

**Architecture:** 
1. **Pilar Analisis Struktur Harga (Price Confluence)**: Memperluas `AstronacciDeterministicEngine.swift` dengan detektor Quasimodo (Left Shoulder, Head, Break of Structure), Fibonacci Cluster (irisan swing H1 + M15 $\le 0.25\times\text{ATR}$), dan divergensi matematis Stochastic (5,3,3) vs ayunan harga.
2. **Pilar Analisis Waktu (Time Dimension & Ephemeris)**: Membangun mesin astronomis murni offline (`AstronacciEphemerisEngine.swift`) berbasis algoritma Jean Meeus untuk menghitung fase Bulan (New/Full Moon $\pm 1$ hari) dan status Merkurius Retrograde secara deterministik (0 API eksternal, 0 network lag), serta memproyeksikan deret bar Fibonacci Time Zones (8, 13, 21, 34 bar).
3. **Pilar Visualisasi & CUA**: Memperbarui skrip Pine Script v5 di `FuturesScoutCoreAnalyst.swift` untuk memplot garis vertikal ungu proyeksi waktu (*Fibonacci Time Windows*) dan zona kotak KRZ Cluster pada TradingView.

**Tech Stack:** Swift 6.2 (Native macOS, Actor Isolation, Pure Mathematical Algorithms), Pine Script v5 (TradingView WebGL Rendering), Jean Meeus Astronomical Algorithms (Pure Swift Ephemeris).

**Spec:** [`docs/futures-scout/04-astronacci-complete-trading-encyclopedia.md`](file:///Users/heizaaa/Desktop/cdev/iza-3/docs/futures-scout/04-astronacci-complete-trading-encyclopedia.md)

## Global Constraints & Binding Auditor Invariants (Agent 1 & Agent 2 Ratified)

- **Engine Core Invariant (FROZEN)**: `AstronacciDeterministicEngine.evaluateConfluence` dan `evaluateVetoGate` berstatus **BEKU MUTLAK (IMMUTABLE)**. Dilarang keras menyuntikkan skor aditif (+10/15 poin) atau mengubah formula sizing/Stop Loss ke dalam core engine agar hasil studi empiris tidak tercemar.
- **Analyst Layer Only**: Seluruh 5 modul baru (Cluster KRZ, Divergensi, Quasimodo, Time Zones, Ephemeris) **wajib hidup murni di `FuturesScoutCoreAnalyst`** sebagai lensa analitis presentasional, anotasi kartu Markdown, dan overlay visual TradingView.
- **Time + Astro PRESENTATIONAL ONLY**: Dimensi waktu dan astrologi memiliki status **NOL GERBANG, NOL SKOR, dan NOL MUTASI KEPUTUSAN STATUS**. Modul ini murni memberikan konteks kognitif bagi trader manusia.
- **Unifikasi SSOT Waktu**: Tidak boleh membuat mesin waktu ganda. Tetap gunakan fungsi kanonis `FuturesScoutCoreAnalyst.evaluateFibonacciTimeWindow` berbasis anchor+count {8, 13, 21, 34} sebagai Single Source of Truth (SSOT), dan perluas dengan kalkulasi estimasi jam dinding UTC (`barsRemaining * barDuration -> Date`).
- **Zero External Network for Astronomy**: Perhitungan fase bulan dan Merkurius retrograde wajib dihitung secara matematika lokal (Meeus algorithms) tanpa ketergantungan API pihak ketiga agar fail-closed, privat, dan instan ($< 1$ ms).
- **Non-Repainting Invariant**: Seluruh deteksi QM, divergensi, dan cluster wajib hanya menggunakan kandel yang telah tertutup penuh (`isClosed == true`).
- **Memory Boundary**: Pine Script v5 overlay wajib mempertahankan batas memori TradingView (`max_lines_count=500`, `max_boxes_count=500`).
- **Backward Compatibility**: Seluruh suite tes regresi P0–P4 (Milestone 120–129) wajib tetap lolos 100%.

---

## 🗺️ Roadmap & Dekomposisi File

```
boringNotch/Clicky/
├── AstronacciDeterministicEngine.swift       [Modify: Integrasi Cluster, Divergensi, QM, & Time Score]
├── AstronacciEphemerisEngine.swift           [Create: Offline Lunar & Mercury Retrograde Calculator]
├── AstronacciTimeCycleEngine.swift           [Create: Fibonacci Time Zone & Bar Projection Engine]
├── AstronacciQuasimodoEngine.swift           [Create: Quasimodo Pattern Structural Validator]
├── FuturesScoutCoreAnalyst.swift             [Modify: Overlay Pine Time-Verticals & KRZ Boxes]
scripts/
├── test_fibonacci_cluster.swift              [Create: TDD KRZ Confluence Unit Tests]
├── test_astronacci_divergence.swift          [Create: TDD Regular & Hidden Divergence Tests]
├── test_astronacci_quasimodo.swift           [Create: TDD QM Pattern Structural Tests]
├── test_astronacci_time_cycles.swift         [Create: TDD Fibonacci Time Projection Tests]
└── test_astronacci_ephemeris.swift           [Create: TDD Lunar & Mercury Retrograde Tests]
```

---

## 📋 Task Breakdown

### Task 1: Fibonacci Cluster Engine (Key Reversal Zone / KRZ)

**Files:**
- Create: `boringNotch/Clicky/AstronacciClusterEngine.swift`
- Modify: `boringNotch/Clicky/AstronacciDeterministicEngine.swift:700-750`
- Test: `scripts/test_fibonacci_cluster.swift`

**Interfaces:**
- Consumes: `AstronacciKline` H1 array, `AstronacciKline` M15 array, `atr14: Double`.
- Produces: `AstronacciFibClusterResult` (`hasCluster: Bool`, `clusterLow: Double`, `clusterHigh: Double`, `confluenceRatios: [String]`, `bonusScore: Int`).

- [x] **Step 1: Write the failing TDD test**
  - Buat tes dengan swing H1 ($Low = 100, High = 150 \rightarrow 61.8\% = 119.10$) dan swing M15 ($Low = 110, High = 130 \rightarrow 50\% = 120.00$).
  - Assert selisih $|120.00 - 119.10| = 0.90 \le 0.25 \times \text{ATR}$ memicu `hasCluster == true`.
  - Jalankan tes dan pastikan gagal kompilasi/evaluasi.

- [x] **Step 2: Implement minimal `AstronacciClusterEngine`**
  - Hitung grid Fibonacci H1 dan grid Fibonacci M15 dari fractal pivots.
  - Cari irisan pasangan level $(H1_{ratio}, M15_{ratio})$ yang jaraknya $\le 0.25 \times \text{ATR}(14)$.
  - Sesuai instruksi Auditor Agent 1 & 2: presentational only pada CoreAnalyst, zero engine score mutation.

- [x] **Step 3: Run verification & commit checkpoint**
  - Jalankan `swiftc -parse-as-library scripts/test_fibonacci_cluster.swift -o /tmp/test_cluster && /tmp/test_cluster`.
  - Pastikan semua tes assertion lolos 100%.

---

### Task 2: Structural Mathematical Divergence Engine (Regular & Hidden)

**Files:**
- Create: `boringNotch/Clicky/AstronacciDivergenceEngine.swift`
- Modify: `boringNotch/Clicky/FuturesScoutCoreAnalyst.swift`
- Test: `scripts/test_astronacci_divergence.swift`

**Interfaces:**
- Consumes: Closed klines array, Stochastic (14,3,3) series.
- Produces: `AstronacciDivergenceResult` (`type: DivergenceType`, `isBullish: Bool`, `firstPivot: DivergencePivot?`, `secondPivot: DivergencePivot?`, `barsAgo: Int`, `description: String`).
  `DivergenceType`: `.regularBullish`, `.regularBearish`, `.hiddenBullish`, `.hiddenBearish`, `.none`.

- [x] **Step 1: Write failing TDD test**
  - Kasus 1: Harga membuat Lower Low ($Low_1 = 100, Low_2 = 92$), Stochastic membuat Higher Low ($K_1 = 12, K_2 = 28$) $\rightarrow$ `.regularBullish`.
  - Kasus 2: Harga membuat Higher Low ($Low_1 = 100, Low_2 = 105$), Stochastic membuat Lower Low ($K_1 = 30, K_2 = 18$) $\rightarrow$ `.hiddenBullish`.
  - Kasus 3: Data kandel flat $\rightarrow$ `.none`.
  - Kasus 4: Signal staleness / expiry $> 8$ bar $\rightarrow$ `.none`.

- [x] **Step 2: Implement minimal `AstronacciDivergenceEngine`**
  - Implementasikan algoritma pencari lembah (*trough*) dan puncak (*crest*) lokal pada kandel M15.
  - Bandingkan kemiringan (*slope*) harga terhadap kemiringan oscillator Stochastic smoothed %K.
  - Sesuai instruksi Auditor: presentational only pada CoreAnalyst Markdown card, zero engine score mutation.

- [x] **Step 3: Run verification & commit checkpoint**
  - Jalankan `swiftc -parse-as-library scripts/test_astronacci_divergence.swift -o /tmp/test_div && /tmp/test_div`.

---

### Task 3: Quasimodo (QM Pattern / Over-Under) Recognizer

**Files:**
- Create: `boringNotch/Clicky/AstronacciQuasimodoEngine.swift`
- Modify: `boringNotch/Clicky/FuturesScoutCoreAnalyst.swift`
- Test: `scripts/test_astronacci_quasimodo.swift`

**Interfaces:**
- Consumes: 3-bar / 5-bar pivot fractals series.
- Produces: `AstronacciQMResult` (`type: QMType`, `isBullish: Bool`, `leftShoulderPrice: Double`, `headPrice: Double`, `bosPrice: Double`, `retestTargetPrice: Double`, `invalidationPrice: Double`, `isLeftShoulderInGP: Bool`, `isRetestingNow: Bool`, `description: String`).

- [x] **Step 1: Write failing TDD test**
  - Definisikan sekuens 4 pivot:
    - Bullish QM: $Low_1 = 100$ (Left Shoulder) $\rightarrow High_1 = 110 \rightarrow Low_2 = 94$ (Head) $\rightarrow High_2 = 116$ (Higher High Break of Structure).
    - Verifikasi level re-test entri berada di $100$ (Left Shoulder) yang berimpit dengan Golden Pocket gelombang $Low_2 \rightarrow High_2$.
  - Jalankan tes dan konfirmasi gagal.

- [x] **Step 2: Implement minimal `AstronacciQuasimodoEngine`**
  - Evaluasi 4 fractal pivot terakhir:
    - Bearish QM: $High_1 \rightarrow Low_1 \rightarrow High_2 > High_1 \rightarrow Low_2 < Low_1$.
    - Bullish QM: $Low_1 \rightarrow High_1 \rightarrow Low_2 < Low_1 \rightarrow High_2 > High_1$.
  - Validasi bahwa level bahu kiri (*Left Shoulder*) berada di dalam rentang Fibonacci 50.0% – 61.8% / OTE dari ayunan Head menuju BOS.

- [x] **Step 3: Run verification & commit checkpoint**
  - Jalankan `swiftc -parse-as-library scripts/test_astronacci_quasimodo.swift -o /tmp/test_qm && /tmp/test_qm`.

---

### Task 4: Fibonacci Time Zones & Bar Projection Engine

**Files:**
- Modify: `boringNotch/Clicky/FuturesScoutCoreAnalyst.swift`
- Test: `scripts/test_astronacci_time_cycles.swift`

**Interfaces:**
- Consumes: Anchor index, current closed bar index, reference Date, barIntervalSeconds.
- Produces: `FibonacciTimeWindow` (`state: State`, `currentBarCount: Int`, `currentTargetFib: Int`, `barsRemaining: Int`, `displayText: String`, `estimatedTargetDate: Date?`).

- [x] **Step 1: Write failing TDD test**
  - Uji durasi bar pada timeframe M15 (900 detik):
    - Assert proyeksi rasio Fibonacci: bar ke-8 inWindow, bar ke-10 menuju bar 13 terhitung 3 bar tersisa.
    - Assert estimasi tanggal pembalikan dihitung akurat dari `referenceDate + barsRemaining * 900s` dalam format UTC.
  - Jalankan tes dan pastikan gagal.

- [x] **Step 2: Implement minimal `FibonacciTimeWindow` extension**
  - Hitung rentang bar antara anchor dominant swing dan kandel terakhir.
  - Proyeksikan zona waktu Fibonacci: bar ke-8, 13, 21, dan 34 dari titik anchor.
  - Hasilkan estimasi tanggal jam dinding UTC untuk kartu Markdown dan garis vertikal Pine Script.

- [x] **Step 3: Run verification & commit checkpoint**
  - Jalankan `swiftc -parse-as-library scripts/test_astronacci_time_cycles.swift -o /tmp/test_tc && /tmp/test_tc`.

---

### Task 5: Deterministic Astronomical Ephemeris Engine (Lunar & Mercury Retrograde)

**Files:**
- Create: `boringNotch/Clicky/AstronacciEphemerisEngine.swift`
- Modify: `boringNotch/Clicky/FuturesScoutCoreAnalyst.swift`
- Test: `scripts/test_astronacci_ephemeris.swift`

**Interfaces:**
- Consumes: `date: Date`.
- Produces: `AstronacciAstroReport` (`lunarPhase: LunarPhase`, `moonAgeDays: Double`, `moonElongationDeg: Double`, `isNearNewOrFullMoon: Bool`, `mercuryMotion: PlanetaryMotion`, `mercuryVelocityDegPerDay: Double`, `description: String`).

- [x] **Step 1: Write failing TDD test**
  - Validasi benchmark tanggal astronomis historis:
    - 2026-09-26: Moon Age ~14.6 hari (Full Moon) $\rightarrow$ `isNearNewOrFullMoon == true`.
    - 2026-03-05: Periode Merkurius Retrograde terverifikasi (kecepatan geosentris semu $< 0^\circ/\text{hari}$).
    - 2026-09-26: Merkurius Direct terverifikasi (kecepatan $> 0.05^\circ/\text{hari}$).
    - Benchmark kinerja: 10.000 kalkulasi dalam $< 50$ ms.
  - Jalankan tes dan pastikan gagal.

- [x] **Step 2: Implement pure-Swift Jean Meeus Astronomical Engine**
  - Hitung Julian Day ($JD$) dari `Date`.
  - Hitung bujur ekliptika Matahari ($\lambda_{sun}$) dan Bulan ($\lambda_{moon}$) menggunakan algoritma aproksimasi presisi tinggi Meeus ($< 0.1^\circ$ error).
  - Tentukan elongasi sudut $(\lambda_{moon} - \lambda_{sun}) \pmod{360^\circ}$ untuk menentukan fase bulan eksak (0° New Moon, 180° Full Moon).
  - Hitung vektor kecepatan semu Merkurius untuk mendeteksi status Retrograde.
  - Nol jaringan, nol internet, dieksekusi dalam $< 0.002$ ms per panggilan.

- [x] **Step 3: Run verification & commit checkpoint**
  - Jalankan `swiftc -parse-as-library scripts/test_astronacci_ephemeris.swift -o /tmp/test_eph && /tmp/test_eph`.

---

### Task 6: Unified Integration — Pine Script v5 Time-Verticals, Presentation Card, & E2E Validation

**Files:**
- Modify: `boringNotch/Clicky/FuturesScoutCoreAnalyst.swift` (tambahkan visualisasi Pine Script vertical lines untuk Time Zones & kotak KRZ Cluster).
- Test: `scripts/test_chart_analyst.swift`.

**Interfaces:**
- Consumes: Hasil dari seluruh Task 1–5.
- Produces: Pine Script v5 terpadu dengan zona KRZ, garis vertikal ungu proyeksi waktu, level QM Left Shoulder, kartu Markdown lengkap dengan seksi *"Dimensi Waktu & Astrologi Finansial"*.

- [x] **Step 1: Update Pine Script generator di `FuturesScoutCoreAnalyst.swift`**
  - Tambahkan plotting garis vertikal ungu putus-putus pada bar proyeksi waktu Fibonacci.
  - Tambahkan kotak penanda Key Reversal Zone (KRZ) jika cluster H1+M15 terkonfirmasi.
  - Tambahkan garis referensi Quasimodo Left Shoulder jika pola terdeteksi.
- [x] **Step 2: Update Card & Voice presentation**
  - Tampilkan rincian:
    - *KRZ Confluence*: Terdeteksi / Tidak
    - *Struktur QM*: Terdeteksi (Left Shoulder @ $X) / Tidak
    - *Divergensi*: Regular Bullish / Hidden / Netral
    - *Siklus Waktu & Bulan*: Full Moon Phase (Hari ke-15) + Waktu Retrace (Bar 13 @ 14:45 UTC)
- [x] **Step 3: Comprehensive Test Suite & Clean Compilation**
  - Jalankan seluruh tes TDD (Tasks 1–5 + Regression P0–P4).
  - Kompilasi `xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug build`.
  - Re-sign `IzanotchyDev` dan luncurkan proses segar.

---

## 🔒 Verification & Safety Protocol

1. **Anti-Hallucination Mathematics**: Semua hitungan astrologi dan Fibonacci berakar pada rumus astronomis Meeus dan matematika fraktal, bukan prompt LLM liar.
2. **Deterministic Fallback**: Jika data kandel H1 atau M15 tidak mencukupi untuk cluster, sistem fail-closed dan kembali ke Fibonacci swing tunggal standar tanpa crash.
3. **Execution Gating**: Tidak ada mutasi kanvas jika status pasar choppy (`.standAsideChoppy`).
