# SPESIFIKASI KEBUTUHAN MODEL PENGGANTI LOKAL (PRD §B, MT-22)

Versi: 1.0 — 2026-10-12
Tujuan: Mengeskalasi Lapisan 2 (TaskStepPlanner & CUA Visual Reasoning) ke model lokal berkinerja tinggi.
Aturan Mengikat: **100% On-Device (Apple Silicon Host) — DILARANG PINDAH KE CLOUD**.

---

## 1. LATAR BELAKANG & TEMUAN EMPIRIS LAPISAN 2

Berdasarkan hasil benchmark empiris (`tasks/BENCHMARK_BRAIN_LAYERS_REPORT.md`):
1. **Laju Cacat Serialisasi Raw AFM 3B**: 100% (12/12 kasus pada compose dan inspect menghasilkan output JSON terdistorsi tanpa repair layer).
2. **Keterbatasan Penalaran Spasial**: AFM 3B mengalami kegagalan pada skenario viewport bersyarat (memilih `click` alih-alih `scroll_up` saat item berada di luar batas pandang) dan pemilihan ordinal kompleks.
3. **Waktu Inferensi**: Laya daemon (System 1) merespons cepat (~160-500ms), tetapi eskalasi System 2 membutuhkan pemahaman visual yang lebih granular.

Sesuai kontrak PRD Bagian B, pemilik berkomitmen menyediakan model lokal pengganti jika ada lapisan yang membutuhkan eskalasi.

---

## 2. SPESIFIKASI TEKNIS MODEL PENGGANTI (LAPISAN 2)

| Parameter | Kebutuhan Minimum | Kebutuhan Rekomendasi |
|---|---|---|
| **Modalitas** | Vision-Language Multimodal (VLM) | Vision-Language Native dengan Point Grounding |
| **Ukuran Parameter** | 3B - 7B Parameter | 7B - 8B Parameter (Kuantisasi 4-bit / 8-bit) |
| **Konsumsi VRAM** | Maksimal 6.0 GB Unified Memory | 4.0 - 5.5 GB Unified Memory (Aman untuk Mac 16GB) |
| **Runtime Engine** | MLX (Apple Silicon Metal) / Ollama / Llama.cpp | MLX Swift / MLX Python Local Daemon |
| **Structured Output** | JSON Schema Enforcement / Grammar-based decoding | Constrained decoding (0% defect rate) |
| **Panjang Konteks** | Minimal 8.192 token | 16.384 token (mendukung multi-turn CUA) |
| **Latensi Inferensi** | < 2.500ms per turn planning | < 1.200ms per turn planning |
| **Konektivitas Jaringan** | **0 KB (Off-grid, no internet required)** | **Off-grid lokal penuh** |

---

## 3. KANDIDAT MODEL LOKAL REKOMENDASI

### Opsi 1 (Pilihan Utama): Qwen2.5-VL 7B Instruct (MLX 4-bit)
- **Kelebihan**:
  - Pelatihan native pada Computer-Use Agentic Tasks.
  - Mendukung point grounding (koordinat pixel `[x, y]` langsung dari screenshot).
  - Kinerja penalaran form composition dan ordinal list sangat tinggi.
- **Kebutuhan Resource**: ~4.8 GB Unified Memory pada kuantisasi 4-bit.
- **Integrasi**: Dapat dilayani lokal via server HTTP/JSON lokal pada port internal (mis. `http://127.0.0.1:1979`).

### Opsi 2: Llama-3.2-Vision 11B (MLX / Ollama 4-bit)
- **Kelebihan**:
  - Pemahaman visual teks beresolusi tinggi (OCR & dokumen UI).
  - Penalaran multi-turn yang stabil.
- **Kebutuhan Resource**: ~6.8 GB Unified Memory pada kuantisasi 4-bit.

### Opsi 3: DeepSeek-R1 Distill Qwen 7B (Untuk Perencanaan Teks Murni) + Luna Grounder
- **Kelebihan**:
  - Reasoning effort bertingkat (PRD §G2) native.
  - Perencanaan sub-goal yang sangat terstruktur dan minim halusinasi.
- **Kebutuhan Resource**: ~4.2 GB Unified Memory.

---

## 4. KONTRAK INTEGRASI & PROTOKOL LOKAL

1. **Port Internal**: Server model pengganti lokal berjalan pada loopback `127.0.0.1:1979` (System 2 Planner Port).
2. **Format Request**: Menggunakan kontrak standar OpenAI / vLLM compatible:
   - Endpoint: `POST http://127.0.0.1:1979/v1/chat/completions`
   - Input: Image base64 screenshot + CanonicalTaskContract prompt
   - Schema: `response_format = {"type": "json_object"}`
3. **Fail-Safe Fallback**:
   Jika daemon model pengganti belum aktif, sistem secara otomatis beralih ke AFM System 2 bawaan (`fm serve` port 1976) dengan `Deterministic Repair Layer`.

---

## 5. KESIMPULAN

Dokumen ini menyerahkan kebutuhan model pengganti Lapisan 2 secara formal kepada pemilik proyek. Dengan model VLM 7B lokal pada runtime MLX, kelemahan penalaran spasial dan cacat serialisasi teratasi sepenuhnya tanpa mengorbankan privasi atau melanggar aturan Zero Cloud.
