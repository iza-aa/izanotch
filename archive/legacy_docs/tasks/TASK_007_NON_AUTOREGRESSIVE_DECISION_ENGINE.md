# TASK-007: Non-Autoregressive System 1 Decision Engine (Laya Multilingual)

<!-- Single Source of Truth untuk implementasi decision router non-autoregresif CUA -->

---

## 1. Latar Belakang & Masalah (Problem Statement)

Saat ini, loop CUA Izanotchy mengandalkan model generatif autoregresif 3B (Apple Foundation Models / AFM) untuk melakukan seluruh proses dalam satu kali panggilan:
1. Menelan observasi JSON layar yang besar (topBar, sidebar, listItems, previewPane).
2. Membaca instruksi panjang yang penuh aturan visual dan larangan bertingkat.
3. Melakukan token generation kata-demi-kata untuk menghasilkan JSON (`thought`, `subGoal`, `actionType`, `targetElement`).

### Gejala Masalah:
- **Latensi Tinggi:** Generasi token JSON autoregresif membutuhkan 1.5 - 3 detik per langkah di NPU/CPU.
- **Cognitive Overload & Halusinasi:** Model 3B kebingungan membedakan konteks wadah aktif vs navigasi (misal: "All Inboxes" vs "Inbox"), lalu merencanakan klik folder yang salah dan grounding kursor melompat ke tengah layar (`0.500, 0.500`).
- **Inkonsistensi Ordinal:** Aturan scroll-up yang ditulis panjang di prompt rawan diabaikan jika pengguna meminta ordinal selain index 1 ("email terbaru kedua").

---

## 2. Solusi Arsitektur: Dual-System Decoupled Engine

Mengadopsi pemisahan **System 1 (Keputusan Cepat Non-Autoregresif)** dan **System 2 (Grounding & Ekstraksi Semantik)**:

```
[User Request + Screen Meta-State]
             │
             ▼
┌──────────────────────────────────────────────┐
│  SYSTEM 1: Laya Decision Engine (322M, ~30ms)│
│  - Non-autoregressive forward pass           │
│  - Input: State Header ringkas (<50 token)   │
│  - Output: Typed Choice (Diskrit Action)     │
│    (scroll_up | scroll_down | click_item |   │
│     switch_container | read_pane | done)     │
└──────────────────────────────────────────────┘
             │
             ▼ [Discrete Action Class]
┌──────────────────────────────────────────────┐
│  SYSTEM 2: Targeted Grounding & Execution    │
│  - Jika scroll_up / scroll_down:             │
│    -> Swift langsung scroll (0 token LLM)    │
│  - Jika switch_container:                    │
│    -> Luna / AX cari folder di Sidebar       │
│  - Jika click_item:                          │
│    -> Luna / Visual Card klik baris target   │
│  - Jika read_pane:                           │
│    -> AFM baca & ekstrak fakta teks          │
└──────────────────────────────────────────────┘
```

---

## 3. Pembagian Peran Komponen: Laya (System 1) vs AFM 3B (System 2)

Laya **bukan pengganti AFM**, melainkan pelengkap arsitektural. Laya adalah **System 1 (Refleks Cepat / Router)**, sedangkan AFM adalah **System 2 (Kecerdasan Linguistik & Sintesis)**.

| Komponen | Layer | Peran Utama | Latensi Khas | Frekuensi Pemanggilan |
|---|---|---|---|---|
| **AFM 3B (Ingress)** | System 2 | Normalisasi instruksi bahasa alami menjadi kontrak tugas terstruktur (`targetApp`, `targetContainer`, `targetIndex`, `searchQuery`). | ~300 - 400 ms | **1x saja di awal sesi** |
| **Laya Multilingual (322M)** | System 1 | Mengambil keputusan aksi UI diskrit (`scroll_up`, `scroll_down`, `click_item`, `switch_container`, `read_pane`, `done`) via single forward pass. | **~20 - 30 ms** | **Setiap langkah CUA loop** |
| **Luna Vision / Fast AX** | Grounding | Menemukan koordinat fisik (X, Y) tombol atau baris target di layar. | ~50 - 100 ms | Hanya saat aksi butuh klik |
| **AFM 3B (Egress)** | System 2 | Membaca dokumen/email yang terbuka di reading pane, mengekstrak fakta nyata, dan merangkum jawaban akhir ke pengguna. | ~400 - 600 ms | **1x saja di akhir sesi** |
| **AFM 3B (Compose)** | System 2 | Mengarang kalimat balasan email atau teks formulir (`textToType`). | ~500 ms | Hanya saat aksi pengetikan |
| **AFM 3B (Fallback)** | System 2 | Fallback penalaran mendalam jika confidence Laya < 0.50 pada layout antarmuka yang sangat tidak lazim. | ~1.5 s | Hanya saat ambiguitas tinggi |

### Detail Peran AFM 3B (System 2 — Tidak Tergantikan):
1. **Laya Tidak Bisa Menghasilkan Teks (Zero Text Generation):** Laya adalah non-autoregressive classifier. Laya tidak bisa menyusun ringkasan, tidak bisa membaca paragraf panjang, dan tidak bisa berbicara kepada pengguna.
2. **AFM Sebagai Pembaca & Pencerita:** Tugas membaca isi email/dokumen di preview pane dan menjelaskan intisarinya kepada pengguna 100% tetap dipegang oleh AFM (`TaskEgressValidator`).
3. **AFM Sebagai Perumus Kontrak:** Tugas memahami bahasa pengguna (apakah user menyapa, minta cek email, atau tanya hal lain) 100% tetap dipegang oleh AFM (`TaskIngressGateway`).

---

## 4. Spesifikasi Model Laya yang Dipilih

### Model: `convaiinnovations/laya-multilingual` (322M Parameter)
- **Alasan Pemilihan:**
  1. **Ukuran Terkecil & Paling Efisien:** 322M parameter (~640 MB fp16 / safetensors), jauh lebih ringan dibanding model English (421M).
  2. **Latensi Super Cepat:** ~30 ms per keputusan di Apple Silicon Metal Performance Shaders (MPS).
  3. **Multibahasa Asli (100+ Bahasa):** Memahami instruksi Bahasa Indonesia ("email terbaru kedua", "cek junk mail") dan Bahasa Inggris secara native tanpa perlu translasi manual.
  4. **Strictly Proper Scoring Rules (RLCD):** Output berupa calibrated choice probabilities murni (non-autoregresif), 100% bebas dari token hallucination atau salah format JSON.

---

## 5. Rencana Implementasi Bertahap

### Fase 1: Setup Lingkungan & Daemon Lokal Laya
- Buat virtual environment Python terisolasi di `scripts/laya_env/` atau instal via `pip install "laya[serve]"`.
- Unduh checkpoint `convaiinnovations/laya-multilingual`.
- Jalankan micro-service FastAPI lokal pada port 1978 (misal: `http://127.0.0.1:1978/predict`).

### Fase 2: Client Swift di Izanotchy (`LayaDecisionClient.swift`)
- Buat `LayaDecisionClient` dengan protokol URLSession async/await ke port 1978.
- Format pertanyaan bertipe (Typed Choice):
  ```json
  {
    "state": "Goal: Check 2nd latest email | Container: All Inboxes | Viewport: isAtTop=false, offset=0.42 | Items: 10 items visible",
    "questions": {
      "action": {
        "type": "choice",
        "instructions": "What is the next UI action needed?",
        "criteria": {
          "scroll_up": "List is scrolled down and user wants recent/top items",
          "scroll_down": "Target ordinal is beyond visible items",
          "click_item": "Target item is currently visible in list",
          "switch_container": "Target folder differs from active container",
          "read_pane": "Target item is loaded in preview pane",
          "done": "Goal is satisfied"
        }
      }
    }
  }
  ```

### Fase 3: Integrasi ke `CompanionVMAgentLoop.swift`
- Loop CUA memanggil `LayaDecisionClient` terlebih dahulu untuk memperoleh aksi diskrit.
- Jika aksi adalah `scroll_up` atau `scroll_down`, loop mengeksekusi aksi kursor fisik langsung tanpa memanggil AFM Planner.
- Jika aksi adalah `click_item`, barulah grounding engine mencocokkan baris item yang relevan.

---

## 6. Kriteria Verifikasi & Sukses
- [ ] Laya daemon merespons permintaan keputusan dalam waktu < 50 ms di Apple Silicon MPS.
- [ ] Kasus "email terbaru kedua" pada posisi list ter-scroll secara konsisten menghasilkan keputusan `scroll_up`.
- [ ] Kasus "email paling baru" tidak pernah menghasilkan keputusan `switch_container` ketika kontainer target tidak diminta.
- [ ] Nol halusinasi klik di tengah layar (`0.500, 0.500`).
