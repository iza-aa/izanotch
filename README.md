# izaNotch — Local-First AI Desktop Companion & Computer-Use Agent for macOS

![macOS](https://img.shields.io/badge/macOS-14%20%7C%2015%20Sequoia-black?style=flat-square&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.10%20%7C%206-orange?style=flat-square&logo=swift)
![Tauri 2](https://img.shields.io/badge/Tauri-2.12-blue?style=flat-square&logo=tauri)
![Rust](https://img.shields.io/badge/Rust-1.90%20(2024%20Ed.)-black?style=flat-square&logo=rust)
![React 19](https://img.shields.io/badge/React-19.3-blue?style=flat-square&logo=react)
![MCP](https://img.shields.io/badge/Protocol-Model%20Context%20Protocol%20(MCP)-blueviolet?style=flat-square)
![License](https://img.shields.io/badge/License-GPLv3-blue?style=flat-square)

**izaNotch** is an autonomous, local-first AI desktop companion for macOS engineered around native MacBook display notch geometries, system accessibility APIs, and an Anthropic Model Context Protocol (MCP) bridge. It orchestrates a ReAct agent loop connecting multimodal perception and virtual desktop sandboxes across **49,000+ lines of Swift and a Tauri 2 / Rust native shell**.

---

## 🏛️ System Architecture Topology

```
+-----------------------------------------------------------------------------------+
|                        Tauri 2 / React 19 Frontend Window                         |
|                   (Floating Notch Canvas & Companion Interface)                   |
+-----------------------------------------------------------------------------------+
           |                                                    ^
           | IPC / Model Context Protocol                       | Window State & Events
           v                                                    |
+-----------------------------------+        +------------------------------------+
| izabot MCP Bridge (Node/TS SDK)   | <----> | Native macOS Swift XPC Service     |
| (Perception & CUA Tool Routing)   |        | (Notch Geometry, MediaRemote, AX)  |
+-----------------------------------+        +------------------------------------+
           |
           v
+-----------------------------------+
| Multi-Layer Prompt Injection      |
| Defense Engine & Untrusted Tagging|
+-----------------------------------+
```

---

## 🌟 Core Capabilities & Engineering Guardrails

### 1. Hardware Notch & Display Topology Awareness
- Dedicated background Swift XPC daemon (`izaNotchXPCHelper`) tracking physical camera notch boundaries on Retina displays and external displays.
- Fluid window anchoring adapting dynamically to multi-monitor setups without obscuring active application menus.

### 2. Standardized Model Context Protocol (MCP) Bridge
- Standalone bridge (`packages/mcp-bridge`) implementing Anthropic's Model Context Protocol SDK.
- Exposes high-level screen observation, active window perception, and controlled interaction primitives directly to agent reasoning engines.

### 3. Multi-Layer Prompt Injection Defense
- **Untrusted Perception Tagging:** Content extracted from third-party application windows via OCR or Accessibility APIs is strictly tagged as untrusted data before entering agent reasoning contexts.
- Prevents malicious websites or documents from hijacking agent execution loops through prompt injection attacks.

### 4. Zero-Hardcoding Dynamic Window Discovery
- Strict policy against static PID, WindowID, or application title hardcoding (`ARCHITECTURE.md`).
- Interacts with system targets through dynamic accessibility hierarchy inspection and semantic element resolution.

### 5. Native Apple Keychain BYOK Security
- `KeychainManager` in Swift securely stores user LLM credentials (Anthropic, OpenAI, Gemini) directly within the encrypted macOS system keychain, preventing plain-text key exposure on disk.

---

## 📂 Project Structure

```
izanotch/
├── apps/
│   └── desktop/                # Tauri 2 frontend shell (React 19, Vite, Rust src-tauri)
├── packages/
│   └── mcp-bridge/             # Model Context Protocol TypeScript SDK server & tests
├── izaNotchXPCHelper/          # Native macOS Swift XPC background helper process
├── mediaremote-adapter/        # macOS MediaRemote system media controls
├── docs/                       # Architecture specs, smoke tests, and design guidelines
├── .github/workflows/          # CI/CD pipelines (macOS-15 runner, Xcode build & tests)
├── ARCHITECTURE.md             # Canonical single-source-of-truth system spec
└── LICENSE                     # GPLv3 License
```

---

## 🚀 Getting Started

### Prerequisites
- macOS 14+ (Sonoma) or macOS 15+ (Sequoia)
- Xcode 15+ & Swift 5.10+
- Rust 1.80+ (`cargo`)
- Node.js `>= 20.x` & `pnpm`

### Installation & Run

1. Clone the repository:
   ```bash
   git clone https://github.com/iza-aa/izanotch.git
   cd izanotch
   ```

2. Build the MCP bridge:
   ```bash
   cd packages/mcp-bridge
   npm install
   npm run build
   npm test
   cd ../..
   ```

3. Launch the desktop application:
   ```bash
   cd apps/desktop
   npm install
   npm run tauri dev
   ```

---

## 📄 License

This project is licensed under the [GNU General Public License v3.0](LICENSE).
