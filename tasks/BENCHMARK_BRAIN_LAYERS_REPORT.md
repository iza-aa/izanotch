# LAPORAN CAPAIAN BENCHMARK LAPISAN OTAK LOKAL (PRD §B, MT-21)

Tanggal Evaluasi: 2026-10-12T03:08:39Z
Target Arsitektur: AFM (System 2) + LAYA (System 1) + LUNA (Vision Truth)
Rujukan Induk: `tasks/PRD_GROKBOT_DI_NOTCH.md` Bagian B

---

## 1. RINGKASAN CAPAIAN PER LAPISAN

| Lapisan | Peran Arsitektur | Total Uji | Lulus | Latensi Rata-rata | Laju Cacat Serialisasi | Laju Pemulihan Repair | Status Capaian |
|---|---|---|---|---|---|---|---|
| Lapisan 1: Ingress (TaskIngressGateway) | §B Otak Lokal | 5 | 5 | 0.0ms | 0% | 100% | LULUS (AFM System 2 Sanggup) |
| Lapisan 2: Planner & Decision (Laya + AFM Step Planner) | §B Otak Lokal | 12 | 8 | 3450.0ms | 100% | 100% | MARGINAL / BUTUH ESKALASI MODEL PENGGANTI (AFM 3B defect rate 100% tanpa repair layer) |
| Lapisan 3: Egress (TaskEgressValidator) | §B Otak Lokal | 4 | 4 | 420.0ms | 0% | 100% | LULUS (TaskEgressValidator Sanggup) |

---

## 2. ANALISIS KEBENARAN TEKNIS PER LAPISAN

### Lapisan 1: TaskIngressGateway (Dekomposisi Intent & Routing Tier)
- **Capaian**: 100% lulus.
- **Analisis**: AFM System 2 mampu membedakan intent conversational, inspect, compose, dan send dengan akurat. Penentuan executionTier (`api_connector`, `web`, `native_cua`) bekerja deterministik melalui `ExecutionRoutingGate`.
- **Keputusan**: AFM System 2 **SANGGUP** untuk Lapisan 1.

### Lapisan 2: TaskStepPlanner & Laya Daemon (Perencanaan Langkah CUA)
- **Capaian**: Marginal (8/12 lulus semantika operatif; laju cacat serialisasi raw 100%).
- **Temuan Bukti Empiris (`test_system_noninvasive.swift`)**:
  - Model AFM 3B lokal gagal menghasilkan JSON murni valid pada 12 dari 12 percobaan tanpa parsing bantuan.
  - Lapisan perbaikan deterministik (`repair layer`) berhasil memulihkan 100% kasus rusak, namun semantika pemilihan elemen pada kasus kompleks (mis. scroll_up vs click, ordinal ketiga) masih memiliki celah kesalahan ~33%.
  - Laya daemon (System 1) cepat (<500ms) untuk triage sederhana, tetapi AFM 3B kesulitan pada multi-step visual reasoning.
- **Keputusan**: Lapisan 2 **MEMBUTUHKAN ESKALASI MODEL PENGGANTI LOKAL** (sesuai komitmen PRD §B, pemilik menyediakan model lokal yang lebih berkemampuan tinggi, DILARANG cloud).

### Lapisan 3: TaskEgressValidator (Validasi Faktual & Laporan 5-Bagian C3)
- **Capaian**: 100% lulus.
- **Analisis**: Evaluasi state teknis, penolakan klaim sukses palsu saat input kosong, anti-parroting guard, dan pemformatan laporan 5-bagian (fakta, asumsi, aksi selesai, menunggu persetujuan, pertanyaan terbuka) berjalan solid dan memenuhi skema C3.
- **Keputusan**: TaskEgressValidator **SANGGUP** untuk Lapisan 3.

---

## 3. KEPUTUSAN ESKALASI MODEL (§B KONTRAK)

1. Lapisan 1 (Ingress) & Lapisan 3 (Egress): **Tetap menggunakan AFM System 2 lokal**.
2. Lapisan 2 (Planner CUA): **Membutuhkan Model Vision-Language / Planning Lokal yang Lebih Besar** (mis. Qwen2.5-VL 7B / DeepSeek-R1 Distill 7B/8B yang dijalankan via Ollama/MLX lokal).
3. **ATURAN MUTLAK**: Sesuai instruksi pemilik, eskalasi dilakukan secara murni lokal pada Mac pengguna — **DILARANG JATUH KE CLOUD**.