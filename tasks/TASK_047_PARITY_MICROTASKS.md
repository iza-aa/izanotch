# TASK-047 — GROK BOT PARITY BUILD: Micro-Task System + Auto-Review Protocol

Dokumen ini adalah kontrak eksekusi & review otomatis. Sumber bacaan agent dan reviewer SATU DAN SAMA (Bagian 1). PRD induk: `tasks/PRD_GROKBOT_DI_NOTCH.md`. Semua micro-task dieksekusi berurutan per fase; setiap micro-task tuntas = reviewer memverifikasi otomatis memakai daftar bukti di tabel (Bagian 3) — pengguna tidak perlu meminta review manual.

---

## 1. SUMBER BACAAN (wajib dibaca agent SEBELUM micro-task terkait; reviewer membaca sumber yang sama untuk verifikasi)

| # | Sumber | Isi | Dipakai untuk micro-task |
|---|---|---|---|
| S1 | `github-reference/grok-bot/HOW_IT_WORKS.md` | Studi cara kerja end-to-end | semua |
| S2 | `github-reference/grok-bot/PRD_NOTES.md` | 9 halaman inti produk (bot, computer, chat) | Fase 1-3 |
| S3 | `github-reference/grok-bot/PRD_NOTES_API_TEAMS.md` | Tools API + Team Bots + Identity + Mobile + FAQ + Security | Fase 2, 5, 6 |
| S4 | `github-reference/grok-bot/PRD_NOTES_ADVANCED.md` | Text capabilities + WebSocket + Prompt caching + Compaction + Governance | Fase 2, 5 |
| S5 | `github-reference/grok-bot/PRD_NOTES_FINAL.md` | Multi-agent + Ephemeral tokens + REST reference + Connector details | Fase 4, 5 |
| S6 | `github-reference/grok-bot/rea-evidence/application-graph.json` | REA graph 67MB (596 file, 25.358 node) — struktur aplikasi asli | semua (verifikasi arsitektur) |
| S7 | `github-reference/grok-bot/` app.asar source | 48MB sumber ter-ekstrak — rujukan perilaku (DILARANG disalin) | semua |

PRD induk: `tasks/PRD_GROKBOT_DI_NOTCH.md` (Bagian A-G). Skill UI: `.zcode/skills/swiftui-pro-iza/` (wajib dimuat untuk micro-task bertanda [UI]).

## 2. PROTOKOL REVIEW OTOMATIS (berlaku setiap micro-task)

1. Agent menyelesaikan micro-task → menjalankan gerbang mesinnya sendiri → melaporkan: `MT-XX SELESAI` + daftar bukti (path artifact/log/screenshot + file yang berubah).
2. Reviewer (ZCode) memverifikasi otomatis, tanpa diminta:
   - **Bukti wajib umum**: `xcodebuild` exit 0; kedua suite lulus (`test_afm_capability`, `test_system_noninvasive`); skenario e2e terkait lulus; Zero Hardcoding (grep pola terlarang pada file yang berubah); daftar KEEP utuh; nol emoji.
   - **Bukti spesifik** per micro-task (kolom "Bukti review" di tabel Bagian 3).
3. Hasil: `MT-XX LULUS` (dicatat status ✓) atau `MT-XX DITOLAK` + prompt perbaikan langsung (Fail-Fix Loop: root-cause → perbaiki sistem → rebuild → lapor ulang).
4. Satu fase selesai = semua MT fase-nya LULUS + satu commit per fase + entri CHANGELOG.
5. Reviewer membaca sumber S1-S7 yang direferensikan MT tersebut — verifikasi perilaku terhadap dokumen asli, bukan terhadap klaim agent.

## 3. DAFTAR MICRO-TASK

### FASE 0 — Gerbang Fase C (sedang berjalan di agent; bukan bagian tabel ini)
Prasyarat masuk TASK-047: 8 skenario `scenarios.fasec.json` lulus + 8 bloker B1-B8 hijau + run live bersih. (Lihat `scripts/e2e/scenarios.fasec.json` + PRD §D.)

### FASE 1 — PARITAS INPUT/OUTPUT (PRD §A9, §C3; sumber S3, S4)

| ID | [Tipe] | Scope | Baca | Bukti review (reviewer jalankan/periksa) | Status |
|---|---|---|---|---|---|
| MT-01 | [UI] | Egress 5-bagian: fakta/asumsi/selesai/menunggu-approval/terbuka — schema C3, tampil di chat sebagai bagian terstruktur | PRD §C3, S3-files | Schema valid; laporan "check email saya" memuat ≥2 fakta spesifik; oracle baru menolak laporan kosong | LULUS |
| MT-02 | [UI] | Kartu hasil (deliverable card): tipe artifact, preview, tombol revisi (revisi artifact SAMA, bukan salinan) | PRD §A9, S3 | Kartu muncul di chat untuk task ber-deliverable; revisi tidak membuat duplikat | LULUS |
| MT-03 | [UI] | Attachment: 6 file/25MB/video 200MB, validasi tipe, pesan error ramah | S3-files | Upload >25MB ditolak dengan pesan; 6 lampiran bekerja | LULUS |
| MT-04 | [non-UI] | Evidence preservation otomatis: source links, screenshot state, timestamp+TZ, nama file, action log, daftar unverified — tersimpan per run | S3 | Folder evidence per run berisi ≥5 jenis bukti; action log tidak di-redact sembarangan | LULUS |

### FASE 2 — SKILLS & ROUTINES (PRD §A8, §C4-C5; sumber S1, S2)

| ID | [Tipe] | Scope | Baca | Bukti review | Status |
|---|---|---|---|---|---|
| MT-05 | [non-UI] | Skill schema 6-field (C4): whenToUse/inputs/access/steps/validation/output/approvalBoundary + library per semua companion | S1-skills, S2 | Schema tersimpan; skill bisa direferensikan `/` | LULUS |
| MT-06 | [UI] | Teach mode: rekam aksi companion (dari action log yang sudah ada) → skill draft → review pengguna → finalisasi | S2-teach | Satu demonstrasi menghasilkan skill draft yang lulus uji safe example | LULUS |
| MT-07 | [non-UI] | Routine scheduler penuh: timezone per companion, event trigger narrow, limits (50/bot, 20 run records, min 5 menit), run history | S2-routines | Routine 5-menit terjadwal jalan; history tersimpan; routine ke-51 ditolak dengan pesan | LULUS |
| MT-08 | [non-UI] | Test run mode ("real work" warning) + trust design: otomatisasi preparation dulu, approval untuk send/purchase/delete/publish/production, no-data/stale-data policy, retry idempotent | S2-trust | Test run menyentuh input aman; aksi berisiko berhenti di approval | LULUS |

### FASE 3 — CONNECTORS & API TIER (PRD §A15-G8/G15, §F5; sumber S5)

| ID | [Tipe] | Scope | Baca | Bukti review | Status |
|---|---|---|---|---|---|
| MT-09 | [non-UI] | Routing tier keempat `api_connector` di CanonicalTaskContract + ExecutionRoutingGate (email intent + Gmail account terhubung → api_connector) | S5-connector | Log [ROUTING] menunjukkan tier api_connector untuk task email saat OAuth aktif | LULUS |
| MT-10 | [non-UI] | Gmail API connector: OAuth scope bertahap (readonly → modify → send — persis G15), search operator Gmail, baca pesan, draft, send | S5-gmail | Baca 3 email teratas via API (bukan webview); kirim draft via API; scope awal = readonly saja | LULUS |
| MT-11 | [non-UI] | Provider derivation via registry: `adapter(forEmailHost:)` dipakai controller — nol domain string di luar registry | PRD G15 | grep domain literal di controller = 0 | LULUS |
| MT-12 | [non-UI] | Connector registry pattern (declarative, account-wide, OAuth per pengguna yang bicara — pola acts-as-the-asker) + disconnect/revoke | S5-connectors | Revoke di Google mencabut akses; nol kredensial di log | LULUS |

### FASE 4 — MEMORI & MULTI-COMPANION (PRD §A1, A7, G3, G11; sumber S1, S2, S4)

| ID | [Tipe] | Scope | Baca | Bukti review | Status |
|---|---|---|---|---|---|
| MT-13 | [non-UI] | CompanionMemory: preferensi stabil + fakta + ringkasan kerja per companion; bukan pengganti sumber otoritatif (wajib cite terkini untuk keputusan) | S1-memory | Setelah sesi: preferensi teringat; keputusan konsekuensial selalu cite sumber | LULUS |
| MT-14 | [non-UI] | Memory compaction (pola G3): sesi panjang → state opak append-only, dilarang edit/reorder, re-compact diizinkan | S4-compaction | Sesi 50+ turn tetap dalam context; ringkasan state mempertahankan fakta kunci | LULUS |
| MT-15 | [non-UI] | Handoff antar companion (pola bot-to-bot async): pesan handoff tercatat, satu owner per stage | S2-handoff | Handoff Inbox→Futures tercatat & dikerjakan companion penerima | LULUS |
| MT-16 | [non-UI] | Multi-companion paralel: satu screen per companion, satu computer-use task per companion | S1-parallel | Dua companion jalan paralel tanpa saling mengunci | LULUS |

### FASE 5 — GOVERNANCE (PRD §A12, G7; sumber S3, S4)

| ID | [Tipe] | Scope | Baca | Bukti review | Status |
|---|---|---|---|---|---|
| MT-17 | [non-UI] | Auto-review rule engine: Ask first / Allow automatically (Ask first menang), personal rules hanya memperketat, rules per-desktop | S3-approvals | Rule Ask first menghentikan aksi match; Allow tidak melewati Ask first | LULUS |
| MT-18 | [non-UI] | Secrets vault: encrypted, redacted `[REDACTED]` di output/log/model (pola Team Secrets), maksimum & format nama persis docs | S3-secrets | Secret tak pernah muncul di log/transkrip/output model | LULUS |
| MT-19 | [non-UI] | Approval expiry ~10 menit untuk aksi tanpa pengguna + kartu expired + retry flow | S3-approvals | Approval kadaluarsa tercatat; aksi tidak jalan | LULUS |
| MT-20 | [non-UI] | Local execution policy: Ask every time default / Always / Never (Never = rekomendasi) + per-computer setting | S3-local | Perintah lokal tanpa approval ditolak; log jelas | LULUS |

### FASE 6 — MODEL CAPABILITY CHECK (PRD §B; sumber S1, S6)

| ID | [Tipe] | Scope | Baca | Bukti review | Status |
|---|---|---|---|---|---|
| MT-21 | [non-UI] | Benchmark tiap lapisan otak (Ingress/planner/egress) terhadap kontrak §B — suite terukur; laporan capaian per lapisan | PRD §B, S6 | Laporan benchmark + keputusan: AFM sanggup / butuh eskalasi model | LULUS |
| MT-22 | [non-UI] | Jika ada lapisan gagal: siapkan spesifikasi kebutuhan model pengganti (lokal) — DILARANG pindah ke cloud | PRD §B | Dokumen kebutuhan model diserahkan pengguna | LULUS |

### FASE 7 — BOT LIFECYCLE & IDENTITY PARITY (PRD §A4; sumber S2)

| ID | [Tipe] | Scope | Baca | Bukti review | Status |
|---|---|---|---|---|---|
| MT-23 | [UI] | Pembuatan companion via percakapan (pola interview: jelaskan job → profil terbentuk; template 8 arketipe use-case sebagai pilihan) | S2-bots, S1 | Companion baru terbentuk lewat percakapan; profil terisi | LULUS |
| MT-24 | [UI] | Edit Profile penuh: nama/label/description/avatar; description = aturan durable yang di-inject ke prompt sistem | S2-bots | Perubahan description mengubah perilaku (uji boundary) | LULUS |
| MT-25 | [UI] | Pin/Hide/Duplicate (profil+skills+routines ikut, history TIDAK) + Delete dengan peringatan files tersisa | S2-bots | Keempat operasi berfungsi; duplicate tanpa history | LULUS |
| MT-26 | [UI] | Share template (strip secrets/customer data) + Import dari template | S2-bots | Template diekspor tanpa secrets; import membuat salinan bersih | LULUS |
| MT-27 | [non-UI] | Marketplace & skill library: discover/install packaged skills + connector catalog UI | S2-skills | Library tampil; instal mengaktifkan skill | LULUS |

### FASE 8 — VOICE & COLLABORATION STACK (PRD §A7; sumber S2)

| ID | [Tipe] | Scope | Baca | Bukti review |
|---|---|---|---|---|
| MT-28 | [UI] | Dictate + voice memo (rekam, play, transkrip di transcript) | S2-chat | Voice memo muncul di transcript dan bisa diputar |
| MT-29 | [UI] | Voice chat live ("Start voice chat", kartu setelah selesai) | S2-chat | Sesi voice live berfungsi dan meninggalkan kartu |
| MT-30 | [UI] | Search palette (Cmd+K: switch companion/cari pesan/file/link/routine) + shortcut set penuh | S2-chat | Palette menemukan bot/pesan/file/routine |
| MT-31 | [UI] | Group chat 2-6 companion (outcome bersama, @-arah, reply = jawab bot itu, tanpa approval/secret di grup) | S2-group | Group chat berfungsi dengan aturan persis docs |
| MT-32 | [non-UI] | Bot-to-bot handoff async terlihat di percakapan (satu owner per stage) + threads & reactions (reaction = acknowledgment saja) | S2-handoff | Handoff dan thread berfungsi; reaction tidak membawa instruksi |

### FASE 9 — CONNECTORS PENUH & EKSTERNAL INGRESS (PRD §A15/G15, §A10; sumber S5, S3)

| ID | [Tipe] | Scope | Baca | Bukti review |
|---|---|---|---|---|
| MT-33 | [non-UI] | Google Calendar connector (events/RSVP/freebusy, scope bertahap) | S5-gmail | Create/RSVP event via API terverifikasi |
| MT-34 | [non-UI] | Google Drive connector (search/read/create/upload, scope bertahap) | S5-drive | Baca & buat file Drive terverifikasi |
| MT-35 | [non-UI] | Outlook Mail+Calendar connector (Mail.ReadWrite/Mail.Send/Calendars.ReadWrite + offline_access) | S5-outlook | Paritas Gmail di Outlook |
| MT-36 | [non-UI] | Custom MCP connector (public-internet server, allowed_tools filter, tanpa kredensial di command) + tunneling doc | S5-mcp | MCP server kustom dipanggil dari companion |
| MT-37 | [UI] | Eksternal task ingress (notifikasi macOS/share sheet): task dari luar chat + ACK ringkas + hasil di app (pola tag-on-x) | S3-tag | Task dari notifikasi masuk, ACK terkirim, hasil di app |

### FASE 10 — TEAM & GOVERNANCE PARITY (PRD §A11/A16, G7; sumber S3, S4) — FASE AKHIR

| ID | [Tipe] | Scope | Baca | Bukti review |
|---|---|---|---|---|
| MT-38 | [non-UI] | Team companion: team memory + private notes per orang, bot acts-as-the-asker | S3-team | Team memory tersimpan saat dinyatakan team-wide; catatan privat tak bocor |
| MT-39 | [non-UI] | Secrets vault tim: encrypted, redacted di output/log/model, limits (25 @ 8-4096 byte) | S3-secrets | Secret tak pernah tampil; redaksi terverifikasi |
| MT-40 | [UI] | Managers & admin distribution (ubah setup vs publish/delete separation) | S3-team | Manager mengubah setup; publish tetap owner |
| MT-41 | [non-UI] | Audit logs + action recording (redaksi kredensial/PEM/email; retensi; export) | S4-security | Audit mencatat peristiwa control-plane; redaksi terverifikasi |
| MT-42 | [non-UI] | Network/egress parity (semua dari Mac pengguna; dokumentasi perbedaan "laptop ditutup" vs cloud) | S4-network | Dokumentasi + uji: kerja berjalan selama Mac menyala |
| MT-43 | [non-UI] | Prompt-injection defense berlapis (untrusted tagging + rule engine + least privilege — melampaui coverage Auto Review mereka yang tidak mencakup memory/settings) | S3-security | Uji injection: aksi tak sah ditolak |

## 4. STATUS TRACKING

- Total: **43 micro-task dalam 10 fase** — memetakan seluruh 22 halaman docs.x.ai tanpa ada fitur yang tertinggal.
- Fase 1-6 = gelombang inti (MVP parity); Fase 7-10 = kelengkapan paritas penuh (lifecycle, voice, connectors penuh, tim/governance).
- Status MT dicatat di dokumen ini (kolom status ditambahkan saat eksekusi: `BELUM → KERJA → LULUS/DITOLAK`).
- Reviewer mencatat hasil verifikasi di CHANGELOG per fase.
- Micro-task baru (dari temuan runtime) ditambahkan ke tabel dengan nomor lanjutan + alasan.
- Pemetaan halaman docs → fase: A1 overview→semua; A2 get-started→F1; A3 use-cases→MT-23; A4 bots→MT-24/25/26; A5 computer→Fase C gate; A6 computers→gerbang Fase C; A7 chat→MT-28/29/30/31/32; A8 skills→MT-05..08; A9 files→MT-01..04; A10 tag-on-x→MT-37; A11 team→MT-38/39/40; A12 approvals→MT-17..20/43; A13 settings→MT-20 + sidebar states; A14 mobile→kontrak data; A15/A16 team/enterprise→MT-38..41; A17 identity→n/a lokal; A18 security→MT-41; A19 troubleshooting→gerbang tiap fase.

## 5. BATAS

- Zero Hardcoding dalam bentuk apa pun (aturan tunggal AGENTS.md).
- Kode Grok Bot dilarang disalin; pola/protokol boleh (implementasi sendiri).
- Otak lokal; eskalasi model hanya ke model lokal yang disediakan pemilik.
- Semua bukti review tersimpan sebagai artifact (log/screenshot/file), bukan narasi.
