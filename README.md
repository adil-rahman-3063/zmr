# ZMR Music 🎵

A premium, high-performance YouTube Music client built with Flutter. ZMR focuses on a sleek, gesture-driven experience with high-fidelity audio and robust background playback.

![App Header](assets/icon.png)

## ✨ Features

- **Premium UI/UX**: Modern design with glassmorphism, dynamic colors, and fluid animations.
- **Background Playback**: Full support for lock-screen controls and persistent audio sessions.
- **Cookie Authentication**: Secure, local-only cookie storage for a standalone YouTube Music experience.
- **Smart Queue**: Automated "Up Next" suggestions and radio discovery.
- **Performance First**: Minimal resource footprint with high-quality stream extraction.

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (Latest Stable)
- Android Studio / Xcode
- A YouTube Music account

### Setup
1. Clone the repository.
2. Run `flutter pub get`.
3. Follow the **Cookie Onboarding** guide within the app to connect your account.
4. Launch the app: `flutter run`.

## 🛠️ Technology Stack

- **Framework**: Flutter
- **State Management**: Riverpod
- **Audio Engine**: `just_audio` & `audio_service`
- **Backend Infrastructure**: Cloudflare Workers
- **Database (Auth)**: Supabase

## 🔒 Privacy & Security

ZMR is designed with privacy in mind. Your YouTube cookies are stored **locally** in your device's secure cache and are never uploaded to any external database.

---

Built with ❤️ by the ZMR Team.
