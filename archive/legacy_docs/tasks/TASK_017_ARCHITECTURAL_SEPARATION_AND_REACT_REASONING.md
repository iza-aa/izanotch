# TASK-017: Separasi Arsitektur Observasi UI, Pemulihan Headless Vision Luna 6, dan ReAct Error Recovery Loop

Dokumen Spesifikasi Teknis & Rencana Eksekusi.
Memperbaiki pemisahan tanggung jawab file (Single Responsibility Principle), memulihkan deteksi biner OpenAI Codex CLI (Luna 6 Headless Vision), menanamkan kemampuan refleksi dan pemulihan kesalahan ReAct pada AFM 3B Planner, serta menegakkan validasi faktual di Egress Gateway.

---

## 1. Analisis Akar Masalah (Root Cause Analysis)

### A. Pelanggaran Single Responsibility Principle di `CompanionVMAgentLoop.swift`
- `CompanionVMAgentLoop.swift` (1.546 baris) bertindak sebagai *God Object*.
- File ini mencampuradukkan:
  1. Siklus hidup agen CUA (`executeAutonomousTask`, state machine per-langkah, delivery receipt).
  2. Eksekusi OCR visual Apple Vision (`VNRecognizeTextRequest`).
  3. Algoritma spasial font-height dynamic gap clustering.
  4. Algoritma rekonsiliasi indeks kartu multi-langkah (*multi-card consensus anchoring*).
  5. Penelusuran pohon hierarki Accessibility (`findTargetAXApplication`, `extractAXToolbarControls`, `AXOutline`/`AXTable` layout boundaries).
  6. Pemformatan teks observasi terstruktur (`summarizeTargetedObservation`, `readStructuredObservation`).
- Dampak: Modifikasi observasi atau penambahan grounding baru rentan merusak kestabilan loop CUA. Kode observasi sulit diuji secara unit test terisolasi.

### B. Kegagalan Resolusi Biner Codex CLI (Luna 6 Headless Vision)
- Pada `ChatGPTCodexVisionService.swift:52` dan `line 95`, path biner Codex di-hardcode ke:
  ```swift
  public static let codexBinaryPath = "/Applications/ChatGPT.app/Contents/Resources/codex"
  ```
- Di macOS lokal, path biner OpenAI Codex CLI yang sebenarnya berada di:
  ```
  /Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex
  ```
- Akibatnya, `FileManager.default.fileExists(atPath: Self.codexBinaryPath)` selalu bernilai `false`.
- Setiap kali tier Accessibility gagal menemukan koordinat elemen UI (misal text area yang tidak memiliki label AX atau dropdown popover), fallback ke Luna 6 langsung melempar error `VisionServiceError.binaryNotFound`, sehingga Luna 6 tidak pernah dieksekusi sama sekali.

### C. Ketiadaan Refleksi ReAct & Penalaran Hambatan Visual di Step Policy
- `GeneralStepPolicy.swift` hanya memberikan arahan forward planning sederhana tanpa membekali model AFM 3B instruksi penalaran terhadap rintangan (*obstacles*) di field `thought`.
- Ketika sebuah field diketik (misal email penerima) dan memunculkan popover autocomplete / dropdown floating, klik pada elemen lain terhalang oleh event dismiss popover.
- Model 3B tidak memiliki instruksi untuk:
  1. Merefleksikan apakah langkah sebelumnya terhambat oleh popover / dropdown.
  2. Memilih item saran dropdown atau menutup popover terlebih dahulu (via Return/Escape) sebelum melanjutkan ke target berikutnya.
  3. Mencoba rute interaksi alternatif jika aksi sebelumnya gagal, alih-alih mengulang aksi yang sama secara membabi buta.

### D. Halusinasi Penyelesaian di Task Egress Validator
- `TaskEgressValidator` dan `ComposeValidationPolicy` mengevaluasi penyelesaian tugas berdasarkan klaim riwayat teks di `performedSteps` (misal `"typed text into..."`), tanpa memverifikasi fakta aktual pada `latestObservation`.
- Ketika pengetikan Subject atau Body gagal atau belum mendarat di editor nyata, validator menganggap tugas selesai (`isDone = true`), memotong loop eksekusi secara prematur (*fake completion*).

---

## 2. Rencana Arsitektur & Sub-Tugas

```
+-----------------------------------------------------------------------------------+
|                            CompanionVMAgentLoop                                   |
|   (Murni State Machine CUA Loop, Dispatching Action, & Lifecycle Management)      |
+-----------------------------------------------------------------------------------+
                                   |                       |
        1. Minta Observasi Layar   |                       |  2. Minta Rencana Langkah
                                   v                       v
+------------------------------------+    +-----------------------------------------+
|     ClickyUIObservationService     |    |            TaskStepPlanner              |
|  - Vision OCR (VNRecognizeText)    |    |  - GeneralStepPolicy (ReAct Reflection) |
|  - Font-Height Gap Clustering      |    |  - Dynamic Obstacle Handling            |
|  - Container Layout Discovery      |    |  - Alternative Route Selection          |
|  - Multi-Card Consensus Anchoring  |    +-----------------------------------------+
|  - Section Slicing & Structuring   |                             |
+------------------------------------+                             | 3. Aksi & Grounding
                                                                   v
                                          +-----------------------------------------+
                                          |       ClickyHybridGroundingEngine       |
                                          |  - Tier 1: Accessibility IPC (Fast)     |
                                          |  - Tier 2: Luna 6 Vision (Codex CLI)    |
                                          |    (Dynamic Path: codex-cli/bin/codex)  |
                                          +-----------------------------------------+
                                                                   |
                                                                   v
                                          +-----------------------------------------+
                                          |           TaskEgressValidator           |
                                          |  - Factual Observation Assertion        |
                                          |  - No Fake Completion on Empty Fields   |
                                          +-----------------------------------------+
```

---

### Sub-Tugas 1: TASK-017A — Ekstraksi `ClickyUIObservationService.swift` & Perampingan Loop
- Buat file baru: `izaNotch/Clicky/CUA/Grounding/ClickyUIObservationService.swift`.
- Pindahkan dari `CompanionVMAgentLoop.swift`:
  - `readStructuredObservation(snapshotPath:pid:targetSection:effectiveTargetIdx:)`
  - `summarizeTargetedObservation(...)`
  - `resolveCardIndices(...)`
  - `findMatchingOcrElement(query:)`
  - Helper Accessibility layout: `findTargetAXApplication`, `findFirstAXElement`, `extractAXToolbarControls`, `extractAXElementTitles`, `extractAXElementTextRecursive`.
- Definisikan model data observasi terstruktur:
  ```swift
  public struct UIObservationSnapshot: Sendable {
      public let viewport: (isAtTop: Bool, scrollOffset: Float)
      public let activeContainer: String?
      public let navigationElements: [String]
      public let toolbarControls: [String]
      public let observedText: [String]
      public let cardBoxes: [String: CGRect]
      public let formattedSummary: String
  }
  ```
- Rampingkan `CompanionVMAgentLoop.swift` dari 1.546 baris menjadi < 700 baris dengan memanggil `ClickyUIObservationService.shared.observe(...)`.

---

### Sub-Tugas 2: TASK-017B — Resolusi Dinamis Biner Codex CLI (Luna 6 Headless Vision)
- Modifikasi `izaNotch/Clicky/Services/Vision/ChatGPTCodexVisionService.swift`:
  - Hapus hardcoding `public static let codexBinaryPath = "..."`.
  - Tambahkan fungsi resolusi dinamis multi-kandidat:
    ```swift
    public static func resolveCodexBinaryPath() -> String? {
        let candidates = [
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex",
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "/usr/local/bin/codex",
            "/opt/homebrew/bin/codex",
            NSString(string: "~/.local/bin/codex").expandingTildeInPath,
            "/Applications/ChatGPT.app/Contents/Resources/codex"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    ```
  - Gunakan `resolveCodexBinaryPath()` pada `executeProcessQuery` sehingga Luna 6 dapat langsung mengeksekusi inferensi visual headless saat AX gagal.

---

### Sub-Tugas 3: TASK-017C — ReAct Error Recovery & Obstacle Reflection di `GeneralStepPolicy.swift`
- Perbarui `GeneralStepPolicy.swift` di `izaNotch/Clicky/Reasoning/Planner/Policies/StepPolicyRegistry.swift`:
  - Tambahkan instruksi ReAct terfokus:
    1. **Reflection**: Pada field `thought`, wajib merefleksikan hasil langkah sebelumnya: Apakah berhasil? Apakah ada rintangan seperti dropdown autocomplete, modal popover, atau elemen yang tidak fokus?
    2. **Obstacle Handling**: Jika muncul dropdown autocomplete atau popover mengambang: klik opsi saran yang relevan atau gunakan penekanan tombol untuk menutup popover sebelum berpindah ke field berikutnya.
    3. **Alternative Routing**: Jika aksi sebelumnya gagal (ungrounded / unclickable), jangan mengulang aksi yang sama. Coba rute interaksi baru (misal klik fokus terlebih dahulu, navigasi Tab, atau menargetkan kontainer terdekat).
  - Jaga panjang prompt tetap ramping (< 35 baris) sesuai prinsip Single Responsibility dan Cognitive Empathy Model 3B.

---

### Sub-Tugas 4: TASK-017D — Verifikasi Faktual State Layar di Egress Validator
- Modifikasi `ComposeValidationPolicy.swift` & `TaskEgressValidator.swift`:
  - Larang `isDone = true` jika ada langkah dalam `performedSteps` yang berstatus `Failed to execute` tanpa adanya pemulihan sukses di langkah berikutnya.
  - Untuk tugas bertipe `compose` atau `send`, validator wajib memeriksa apakah konten (subjek / pesan) secara faktual tampak di `latestObservation`. Jika area formulir masih kosong, tugas belum selesai (`isDone: false`).

---

### Sub-Tugas 5: TASK-017E — Verifikasi TDD & Kompilasi Bersih
- Buat unit test baru: `scripts/test_task017_architectural_separation_and_react.swift` yang memvalidasi:
  1. `ClickyUIObservationService` mengembalikan `UIObservationSnapshot` yang valid secara mandiri.
  2. `ChatGPTCodexVisionService.resolveCodexBinaryPath()` berhasil menemukan path biner yang valid dan executable di mesin.
  3. `GeneralStepPolicy` memuat instruksi refleksi ReAct dan penanganan dropdown/popover.
  4. `TaskEgressValidator` menolak `isDone = true` saat ada langkah gagal tanpa pemulihan atau saat observasi faktual kosong.
- Jalankan seluruh 16 skrip pengujian regresi di `scripts/`.
- Jalankan `xcodebuild` (target `boringNotch`, konfigurasi `Debug`) dengan exit code 0 (`** BUILD SUCCEEDED **`).
- Relaunch aplikasi biner baru, verifikasi PID via `ps aux`, dan pastikan log runtime `clicky.log` bersih.

---

## 3. Matriks Tanggung Jawab File (Single Responsibility Matrix)

| File | Tanggung Jawab Tunggal | Hal yang Dilarang Ada di File Ini |
|---|---|---|
| `CompanionVMAgentLoop.swift` | Orkestrasi siklus loop CUA agen, state machine, dan deliverable receipt | Eksekusi OCR Vision, gap clustering, AX tree traversal, format text observasi |
| `ClickyUIObservationService.swift` | Ekstraksi teks OCR, clustering kartu berbasis tinggi font, konsensus indeks, dan layout AX | Logika loop agen CUA, pergerakan mouse kursor, validasi tugas |
| `ChatGPTCodexVisionService.swift` | Resolusi biner Codex CLI & eksekusi headless vision coordinate via Luna 6 | Logika Accessibility fallback internal, hardcoded binary path tunggal |
| `GeneralStepPolicy.swift` | Aturan naskah positif ReAct perencana micro-step untuk model AFM 3B | Hardcoding nama aplikasi, aturan parsing JSON manual |
| `TaskEgressValidator.swift` | Validasi teknis deterministik dan ekstraksi fakta aktual dari observasi layar | Manipulasi UI fisik, perencanaan langkah maju |

---

## 4. Kriteria Keberhasilan (Definition of Done)

1. `ClickyUIObservationService.swift` terdaftar di project Xcode dan `CompanionVMAgentLoop.swift` menyusut signifikan (< 700 baris).
2. `ChatGPTCodexVisionService` berhasil mendeteksi `/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex`.
3. Skrip verifikasi `scripts/test_task017_architectural_separation_and_react.swift` lulus 100%.
4. Seluruh skrip regresi lama (15 skrip) tetap lulus 100%.
5. Kompilasi `xcodebuild` berhasil bersih (`** BUILD SUCCEEDED **`).
6. Biner baru berjalan aktif dan log runtime bersih.
7. `CHANGELOG.md`, `TASKS.md`, `ERRORS.md`, dan `AGENTS.md` diperbarui.
