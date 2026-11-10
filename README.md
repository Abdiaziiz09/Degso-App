<div align="center">

# ⚡ Degso: All-In-One High Performance Media Downloader

<p align="center">
  <b>A lightweight, ultra-fast, on-device media engine built with Flutter. Download high-definition videos with sound directly into your device Gallery without requiring third-party backends or server compute.</b>
</p>

[![Flutter](https://img.shields.io/badge/Flutter-3.47.5-02569B?logo=flutter&logoColor=white&style=for-the-badge)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13+-0175C2?logo=dart&logoColor=white&style=for-the-badge)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-3DDC84?logo=android&logoColor=white&style=for-the-badge)](https://android.com)
[![License](https://img.shields.io/badge/License-MIT-F7DF1E?style=for-the-badge)](LICENSE)
[![Architecture](https://img.shields.io/badge/Architecture-ARM64--v8a%20Optimized-critical?style=for-the-badge)](#building--releases)

<br/>

[Key Features](#-key-features) • [How Extraction Works](#-how-it-works-under-the-hood) • [Supported Platforms](#-platform-support-matrix) • [Installation & Build](#-installation--build) • [Architecture](#-project-architecture) • [Disclaimer](#-disclaimer)

</div>

---

> [!IMPORTANT]
> **Zero External Servers Needed**: All parsing, network routing, and media extraction run directly on your smartphone. Degso does not send your download history, URLs, or personal data to any middleman server.

---

## 🌟 Key Features

- **🚀 5 Major Platforms Supported**: YouTube, TikTok (No-Watermark), Facebook (Reels & Videos), Pinterest (Pins & Videos), and X / Twitter.
- **🎧 Audio + Video Synchronized**: Downloads full pre-muxed MP4 streams with crisp, high-bitrate audio included.
- **🛡️ Intelligent Login-Wall Bypass**: Transparently bypasses authentication paywalls and login redirects on public posts using protocol-level reverse-engineered crawler identities.
- **📱 Direct Gallery Export**: Automatically saves and registers completed downloads to your device's native Gallery / Camera Roll inside a dedicated `Degso` album (via `gal`).
- **🎛️ Multi-Quality Selection**: Choose between 720p HD, 480p SD, 360p, or standalone audio streams where available.
- **🌙 Adaptive Theme Engine**: Fully responsive dark, light, and OLED true-black AMOLED system modes.
- **⚡ Super Lightweight APK**: Built with native ABI split architecture (`app-arm64-v8a-release.apk` is under **19.5 MB**).

---

## 🔬 How It Works (Under The Hood)

Degso operates as a direct on-device stream extractor. Here is how each platform engine is designed to retrieve media without browser overhead or server dependencies:

```
┌────────────────────────────────────────────────────────┐
│                   Input Media URL                      │
└──────────────────────────┬─────────────────────────────┘
                           │
       ┌───────────────────┼────────────────────┐
       ▼                   ▼                    ▼
 ┌───────────┐       ┌───────────┐        ┌───────────┐
 │ YouTube   │       │ Facebook  │        │ Pinterest │ ... [TikTok, X]
 └─────┬─────┘       └─────┬─────┘        └─────┬─────┘
       │                   │                    │
  Manifest Client     Crawler Bypass       Redirect Flow
  (Muxed Streams)     (externalhit UA)    + expMp4 JSON
       │                   │                    │
       └───────────────────┼────────────────────┘
                           │
                           ▼
              ┌──────────────────────────┐
              │ Stream Selection Sheet   │
              └────────────┬─────────────┘
                           │ Direct Chunked I/O Download
                           ▼
              ┌──────────────────────────┐
              │ Native Gallery (Gal/I/O) │
              └──────────────────────────┘
```

### 1. 📘 Facebook: Login-Wall Bypass & SSR Stream Scraping
* **The Challenge**: Meta actively blocks standard browser `User-Agents` with HTTP 400/302 redirects to force mobile users to the login screen.
* **Degso's Solution**: When fetching Facebook links, Degso impersonates Meta's internal OpenGraph scraper identity:
  ```http
  User-Agent: facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)
  ```
  This forces Facebook's servers to respond with raw Server-Side Rendered (SSR) HTML. Degso then traverses the payload to extract:
  - `browser_native_hd_url` / `hd_src`: 1080p/720p high-definition progressive MP4.
  - `browser_native_sd_url` / `sd_src`: Fast, bandwidth-efficient standard-definition MP4.
  - Clean `og:title` and metadata free from login prompts.

---

### 2. 📌 Pinterest: Multi-Hop Redirects & Direct `expMp4` Extraction
* **The Challenge**: Pinterest uses shortened `pin.it` domains and renders client-side using a complex React SPA without embedding raw `<video>` tags in typical HTML elements.
* **Degso's Solution**:
  1. Follows recursive HTTP `302/301` location redirects to resolve `https://pin.it/XXXXXX` down to its canonical `https://www.pinterest.com/pin/ID/`.
  2. Inspects the hydrated JSON state (`__PWS_DATA__` & video descriptor trees).
  3. Extracts pristine non-HLS direct MP4 mirrors matching the `expMp4` pattern:
     ```text
     https://v1.pinimg.com/videos/iht/expMp4/xx/xx/xx/<hash>_720w.mp4
     ```
  4. Filters out viewport metadata to extract authentic post titles and high-resolution pin covers.

---

### 3. 🐦 X (Twitter): High-Speed Edge Manifest Resolution
* **The Challenge**: X/Twitter discontinued standard guest tokens and locked public API endpoints behind strict paywalls.
* **Degso's Solution**:
  - Automatically parses the status snowflake ID (`/status/<id>`).
  - Queries high-speed edge mirrors (`api.fxtwitter.com`) with structured JSON response payloads.
  - Inspects `media_extended` variants, sorts all streams in descending order by bitrate, and presents each video stream tagged with its real kbps bitrate.

---

### 4. 🔴 YouTube: Native Dash & Muxed Manifests
* **The Challenge**: YouTube splits high-resolution video and audio into separate streams (DASH), requiring heavyweight FFmpeg merging on mobile devices.
* **Degso's Solution**:
  - Leverages `youtube_explode_dart` to query Google's innertube endpoints directly.
  - Filters strictly for **muxed streams** (`manifest.muxed`) where video and stereo audio are already pre-muxed at Google's edge CDNs (up to 720p HD).
  - Eliminates the need for local FFmpeg merging, saving battery, CPU cycles, and keeping APK size minuscule.
  - Provides a fallback CORS-compliant oEmbed path for web client targets.

---

### 5. 🎵 TikTok: Lossless Watermark Stripper
* **The Challenge**: Default TikTok shares embed intrusive animated logos and user ID watermarks.
* **Degso's Solution**:
  - Queries dual-redundancy REST endpoints (TikWM + Tiklydown fallback).
  - Offers dual tabs: **No Watermark** (lossless direct source stream) and **With Watermark** (original broadcast stream).
  - Fetches original background audio as a separate sound option.

---

## 📊 Platform Support Matrix

| Platform | URL Formats | Resolutions Available | Audio Included? | No Login Needed? |
|:---|:---|:---:|:---:|:---:|
| **YouTube** | `youtube.com/watch`, `youtu.be/`, `/shorts/` | 720p HD, 480p, 360p | ✅ Yes | ✅ Yes |
| **TikTok** | `tiktok.com/@user/video/`, `vm.tiktok.com/` | Original HD (Clean / Logo) | ✅ Yes | ✅ Yes |
| **Facebook** | `facebook.com/reel/`, `fb.watch/`, `/videos/` | HD (720p/1080p), SD | ✅ Yes | ✅ Yes |
| **Pinterest** | `pinterest.com/pin/`, `pin.it/` | 720p MP4 | ✅ Yes | ✅ Yes |
| **X / Twitter** | `x.com/user/status/`, `twitter.com/` | Multi-Bitrate (High/Mid/Low) | ✅ Yes | ✅ Yes |

---

## 🚀 Installation & Build

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`v3.24+` or newer)
- Android SDK with JDK 17
- Git

### 1. Clone & Fetch Dependencies
```bash
git clone https://github.com/Abdiaziiz09/Degso-App.git
cd Degso-App
flutter pub get
```

### 2. Run Locally in Development
```bash
# Check connected devices
flutter devices

# Run on your connected phone or emulator
flutter run
```

### 3. Build Optimized Production APK (Recommended)
Degso is optimized for ABI splitting. Instead of compiling a bloated universal APK (~60 MB), compile targeted binaries:

```bash
flutter build apk --release --split-per-abi
```

The resulting binaries will be saved in `build/app/outputs/flutter-apk/`:
* 📱 **`app-arm64-v8a-release.apk`** (**19.5 MB**) — **Recommended for all modern phones (2017+)**
* 📱 `app-armeabi-v7a-release.apk` (17.6 MB) — For legacy 32-bit devices
* 💻 `app-x86_64-release.apk` (20.9 MB) — For PC emulators and ChromeOS

---

## 📁 Project Architecture

```text
Degso-App/
├── lib/
│   ├── main.dart                      # App bootstrapping, routes & MultiProvider setup
│   ├── models/
│   │   ├── download_item.dart         # Download state, status enum & file metadata
│   │   └── video_info_model.dart      # VideoPlatform enum, StreamOption & ParsedVideoInfo
│   ├── providers/
│   │   ├── download_provider.dart     # Central download coordinator, queue & routing logic
│   │   └── theme_provider.dart        # Light, dark, AMOLED theme manager
│   ├── screens/
│   │   ├── home_screen.dart           # Search bar, clipboard paste, 5-platform hero banner
│   │   ├── downloads_screen.dart      # Active task progress, completed history & playback
│   │   └── settings_screen.dart       # Directory selector, theme switcher & app info
│   ├── services/
│   │   ├── facebook_service.dart      # Facebook OpenGraph crawler & SSR video extractor
│   │   ├── pinterest_service.dart     # Pinterest 302 redirect & expMp4 CDN resolver
│   │   ├── twitter_service.dart       # X/Twitter snowflake ID parser & FxTwitter client
│   │   ├── youtube_service.dart       # Innertube stream manifest resolver (pre-muxed)
│   │   ├── tiktok_service.dart        # TikWM & Tiklydown no-watermark API integration
│   │   ├── storage_service.dart       # Local filesystem management & Gal gallery exporter
│   │   └── platform/                  # Cross-platform chunked streaming I/O writer
│   ├── theme/
│   │   └── app_theme.dart             # Custom dark/light palettes, typography & badges
│   └── widgets/
│       ├── stream_selection_sheet.dart# Bottom sheet showing quality chips & audio tags
│       └── video_preview_card.dart    # Dynamic platform-aware video preview card
└── pubspec.yaml                       # Dependencies: youtube_explode_dart, gal, provider, etc.
```

---

## 🔒 Permissions

Degso requires only minimal permissions needed to write media files to your device storage:

- **Android**:
  - `INTERNET` — To download media streams directly from CDNs.
  - `READ_MEDIA_VIDEO` / `READ_MEDIA_AUDIO` (Android 13+) — To verify downloaded media.
  - `WRITE_EXTERNAL_STORAGE` (Android 10 and below) — To save media to local storage.

---

## ⚖️ Disclaimer

Degso is an independent educational and utility project created to demonstrate on-device video stream parsing and Flutter UI design. 

- This software is **not affiliated with, endorsed by, or sponsored by** YouTube, TikTok, ByteDance, Meta (Facebook), Pinterest, or X (Twitter).
- Users are solely responsible for ensuring that their downloads comply with each platform’s Terms of Service and applicable copyright laws. Only download media that you own, have express permission to use, or that is distributed under a permissive license (e.g., Creative Commons).

---

## 👨‍💻 Author & Maintainer

**Eng. Abdiaziz Abdirahman Hassan**  
- **GitHub**: [@Abdiaziiz09](https://github.com/Abdiaziiz09)
- **Project Repository**: [Degso-App](https://github.com/Abdiaziiz09/Degso-App)

---

<div align="center">
  <sub>Built with ❤️ using Flutter and Dart. If you found this project helpful, please give it a ⭐ on GitHub!</sub>
</div>
