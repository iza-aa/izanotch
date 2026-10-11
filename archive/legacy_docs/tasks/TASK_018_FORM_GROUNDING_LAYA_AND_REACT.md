# TASK-018: Form Input Grounding Protection, Dynamic Laya System 1 Choices, Autonomous ReAct Reasoning & Factual Egress Integrity

Dokumen Spesifikasi Teknis & Rencana Eksekusi.
Memperbaiki grounding formulir agar tidak dibajak oleh toolbar, mengadaptasi pilihan System 1 Laya Decision Engine secara dinamis ke affordance form, menanamkan penalaran ReAct otonom pengisian field pada GeneralStepPolicy, serta menegakkan integritas fakta di TaskEgressValidator.

---

## 1. Analisis Akar Masalah (Root Cause Analysis)

### A. Pembajakan Query Field oleh Pemindaian Priority 1 AXToolbar
- Pada `ClickyHybridGroundingEngine.swift`, Priority 1 Fast-Path memindai seluruh tombol toolbar (`AXToolbar`) secara langsung.
- Ketika query perencana mencari input field seperti `"message field"`, pencocokan substring atau token `"message"` tumpang tindih dengan tombol `"New Message"` di toolbar (koordinat Y: 102).
- Akibatnya, kursor CUA diarahkan ke tombol toolbar alih-alih area teks pesan yang sebenarnya, dan teks diketikkan ke toolbar atau hilang.

### B. Kamus Pilihan dan State Laya Decision Engine Ter-hardcode ke Navigasi Daftar
- `LayaDecisionEngine.swift:158-175` mengasumsikan seluruh navigasi adalah daftar item (`scroll_up`, `scroll_down`, `click_item`).
- Pada formulir komposisi atau jendela interaksi tanpa item daftar (`visibleItemCount == 0`), Laya dipaksa memilih `click_item` dengan keyakinan palsu 89-94%.
- Pilihan Laya tidak merefleksikan affordance antarmuka yang sebenarnya (formulir input dan kontrol aksi).

### C. Ketiadaan Penalaran ReAct Pengisian Form di GeneralStepPolicy
- Model AFM 3B melompati pengisian field penerima dan subjek, langsung mengeklik tombol kirim (`Send`) secara berulang tanpa memastikan kelengkapan data yang diminta pada tujuan (`Goal`).
- Dibutuhkan instruksi ReAct otonom umum: mencocokkan informasi yang dibutuhkan pada Goal terhadap input field yang tampak di Observation, dan melengkapi field sebelum mengirim.

### D. Halusinasi Kesuksesan di Egress Gateway saat isDone == false
- Ketika tugas komposisi atau pengiriman belum selesai (`effectiveIsDone == false`), synthesizer respon di `TaskEgressValidator` mengekstrapolasi riwayat langkah dan berhalusinasi menyatakan bahwa email telah terkirim (`"The email was sent to..."`).

---

## 2. Rencana Arsitektur & Perbaikan

### A. Proteksi Grounding Form Input (ClickyHybridGroundingEngine)
- Fungsi `isInputFieldQuery(_ query: String) -> Bool` mendeteksi query berorientasi input teks.
- Pemindaian Priority 1 `AXToolbar` di-bypass secara otomatis jika query berorientasi field/input.
- Token matching 2-kata pada query field menolak elemen bertipe tombol (`AXButton`, `AXMenuButton`) dan mewajibkan kesesuaian token penuh.

### B. Affordance-Driven Dynamic Choices Laya System 1 (LayaDecisionEngine & CompanionVMAgentLoop)
- Menambahkan parameter `hasActiveForm: Bool` pada `decideStep(...)`.
- Ketika form aktif atau `visibleItemCount == 0`, Laya menyediakan choices:
  - `type_field`: Mengetikkan teks ke dalam field input atau text area.
  - `click_control`: Mengeklik tombol atau kontrol aksi formulir.
  - `conclude_task`: Formulir selesai dan aksi terkonfirmasi.
- `CompanionVMAgentLoop` mendelegasikan resolusi target spesifik ke System 2 AFM Task Planner.

### C. Penalaran ReAct Otonom Pengisian Form (GeneralStepPolicy)
- Memperbarui instruksi `GeneralStepPolicy`:
  `When filling forms: identify all required information in Goal (e.g. recipient, subject, message body) and match them to visible input fields in Observation. Fill required fields before clicking submit or send.`

### D. Guard Anti-Halusinasi Egress (TaskEgressValidator)
- Menambahkan step 5 guard anti-halusinasi pada `postProcessValidation`:
  Jika `effectiveIsDone == false` dan respon yang disintesis mengandung frasa klaim pengiriman/kesuksesan ("was sent", "telah dikirim"), respon diganti dengan status faktual objektif bahwa formulir belum sepenuhnya terisi atau dikirimkan.

---

## 3. Hasil Verifikasi Empiris

- Unit Test: `scripts/test_task018_form_grounding_laya_and_react.swift` (100% PASS, 17 asersi).
- Regression Tests: Seluruh 12 skrip pengujian tugas 007 hingga 018 di `scripts/` (100% PASS).
- Kompilasi: `xcodebuild -project izaNotch.xcodeproj -scheme izaNotch -configuration Debug build` (`** BUILD SUCCEEDED **`, exit code 0).
- Runtime Process: Biner baru berjalan aktif (PID 20481 untuk `izaNotch`, PID 20499 untuk `IzaNotchXPCHelper`).
- Log Runtime: `~/Library/Logs/Izanotchy/clicky.log` bersih tanpa unhandled runtime exception.
