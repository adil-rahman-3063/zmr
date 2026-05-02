# ZMR Music v1.3.0 - The Discovery & Customization Update 🎨

This major update introduces personalized feed filtering, advanced playback controls, and a new identity hub to make ZMR truly yours.

### ✨ New Features
*   **Modernized Home Feed**: A redesigned discovery experience featuring **Category Chips**. Instantly filter your feed for moods like "Relax", "Workout", or "Energize" with a single tap.
*   **Dynamic Quick Picks**: Your most-listened tracks are now intelligently organized into responsive 4x4 grids for faster access.
*   **The Profile Hub**: A new centralized location for your account info, settings, and support. Replace the old settings icon with your personal profile.
*   **Advanced Playback Controls**:
    *   **Crossfade (0-10s)**: Smoothly transition between tracks with customizable fade-ins.
    *   **Gapless Playback**: Eliminate silence between songs for a continuous listening experience.
    *   **Volume Normalization**: Balance audio levels across different tracks to prevent volume spikes.
*   **Ultimate Personalization**:
    *   **Theme Modes**: Full support for Light, Dark, and System-synced themes.
    *   **AMOLED Mode**: Save battery and enjoy deep contrast with "True Black" support for OLED displays.
*   **Integrated Bug Reporting**: Found a glitch? Report it directly from your profile using our new feedback system connected to Supabase.

### 🛠️ Technical Improvements
*   **Enhanced Feed Parsing**: Refactored the InnerTube integration to support specialized section types and parameter-based category filtering.
*   **Settings Persistence**: All your playback and UI preferences are now saved locally and applied instantly across sessions.
*   **Performance Optimization**: Reduced layout shifts in the home feed with better grid pre-calculation.

---

# ZMR Music v1.2.1 - Artist Experience Stability Hotfix 🩹

This minor update resolves critical issues discovered during the rollout of the Artist Experience.

### 🔧 Fixes & Stability
* **Resolved 400 Errors**: Fixed a critical "Bad Request" error that occurred when fetching extended artist song lists or toggling subscriptions.
* **Optimistic Follow Actions**: Pressing "Follow" or "Following" now provides instant visual feedback while the sync happens in the background. No more waiting for the server to confirm!
* **Authenticated Requests**: Corrected authentication context for likes and subscriptions, ensuring actions are properly saved to your YouTube Music account.
* **Enhanced Discovery**: Improved the reliability of the "Songs" section in artist profiles to fetch a much larger catalog of music.

---

# ZMR Music v1.2.0 - The Artist Experience 🎤

This update transforms how you interact with your favorite musicians, bringing dedicated profiles and deep-linking across the entire app.

### ✨ New Features
* **Artist Profiles**: Deep dive into any artist's library. View popular songs, categorized albums, singles, and new releases with a stunning new glassmorphic profile view.
* **Subscription Management**: Follow and unfollow artists directly from their profile page. Your followed artists section on the home screen will stay perfectly in sync.
* **Deep Linking Everywhere**: 
    * Click any artist name in the search results, home feed, or player to jump to their profile.
    * Added subtle visual indicators (underlines) to clickable artist names for better discoverability.
* **Refined Mini Player**: Simplified the mini player design by focusing on the song title for a more minimalist look.

### 🛠️ Technical Improvements
* **Enhanced Metadata Extraction**: Updated the YouTube service to automatically resolve and store Artist IDs, enabling seamless navigation for all parsed tracks.
* **Performance Polish**: Optimized the transition animations between the home screen and artist profiles for 60fps fluidity.

---

# ZMR Music v1.0.1 - Infrastructure Update 🛠️

This update focuses on reinforcing the application's underlying infrastructure to ensure consistent data synchronization and smoother playback reliability.

### 🔧 Stability Improvements
* **Resilient Token Provider**: Enhanced the app's ability to handle edge cases with the Cloudflare Link Provider, including support for non-standard response formats.
* **Safety Fallback Mechanism**: Introduced an automated fallback system for library synchronization. Your playlists and liked songs will now load successfully even if the token service is experiencing temporary instability.
* **Concurrent Request Optimization**: Optimized how the app handles multiple simultaneous data requests to reduce network overhead and prevent redundant token fetches.

---

# ZMR Music v1.0.0 - Initial Release 🚀

Welcome to the first official release of ZMR Music! ZMR is a premium, high-performance YouTube Music client designed for audiophiles who value a sleek, distraction-free experience.

### ✨ Core Launch Features
* **Pro Audio Engine**: Engineered for high-fidelity, persistent background playback that continues even when your screen is locked.
* **Smart Lock Screen**: Interactive lock screen and notification controls featuring full album artwork and live seeking.
* **Secure Auth Flow**: Privacy-focused cookie authentication. Connect your YouTube Music library without ever sharing your credentials with an external database.
* **Interactive App Shell**: A unique, gesture-driven "Stacked Card" UI for seamless switching between your Mini Player and Navigation.
* **Smart Radio**: Instant radio discovery—start with one song and let ZMR build the perfect "Up Next" queue for you.

### 🎨 Modern Design
* **Glassmorphism UI**: A beautiful, translucent interface that adapts to your theme.
* **Animated Gestures**: Fluid swipe-to-switch cards and physics-based interactions.
* **Dynamic Icons**: Custom-designed ZMR branding across the app and system notifications.

### 🔒 Privacy & Performance
* **Local-First**: Your data stays on your device. Period.
* **Cloudflare Optimized**: Lightning-fast stream extraction powered by Cloudflare Workers.
* **Battery Efficient**: Optimized for minimal battery drain during long listening sessions.

---
**Welcome to the future of your music library. Welcome to ZMR.**
