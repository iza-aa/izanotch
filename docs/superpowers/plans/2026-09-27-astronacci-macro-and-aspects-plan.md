# Rencana Implementasi: Tiga Dimensi Makro & Astrologi Lanjutan Metodologi Prof. Dr. Gema Goeyardi (Konsensus Auditor Agent 1 & Agent 2)

> **Status:** RATIFIED BY AUDITOR AGENT 1 & AGENT 2 — SIAP EKSEKUSI FASE 1  
> **Metodologi:** Opsi A Bertahap (Fase 1: News Buffer + Planetary Aspects; Fase 2: Intermarket Analysis)  
> **Kompatibilitas:** Mempertahankan Engine Core `AstronacciDeterministicEngine` tetap BEKU MUTLAK (IMMUTABLE), murni diekspos di lapisan `FuturesScoutCoreAnalyst` dan presentasi kartu Markdown.  
> **UI Invariant:** NOL clutter di kanvas chart (NOL Pine Script badge makro/aspek; murni di briefing card). TTS audio narasi tetap $< 300$ karakter bersih tanpa aspek planet.

---

## 🎯 Goal & Konsensus Auditor

Melengkapi 3 ranah keilmuan makro dan astrologi tingkat lanjut dari metodologi lengkap **Asst. Prof. Dr. Gema Merdeka Goeyardi (Astronacci International)** dengan disiplin bertahap:

- **Fase 1 (Eksekusi Sekarang — 100% Offline & Penjaga Risiko Langsung)**:
  1. **Modul 1: High-Impact Economic News Calendar (Buffer $\pm 45$ Menit)**:
     - Resource JSON berversi (`economic_calendar_2025_2026.json`) dengan field `validUntil`.
     - Penjadwalan waktu rilis dalam ET dengan tzdb (CPI/NFP 08:30 ET, FOMC 14:00 ET) otomatis menyesuaikan DST (EDT/EST).
     - Aturan SOP Bab 7 Astronacci: Jarak waktu $\le 45$ menit memicu badge peringatan merah **STAND ASIDE**.
     - Fail-open transparan: Jika kalender melewati `validUntil`, sistem menampilkan peringatan *"jadwal melewati masa berlaku — perbarui data"*.
  2. **Modul 2: Planetary Aspects & Zodiac Ingress (Jean Meeus Canon)**:
     - 7 benda langit: Matahari, Bulan, Merkurius, Venus, Mars, Jupiter, Saturnus.
     - 5 aspek geometri mayor: Conjunction ($0^\circ$), Sextile ($60^\circ$), Square ($90^\circ$), Trine ($120^\circ$), Opposition ($180^\circ$) dengan orb $\le 3.0^\circ$.
     - Pembatasan kepadatan informasi: Maksimal 3 aspek terkuat (orb terkecil) yang ditampilkan pada kartu.
     - Labeling kualifikasi presentasional jujur: *"konteks geometri astrologi (Eye of Future), bukan sinyal pasti"*.
     - Kalibrasi bujur Bulan terhadap almanak historis toleransi $\le 0.5^\circ$.
     - Audio TTS tetap $< 300$ karakter (aspek planet murni di kartu, nol polusi suara).
     - Nol Pine Script clutter (kanvas chart TradingView tetap bersih).

- **Fase 2 (Eksekusi Berikutnya — Data Feed Cross-Market)**:
  3. **Modul 3: Intermarket Analysis (Proksi Indeks DXY & Emas)**:
     - Menggunakan pemetaan kontrak BingX yang valid hasil probe Auditor Agent 1: `NCSIDXY2USD-USDT` (proksi indeks DXY) dan `XAUT-USDT` (Tether Gold).
     - Dilabeli secara eksplisit di kartu sebagai *"proksi indeks DXY"*, bukan DXY resmi ICE.
     - Analisis tren EMA 21/34 H1 sebagai heuristik konteks likuiditas makro (Headwind vs Tailwind), tanpa memutasi skor engine core.

---

## 🏛️ Invarian Arsitektur & Dewan Auditor

1. **Engine Core Immutability (FROZEN)**:
   - `AstronacciDeterministicEngine` tetap 100% BEKU. Nol perubahan formula skor, nol penambahan bobot retroaktif, dan nol modifikasi stop-rule Gerbang 2 OOS yang telah diratifikasi.
2. **Presentational & Advisory Layer Only**:
   - Seluruh modul makro dan aspek hidup murni di `FuturesScoutCoreAnalyst` dan kartu briefing.
3. **Zero-Lag & Offline-First**:
   - Modul Berita dan Modul Aspek Planet berjalan 100% offline secara deterministik instan ($< 0.05$ ms).
4. **Clean Canvas Invariant**:
   - Tidak ada penambahan badge makro/aspek ke dalam Pine Script overlay agar chart TradingView tidak over-cluttered.

---

## 🗺️ Roadmap & Dekomposisi File Fase 1

```
boringNotch/Clicky/
├── Resources/
│   └── economic_calendar_2025_2026.json     [CREATE: Database JSON rilis resmi FOMC, CPI, NFP, GDP + validUntil]
├── AstronacciEconomicCalendarEngine.swift   [CREATE: Engine deteksi buffer berita 45 menit ET/tzdb]
├── AstronacciPlanetaryAspectEngine.swift    [CREATE: Engine 5 Aspek Mayor Meeus, Ingress, & Cap Orb]
├── FuturesScoutCoreAnalyst.swift            [MODIFY: Integrasi kartu briefing News Alert & 3 Aspek Terkuat]
scripts/
├── test_astronacci_economic_calendar.swift  [CREATE: Suite TDD 6 Kasus Uji Kalender Berita]
├── test_astronacci_planetary_aspects.swift  [CREATE: Suite TDD 7 Kasus Uji Aspek Planet, Ingress, & Kalibrasi Bulan]
└── run_all_tdd.sh                           [MODIFY: Integrasi Suite 8 & Suite 9 ke runner kanonis]
```

---

## 📋 Task Breakdown Fase 1

### Task 1: Resource JSON Kalender Berita & `AstronacciEconomicCalendarEngine`
*Menegakkan Bab 7 SOP Astronacci: Buffer berita besar $\le 45$ menit.*

- **Komponen**:
  - `boringNotch/Clicky/Resources/economic_calendar_2025_2026.json`:
    - Memuat tanggal dan jam rilis (ET) resmi FOMC, CPI, NFP, dan GDP AS untuk 2025–2026.
    - Field `version: "1.0"` dan `validUntil: "2026-12-31T23:59:59Z"`.
  - `boringNotch/Clicky/AstronacciEconomicCalendarEngine.swift`:
    - Mengurai JSON berversi dengan fallback built-in string JSON jika dijalankan di luar app bundle.
    - Mengonversi `date` (YYYY-MM-DD) dan `timeET` (HH:mm) menggunakan `TimeZone(identifier: "America/New_York")!` sehingga kebal perubahan DST (EDT vs EST).
    - Menghitung delta waktu menit $\Delta t = (t_{\text{event}} - t_{\text{current}})$.
    - Evaluasi buffer: Jika $-45 \le \Delta t \le +45 \implies \text{isInsideBuffer} = \text{true}$.
    - Deteksi kedaluwarsa: Jika $t_{\text{current}} > \text{validUntil} \implies$ pasang peringatan `"Jadwal kalender ekonomi telah melewati masa berlaku (\(validUntilStr)) — mohon perbarui data kalender."`.
- **TDD Test**: `scripts/test_astronacci_economic_calendar.swift`
  - Kasus 1: Simulasi 30 menit sebelum FOMC (13:30 ET) $\rightarrow$ `isInsideBuffer == true`, Veto News Alert aktif.
  - Kasus 2: Simulasi 15 menit setelah CPI (08:45 ET) $\rightarrow$ `isInsideBuffer == true` (volatilitas pasca-rilis).
  - Kasus 3: Simulasi 90 menit sebelum NFP (07:00 ET) $\rightarrow$ `isInsideBuffer == false`, hitung mundur 90 menit ditampilkan.
  - Kasus 4: Hari libur / tidak ada agenda $\rightarrow$ `isInsideBuffer == false`.
  - Kasus 5: Uji kekebalan DST: Summer (EDT UTC-4) vs Winter (EST UTC-5) terhitung presisi jam rilisnya.
  - Kasus 6: Uji tanggal melewati `validUntil` (2027) $\rightarrow$ pesan peringatan kedaluwarsa muncul jelas.

---

### Task 2: `AstronacciPlanetaryAspectEngine` (Meeus Canon & Cap Kepadatan)
*Memperluas ephemeris ke 5 aspek mayor, perpindahan zodiak, dan kalibrasi bujur Bulan.*

- **Komponen**: `AstronacciPlanetaryAspectEngine.swift`
- **Konsep Matematis & Aturan Auditor**:
  - 7 benda langit: Matahari, Bulan, Merkurius, Venus, Mars, Jupiter, Saturnus.
  - Menghitung bujur ekliptika geosentris presisi tinggi (deret Meeus).
  - Menghitung sudut separasi terkecil $\Delta\theta = \min(|\lambda_A - \lambda_B| \pmod{360^\circ}, 360^\circ - |\lambda_A - \lambda_B| \pmod{360^\circ})$.
  - 5 Aspek Mayor (Orb $\le 3.0^\circ$):
    - Conjunction ($0^\circ$), Sextile ($60^\circ$), Square ($90^\circ$), Trine ($120^\circ$), Opposition ($180^\circ$).
  - Filter Kepadatan (Amandemen Agent 1):
    - Sortir seluruh aspek aktif berdasarkan orb terkecil.
    - Ambil **maksimal 3 aspek terkuat** untuk ditampilkan pada kartu.
  - Zodiac Ingress:
    - Deteksi jika benda langit berada dalam jarak $\le 0.5^\circ$ dari pergantian tanda zodiak ($30^\circ \times k$).
  - Kalibrasi Bulan (Amandemen Agent 1):
    - Verifikasi bujur Bulan ($\lambda_{moon}$) terhadap almanak referensi astronomis dengan toleransi ketat $\le 0.5^\circ$.
- **TDD Test**: `scripts/test_astronacci_planetary_aspects.swift`
  - Kasus 1: Conjunction eksak ($0^\circ \pm 3^\circ$).
  - Kasus 2: Opposition eksak ($180^\circ \pm 3^\circ$).
  - Kasus 3: Square ($90^\circ \pm 3^\circ$) dan Trine ($120^\circ \pm 3^\circ$).
  - Kasus 4: Cap kepadatan: dari puluhan kombinasi, hanya top 3 aspek orb terkecil yang diekspos.
  - Kasus 5: Zodiac Ingress terdeteksi saat planet melintasi batas $30^\circ$.
  - Kasus 6: Kalibrasi bujur Bulan terhadap 3 tanggal referensi almanak historis ($\le 0.5^\circ$).
  - Kasus 7: Kinerja instan: 1.000 kalkulasi multi-aspek dalam $< 50$ ms.

---

### Task 3: Integrasi Presentasi `FuturesScoutCoreAnalyst` & Ekspansi Runner Kanonis
- Integrasikan laporan News Calendar dan Planetary Aspects ke dalam kartu ringkasan eksekutif `FuturesScoutCoreAnalyst.swift`:
  - Jika `isInsideBuffer == true`: Kartu menampilkan kotak merah mencolok di bagian atas status:
    `> 🚨 **PERINGATAN BUFFER BERITA BESAR (SOP ASTRONACCI)**: [Event] dijadwalkan dalam [X] menit. Rekomendasi: STAND ASIDE demi menghindari lonjakan slippage & manipulasi likuiditas.`
  - Seksi Astrologi diperkaya dengan maksimal 3 aspek mayor terkuat + Ingress (disertai penafian: *konteks geometri astrologi — interpretasi Eye of Future, bukan kepastian arah*).
  - Audio TTS narasi: **TETAP BERSIH** ($< 300$ karakter, zero markdown, nol aspek astrologi yang dibacakan suara).
  - TradingView Pine Script: **TETAP BERSIH** (NOL badge makro/aspek yang mengotori chart).
- Perbarui `./scripts/run_all_tdd.sh` dari 7 suite $\to$ **9 suite** (menambahkan Suite 8 News Calendar dan Suite 9 Planetary Aspects).
- Kompilasi penuh `xcodebuild`, deep re-sign `IzanotchyDev`, verifikasi PID baru dan log runtime.
