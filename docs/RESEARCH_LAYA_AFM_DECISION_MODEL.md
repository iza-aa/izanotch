# Decision Model untuk Izanotchy: Laya + Apple Foundation Models + Model Lokal 3–4B + cua-driver
*Laporan Riset — 2026-10-01 · Sumber: ~60 unik · Confidence: Medium-High (klaim satu-sumber ditandai)*

---

## Executive Summary

Intuisi Anda **tervalidasi industri**: arah "decision model" (model kecil yang memutuskan aksi, bukan menghasilkan teks) persis seperti yang sedang dibangun `laya` ("System 1 decision engine") dan `trycua/cua` (CUA-S1 "System 1 models for computer use"). Yang perlu dikoreksi dari asumsi awal:

1. **Laya bukan asisten/voice assistant** — ia tidak bisa bicara, mendengar, atau menghasilkan teks. Ia adalah **klasifier ultra-cepat (~33 ms)** yang menjawab pertanyaan bertipe (pilihan/skor/ya-tidak) dalam **satu forward pass**, dengan checkpoint **322M–421M** (bukan 3B). Total 3 checkpoint ≈ 1,16B parameter.
2. **Apple Foundation Models (AFM/Siri, ~3B on-device, gratis)** **belum mendukung Bahasa Indonesia** resmi per Oktober 2026 — memaksa prompt bahasa Indonesia bisa melempar `unsupportedLanguageOrLocale` atau lolos tanpa guardrail. Namun AFM 3 (Juni 2026) sudah dievaluasi pada kelompok bahasa yang memuat Indonesia → dukungan resmi "plausibly coming".
3. Untuk otak bahasa Indonesia lokal ~4B, kandidat terkuat: **Qwen3.5-4B** (Apache 2.0, tool calling native, 201 bahasa), **Gemma-SEA-LION-v4-4B** (spesialis SEA/Indonesia, function calling ditambahkan), **Gemma 4 E4B** (agentic terkuat di kelasnya).
4. **cua-driver sudah generasi baru**: Izanotchy memakai 0.21.0 (Python), sedangkan rilis stabil sekarang **cua-driver-rs v0.31.0 (Rust, 30 Sep 2026)**. cua sendiri kini punya model keputusan bawaan (CUA-S1-FORMS) dan hook otorisasi (`DriverAuthorizationHost`) yang bisa disambungkan langsung ke consent card Izanotchy.

**Kesimpulan arsitektur:** tiga tier decision model + laya sebagai sidecar MCP — AFM sebagai fast-path gratis, model lokal 4B sebagai otak Indonesia untuk keputusan rutin berbasis AX (bukan pixel), Claude/Gemini tetap Tier 3 untuk penalaran berat. Laya mengisi celah yang tidak bisa diisi keduanya: keputusan bertipe kalibrasi <35 ms.

---

## 1. Laya (NandhaKishorM/laya) — Fakta Inti

- **Apa itu**: "Multilingual, non-autoregressive System 1 decision engine. Typed decisions over 100+ languages in a single forward pass — 33 ms." Tiga primitif: `choice` (label + probabilitas), `score` (level ordinal), `noul` (P(true) terkalibrasi). README eksplisit: *"No text generation, so nothing to parse and nothing to hallucinate"* — bukan untuk Q&A terbuka. (README repo)
- **Checkpoint** (semua Apache 2.0 di HuggingFace, `convaiinnovations/`): `laya` (ModernBERT-large, 421M, EN, 512 ctx), `laya-multilingual` (mmBERT-base, 322M, 100+ bahasa, 1024–8192 ctx), `laya-typed-decisions` (421M, fine-tuned). **Tidak ada model 3B.**
- **Runtime**: Python 3.10+, PyTorch native (safetensors), auto-device CUDA→MPS→XPU→CPU (MPS = Apple Silicon jalan). TS SDK + ONNX juga ada.
- **Permukaan integrasi**: MCP stdio server (`laya-mcp-server`, 8 tools: `laya_predict`, `laya_route`, `laya_shortlist`, `laya_predict_batch`, `laya_decide`, dll.), FastAPI + HTTP server, CLI, LangChain/LlamaIndex/CrewAI, Docker. → **Drop-in ke arsitektur MCP Izanotchy hampir verbatim.**
- **Bukan voice, bukan computer use**: tidak ada STT/TTS/wake word sama sekali; tidak ada kontrol mouse/keyboard. Studi kasus terdekat: fine-tune laya sebagai *action-decision head* untuk `browser-use/jev` — memprediksi CLICK/TYPE/SELECT/DONE, executor-nya framework lain. Hasil: element top-1 0.10→0.66, 16 task browser 0%→62% sukses pada 17–23 ms/step. **Ini resep persis untuk dipakai sebagai decision model di depan cua-driver.**
- **Bahasa Indonesia**:
  - Sweep 51 bahasa yang di-commit di repo (`research/results/cpu_51_language_sweep.json`) memuat `id`: akurasi zero-shot checkpoint multilingual **0.51** vs checkpoint Inggris **0.36** → multilingual benar-benar membaca Indonesia, salah routing mengorbankan ~15 poin.
  - **Bug/blind spot**: `laya/lang.py` tidak punya stopword Indonesia dan teks Latin Indonesia tanpa diakritik → **teks Indonesia akan salah dirutekan ke checkpoint Inggris**. Fix trivial: `Router(default="multilingual")`, atau `lang="id"` per request, atau tambah stopword `"id"` ke `_STOP` (pure Python, pekerjaan akhir pekan).
  - Catatan jujur dari README: multilingual **belum punya calibration temperature**, dan ada position bias pada pertanyaan `score` (issue #131). Keputusan Indonesia yang tepercaya butuh fine-tune domain (notebook RLCD jalan di 2×T4 atau MPS).
- **Status repo**: dibuat 2026-09-18, v0.3.21, ~29.629 stars (satu-sumber: GitHub API — tidak bisa diverifikasi silang), 161 issue terbuka. Sangat muda; API bisa berubah.

## 2. Apple Foundation Models (AFM) — Fakta Inti

- **Model**: ~3B on-device (2-bit QAT, LoRA adapters per-task), macOS/iOS 26+, gratis & unlimited, privasi penuh, **context window 4096 token per session** (8192 di macOS 27 — satu-sumber). Diposisikan Apple untuk summarization/extraction/classification — *bukan* reasoning berat. (Apple ML tech report 2025; docs resmi)
- **API Swift**: `SystemLanguageModel` + `LanguageModelSession` (streaming snapshot untuk SwiftUI), **guided generation** `@Generable`/`@Guide` (constrained decoding — output struktur dijamin), **tool calling** `Tool` protocol (argumen schema-constrained; mode `.allowed/.required/.disallowed`). On-device tanpa entitlement khusus.
- **Bahasa Indonesia: TIDAK resmi.** Daftar resmi Apple Intelligence (16 bahasa): EN, DA, NL, FR, DE, IT, NO, PT, ES, SV, TR, VI, zh-S, zh-T, JA, KO. Prompt bahasa Indonesia → error `unsupportedLanguageOrLocale`, atau lebih berbahaya untuk agen: lolos **tanpa perlindungan guardrail**. AFM 3 (Juni 2026, dibangun dengan Google) mengevaluasi grup "AFIHHMPRTU" yang memuat **Indonesian** → dukungan resmi wajar diantisipasi, belum rilis. (Apple Support 121115; apple.com/ios/feature-availability; Apple ML)
- **Reliabilitas agentic**: Apple sendiri menyarankan **maks 3–5 tools per request**, context pendek, pecah session. Data sistematis terbaik (proyek *apfel*, server OpenAI-compatible di atas AFM): tool call tunggal 100% sukses, tapi **~50% panggilan menghalusinasi parameter ekstra**, parallel tool calls tidak pernah berhasil, guardrail false-positive, ~1,1 s latensi. Komunitas konsisten: "tool calling super buggy" (anekdot, tapi saling konsisten).
- **Jembatan non-Swift** (kalau mau dipakai dari luar app): `gety-ai/apple-on-device-openai` (OpenAI-compatible di 127.0.0.1:11535, tool calling WIP), **`apfel`** (tool calling paling matang + `--mcp`), `phimage/mcp-foundation-models` (MCP server), `airy10/AppleFoundationMCPTool` (AFM sebagai MCP *client*).
- **2026**: AFM 3 family (Core ~3B, Core Advanced 20B sparse-MoE, Cloud, Cloud Pro); PCC (32K context, reasoning levels — gated entitlement + syarat App Store); **`LanguageModelExecutor`** — jalankan model Core AI custom *di dalam* `LanguageModelSession` → jalur paling bersih untuk menjalankan model Indonesia-capable lewat API AFM yang sama; Dynamic Profiles untuk agentic switching.

## 3. Model Lokal ~3–4B dengan Bahasa Indonesia

| Model | Params | Bukti Indonesia | Tool calling | Lisensi | Runtime |
|---|---|---|---|---|---|
| **Qwen3.5-4B** (Feb 2026) | 4.66B | Klaim 201 bahasa; keluarga Qwen memimpin SEA-HELM Indonesia (di ukuran 32B+; skor 4B belum dipublikasikan — perlu smoke test) | Native `<tool_call>`; BFCL-V4 50.3, TAU2 79.9 | Apache 2.0 | MLX 4-bit (~2,9 GB) + Ollama |
| **Gemma-SEA-LION-v4-4B-VL** (Agu 2025) | 4B | Post-training khusus SEA; SEA-HELM; contoh output Indonesia | Function calling sengaja ditambahkan (tool-use SFT) | Gemma ToU | Ollama resmi; MLX tidak ditemukan |
| **Gemma 4 E4B** (Apr 2026) | ~4B efektif | 140 bahasa, klaim "cultural context" | Native FC; τ2-Bench Retail 57,5% (vs Gemma 3 27B: 6,6%!) | Apache 2.0 *(perlu verifikasi di model card)* | MLX 4-bit sudah ada |
| Llama 3.2 3B | 3B | **Indonesia TIDAK ada di 8 bahasa resmi** | Native | Llama license | MLX/Ollama |
| Phi-4-mini | 3.8B | English-centric ("English-only environments") | Terbaik di kelas (~97% BFCL, vendor) | MIT | MLX/Ollama |
| Sahabat-AI v1 | **8B/9B** | ~50B token Indonesia + Jawa/Sunda — terbaik secara murni, tapi **tidak ada varian kecil** | Tidak terdokumentasi | Llama/Gemma | GGUF komunitas |

- **Faktor reliabilitas**: evaluasi independen Docker (21 model) menunjukkan Qwen keluarga paling andal untuk tool calling lokal; Gemma 3 4B lemah (0,733 F1). Kuantisasi 4-bit **tidak** menurunkan tool calling signifikan. Wall untuk model kecil sebagai agen adalah **format tool call, bukan reasoning** → grammar-constrained decoding (GBNF/Outlines) adalah perbaikan kanonik.
- **Swift-native**: `MLXGuidedGeneration` di `mlx-swift-lm` membatasi output model MLX ke JSON Schema/EBNF **dari Swift native** — primitif paling relevan untuk decision model in-app. Ollama mengompilasi JSON Schema→GBNF otomatis.
- **Performa**: 4-bit 3–4B ≈ 60–80 tok/s (M-series base), 100–150+ (M4 Max/Ultra); MLX ~41–45% lebih cepat dari Ollama pada model sama.
- **Voice Indonesia**: STT → Whisper large-v3-turbo (WER Indonesia ~6–8%, ~5× lebih cepat dari large-v3); Apple SFSpeechRecognizer `id-ID` didukung tapi kalah dari Whisper. TTS → Piper `id_ID-news_tts-medium` (satu-satunya voice terbuka mature) atau AVSpeechSynthesizer id-ID.

## 4. cua-driver & Arsitektur Decision Model

- **Versi**: Izanotchy memakai 0.21.0 (Python era); stable sekarang **cua-driver-rs v0.31.0 (Rust, 30 Sep 2026)**. ⚠️ Permukaan MCP tool kemungkinan berubah antar generasi.
- **Filosofi**: bring-your-own-agent — driver **tidak** membungkus loop; integrasi via MCP (default), SDK in-process, app-hosted service (untuk TCC chain), atau CLI/daemon. Escalation ladder resmi: **element/ax → element/px → browser DOM → foreground**; hanya **AX read-back yang menghasilkan `verified: true`** → doktrin element-token Izanotchy (#76) tervalidasi sebagai official doctrine.
- **Model lokal di cua**: docs resmi hanya Ollama + llama.cpp; model uji `muse-glimmer:30b-mlx` (satu-sumber). Constraint keras: **filter ke ~12 tool** dari set penuh, context ≥64K, jangan flattening image block. Hasil pengukuran cua: filtering tools + bounding state reads memangkas input 71.088 → 12.251 token, durasi 660 s → 224 s.
- **CUA-S1** (Sep 2026): "small, specialized **System 1** models for computer use" — CUA-S1-FORMS "scores decisions from structured interface elements... rather than generating a response token by token". Prinsip desain: model kecil **meranking kandidat yang kode Anda sediakan** (bounded ranking error), LLM tetap memplankan. MIT kode; bobot HF lisensi artifact-spesifik. Belum ada jumlah parameter/benchmark publik.
- **Consent gating bawaan**: permission modes (`standard` / `bounded` / `unrestricted`) + structured refusal `authorization_required` + **`DriverAuthorizationHost` callback** — app embedder boleh memutuskan sendiri → sambungkan langsung ke `NotchComputerUseConsentWindow` / inline consent HomeSpace, tanpa bangun gerbang paralel.
- **Pola industri**: cascading routing kecil→besar berbasis confidence (OpenRouter, NeuralTrust); kegagalan model kecil di computer use = pixel grounding (meleset 2px, mengarang tombol) — **"model teks 7–14B cukup jika observasinya terstruktur"** (elemen AX + crop, bukan screenshot mentah); aturan praktis praktisi: **tanya manusia bila confidence < ~0,8** dan selalu tolak dialog Purchase otonom. Memori: pola Mem0 (app-managed) memadai via file JSON `~/.izanotchy/` yang sudah ada.

---

## 5. Sintesis: Arsitektur Decision Model untuk Izanotchy

```
┌─────────────────────────────────────────────────────────────────┐
│                     PERSEPSI (sudah ada)                         │
│  AX element tokens · window state · screenshot (bila perlu)      │
└──────────────┬──────────────────────────────────────────────────┘
               ▼
┌─ TIER 1: AFM (Swift in-process, ~3B, gratis, offline) ───────────┐
│  Intent classification · slot extraction (@Generable) ·          │
│  pre-screening consent · pemilihan ≤5 tool · memory writes       │
│  ⚠ Prompt EN + jembatan Translation ID↔EN sampai AFM resmi id    │
└──────────────┬──────────────────────────────────────────────────┘
               ▼
┌─ TIER 2: Model lokal 4B (Ollama/MLX: Qwen3.5-4B / SEA-LION 4B) ──┐
│  Otak Bahasa Indonesia untuk keputusan rutin berbasis AX         │
│  (element-token ranking ala CUA-S1/laya), structured output      │
│  GBNF/JSON-Schema, tool subset dinamis ≤12 dari 56               │
└──────────────┬──────────────────────────────────────────────────┘
               ▼
┌─ TIER 3: Claude/Gemini cloud (existing, prompt-cached) ──────────┐
│  Planning multi-hop · analisis trading · pixel grounding ·       │
│  fallback bila confidence Tier 1/2 < ~0,8                        │
└──────────────┬──────────────────────────────────────────────────┘
               ▼
        cua-driver (element-first) ── AX read-back = verified:true
               ▼
  Sidecar: LAYA MCP server (Router default="multilingual", lang="id")
  Keputusan bertipe <35 ms: routing kecil-vs-frontier, guard,
  shortlist, yes/no gating kalibrasi — bahasa Indonesia ✓ hari ini
               ▼
  Consent: confidence <0,8 / efek destruktif → DriverAuthorizationHost
  → NotchComputerUseConsentWindow + inline card HomeSpace (existing)
```

**Jawaban "seberapa jauh bisa dikembangkan":** hari ini sudah bisa sampai **decision model bertipe berbahasa Indonesia yang berjalan 100% lokal** (laya untuk keputusan ya/tidak/pilihan + Qwen3.5-4B/SEA-LION untuk pemilihan aksi berbasis AX), dengan AFM sebagai lapisan gratis untuk klasifikasi berprompt-Inggris. Yang **belum** mungkin hari ini: AFM berbahasa Indonesia (tunggu dukungan resmi atau pakai `LanguageModelExecutor` dengan model open custom), dan model 4B lokal untuk pixel grounding dari screenshot (tetap route ke cloud).

## Roadmap Bertahap (usulan — menunggu persetujuan Anda)

- **Fase 0 — Spike laya (1–2 hari)**: `pip install "laya[mcp]"`, set `Router(default="multilingual")`, uji 20 kasus keputusan Indonesia (intent chat vs computer-use, ya/tidak konsent, skor urgensi) → ukur akurasi & latensi nyata di Mac Anda.
- **Fase 1 — AFM fast-path (3–5 hari)**: `LanguageModelSession` + `@Generable` untuk intent/slot dengan prompt EN + jembatan `Translation` framework; runtime check `supportsLocale` agar otomatis naik kelas saat Indonesia didukung.
- **Fase 2 — Otak lokal 4B (1–2 minggu)**: Ollama `qwen3.5:4b` (atau SEA-LION 4B) + structured output GBNF; keputusan aksi berbasis element-token dengan tool subset dinamis ≤12; benchmark 20 skenario TradingView/OS-like vs Tier 3.
- **Fase 3 — Consent cascade (3–5 hari)**: gabungkan confidence + `DriverAuthorizationHost` + rule destruktif → consent card existing; audit log keputusan Tier 1/2.
- **Fase 4 (opsional, risiko terpisah)**: upgrade cua-driver 0.21.0 → 0.31.0-rs + verifikasi TCC/codesign `IzanotchyDev` (pelajaran #21/#51).

## Key Takeaways

- Laya = komponen decision model yang **justru paling siap untuk bahasa Indonesia hari ini** (fix routing satu baris), tapi ia *gate*, bukan *otak* — tetap butuh LLM generatif di sampingnya.
- AFM gratis & tool calling-nya nyata, tapi 4K context + ~3B + dukungan bahasa yang belum mencakup Indonesia membatasinya ke klasifikasi/slot berprompt-EN dengan terjemahan sebagai jembatan.
- Model lokal 4B (Qwen3.5-4B) + grammar-constrained decoding + observasi AX terstruktur = kombinasi yang membuat "decision model lokal berbahasa Indonesia" realistis di Apple Silicon.
- cua-driver sudah menyediakan hampir semua lem (tool filtering, verification ladder, consent callback) — pekerjaan kita mayoritas wiring, bukan penemuan baru.
- Risiko #1: model kecil memverifikasi dirinya sendiri dari pixel — dilarang; hanya AX read-back yang boleh menyatakan `verified: true`.

## Klaim Satu-Sumber / Perlu Verifikasi

- Jumlah stars laya 29.629 (GitHub API tunggal); bobot CUA-S1 & detailnya (samcodeman/HN); model `muse-glimmer:30b-mlx` (docs cua saja); context 8192 di macOS 27 (proyek apfel); Apache 2.0 Gemma 4 (snippet blog — cek model card); skor Indonesia Qwen3.5-4B (inferensi keluarga, belum terukur); "confidence <0,8" (praktisi tunggal).

## Methodology

4 sub-pertanyaan dieksekusi paralel oleh 4 agen riset (laya; AFM; model 3–4B Indonesia; cua-driver & arsitektur) via WebSearch/WebFetch/webReader: ~20+ query, ~60 sumber unik (GitHub API & raw files, docs resmi Apple, Apple ML, WWDC25/26, HuggingFace, arXiv, docs.cua.ai, leaderboard BFCL/SEA-HELM/OSWorld, evaluasi independen Docker, blog komunitas). Klaim diverifikasi silang bila ≥2 sumber; sisanya ditandai.

---

# ADDENDUM — Gelombang 2 (2026-10-01): Laya Dijelaskan, Kontradiksi Bahasa Indonesia, & Menu Model di AFM

## A. Laya itu bisa ngapain — penjelasan konkret

**Analogi:** otak manusia punya System 1 (refleks cepat: "itu lampu merah, rem!") dan System 2 (pikir panjang: "strategi apa yang tepat?"). Laya = **System 1**. LLM besar (Claude/Gemini) = **System 2**. Laya tidak menjawab pertanyaan terbuka — ia menjawab **pertanyaan tertutup bertipe tentang sebuah teks**, dalam satu forward pass ~33 ms, tanpa menghasilkan satu kata pun.

Tiga primitif decision:

| Primitif | Pertanyaan contoh (bisa Bahasa Indonesia) | Output |
|---|---|---|
| `choice` | "Transkrip 'tutup Safari dong' ini termasuk kategori apa? Pilihan: percakapan / perintah-komputer / perintah-trading" | `{label: "perintah-komputer", probabilities: {perintah-komputer: 0.94, percakapan: 0.05, perintah-trading: 0.01}}` |
| `score` | "Seberapa destruktif aksi 'hapus semua drawing di chart'? (rubrik 0–4)" | level ordinal 0–4 |
| `noul` | "Apakah aman mengeksekusi aksi ini tanpa bertanya ke pengguna?" | `P(true) = 0.31` (terkalibrasi) |

**Yang BISA dilayanya:**
- Klasifikasi intent (chat biasa vs perintah computer-use vs tugas TradingView) dalam 33 ms — tanpa memanggil LLM.
- Gate konsent murah: sebelum aksi dieksekusi, tanya laya "apakah ini destruktif?" → P(true) rendah → baru tampilkan consent card.
- Routing murah kecil-vs-besar: pertanyaan gampang → model lokal; susah → Claude/Gemini (preset `router` bawaan).
- Shortlist/filtering: memilih 12 tool relevan dari 56 tool cua sebelum prompt dikirim (hemat context).
- Batch: puluhan keputusan sekaligus masih milidetik.
- MCP server bawaan (`laya-mcp-server`) → bisa dipanggil dari arsitektur MCP Izanotchy seperti cua-driver.

**Yang TIDAK bisa dilayanya:**
- Ngobrol, menjawab pertanyaan terbuka, menghasilkan teks/terjemahan/ringkasan — **tidak ada text generation sama sekali**.
- Melihat layar, klik, mengetik, suara (STT/TTS) — bukan bagian dari laya.
- Bekerja sendirian: ia butuh executor (cua-driver) dan otak generatif (LLM) di sampingnya.

**Posisi di Izanotchy:** laya adalah *layer keputusan cepat murah* yang duduk di depan Claude/Gemini — memangkas panggilan cloud untuk keputusan rutin dan menggantikan heuristik regex/hardcode kita (mis. deteksi ticker vs sapaan, masalah #73) dengan klasifier terlatih berprobabilitas.

## B. Kontradiksi "Apple Intelligence bisa Bahasa Indonesia" — terjawab

**Pengguna benar DAN daftar resmi benar — karena dua lapisan berbeda:**

1. **Lapisan model (bisa):** Docs resmi Apple menyatakan *"The on-device system language model is multilingual"* (FoundationModels docs), dan Apple mengevaluasi AFM 3 pada grup locale **AFIHHMPRTU yang eksplisit memuat Indonesian** (Apple ML Research). Modelnya memang paham Bahasa Indonesia.
2. **Lapisan produk konsumen (gate bocor):** Daftar resmi Apple Intelligence = 16 bahasa tanpa Indonesia (support.apple.com/en-us/121115, revisi 14 Sep 2026; halaman feature-availability diverifikasi langsung — Indonesia hanya muncul di Dictation/Live Text/VoiceOver/Scribble). TAPI: pengguna dengan device berbahasa Inggris yang **mengetik** Bahasa Indonesia ke Siri/chat tetap dilayani — permukaan konsumen tidak mengecek ulang bahasa prompt (laporan komunitas r/Applelntelligence; workaround region US + English umum dipakai pengguna Indonesia). Itulah pengalaman Anda.
3. **Lapisan framework developer (gate keras):** Di sinilah bedanya untuk Izanotchy:
   - Device language diset Indonesia → `SystemLanguageModel.default.availability` **bukan** `.available` sama sekali (Apple Dev Forums #805378) → model tidak bisa dipakai berapa pun bahasa promptnya.
   - Device bahasa Inggris + prompt Indonesia → docs mendokumentasikan throw `LanguageModelError.unsupportedLanguageOrLocale`; error ini **tidak recoverable** (bukan seperti context overflow), dan deteksi bahasanya rentan false-positive (contoh terdokumentasi: artikel Inggris terdeteksi `tr`).
   - Guardrails hanya menjamin bahasa resmi — konten bahasa tak resmi bisa lolos tanpa pemeriksaan keamanan.

**Kesimpulan:** pengalaman "chat Bahasa Indonesia jalan" = perilaku model yang bocor lewat permukaan konsumen. Untuk **aplikasi** yang memakai FoundationModels framework, Indonesia resmi ditolak. Jangan bangun fitur Bahasa Indonesia di atas `SystemLanguageModel` — pakai route alternatif di bawah, atau jadikan AFM fast-path khusus prompt-Inggris dengan try/catch.

## C. Menu model yang bisa dipakai di/dengan FoundationModels (Okt 2026)

Base model **tidak bisa ditukar developer** — ia bagian OS. Yang bisa dipakai melalui API `LanguageModelSession` yang sama (macOS 27):

| # | Slot model | Bahasa Indonesia? | Catatan praktis |
|---|---|---|---|
| 1 | **Provider package `LanguageModel`** — Anthropic Claude & Google Gemini punya Swift package resmi (WWDC26 s241/s339) | ✅ penuh | API `LanguageModelSession` yang sama dengan AFM, tanpa gate eligibilitas; butuh API key. Jalur tercepat ke Bahasa Indonesia + tool calling berkualitas |
| 2 | **Core AI model kustom** — `CoreAILanguageModel` (`.aimodel`), model open-weight via registry resmi `apple/coreai-models` (Gemma 3, GPT-OSS, Mistral, Mixtral, **Qwen**) | ✅ (per model) | Jalur first-party "model sendiri di dalam session AFM"; macOS 27 + Xcode 27; tool calling + guided generation didukung (XGrammar) |
| 3 | **MLXLanguageModel** (ml-explore/mlx-swift-lm) — model MLX HuggingFace apa pun | ✅ (per model) | Katalog terbesar (Qwen3.5-4B dll.), `@Generable` + tools; macOS 27 SDK |
| 4 | **PCC** (`PrivateCloudComputeLanguageModel`, AFM 3 Cloud/Pro, 32K ctx) | ⚠️ tergate bahasa | Perlu Small Business Program + <2M downloads + managed entitlement; kuota harian user; kemungkinan besar kena gate bahasa yang sama |
| 5 | **SystemLanguageModel on-device** (AFM 3 Core / Core Advanced 20B-sparse di silicon atas; 4K–8K ctx) | ⚠️ throw untuk prompt Indonesia | Gratis, offline, instan — tapi `unsupportedLanguageOrLocale` |
| 6 | **LoRA adapter `.fmadapter`** | ❌ jalan buntu | Toolkit v26.0.0 adalah rilis terakhir, tidak kompatibel macOS 27; tidak ada contoh adapter Indonesia |

**Implikasi untuk Izanotchy:** di macOS 27, `LanguageModelSession` bisa di-back oleh model apa pun yang conform `LanguageModel` — jadi arsitektur decision model tidak perlu pindah API: Tier 1 bisa Claude/Gemini package (slot #1), Tier offline bisa Qwen via Core AI/MLX (slot #2–3), dan slot AFM on-device (#5) dipakai selektif untuk keputusan berprompt-Inggris dengan runtime check `supportedLanguages` (otomatis naik kelas saat Apple menambah Indonesia — kelompok eval AFIHHMPRTU mengindikasikan itu akan datang).

## D. Sumber baru gelombang 2

support.apple.com/en-us/121115 · apple.com/ios/feature-availability · developer.apple.com/documentation/foundationmodels (SystemLanguageModel, Variant, languages & locales, PCC, Core AI session, unsupportedLanguageOrLocale) · machinelearning.apple.com (AFM 3, 2025 updates) · developer.apple.com/apple-intelligence/foundation-models-adapter · apple/coreai-models · ml-explore/mlx-swift-lm · developer.apple.com/videos/play/wwdc2026/{241,242,319,339} · blog.google (Gemini untuk Apple developers) · developer.apple.com/forums/thread/805378 · drobinin.com · destiner.io · dodecaidr.pro · rudrank.com · enigmus.cc · Wikipedia Siri · r/Applelntelligence · detikInet & techfin.id (pers Indonesia: "belum diumumkan")

---

# ADDENDUM — Gelombang 3 (2026-10-02): Qwen3.8-Max di M4 Pro, imajev, Ollaya, heytaby

## A. Qwen3.8-Max di M4 Pro — TIDAK BISA lokal (definitif)

- **Identitas terverifikasi**: Qwen3.8-Max diumumkan 3 Agu 2026 (API ~$2/M token input, konteks 1M); bobot terbuka **Qwen3.8-2.4T-A95B** (2,4 triliun parameter total, MoE **95B aktif**, 512 expert, ~4,89 TB BF16, konteks 262K, lisensi custom `qwen3.8-max` — bukan Apache; thinking mode selalu aktif). (qwen.ai blog; HF Qwen/Qwen3.8-2.4T-A95B)
- **Kuant terkecil yang ada**: Unsloth dynamic 1-bit `UD-Q1_0` = **397 GB** (butuh 410 GB+ RAM/VRAM). M4 Pro maksimal 64 GB → kekurangan **6,4×**. Tidak ada build MLX. Satu-satunya Mac yang muat (M3 Ultra 512 GB) hanya ~5–10 tok/s. (unsloth/Qwen3.8-2.4T-A95B-GGUF; r/LocalLLaMA)
- **Praktis**: pakai via API (qwen.ai / OpenRouter `qwen3.8-max` / Alibaba Model Studio).
- **Yang realistis di M4 Pro (24 GB)**:

| Model | Ukuran 4-bit | Perkiraan tok/s (M4 Pro) | Catatan |
|---|---|---|---|
| **Qwen3-30B-A3B** (MoE, 3B aktif) | ~15–18 GB | **~40–80** (konteks pendek; degrade >40K) | kualitas/kecepatan terbaik; MLX 4-bit resmi |
| **Qwen3.5-4B** | 3,4 GB (GGUF) / 4,0 GB (MLX) | **~60–100+** | vision + tools + thinking, Apache 2.0 |
| Qwen3-8B | ~6,5 GB | ~45 | satu-sumber |
| Qwen3.8-27B (dense, Apache 2.0, vision) | 18–20 GB | **~8–14** | muat tapi sempit & lambat |
| Qwen3.8-Max | 397 GB (1-bit) | — | API saja |

- **Sumber unduhan**: HF `Qwen/` & `mlx-community` & `lmstudio-community`; Unsloth GGUF; Ollama `qwen3.5:4b` / `qwen3.5:4b-mlx` / `qwen3.8:27b`; GitHub `QwenLM/Qwen3.8`.

## B. imajev — ketemu, proyek nyata (bukan typo): laya + gambar

- **Repo**: `mohit67890/imajev` — 192 stars, Apache-2.0, push terakhir 2026-10-01. Deskripsi: *"Open Jev-style typed-decision model that also takes images: photo + app state + typed questions in, calibrated probabilities out, locally."*
- **Bentuk**: LoRA adapter di atas **Qwen3.5** (imajev-2b / **4b default** / 9b; base resmi `Qwen/Qwen3.5-4B`, ~122,5M param trainable, HF `mohit67890/imajev-4b`). Input: teks + **hingga 2 foto** + pertanyaan bertipe (choice/score/ya-tidak) → probabilitas terkalibrasi + output "can't tell" + flag `abstained`. Jalan lokal di Mac via **MLX**, ~0,1 s per keputusan.
- **Posisi ekosistem**: satu keluarga "System One" dengan laya (kontrak API TypeSafe/Jev); laya hanya muncul sebagai pembanding benchmark (52,8% Atlan Decision Bench — laya di bawah imajev menurut klaim author).
- **Kredibilitas**: benchmark self-reported, data latih sintetis, README mengakui keterbatasan (English-only, over-confidence tanpa kalibrasi, perbandingan dua gambar lemah). Anggap angka author, belum diaudit.
- **Relevansi Izanotchy**: decision model dengan input gambar = pasangan ideal untuk consent gating berbasis screenshot ("apakah dialog ini destruktif?" + screenshot → P(ya/tidak) dalam 0,1 s) dan verifikasi UI murah sebelum eskalasi ke cloud.

## C. Ollaya — ketemu juga, proyek nyata: "Ollama untuk decision models"

- **Repo**: `ollaya-dev/ollaya` (~1,1k stars, Apache-2.0, Mert Cobanov; situs ollaya.dev; HN #49848269). Rust: CLI + daemon + HTTP server + registry + runners (ONNX Runtime + llama.cpp).
- **Yang dilayani**: `laya` (`laya:en` 421M @ 8–10 ms; `laya:multilingual` 100+ bahasa; `laya:typed-decisions`), `decider` (decoder Qwen3.5), `nli`, `gliclass`, `winnow`, `kev`, `qwen3guard`, ~15 keluarga. CLI paritas Ollama (`ollaya run/pull/list/ps`), API kompatibel TypeSafe (`POST /v1/systemone`, `/v1/decisions` — SDK Python TypeSafe resmi jalan tanpa perubahan), **MCP server (`ollaya mcp`)**. Port **11435**.
- **macOS**: Apple Silicon, macOS 14+, app menu-bar .dmg; `laya` & `nli` jalan di Apple GPU via **MLX** (keluarga lain CPU di macOS). Bobot tidak di-rehost (graph ONNX ~3MB membaca safetensors asli, pin sha256).
- **Catatan kritis**: klaim "5,5× kalibrasi lebih baik dari Ollama 0.35" = satu-sumber (vendor). Resepsi HN campur aduk — skeptisi menyebut decision models = klasifier biasa dengan marketing, dan laporan generalization gap pada laya (skor rendah vs Jev di query kompleks). Tidak tercantum di README laya (klaim satu arah). **Kesimpulan: pakai laya/Ollaya sebagai pre-filter cepat, bukan oracle.**
- **Ollama sendiri** (karena namanya mirip, diteliti sekalian): v0.35.0 (28 Sep) menambah decision models via `/v1/systemone` (model Nimble/Tev1 — bukan laya); v0.40.0-rc0 menjadikan **MLX runtime default di Apple Silicon**; tool calling + structured outputs (JSON schema) + vision + OpenAI-compat; **jebakan default context 4096** → selalu set `num_ctx` eksplisit; `keep_alive` default 5 menit; client Swift terbaik: `ollama-swift` (mattt — structured outputs + tools + vision) atau OllamaKit; model kunci: `qwen3.5:4b` (3,4 GB, tools+vision), `phi4-mini` (2,5 GB, tools), `gemma3:4b` (3,3 GB, **tanpa tools**), `aisingapore/Gemma-SEA-LION-v4-4B-VL` (~3,3 GB). Ollama Cloud = fallback nol-kode (tanpa structured outputs).

## D. heytaby — app notch komersial, blueprint dari keputusan produk

- **Terverifikasi**: heytaby.com — asisten yang tinggal **di notch Mac** (Windows: top bar), solo dev "Lloyd December", free tier lokal + **Premium €8,99/bln** (cloud AI, voice 100+ bahasa, web search, image gen, ZDR), plus robot meja fisik €79,99 yang open-source (repo `tabbie`, ESP32 + STL) — tapi **app desktop closed-source** dan fine-tune "Taby 4B" tidak dipublikasikan (Gemma ToU). Runtime: **GGUF/llama.cpp-family** (bukan MLX) demi satu pipeline lintas macOS+Windows.
- **Line-up model picker** (teks persis yang Anda tempel = picker in-app; konsisten dengan situs): Taby 2B/4B/12B (fine-tune Gemma proprietary), **Qwen3.5 4B** (Apache 2.0, vision), **Phi-4 mini 3.8B** (MIT, instruction/reasoning). Unduhan sekali ~6 GB, 4-bit default, asumsi ~4K context.
- **Fitur unggul yang bisa dicontek**:
  1. **Compatibility checker** → auto-rekomendasi tier berdasar RAM/chip + copy jujur ("12B mungkin bisa dimuat tapi headroom kecil dan terasa lebih lambat") — deterministik, bukan tebak-tebakan.
  2. **Picker terkurasi 3 model** (1 house fine-tune + 2 model permissive) alih-alih zoo 50 model.
  3. **MCP server dari app notch-nya** — agen eksternal (Claude, Codex) bisa baca/tulis task & notes Taby. Kebalikan arsitektur kita (kita konsumen tools) — kombinasi keduanya menarik: Izanotchy bisa punya keduanya.
  4. Freemium split: lokal = gratis/privat; cloud = berbayar.
- Computer use & konteks layar masih "Coming soon" (cloud) → belum lebih jauh dari Izanotchy di ranah agenik.

## E. Implikasi stack untuk Izanotchy (terupdate gelombang 3)

1. **M4 Pro Anda**: Qwen3.8-Max via API kalau butuh kualitas Max; lokal → **Qwen3.5-4B MLX/Ollama** (60–100+ t/s, vision+tools) sebagai default, **Qwen3-30B-A3B** (~40–80 t/s) kalau mau kualitas naik kelas.
2. **Decision engine**: dua kandidat nyata di ekosistem "System One" — **laya via Ollaya** (menu-bar app, MLX, port 11435, MCP) atau **imajev** (kalau butuh input gambar/screenshot; MLX, ~0,1 s). Bisa keduanya: laya untuk teks, imajev untuk verifikasi visual.
3. **Runtime lokal**: Ollama (11434) sebagai manajer model + API (tool calling, structured outputs, vision); selalu `num_ctx` ≥8192 dan `keep_alive` eksplisit.
4. **Produk**: contek pola heytaby — compatibility probe → tier otomatis, picker terkurasi, dan pertimbangkan expose MCP server dari Izanotchy.

## F. Sumber baru gelombang 3

qwen.ai/blog?id=qwen3.8 · huggingface.co/Qwen/Qwen3.8-2.4T-A95B · huggingface.co/unsloth/Qwen3.8-2.4T-A95B-GGUF · github.com/QwenLM/Qwen3.8 · ollama.com/library/qwen3.5 & qwen3.8 · github.com/mohit67890/imajev · huggingface.co/mohit67890/imajev-4b · github.com/ollaya-dev/ollaya · ollaya.dev · news.ycombinator.com/item?id=49848269 · github.com/ollama/ollama (+releases, docs.ollama.com) · github.com/mattt/ollama-swift · github.com/kevinhermawan/OllamaKit · heytaby.com (/blog/how-taby-works, /models, /tools/can-my-computer-run-local-ai, /premium, /downloads) · github.com/lloyd-december/tabbie · huggingface.co/Qwen/Qwen3-30B-A3B-MLX-4bit · llm-speed.com/hw/m4-pro · modelfit.io · docs.sea-lion.ai
