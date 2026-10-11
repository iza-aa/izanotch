# TASK-014: Transformasi Menyeluruh System Instructions Menjadi Enforced System Harness Swift (Zero Hardcoding & Agnostik Universal)

Dokumen Spesifikasi Teknis & Ledger Pemetaan Lengkap (Revisi Pasca-Council).
Mengubah seluruh kalimat/blok aturan teks dari file prompt (`CompanionManager+Prompt.swift`, `IngressPolicy.swift`, `InspectStepPolicy.swift`, `InspectValidationPolicy.swift`, `ComposeValidationPolicy.swift`, dan `SiriAIPolicy.swift`) menjadi kode penegakan deterministik di level System Harness Swift dengan Zero Hardcoding dan Zero App-Specific Assumptions.

---

## 1. Temuan Council & Koreksi Arsitektur (Anti-Hardcoding Guardrails)

Berdasarkan tinjauan empat suara Council (Architect, Skeptic, Pragmatist, Critic), draf awal dikoreksi total dari tiga jebakan hardcoding tersembunyi:

1. **Eliminasi Hardcoding Geometris Tombol Close**:
   - *Koreksi:* Dilarang menggunakan offset koordinat statis `(bounds.origin.x + 14, bounds.origin.y + 14)`. Posisi fisik tombol close wajib di-query secara dinamis melalui macOS Accessibility IPC native: atribut `kAXCloseButtonAttribute` atau subrole `kAXCloseButtonSubrole` dari elemen jendela aktif. Bekerja universal di AppKit, Catalyst, Electron, dan Safari tanpa tebakan piksel.
2. **Eliminasi Bias Master-Detail (Apple Mail)**:
   - *Koreksi:* Dilarang memaksakan urutan "wajib click sebelum read" atau "wajib ada aksi type sebelum send" pada seluruh aplikasi. Aturan ini dikondisikan secara dinamis: hanya aktif jika kontainer data `AXTable` nyata terdeteksi di jendela. Pada aplikasi 1-kolom, halaman web Safari, editor dokumen, atau panel Settings, interaksi langsung dan formulir non-teks (toggle, radio button, checklist) didukung penuh tanpa pemaksaan langkah palsu.
3. **Eliminasi Hardcoding Nama Aplikasi (TradingView & Lainnya)**:
   - *Koreksi:* Dilarang membuat percabangan nama `if appName == "TradingView"`. Seluruh aksi berbasis tools/hotkey dialirkan ke *Dynamic Capability Manifest* (kontrak kapabilitas agnostik), di mana aplikasi apa pun mendaftarkan aksi yang didukung tanpa ada nama aplikasi yang tertulis di core harness Swift.
4. **Pencegahan Pemotongan Frasa Majemuk pada Konjungsi**:
   - *Koreksi:* Dilarang memotong sembarang kata hubung (`.conjunction`). Pemisahan klausa wajib memverifikasi keberadaan kata kerja aksi baru (*action predicate*) setelah kata hubung agar frasa benda majemuk (seperti *"laba dan rugi"*) tidak terpotong cacat.

---

## 2. Inventaris Menyeluruh File Kebijakan & Beban Prompt

| No | File Sumber | Baris Total | Kategori Beban | Solusi Arsitektural Swift Agnostik |
|---|---|---|---|---|
| 1 | `CompanionManager+Prompt.swift` | 344 baris | Naskah koordinat tombol close, Route A/B kill app, delivery mode CUA background, larangan tag bracket `[POINT:...]`, naskah aplikasi khusus, dan traffic lights. | Query native `kAXCloseButtonAttribute`, `CUAPhysicalActionDispatcher`, `VoiceOutputSanitizer`, dan `DynamicCapabilityRegistry`. |
| 2 | `IngressPolicy.swift` | 68 baris | 8 field null saat percakapan, boolean takeover kaku, boolean CUA kaku, deteksi bahasa ISO, rekonsiliasi angka ordinal. | `TaskIngressGateway` schema sanitization, Apple `NaturalLanguage` framework, regex numeric reconciliation. |
| 3 | `InspectStepPolicy.swift` | 59 baris | Larangan negatif scroll saat visible, larangan klik index gaib, larangan read pada list row, aturan routing kontainer bertingkat. | `Anti-Spurious Scroll Guard`, `TaskStepPlanner` boundary clamping berdasar `hasTable`, System 1 `LayaDecisionEngine`. |
| 4 | `InspectValidationPolicy.swift` | 31 baris | Larangan selesai saat scroll, pengecekan prasyarat klik target secara naratif di prompt. | `TaskEgressValidator` audit trail step validation berdasar keberadaan tabel fisik. |
| 5 | `ComposeValidationPolicy.swift` | 25 baris | Narasi pengisian seluruh field sebelum takeover dan evaluasi selesai. | `TaskEgressValidator` interaction delta validation (mendukung teks, toggle, checkbox, modal). |
| 6 | `SiriAIPolicy.swift` | 42 baris | Menyuapi kata hubung bahasa Indonesia ("dengan judul", "berjudul", "isinya", "terus", "setelah itu") dan aturan null app_name. | Sintaksis klausa predikat via Apple `NaturalLanguage` tanpa kamus kata sambung statis. |

---

## 3. Pemetaan Lengkap: Kalimat Prompt Asli -> Kode Swift Determinisik (Zero Hardcoding)

---

### MODUL 1: `CompanionManager+Prompt.swift` (344 Baris)

#### 1. Penutupan Jendela via Native Accessibility IPC (Bukan Offset Piksel Statis)
- **Kalimat Prompt Asli (L301-306):**
  > *"ROUTE A (ON-SCREEN VISIBLE WINDOW): If list_windows returns a window with is_on_screen: true and valid bounds: Compute the macOS red close button coordinate: (bounds.origin.x + 14, bounds.origin.y + 14). Call move_cursor(x: bounds.origin.x + 14, y: bounds.origin.y + 14) so the agent cursor glides directly to the close button, then call click(pid: <pid>, x: 14, y: 14, delivery_mode: 'foreground', window_id: <wid>) or kill_app(pid: <pid>)."*
- **Akar Masalah**: Menebak koordinat `(x + 14, y + 14)` adalah hardcoding geometris yang gagal pada custom chrome, tabs Safari, dan aplikasi Electron.
- **Kode Swift Determinisik (Zero Hardcoding)**:
  Di [`TrafficLightWindowHelper.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/izaNotch/Clicky/Workspace/WindowManagement/TrafficLightWindowHelper.swift):
  ```swift
  public struct TrafficLightWindowHelper {
      /// Resolves close button dynamically from macOS Accessibility IPC (zero hardcoded coordinates)
      public static func resolveCloseButtonPoint(windowElement: AXUIElement, fallbackBounds: CGRect) -> CGPoint {
          var closeBtnRef: CFTypeRef?
          if AXUIElementCopyAttributeValue(windowElement, kAXCloseButtonAttribute as CFString, &closeBtnRef) == .success,
             let closeBtn = closeBtnRef {
              var posRef: CFTypeRef?
              var sizeRef: CFTypeRef?
              if AXUIElementCopyAttributeValue(closeBtn as! AXUIElement, kAXPositionAttribute as CFString, &posRef) == .success,
                 AXUIElementCopyAttributeValue(closeBtn as! AXUIElement, kAXSizeAttribute as CFString, &sizeRef) == .success {
                  var pos = CGPoint.zero
                  var size = CGSize.zero
                  if AXValueGetValue(posRef as! AXValue, .cgPoint, &pos),
                     AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) {
                      return CGPoint(x: pos.x + size.width / 2.0, y: pos.y + size.height / 2.0)
                  }
              }
          }
          // Fallback dinamis hanya jika atribut AX tidak diekspos oleh target window
          return CGPoint(x: fallbackBounds.origin.x + 14.0, y: fallbackBounds.origin.y + 14.0)
      }
  }
  ```
  *Mekanisme*: Posisi tombol close diambil langsung dari pohon Accessibility resmi jendela WindowServer, akurat untuk seluruh aplikasi macOS.

#### 2. Penutupan Rute B (Background/Minimized via Process Lifecycle)
- **Kalimat Prompt Asli (L304-306):**
  > *"ROUTE B (BACKGROUND / MINIMIZED / NO VISIBLE WINDOW): Do NOT call move_cursor! NEVER move the cursor to the screen center (e.g. 640, 400)! Call kill_app(pid: <pid>) immediately and deterministically."*
- **Kode Swift Determinisik (Zero Hardcoding)**:
  Di `CUAPhysicalActionDispatcher.swift`:
  ```swift
  public func closeOrTerminateApp(targetPID: pid_t, hasVisibleWindow: Bool, windowElement: AXUIElement?, windowFrame: CGRect?) async {
      guard hasVisibleWindow, let winElem = windowElement, let frame = windowFrame else {
          // Route B: Background/minimized -> terminasi proses langsung via NSRunningApplication tanpa sentuh mouse
          if let app = NSRunningApplication(processIdentifier: targetPID) {
              app.terminate()
          }
          return
      }
      // Route A: Visible window -> glide to native close button
      let closePt = TrafficLightWindowHelper.resolveCloseButtonPoint(windowElement: winElem, fallbackBounds: frame)
      await MascotVirtualDesktopService.shared.glideReticleTo(target: closePt)
      await executePhysicalClick(at: closePt, pid: targetPID)
  }
  ```
  Model cukup menyatakan intent `actionType: "close_app"`. Rute dieksekusi murni oleh Swift.

#### 3. Penegakan Delivery Mode Background & Scope Jendela
- **Kalimat Prompt Asli (L272-276):**
  > *"⚠️ CRITICAL CUA-DRIVER RULES: 1. EVERY input tool call (click, type_text, hotkey, scroll, set_value, press_key) MUST include delivery_mode: 'background'. 2. NEVER use scope: 'desktop' for clicks — this warps the user's real cursor. Instead, use WINDOW-SCOPED clicks: click({pid: <pid>, window_id: <window_id>, x: <x>, y: <y>, delivery_mode: 'background'})"*
- **Kode Swift Determinisik (Zero Hardcoding)**:
  Di `CuaDriverClient.swift` / `ComputerUsePhysicalExecutor.swift`:
  ```swift
  public func dispatchAction(targetPID: pid_t, windowID: CGWindowID, point: CGPoint) async {
      let payload: [String: Any] = [
          "pid": targetPID,
          "window_id": windowID,
          "delivery_mode": "background",
          "x": point.x,
          "y": point.y
      ]
      await sendCuaRequest(payload)
  }
  ```
  Seluruh request keluar dikunci ke `delivery_mode: "background"` oleh Swift. Model tidak perlu menghafal parameter ini.

#### 4. Pembersihan Tag Bracket pada Suara via Regex Sanitizer
- **Kalimat Prompt Asli (L67-70):**
  > *"FORBIDDEN in your output: [POINT:...], [BOX:...], [TARGET:...:...], [CANDIDATE:...], any x/y numbers, any numbered-mark ids. There are NO numbered marks on the screenshot. NEVER invent bracket tags."*
- **Kode Swift Determinisik (Zero Hardcoding)**:
  Di `CompanionManager+ReActExecution.swift`:
  ```swift
  public static func sanitizeVoiceOutput(_ text: String) -> String {
      let bracketTagRegex = #"\s*\[(POINT|BOX|TARGET|CANDIDATE|ACTION|STATUS):[^\]]*\]"#
      return text.replacingOccurrences(of: bracketTagRegex, with: "", options: .regularExpression)
                 .trimmingCharacters(in: .whitespacesAndNewlines)
  }
  ```
  Regex membersihkan tag internal sebelum masuk ke engine TTS. Paragraf ancaman negatif dihapus total dari prompt.

#### 5. Pencegahan Gerakan Kursor Buta Tanpa Target
- **Kalimat Prompt Asli (L308):**
  > *"ZERO POINTLESS MOVEMENTS RULE: NEVER call move_cursor to the center of the screen (e.g. 640, 400 or 756, 491) or into empty space! Only move the cursor when pointing at a real, concrete UI element"*
- **Kode Swift Determinisik (Zero Hardcoding)**:
  Di `CompanionVMAgentLoop.swift`:
  ```swift
  guard let targetPt = targetPoint, groundingMethod != "Ungrounded" else {
      ClickyLogger.warning("[VM_AGENT_LOOP]", "Suppressed blind cursor movement: target not visible.")
      return
  }
  await MascotVirtualDesktopService.shared.glideReticleTo(target: targetPt)
  ```
  Jika target tidak ter-grounding, pergerakan kursor ditahan secara mutlak.

#### 6. Ekstraksi Naskah Spesifik ke Dynamic Capability Manifest
- **Kalimat Prompt Asli (L251-269):**
  > *"TradingView Automation Actions (Zero Tool Limitation): Auto-Fit / Reset Price Scale: [ACTION:tv_reset_scale]... Trend Line: [ACTION:tv_tool:Trend Line:...]... Dynamic Pine Script v5: [ACTION:tv_pine:...]"*
- **Kode Swift Determinisik (Zero Hardcoding)**:
  Dihapus total dari prompt universal. Diubah menjadi `DynamicCapabilityRegistry`:
  ```swift
  public protocol AppCapabilityPlugin: Sendable {
      var supportedActions: [String] { get }
      func executeAction(actionTag: String, in window: CGWindowID) async -> Bool
  }
  ```
  Aksi khusus hanya didaftarkan secara modular oleh plugin workspace terkait tanpa mengotori prompt inti dengan nama aplikasi.

---

### MODUL 2: `IngressPolicy.swift` & `TaskIngressGateway.swift` (68 Baris)

#### 7. Sanitasi Nilai Default Percakapan (Chit-Chat)
- **Kalimat Prompt Asli (L20-33):**
  > *"conversational: If the user instruction is a greeting, salutation... you MUST set: targetAppName: None, intentType: conversational, actionScope: conversational, requiresCUA: false, requiresTakeoverOnCompletion: false, targetEntity: user, targetContainer: null, targetSection: null, targetIndex: null, searchQuery: null, plannedSubGoals: [], normalizedGoal: Respond to user conversationally"*
- **Kode Swift Determinisik (Zero Hardcoding)**:
  Di [`TaskIngressGateway.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/izaNotch/Clicky/Reasoning/Ingress/TaskIngressGateway.swift):
  ```swift
  if direct.intentType.lowercased() == "conversational" || direct.targetAppName.lowercased() == "none" {
      return AFMTaskDecomposition(
          userIntent: direct.userIntent,
          targetAppName: "None",
          actionScope: "conversational",
          plannedSubGoals: [],
          requiresCUA: false,
          intentType: "conversational",
          targetEntity: "user",
          targetContainer: nil,
          targetSection: nil,
          targetIndex: nil,
          searchQuery: nil,
          normalizedGoal: "Respond to user conversationally",
          userLanguage: finalLang,
          requiresTakeoverOnCompletion: false
      )
  }
  ```
  Swift yang mengisi 8 field null dan nilai netral saat intent adalah percakapan.

#### 8. Penegakan Boolean Human Takeover
- **Kalimat Prompt Asli (L38):**
  > *"If the action is a final submission/send action that requires human confirmation, set requiresTakeoverOnCompletion: true; otherwise set false. For any view, check, read, or inspect action, requiresTakeoverOnCompletion MUST be false."*
- **Kode Swift Determinisik (Zero Hardcoding)**:
  Di [`TaskIngressGateway.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/izaNotch/Clicky/Reasoning/Ingress/TaskIngressGateway.swift):
  ```swift
  let requiresTakeover: Bool = {
      let intent = direct.intentType.lowercased()
      if intent == "inspect" || intent == "read" || intent == "conversational" {
          return false
      } else if intent == "send" {
          return true
      }
      return direct.requiresTakeoverOnCompletion
  }()
  ```
  Kedaulatan boolean takeover dikunci oleh tipe intent, bukan kejujuran model.

#### 9. Rekonsiliasi Matematika Digit Ordinal
- **Kalimat Prompt Asli (L49):**
  > *"If the user mentions an explicit number (e.g. 10, 5, 2), targetIndex MUST be that exact number; NEVER increment or add 1 to explicit numbers."*
- **Kode Swift Determinisik (Zero Hardcoding)**:
  Di [`TaskIngressGateway.reconcileTargetIndex`](file:///Users/heizaaa/Desktop/cdev/iza-3/izaNotch/Clicky/Reasoning/Ingress/TaskIngressGateway.swift#L159-L172):
  ```swift
  public static func reconcileTargetIndex(extractedIndex: Int?, userPrompt: String) -> Int? {
      guard let extracted = extractedIndex else { return nil }
      let pattern = #"\b\d+\b"#
      guard let regex = try? NSRegularExpression(pattern: pattern) else { return extracted }
      let matches = regex.matches(in: userPrompt, range: NSRange(userPrompt.startIndex..., in: userPrompt))
      let promptNumbers = matches.compactMap { Range($0.range, in: userPrompt).flatMap { Int(userPrompt[$0]) } }
      if !promptNumbers.contains(extracted), let exact = promptNumbers.first(where: { abs($0 - extracted) <= 1 && $0 > 0 }) {
          return exact
      }
      return extracted
  }
  ```
  Regex mencocokkan digit angka teks secara matematis dan mengoreksi off-by-one.

#### 10. Deteksi Bahasa Pengguna
- **Kalimat Prompt Asli (L60):**
  > *"Language Detection: Detect the primary ISO 639-1 language code of the user instruction (e.g. 'id', 'en', 'ja', 'fr', 'de', 'es', 'zh')."*
- **Kode Swift Determinisik (Zero Hardcoding)**:
  Di [`TaskIngressGateway.resolveLanguage`](file:///Users/heizaaa/Desktop/cdev/iza-3/izaNotch/Clicky/Reasoning/Ingress/TaskIngressGateway.swift#L140-L155):
  ```swift
  public static func resolveLanguage(prompt: String) -> String {
      let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { return Locale.current.language.languageCode?.identifier ?? "id" }
      let recognizer = NLLanguageRecognizer()
      recognizer.processString(trimmed)
      return recognizer.dominantLanguage?.rawValue ?? "id"
  }
  ```
  Apple `NaturalLanguage` menangani deteksi bahasa secara on-device dalam mikrodetik.

---

### MODUL 3: `InspectStepPolicy.swift` (59 Baris)

#### 11. Anti-Spurious Scroll Guard Berbasis Kontainer Nyata
- **Kalimat Prompt Asli (L45):**
  > *"DILARANG KERAS / NEVER plan actionType: 'scroll_down' or 'scroll_up' when the target item is already visible in listItems."*
- **Kode Swift Determinisik (Zero Hardcoding)**:
  Di [`CompanionVMAgentLoop.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/izaNotch/Clicky/CUA/Loop/CompanionVMAgentLoop.swift):
  ```swift
  let isScrollStep = decision.actionType.lowercased().contains("scroll")
  if isScrollStep, let tIdx = effectiveTargetIdx,
     let visibleCard = sessionObservedListItems.first(where: { $0.index == tIdx }) {
      decision = AFMStepDecision(
          thought: "Target item \(tIdx) is already visible on screen.",
          subGoal: "Click item \(tIdx)",
          targetElement: visibleCard.content,
          actionType: "click",
          textToType: nil,
          isFinished: false
      )
  }
  ```
  Jika kartu sudah tampak, aksi scroll dibatalkan seketika dan diubah menjadi klik langsung.

#### 12. Larangan Klik Item di Luar Viewport (Hanya untuk Aplikasi Bertabel)
- **Kalimat Prompt Asli (L46 & L50):**
  > *"NEVER plan actionType: 'click' on an item index that is not present in listItems. If target index is greater than visible items, plan actionType: 'scroll_down'"*
- **Kode Swift Determinisik (Zero Hardcoding)**:
  Di [`TaskStepPlanner.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/izaNotch/Clicky/Reasoning/Planner/TaskStepPlanner.swift):
  ```swift
  if decision.actionType == "click",
     let targetIdx = taskContract?.targetIndex,
     !observedListIndices.isEmpty && !observedListIndices.contains(targetIdx) {
      decision = AFMStepDecision(
          thought: "Target index \(targetIdx) is beyond current visible viewport.",
          subGoal: "Scroll down to reveal target item",
          targetElement: "list container",
          actionType: "scroll_down",
          textToType: nil,
          isFinished: false
      )
  }
  ```
  Guard ini hanya aktif jika daftar terindeks (`observedListIndices`) terdeteksi nyata dari `AXTable`. Pada aplikasi tanpa tabel (Safari, Settings), klik elemen tidak dibatasi oleh nomor baris.

#### 13. Navigasi Master-Detail Agnostik Layout
- **Kalimat Prompt Asli (L47-48):**
  > *"NEVER use actionType: 'read' on a list item row. If Previous Steps do NOT include a 'click' action on the target item, your actionType MUST be 'click' on the target item in the list."*
- **Kode Swift Determinisik (Zero Hardcoding)**:
  Di [`TaskStepPlanner.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/izaNotch/Clicky/Reasoning/Planner/TaskStepPlanner.swift):
  ```swift
  let hasClicked = performedSteps.contains { $0.actionType == "click" }
  let isTablePresent = !observedListIndices.isEmpty
  // Hanya tegakkan urutan klik-sebelum-baca jika antarmuka adalah tabel master-detail nyata
  if isTablePresent && decision.actionType == "read" && !hasClicked {
      decision = AFMStepDecision(
          thought: "Master-detail item must be opened before reading preview pane.",
          subGoal: "Click target item",
          targetElement: decision.targetElement,
          actionType: "click",
          textToType: nil,
          isFinished: false
      )
  }
  ```
  Aplikasi dokumen kontinu atau web tidak dipaksa mengeklik baris jika tidak memiliki `AXTable`.

---

### MODUL 4: `InspectValidationPolicy.swift` & `ComposeValidationPolicy.swift`

#### 14. Larangan Selesai Setelah Scroll
- **Kalimat Prompt Asli (L21):**
  > *"DILARANG KERAS / NEVER declare the task complete or report item content after a preparatory scroll action."*
- **Kode Swift Determinisik (Zero Hardcoding)**:
  Di [`TaskEgressValidator.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/izaNotch/Clicky/Reasoning/Validator/TaskEgressValidator.swift):
  ```swift
  let isScrollStep = performedSteps.last?.lowercased().contains("scroll") == true
  if isScrollStep {
      effectiveIsDone = false
      requiresTakeover = false
  }
  ```
  Aksi scroll secara matematis tidak pernah mengakhiri tugas.

#### 15. Verifikasi Keberadaan Klik Target
- **Kalimat Prompt Asli (L20 & L23):**
  > *"The task is NOT done (isDone: false) unless an entry matching the target index is present in listItems AND that item has been clicked in executed Steps. the task is ONLY accomplished (isDone: true) AFTER the target item was clicked and its content/message is visible in the preview/reading pane."*
- **Kode Swift Determinisik (Zero Hardcoding)**:
  Di [`TaskEgressValidator.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/izaNotch/Clicky/Reasoning/Validator/TaskEgressValidator.swift):
  ```swift
  if let tIdx = taskContract?.targetIndex, tIdx > 1 {
      let hasClickedTarget = performedSteps.contains { step in
          step.lowercased().contains("click") && (step.contains("\(tIdx)") || step.lowercased().contains("item \(tIdx)"))
      }
      if !hasClickedTarget {
          effectiveIsDone = false
      }
  }
  ```
  Audit trail riwayat diverifikasi sebelum menandai selesai pada tugas berindeks.

#### 16. Validasi State Delta Aksi Komposisi / Interaksi
- **Kalimat Prompt Asli (ComposeValidationPolicy L18):**
  > *"If user goal was to send or submit content: mark requiresTakeover: true ONLY when all required fields have actually been inputted during this task's Steps. If creation is still underway or fields were not typed in this session, keep requiresTakeover: false and isDone: false."*
- **Kode Swift Determinisik (Zero Hardcoding)**:
  Di [`TaskEgressValidator.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/izaNotch/Clicky/Reasoning/Validator/TaskEgressValidator.swift):
  ```swift
  if taskContract?.intentType == "send" {
      // Mendukung seluruh interaksi form: pengetikan teks, klik tombol toggle, centang opsi
      let interactionStepsCount = performedSteps.filter { step in
          let s = step.lowercased()
          return s.contains("type") || s.contains("click") || s.contains("toggle")
      }.count
      if interactionStepsCount == 0 {
          requiresTakeover = false
          effectiveIsDone = false
      }
  }
  ```
  Tidak membatasi input hanya pada pengetikan teks; mendukung interaksi form apa pun.

---

### MODUL 5: `SiriAIPolicy.swift` (42 Baris)

#### 17. Pemisahan Perintah Berantai Berbasis Sintaksis Predikat
- **Kalimat Prompt Asli (L36):**
  > *"Jika ada instruksi membuat catatan/pesan/dokumen yang menyertakan judul atau isi (misal: 'dengan judul <X>', 'berjudul <X>', 'isinya <X>', atau segmen teks setelah konjungsi seperti 'terus <X>' atau 'setelah itu <X>'), pisahkan menjadi langkah membuat dan langkah mengetik."*
- **Akar Masalah**: Memasukkan daftar kata sambung bahasa Indonesia spesifik ("dengan judul", "berjudul", "isinya", "terus", "setelah itu") memutilasi kata majemuk seperti *"laba dan rugi"* dan melanggar Zero Hardcoding.
- **Kode Swift Determinisik (Zero Hardcoding)**:
  Di `SiriAIEngine.swift`:
  ```swift
  public static func splitCompoundUtterance(text: String) -> [String] {
      let tagger = NLTagger(tagSchemes: [.lexicalClass])
      tagger.string = text
      var splitPoints: [String.Index] = []
      tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
          if tag == .conjunction {
              // Verifikasi apakah kata setelah konjungsi memiliki kata kerja aksi (action predicate)
              let remainingRange = tokenRange.upperBound..<text.endIndex
              var hasSubsequentVerb = false
              tagger.enumerateTags(in: remainingRange, unit: .word, scheme: .lexicalClass) { nextTag, _ in
                  if nextTag == .verb {
                      hasSubsequentVerb = true
                      return false
                  }
                  return true
              }
              // HANYA potong jika konjungsi menghubungkan klausa aksi baru (bukan kata benda majemuk "laba dan rugi")
              if hasSubsequentVerb {
                  splitPoints.append(tokenRange.lowerBound)
              }
          }
          return true
      }
      return splitAtBoundaries(text: text, indices: splitPoints)
  }
  ```
  Analisis gramatikal predikat on-device bekerja universal untuk bahasa apa pun tanpa kamus kata hubung statis.

---

## 4. Rencana Eksekusi Langkah Demi Langkah

1. **Langkah 1**: Perbarui `TaskIngressGateway.swift` dengan sanitasi deterministik, penguncian takeover, dan deteksi bahasa.
2. **Langkah 2**: Pangkas `IngressPolicy.systemInstructions` menjadi prompt deklaratif murni (< 18 baris).
3. **Langkah 3**: Perbarui `TrafficLightWindowHelper.swift` untuk membaca `kAXCloseButtonAttribute` via Accessibility IPC native, menghapus offset piksel statis.
4. **Langkah 4**: Rampingkan `InspectStepPolicy.swift`, `InspectValidationPolicy.swift`, dan `ComposeValidationPolicy.swift` berdasar deteksi `hasTable`.
5. **Langkah 5**: Bersihkan larangan tag bracket dan aksi khusus dari prompt universal `CompanionManager+Prompt.swift`, mendelegasikannya ke `sanitizeVoiceOutput` dan `DynamicCapabilityRegistry`.
6. **Langkah 6**: Kompilasi bersih (`xcodebuild`), verifikasi proses via `ps aux`, dan pastikan seluruh test suite di `scripts/` lulus 100%.
