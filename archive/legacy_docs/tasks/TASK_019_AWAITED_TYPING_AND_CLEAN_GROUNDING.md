# TASK-019: Awaited Typing, Native AX Neighbor Traversal & Dynamic Window Refresh

## 1. Masalah & Gejala Faktual
Pada tugas komposisi email ("tolong kirim email ke rezkyhaikal10@gmail.com bahwa sistem berhasil dibuat"):
1. Field tujuan (To:) dan subjek (Subject:) tidak terisi (kosong).
2. Teks alamat dan pesan terketik campur aduk di area body (isi email):
   `rezkyhaikal10`
   `@gmail.comSystem created successfully`
3. Tombol Send diklik sebelum formulir selesai diisi, Mail menolak pengiriman, dan tugas berakhir gagal.

## 2. Root Cause & Analisis
1. **Race Condition Pengetikan Non-Awaited:**
   - File: [MascotVirtualDesktopService.swift](file:///Users/heizaaa/Desktop/cdev/iza-3/izaNotch/Clicky/Workspace/VirtualDisplay/MascotVirtualDesktopService.swift)
   - `performCuaType` dijalankan di background thread secara fire-and-forget tanpa async/await. Pengetikan 23 karakter membutuhkan ~575ms (25ms per karakter).
2. **Injeksi Return Hardcoded:**
   - File: [CUATypeActionTool.swift](file:///Users/heizaaa/Desktop/cdev/iza-3/izaNotch/Clicky/CUA/Actions/CUATypeActionTool.swift)
   - Tool menunggu jeda statis 350ms lalu mengirim tombol Return (`keyCode: 0x24`) jika teks memuat `@` atau nama target memuat `"to"`. Karena 350ms < 575ms, Return disuntikkan saat pengetikan baru mencapai `rezkyhaikal10`, memecah string email menjadi dua baris dan melanggar Zero Hardcoding Policy.
3. **Hardcoding Kamus String & Offset Buatan di Grounding:**
   - File: [ClickyHybridGroundingEngine.swift](file:///Users/heizaaa/Desktop/cdev/iza-3/izaNotch/Clicky/CUA/Grounding/ClickyHybridGroundingEngine.swift)
   - Grounding input mengandalkan `fieldKeywords` statis serta offset buatan horizontal `+ 50.0pt` pada label `AXStaticText`. Koordinat meleset dari field teks asli.
4. **Stale Window Bounds di Loop:**
   - File: [CompanionVMAgentLoop.swift](file:///Users/heizaaa/Desktop/cdev/iza-3/izaNotch/Clicky/CUA/Loop/CompanionVMAgentLoop.swift)
   - `candidateWindows` hanya dicari sekali di awal sebelum loop dimulai. Saat jendela baru (compose window) muncul, bounds dan judul jendela aktif tidak disegarkan.

## 3. Solusi & Perubahan Implementasi
1. **Awaited Typing:**
   - `performCuaType` diubah menjadi fungsi `async` yang di-await dengan `withCheckedContinuation` hingga seluruh karakter selesai diketik dan snapshot diperbarui.
   - `CUATypeActionTool` meng-await `performCuaType` dan menghapus seluruh injeksi Return berbasis `@`/`"to"`.
2. **Native AX Neighbor Traversal & Semantic Action Type:**
   - Parameter `actionType: String?` diteruskan ke `resolveElementCoordinate` dan `locateViaAXUIElementAsync`.
   - Jika `actionType == "type"`: melewati (bypass) AXToolbar, menolak elemen tombol (`AXButton`, `AXMenuButton`), dan jika menemukan label `AXStaticText`, mencari elemen input tetangga (`AXTextField`, `AXTextArea`, `AXSearchField`, `AXComboBox`) di dalam kontainer yang sama via `kAXParentAttribute` tanpa offset numerik buatan `+ 50pt`.
3. **Dynamic Window Refresh:**
   - `candidateWindows` disegarkan di awal setiap iterasi langkah loop di `CompanionVMAgentLoop.swift` via `findCandidateWindows(appName:)`.
   - Parameter `actionType: decision.actionType` diteruskan ke fungsi grounding fallback.

## 4. Hasil Verifikasi Empiris
1. Skrip pengujian otomatis `scripts/test_task019_form_typing_awaited_and_grounding.swift` lulus 100%.
2. Skrip pengujian regresi `scripts/test_task018_form_grounding_laya_and_react.swift` lulus 100%.
3. Kompilasi bersih dengan `xcodebuild` exit code 0 (`** BUILD SUCCEEDED **`).
4. Biner baru `izaNotch` terverifikasi aktif berjalan (PID 30997) dengan log runtime bersih.
