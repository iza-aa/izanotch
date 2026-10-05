# 🛠️ Rencana Kerja: Eliminasi Residu Hardcoding Bahasa, Verb List, & Template String

> **Status:** Siap Diajukan & Di-acc  
> **Target:** Menghilangkan seluruh sisa daftar kata kerja statis (`actionVerbs`), kamus marker bahasa statis (`indonesianMarkers`/`englishMarkers`), percabangan bahasa biner `(lang == "id") ? ... : ...`, ordinals kaku (`["pertama", ...]`), dan template teks statis di `CompanionVMAgentLoop`, `TaskIngressGateway`, dan `TaskEgressValidator`. Mengalihkan sintesis pesan penutup ke model AI melalui `TaskEgressValidator`.

---

## 🔍 1. Analisis Akar Masalah (Root Cause)

1. **Hardcoded Action Verbs & Fallback Asumtif di Ingress Gateway (`TaskIngressGateway.swift:145-182`)**:
   - `TaskIngressGateway` memiliki daftar kaku: `actionVerbs = ["buka", "cek", "check", "lihat", "kirim", "cari", "tulis", "open", "read", "inspect", "send", "browse", "chart"]`.
   - Jika model AI gagal menghasilkan JSON dekomposisi dan terdapat verb dalam daftar tersebut, fallback-nya memaksakan dekomposisi kaku: `intentType: "inspect"`, `targetEntity: "inbox_item_1"`, `targetIndex: 1`, `normalizedGoal: "Inspect latest received item in \(candidateApp)"`. Hal ini membuat perintah seperti *"kirim email ke Budi"* atau *"tulis catatan"* dialihkan secara keliru menjadi "periksa inbox item 1".
   - Metode `resolveLanguage` mengandalkan 40+ kata bahasa Indonesia dan 25+ kata bahasa Inggris secara hardcoded, padahal macOS memiliki framework bawaan Apple `NaturalLanguage` (`NLLanguageRecognizer`) yang bekerja on-device secara machine-learned tanpa kamus statis.
   - Terdapat juga daftar statis `pureGreetings = ["halo", "hai", ...]` padahal model AI diinstruksikan untuk mengenali `conversational` intent secara otomatis.

2. **Bypass Egress Validator di Loop Otonom (`CompanionVMAgentLoop.swift:507-512`)**:
   - Ketika loop mencapai `maxSteps` (batas langkah), kode menyusun pesan menggunakan percabangan manual:
     ```swift
     finalResponseToUser = (userLang == "id")
         ? "Langkah kerja pada \(appName) mencapai batas maksimum (\(maxSteps) langkah) tanpa konfirmasi keberhasilan dari AFM."
         : "Task steps on \(appName) reached the maximum limit (\(maxSteps) steps) without confirmation from AFM."
     ```
   - Padahal arsitektur kita sudah memiliki **Egress Gateway (`TaskEgressValidator`)** yang bertugas menyintesis respons faktual dalam bahasa pengguna menggunakan model AI (AFM / SiriAIEngine / ClaudeAPI).
   - Terdapat juga teks statis hardcoded di baris 239-240 (`var finalSystemState = "Tugas pada \(appName)..."`), baris 253, baris 525 (`"Pemeriksaan pada \(appName) telah selesai dilakukan."`), dan baris 181 (`let allowedApps = session?.workflowAppNames ?? ["Mail", "Safari"]`).

3. **Template Bahasa Biner & Ordinals Kaku di Egress Validator (`TaskEgressValidator.swift`)**:
   - Baris 32: `let targetLanguageName = (lang == "id") ? "Bahasa Indonesia" : "English"` (mengabaikan seluruh bahasa dunia lainnya).
   - Baris 159-163, 172, 182-186: Template if-else bahasa ganda:
     `if lang == "id" { responseToUser = "Hasil pemeriksaan \(appName): \(extractedData)" } else { ... }`
   - Baris 201-203: Array ordinal kaku `let ordinals = ["pertama", "kedua", "ketiga", "keempat", "kelima"]`.
   - Baris 111: Pesan fallback statis `"Sedang memproses permintaan pada \(appName)..."`.

---

## 📋 2. Rencana Implementasi Bertahap (Surgical Fix Plan)

### Task 1: Refaktorisasi `TaskIngressGateway.swift` (Deteksi Bahasa ML & Zero Hardcoded Fallback)
- **File:** `boringNotch/Clicky/Tools/TaskIngressGateway.swift`
- **Tindakan:**
  1. Hapus array hardcoded `pureGreetings` (biarkan model AI mengklasifikasikan intent `conversational` secara dinamis; untuk fast-path kosong, periksa `userPrompt.trimmingCharacters.isEmpty`).
  2. Hapus array `actionVerbs = ["buka", "cek", ...]` pada fallback baris 145.
  3. Ubah fallback ketika model gagal menjadi abstrak dan netral:
     - `targetAppName: candidateApp`
     - `actionScope: "Execute user request in \(candidateApp)"`
     - `plannedSubGoals: ["Interact with \(candidateApp) interface to fulfill user request"]`
     - `intentType: "interact"`
     - `targetEntity: "main_window"`
     - `targetIndex: nil`
     - `searchQuery: nil`
     - `normalizedGoal: userPrompt`
     - Tidak ada asumsi `inbox_item_1`, `inspect`, atau ordinal 1.
  4. Refaktor `resolveLanguage`: Gunakan `import NaturalLanguage` dan `NLLanguageRecognizer`. Jika model AI mendeteksi kode bahasa ISO, gunakan itu. Jika tidak, gunakan `NLLanguageRecognizer.dominantLanguage?.rawValue` yang bekerja dinamis on-device untuk ratusan bahasa. Hapus array `indonesianMarkers` dan `englishMarkers`.

### Task 2: Delegasikan Seluruh Sintesis Respons Akhir ke `TaskEgressValidator` di `CompanionVMAgentLoop.swift`
- **File:** `boringNotch/Clicky/Tools/CompanionVMAgentLoop.swift`
- **Tindakan:**
  1. Ganti `allowedApps = session?.workflowAppNames ?? ["Mail", "Safari"]` menjadi `session?.workflowAppNames ?? CompanionManager.shared.activeBuddy.workflowAppNames`.
  2. Saat loop selesai pada batas maksimum langkah (step limit reached), **JANGAN** membuat string ternary `(userLang == "id") ? ... : ...`.
  3. Panggil `TaskEgressValidator.shared.validate(...)` dengan observasi akhir:
     `latestObservation: "Maximum execution limit reached (\(maxSteps) steps). Current screen observation: \(currentObservationSummary)"`
     Biarkan AFM / SiriAIEngine / ClaudeAPI merumuskan penjelasan ramah langsung dalam bahasa pengguna (`userLanguage`).
  4. Hapus string fallback statis bahasa Indonesia di baris 239-240, 253, dan 525. Gunakan hasil sintesis `TaskEgressValidator` sebagai sumber kebenaran tunggal (*Single Source of Truth*).

### Task 3: Bersihkan Residu Template Bahasa & Ordinals di `TaskEgressValidator.swift`
- **File:** `boringNotch/Clicky/Tools/TaskEgressValidator.swift`
- **Tindakan:**
  1. Ubah `targetLanguageName` menggunakan Apple Foundation:
     `let targetLanguageName = Locale(identifier: "en").localizedString(forLanguageCode: lang) ?? lang`
     Menghasilkan nama bahasa resmi ("Indonesian", "English", "French", "Japanese", dll.) secara universal tanpa ternary kaku.
  2. Hapus array `ordinals = ["pertama", "kedua", ...]`. Jika target memiliki nomor urut, rujuk secara dinamis dengan format `#\(targetIdx)`.
  3. Hapus percabangan template ganda `if lang == "id" { ... } else { ... }`.
  4. Jika data faktual (`extractedData`) tersedia dan valid, biarkan data faktual tersebut menjadi inti respons tanpa membungkusnya dengan frasa template statis.
  5. Fallback inisial dibuat netral atau dihasilkan secara dinamis.

### Task 4: Pembuatan TDD Regression Suite (`scripts/test_taskI_eliminate_language_and_verb_hardcoding.swift`)
- **File:** `scripts/test_taskI_eliminate_language_and_verb_hardcoding.swift`
- **Verifikasi:**
  - Test 1: `TaskIngressGateway.resolveLanguage` mengidentifikasi bahasa Indonesia (`"id"`), bahasa Inggris (`"en"`), dan bahasa lain tanpa kamus kata statis (menggunakan `NaturalLanguage`).
  - Test 2: `TaskIngressGateway` dekonstruksi fallback tidak menghasilkan asumsi `inbox_item_1` atau verb list statis.
  - Test 3: `TaskEgressValidator` menghasilkan nama bahasa universal via `Locale` untuk berbagai bahasa.
  - Test 4: `CompanionVMAgentLoop` tidak memiliki ternary string `(userLang == "id")` dan mengalirkan sintesis ke validator.

### Task 5: Kompilasi Bersih & Verifikasi Runtime
1. Eksekusi `xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug build` -> Pastikan `** BUILD SUCCEEDED **`.
2. Matikan instance lama (`pkill -9 -f boringNotch`) dan luncurkan instance biner baru.
3. Verifikasi PID baru aktif (`ps aux | grep -i boringnotch`).
4. Update `CHANGELOG.md` dan `ERRORS.md`.
