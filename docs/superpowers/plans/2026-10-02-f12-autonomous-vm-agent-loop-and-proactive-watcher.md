# Autonomous Mascot VM Dynamic Agent Loop & Proactive Watcher (1:1 Grok Bot) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mengganti total hardcoded action pipeline dengan Autonomous Dynamic Agent Loop (ReAct / Tool Calling) berbasis persona.md dan generic CUA tools, serta membangun Background VM Watcher yang aktif terus-menerus memantau workspace/inbox dan secara proaktif mengabari user saat ada email penting (1:1 Grok Bot).

**Architecture:** 
1. Eliminasi total `MascotEmailActionPipeline.swift` dan interceptor statis di UI.
2. Integrasikan `persona.md` sebagai inviolable sovereign system prompt maskot di VM sandbox.
3. Bangun `CompanionVMAgentLoop.swift` yang membiarkan model AI (6 Luna Medium / Codex headless) berpikir dan memutuskan sendiri langkah GUI (inspect, ground & click, type, read, report) via generic CUA tools.
4. Bangun `CompanionVMBackgroundWatcher.swift` yang berjalan di latar belakang ("on terus"), mendeteksi email penting di workspace VM, mengirim pesan proaktif ke chat, dan menyalakan badge notifikasi maskot di floating rail.

**Tech Stack:** Swift, SwiftUI, AppKit, CUA Driver (56 generic tools), AXUIElement Accessibility APIs, 6 Luna Medium Headless Vision VM (`ChatGPTCodexVisionService`), Companion Workspace Storage (`~/.izanotchy/companions/<slug>/`).

---

## Global Constraints
- DILARANG KERAS membuat file action hardcoded per aplikasi (misal: `MascotEmailActionPipeline`, `SafariActionPipeline`).
- Model AI harus bebas bernalar menentukan langkah-langkahnya sendiri sesuai prompt bebas user.
- Perilaku bot diatur secara kedaulatan penuh oleh `persona.md` dan tidak boleh melenceng dari perannya.
- Evaluasi koordinat wajib memprioritaskan AXUIElement terlebih dahulu (Tier 1) dan hanya fallback ke 6 Luna Vision (Tier 2) jika tidak terdeteksi.
- Verifikasi fisik wajib menggunakan `xcodebuild`, PID check, targeted window capture `screencapture -l <WindowID>`, dan log audit.

---

### Task 1: Eliminasi Total Hardcoded Action Pipeline & Interceptor
**Files:**
- Delete: `boringNotch/Clicky/Tools/MascotEmailActionPipeline.swift`
- Modify: `boringNotch/Clicky/HomeSpace/HomeSpaceRootView.swift`
- Modify: `boringNotch/boringNotchApp.swift`
- Modify: `boringNotch.xcodeproj/project.pbxproj`
- Test: `scripts/test_revisions_f12_task1_no_hardcoded_pipeline.swift`

- [ ] **Step 1: Tulis tes TDD memastikan tidak ada hardcoded pipeline**
- [ ] **Step 2: Jalankan tes untuk memverifikasi kegagalan jika file masih ada**
- [ ] **Step 3: Hapus `MascotEmailActionPipeline.swift` dan hapus referensinya dari `project.pbxproj`**
- [ ] **Step 4: Hapus interceptor `rezkyhaikal2@gmail.com` dan URL handler terkait di `HomeSpaceRootView.swift` dan `boringNotchApp.swift`**
- [ ] **Step 5: Jalankan tes TDD memastikan lulus 100%**

---

### Task 2: Persona Sovereignty & VM Sandboxing Engine
**Files:**
- Modify: `boringNotch/Clicky/CompanionManager.swift`
- Modify: `boringNotch/Clicky/Onboarding/CompanionWorkspaceManager.swift`
- Test: `scripts/test_revisions_f12_task2_persona_sovereignty.swift`

- [ ] **Step 1: Tulis tes TDD verifikasi kedaulatan persona.md dan path sandbox VM**
- [ ] **Step 2: Jalankan tes untuk memverifikasi kondisi awal**
- [ ] **Step 3: Pastikan prompt sistem maskot VM menyematkan `persona.md` secara utuh tanpa kompromi**
- [ ] **Step 4: Jalankan tes TDD memastikan lulus 100%**

---

### Task 3: Autonomous Dynamic Agent Loop (`CompanionVMAgentLoop.swift`)
**Files:**
- Create: `boringNotch/Clicky/Tools/CompanionVMAgentLoop.swift`
- Test: `scripts/test_revisions_f12_task3_vm_agent_loop.swift`

- [ ] **Step 1: Tulis tes TDD untuk generic tools (inspect, click, type, read, report, finish) dan ReAct loop**
- [ ] **Step 2: Jalankan tes untuk memverifikasi file belum ada**
- [ ] **Step 3: Implementasikan `CompanionVMAgentLoop.swift` dengan pemanggilan generic CUA tools dan grounding bertingkat**
- [ ] **Step 4: Jalankan tes TDD memastikan lulus 100%**

---

### Task 4: Continuous Background VM Watcher & Proactive Notifier (1:1 Grok Bot)
**Files:**
- Create: `boringNotch/Clicky/Tools/CompanionVMBackgroundWatcher.swift`
- Modify: `boringNotch/boringNotchApp.swift` (start watcher saat app aktif)
- Test: `scripts/test_revisions_f12_task4_proactive_watcher.swift`

- [ ] **Step 1: Tulis tes TDD untuk background loop, deteksi email penting, dan dispatch notifikasi rail**
- [ ] **Step 2: Jalankan tes untuk memverifikasi kegagalan awal**
- [ ] **Step 3: Implementasikan `CompanionVMBackgroundWatcher.swift` yang memantau workspace/inbox dan mengirim pesan penting ke user**
- [ ] **Step 4: Hubungkan pemanggilan watcher ke lifecycle aplikasi**
- [ ] **Step 5: Jalankan tes TDD memastikan lulus 100%**

---

### Task 5: Master Integration, Compilation, Physical Verification & Documentation
**Files:**
- Modify: `boringNotch.xcodeproj/project.pbxproj`
- Create: `scripts/test_revisions_f12_master_all.swift`
- Modify: `CHANGELOG.md`
- Modify: `AGENTS.md`

- [ ] **Step 1: Daftarkan file baru ke `boringNotch.xcodeproj/project.pbxproj`**
- [ ] **Step 2: Jalankan seluruh suite tes TDD di `scripts/test_revisions_f12_master_all.swift`**
- [ ] **Step 3: Kompilasi aplikasi via `xcodebuild` dan jalankan app binary baru**
- [ ] **Step 4: Uji eksekusi dinamis dan verifikasi log serta visual snapshot**
- [ ] **Step 5: Perbarui `CHANGELOG.md` dan `AGENTS.md`**
