<h1 align="center">
  <br>
  izaNotch
  <br>
</h1>

<p align="center">
  <strong>Dynamic Notch Utility & AI Companion for macOS</strong>
</p>

<p align="center">
  <a href="https://github.com/iza-aa/izanotch/actions"><img src="https://img.shields.io/badge/build-passing-brightgreen.svg" alt="Build Status"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-blue.svg" alt="License"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey.svg" alt="Platform">
</p>

---

## 🌟 About izaNotch

**izaNotch** turns your MacBook's notch into an intelligent control center and AI companion workspace. Seamlessly blending hardware aesthetics with macOS productivity:

- 🎵 **Dynamic Music Controller:** Real-time visualizer, Now Playing info, and smooth playback controls (Spotify & Apple Music).
- 🤖 **Clicky AI Companion:** On-screen multimodal assistant with procedural animation, contextual suggestions, and Computer Use Agent (CUA).
- 📅 **Integrated Notch Calendar:** View upcoming schedules and events directly from the notch.
- 🗄️ **Shelf & Quick Drop:** Drag and drop files into the notch for quick staging and AirDrop sharing.
- 🎛️ **Native macOS HUD:** Smooth volume, brightness, and keyboard backlight HUD transitions.

---

## 💻 System Requirements

- **macOS:** 14.0 Sonoma or later
- **Architecture:** Apple Silicon (M1/M2/M3/M4) and Intel Macs
- **Permissions:** Accessibility (AX), Screen Recording, Microphone (optional, for speech interaction).

---

## 🛠️ Building from Source

```bash
# Clone the repository
git clone https://github.com/iza-aa/izanotch.git
cd izanotch

# Build Clicky modular package
cd Packages/ClickyKit && swift build && swift test && cd ../..

# Build Xcode project
xcodebuild -project izaNotch.xcodeproj -scheme izaNotch -configuration Debug build
```

---

## 📜 License

izaNotch is licensed under the [GPL-3.0 License](LICENSE).
See [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES) for open-source library attributions.
