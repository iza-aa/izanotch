# Fitur F-10: 6 Luna Medium Vision VM, Multi-Account Session Pool (Zero Restart), & Dynamic Island Notch Usage Monitor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Membangun engine AI Vision VM super akurat bertenaga **6 Luna Medium** (`gpt-6-luna` dengan reasoning effort `medium`) yang berjalan 100% headless di latar belakang, didukung oleh **Multi-Account Session Pool** (hot-fallback instan tanpa me-restart aplikasi saat limit), eliminasi total mockup palsu di kartu chat menjadi **Hybrid Precision Grounder** (Live Snapshot + Grid 100px + Tag ID), dan **Widget Pemantau Kuota Akun ChatGPT** di Tab AI Notch.

**Architecture:**
1. **Hybrid Precision Grounder (`HomeSpaceComputerCardView.swift`)**: Menghapus seluruh gambar statis Sonoma/CRM palsu; menggantinya dengan live snapshot jendela aplikasi riil (Mail/Safari) yang dilapisi kisi koordinat 100px semi-transparan, penggaris piksel X/Y, dan kursor bidik crosshair.
2. **Headless 6 Luna Medium Vision Engine (`ChatGPTCodexVisionService.swift`)**: Memanggil binary resmi OpenAI `/Applications/ChatGPT.app/Contents/Resources/codex exec` dengan modalitas gambar `-i`, model `-m gpt-6-luna`, `-c reasoning_effort=medium`, sandbox `-s read-only`, dan output JSON murni tanpa membuka jendela GUI ChatGPT.
3. **Multi-Account Session Pool & Hot Failover (`ChatGPTAccountPoolManager.swift`)**: Mengelola isolasi multi-akun di `~/.izanotchy/credentials/gpt_accounts/` dengan injeksi `CODEX_HOME` per request. Saat akun aktif limit (HTTP 429 / kuota habis), engine langsung mengalihkan request ke akun cadangan dalam <50ms tanpa restart aplikasi.
4. **Notch AI Usage & Pool Monitor (`ChatGPTAccountMonitorWidget.swift`)**: Widget Dynamic Island pada Notch yang memantau akun aktif, sisa kuota, status akun cadangan (Ready / Cooldown), dan aksi tambah akun.
5. **Multi-Companion Group Delegation (`CompanionCollaborationBus.swift`)**: Integrasi alur kerja grup chat antar companion (Inbox Buddy, Futures Scout) yang berbagi engine vision VM yang sama.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit, Process/Pipe stdio, Apple Accessibility API (`AXUIElement`), macOS WindowServer (`CGWindowListCopyWindowInfo`), OpenAI Codex CLI (`/Applications/ChatGPT.app/Contents/Resources/codex`).

---

## Global Constraints

- **Zero Speculative / Fake UI**: Tidak boleh ada lagi wallpaper palsu Sonoma atau jendela fiktif Priya Natarajan. Seluruh preview harus berasal dari jendela aplikasi macOS asli.
- **Zero GUI Popups**: Pemanggilan model 6 Luna Medium WAJIB 100% headless di latar belakang tanpa membuka aplikasi ChatGPT desktop.
- **Zero Restart on Account Switch**: Pergantian akun ChatGPT saat limit harus terjadi in-flight (<50ms) melalui injeksi `CODEX_HOME` per proses tanpa me-restart aplikasi Izanotchy maupun ChatGPT.
- **Privacy & Security**: Token OAuth disimpan secara terisolasi di direktori lokal `~/.izanotchy/credentials/gpt_accounts/` dengan permission `0700`.
- **Target Separation**: Komponen hanya ditambahkan ke target `boringNotch`, jangan pernah dimasukkan ke `BoringNotchXPCHelper`.

---

### Task 1: Chat Card Live Mirroring & Hybrid Precision Grounding (UI Polish)

**Files:**
- Modify: `boringNotch/Clicky/HomeSpace/HomeSpaceComputerCardView.swift`
- Test: `scripts/test_revisions_f10_chat_card_grounding.swift`

**Interfaces:**
- Consumes: `CompanionWindowStreamService.shared.activeSnapshot`
- Produces: `HomeSpaceComputerCardView` dengan live snapshot dan `precisionGroundingOverlay`

- [x] **Step 1: Tulis tes TDD gagal untuk verifikasi live mirroring dan grounding grid di kartu chat**

```swift
// scripts/test_revisions_f10_chat_card_grounding.swift
import Foundation

let cardPath = "boringNotch/Clicky/HomeSpace/HomeSpaceComputerCardView.swift"
guard let content = try? String(contentsOfFile: cardPath, encoding: .utf8) else {
    print("FAIL: Cannot read HomeSpaceComputerCardView.swift")
    exit(1)
}

let hasNoFakeMockup = !content.contains("mockupDesktopCanvas") && !content.contains("scenicNatureWallpaper")
let hasStreamService = content.contains("CompanionWindowStreamService.shared")
let hasGroundingGrid = content.contains("precisionGroundingOverlay") || content.contains("coordinateGrid")
let hasCrosshair = content.contains("crosshair") || content.contains("targetBadge")

if hasNoFakeMockup && hasStreamService && hasGroundingGrid {
    print("PASS: HomeSpaceComputerCardView eliminates fake Sonoma mockup and provides precision grounding overlay")
    exit(0)
} else {
    print("FAIL: Verification failed: hasNoFakeMockup=\(hasNoFakeMockup), hasStreamService=\(hasStreamService), hasGroundingGrid=\(hasGroundingGrid)")
    exit(1)
}
```

- [x] **Step 2: Jalankan tes untuk memastikan gagal**
Run: `swift scripts/test_revisions_f10_chat_card_grounding.swift`
Expected: FAIL (karena `mockupDesktopCanvas` masih ada di `HomeSpaceComputerCardView.swift`).

- [x] **Step 3: Implementasi Live Snapshot & Hybrid Precision Grounder di `HomeSpaceComputerCardView.swift`**
  - Hubungkan `@ObservedObject private var streamService = CompanionWindowStreamService.shared`.
  - Hapus fungsi `mockupDesktopCanvas`, `scenicNatureWallpaper`, `backCRMWindow`, dan `frontOutreachWindow`.
  - Ganti `canvasFrame` agar menampilkan `streamService.activeSnapshot` atau placeholder workspace interaktif yang bersih.
  - Tambahkan `precisionGroundingOverlay`: garis grid halus semi-transparan per 100px, label angka koordinat di sudut, dan target crosshair jika AI sedang menunjuk elemen.

- [x] **Step 4: Jalankan tes untuk memastikan lolos**
Run: `swift scripts/test_revisions_f10_chat_card_grounding.swift`
Expected: PASS (Semua tes hijau).

---

### Task 2: Backend Headless 6 Luna Medium Vision Service

**Files:**
- Create: `boringNotch/Clicky/Vision/ChatGPTCodexVisionService.swift`
- Test: `scripts/test_revisions_f10_codex_vision_service.swift`

**Interfaces:**
- Produces: `public final class ChatGPTCodexVisionService`
  - `func queryCoordinates(imagePath: String, prompt: String, codexHome: String?) async throws -> VisionCoordinateResult`
  - `struct VisionCoordinateResult: Codable { let target: String; let x: Int; let y: Int; let confidence: Double }`

- [x] **Step 1: Tulis tes TDD gagal untuk `ChatGPTCodexVisionService`**

```swift
// scripts/test_revisions_f10_codex_vision_service.swift
import Foundation

let servicePath = "boringNotch/Clicky/Vision/ChatGPTCodexVisionService.swift"
guard let content = try? String(contentsOfFile: servicePath, encoding: .utf8) else {
    print("FAIL: Cannot read ChatGPTCodexVisionService.swift")
    exit(1)
}

let hasCodexPath = content.contains("/Applications/ChatGPT.app/Contents/Resources/codex")
let has6LunaModel = content.contains("gpt-6-luna")
let hasMediumEffort = content.contains("reasoning_effort=medium") || content.contains("medium")
let hasCodexHomeEnv = content.contains("CODEX_HOME")
let hasOutputParser = content.contains("VisionCoordinateResult")

if hasCodexPath && has6LunaModel && hasMediumEffort && hasCodexHomeEnv && hasOutputParser {
    print("PASS: ChatGPTCodexVisionService declared with 6 Luna Medium headless execution and CODEX_HOME support")
    exit(0)
} else {
    print("FAIL: Service missing required declarations")
    exit(1)
}
```

- [x] **Step 2: Jalankan tes untuk memastikan gagal**
Run: `swift scripts/test_revisions_f10_codex_vision_service.swift`
Expected: FAIL (file belum ada).

- [x] **Step 3: Implementasikan `ChatGPTCodexVisionService.swift`**
  - Buat singleton `@MainActor public final class ChatGPTCodexVisionService: ObservableObject`.
  - Eksekusi non-interaktif headless menggunakan `Process()`:
    * Executable: `/Applications/ChatGPT.app/Contents/Resources/codex`
    * Arguments: `["exec", "--ephemeral", "--skip-git-repo-check", "-s", "read-only", "-m", "gpt-6-luna", "-c", "reasoning_effort=medium", "-i", imagePath, "-o", tempOutputFile, "-"]`
    * Injeksi environment `CODEX_HOME` jika disediakan akun kustom.
    * Pipe prompt JSON terstandar via stdin pipe.
  - Parse file output JSON menjadi `VisionCoordinateResult(target: ..., x: ..., y: ..., confidence: ...)`.

- [x] **Step 4: Jalankan tes untuk memastikan lolos**
Run: `swift scripts/test_revisions_f10_codex_vision_service.swift`
Expected: PASS.

---

### Task 3: Multi-Account Session Pool & Hot-Failover Manager (Zero Restart)

**Files:**
- Create: `boringNotch/Clicky/Vision/ChatGPTAccountPoolManager.swift`
- Test: `scripts/test_revisions_f10_account_pool_manager.swift`

**Interfaces:**
- Produces: `public final class ChatGPTAccountPoolManager: ObservableObject`
  - `@Published public private(set) var accounts: [GPTAccount]`
  - `@Published public private(set) var activeAccount: GPTAccount?`
  - `func registerAccount(label: String, authJsonString: String) throws`
  - `func markActiveAccountCooldown(durationSeconds: TimeInterval)`
  - `func getActiveCodexHome() -> String?`

- [x] **Step 1: Tulis tes TDD gagal untuk `ChatGPTAccountPoolManager`**

```swift
// scripts/test_revisions_f10_account_pool_manager.swift
import Foundation

let managerPath = "boringNotch/Clicky/Vision/ChatGPTAccountPoolManager.swift"
guard let content = try? String(contentsOfFile: managerPath, encoding: .utf8) else {
    print("FAIL: Cannot read ChatGPTAccountPoolManager.swift")
    exit(1)
}

let hasAccountStruct = content.contains("struct GPTAccount")
let hasStatusEnum = content.contains("enum GPTAccountStatus") && content.contains("cooldown")
let hasHotFailover = content.contains("switchToNextReadyAccount") || content.contains("markActiveAccountCooldown")
let hasCodexHome = content.contains("credentials/gpt_accounts")

if hasAccountStruct && hasStatusEnum && hasHotFailover && hasCodexHome {
    print("PASS: ChatGPTAccountPoolManager implements multi-account pool and hot failover")
    exit(0)
} else {
    print("FAIL: ChatGPTAccountPoolManager missing required methods")
    exit(1)
}
```

- [x] **Step 2: Jalankan tes untuk memastikan gagal**
Run: `swift scripts/test_revisions_f10_account_pool_manager.swift`
Expected: FAIL.

- [x] **Step 3: Implementasikan `ChatGPTAccountPoolManager.swift`**
  - Buat enum `GPTAccountStatus`: `.active`, `.ready`, `.cooldown(resetAt: Date)`, `.invalid`.
  - Buat struct `GPTAccount`: `id: UUID`, `label: String`, `email: String?`, `homeDirectoryPath: String`, `status: GPTAccountStatus`, `requestCount: Int`, `lastUsed: Date`.
  - Simpan direktori akun di `~/.izanotchy/credentials/gpt_accounts/<account_id>/auth.json`.
  - Otomatis impor akun default dari `~/.codex/auth.json` sebagai Akun 1 saat inisialisasi awal.
  - Implementasikan `switchToNextReadyAccount()`: memilih akun berikutnya yang berstatus `.ready` dalam <50ms.
  - Implementasikan timer latar belakang untuk mengembalikan akun dari `.cooldown` ke `.ready` saat waktu reset tercapai.

- [x] **Step 4: Jalankan tes untuk memastikan lolos**
Run: `swift scripts/test_revisions_f10_account_pool_manager.swift`
Expected: PASS.

---

### Task 4: Dynamic Island Notch AI Tab - ChatGPT Usage & Pool Monitor Widget

**Files:**
- Create: `boringNotch/Clicky/Vision/ChatGPTAccountMonitorWidget.swift`
- Modify: `boringNotch/NotchView/Components/AIPanelView.swift` (atau panel AI Notch terkait)
- Test: `scripts/test_revisions_f10_notch_usage_widget.swift`

**Interfaces:**
- Consumes: `ChatGPTAccountPoolManager.shared`
- Produces: `ChatGPTAccountMonitorWidget: View`

- [x] **Step 1: Tulis tes TDD gagal untuk widget monitor usage di Notch**

```swift
// scripts/test_revisions_f10_notch_usage_widget.swift
import Foundation

let widgetPath = "boringNotch/Clicky/Vision/ChatGPTAccountMonitorWidget.swift"
guard let content = try? String(contentsOfFile: widgetPath, encoding: .utf8) else {
    print("FAIL: Cannot read ChatGPTAccountMonitorWidget.swift")
    exit(1)
}

let hasObservedPool = content.contains("ChatGPTAccountPoolManager.shared")
let hasActivePill = content.contains("activeAccountPill") || content.contains("gpt-6-luna")
let hasAccountList = content.contains("accountRow") || content.contains("cooldown")
let hasAddButton = content.contains("Add Account") || content.contains("tambahAkun")

if hasObservedPool && hasActivePill && hasAccountList {
    print("PASS: ChatGPTAccountMonitorWidget correctly renders pool status in Notch AI")
    exit(0)
} else {
    print("FAIL: ChatGPTAccountMonitorWidget incomplete")
    exit(1)
}
```

- [x] **Step 2: Jalankan tes untuk memastikan gagal**
Run: `swift scripts/test_revisions_f10_notch_usage_widget.swift`
Expected: FAIL.

- [x] **Step 3: Implementasikan `ChatGPTAccountMonitorWidget.swift`**
  - Desain compact pill untuk baris Dynamic Island: `● GPT: Acc 1 (Active) | 2 Ready`.
  - Desain popover detail panel saat di-hover/klik:
    * Menampilkan daftar semua akun ChatGPT yang terdaftar di pool.
    * Indikator warna status: Hijau (Active), Putih/Abu (Ready Standby), Amber (Cooldown dengan countdown timer sisa menit).
    * Tombol interaktif `[ ＋ Add Account ]` yang membuka modal input session token atau impor cepat.
  - Pasang widget ini di tab AI / Notch header.

- [x] **Step 4: Jalankan tes untuk memastikan lolos**
Run: `swift scripts/test_revisions_f10_notch_usage_widget.swift`
Expected: PASS.

---

### Task 5: Registrasi Project, Kompilasi xcodebuild, & Verifikasi Fisik

**Files:**
- Modify: `boringNotch.xcodeproj/project.pbxproj`
- Test: `scripts/test_revisions_f10_all.swift`
- Verification: Physical window capture (`screencapture -l <WindowID>`)

- [x] **Step 1: Daftarkan seluruh file baru ke `boringNotch.xcodeproj`**
  - `ChatGPTCodexVisionService.swift`
  - `ChatGPTAccountPoolManager.swift`
  - `ChatGPTAccountMonitorWidget.swift`
  - Pastikan hanya ditambahkan ke target `boringNotch`, bukan `BoringNotchXPCHelper`.

- [x] **Step 2: Jalankan tes integrasi menyeluruh**
Run: `swift scripts/test_revisions_f10_all.swift`
Expected: 5/5 tests passed (100%).

- [x] **Step 3: Kompilasi dengan `xcodebuild`**
Run: `xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug build`
Expected: `** BUILD SUCCEEDED **` (kode 0).

- [x] **Step 4: Relaunch binary dan verifikasi fisik**
  - Jalankan `./scripts/launch_app.sh` dan catat PID baru.
  - Buka HomeSpace dan tangkap Window ID kartu chat: pastikan gambar mockup Sonoma hilang dan digantikan oleh Live Snapshot + Precision Grounding Grid.
  - Trigger kueri vision headless 6 Luna Medium dan buktikan JSON koordinat diekstrak tanpa membuka jendela aplikasi ChatGPT.
  - Tangkap Window ID Notch untuk membuktikan widget monitor akun ChatGPT aktif.

- [x] **Step 5: Dokumentasi & Laporan**
  - Catat Milestone 191 di `CHANGELOG.md` dan `AGENTS.md`.
  - Update `docs/grok-bot-companion-adoption/09_FEATURE_BY_FEATURE_TRACKER.md`.
  - Laporkan kepada pengguna sesuai format 4 langkah (Backend ➔ Frontend ➔ Cara Ngetest ➔ Lanjut/Revisi).

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-10-02-f10-gpt6-luna-multi-account-pool-vision-vm.md`.

Dua opsi eksekusi yang tersedia:
1. **Subagent-Driven (Recommended)** — Mengeksekusi task satu per satu menggunakan subagent mandiri dengan review dua tahap per task untuk iterasi cepat dan aman.
2. **Inline Execution** — Mengeksekusi langsung task demi task di sesi saat ini secara batch dengan checkpoint verifikasi fisik.
