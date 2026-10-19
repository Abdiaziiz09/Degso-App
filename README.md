# Degso

Degso is a Flutter app for finding and downloading videos from YouTube and
TikTok. Download choices are MP4 videos with sound included; the app does not
offer separate MP3/audio-only downloads. TikTok videos can be downloaded with
or without the watermark when the source provides both options.

Videos can be saved to the device and, where supported and permitted, exported
to the device Gallery/Photos in the **Degso** album. The app also includes a
download history and light, dark, and system theme settings.

## Features

- Accepts YouTube and TikTok video links.
- Shows video details before downloading.
- Offers MP4 video downloads with sound included.
- Shows available YouTube quality options that contain both video and audio.
- Offers TikTok no-watermark and watermarked video options when available.
- Tracks download progress and keeps a local download history.
- Saves completed videos to the device Gallery/Photos on supported platforms.
- Supports light, dark, and system themes.
- Provides Android, iOS, and web app targets.

## Requirements

### Flutter and Dart

- Flutter SDK: Flutter **3.47.5** is the version used to check this project.
- Dart SDK: the project requires **Dart 3.12.1 or newer, below Dart 4.0.0**
  (`pubspec.yaml` declares `^3.12.1`). The checked development environment has
  Dart **3.13.4**.
- Git, for cloning the repository.
- An internet connection to fetch packages and resolve video links.

Flutter includes the Dart SDK. Install Flutter using the
[official Flutter installation guide](https://docs.flutter.dev/get-started/install),
then run `flutter doctor` to check that the required tools are available.

### Android development

- Android SDK and an Android device or emulator.
- Java Development Kit (JDK) **17**.
- Android Gradle Plugin **9.0.1** and Gradle **9.1.0** are configured in the
  project; Gradle Wrapper downloads the configured Gradle version as needed.
- Kotlin Gradle plugin **2.3.20** is configured for Android.
- The Android app is configured to use Flutter's `compileSdk`, `minSdk`, and
  `targetSdk` values.

Android Studio is recommended for installing Android SDK components, managing
emulators, and debugging.

### iOS development

- A Mac running macOS, with Xcode and the iOS SDK installed.
- An iOS simulator or a physical iPhone/iPad for running the app.
- iOS builds cannot be produced on Windows.

### Web development

- A modern browser. No separate browser SDK is required for local development.
- Some download flows depend on external video resolver services and may open
  an external page due to browser restrictions.

## Get the project

Clone the repository and enter its directory:

```bash
git clone https://github.com/Abdiaziiz09/Degso-App.git
cd Degso-App
```

Fetch Flutter packages:

```bash
flutter pub get
```

Check your local toolchain:

```bash
flutter doctor
flutter --version
dart --version
```

## Run the app

Connect a device, start an emulator, or choose a supported target, then run:

```bash
flutter devices
flutter run
```

To run on a specific device, use the device ID shown by `flutter devices`:

```bash
flutter run -d <device-id>
```

For a web development session:

```bash
flutter run -d chrome
```

## Use Degso

1. Open **Search** and paste a YouTube or TikTok video link into the link field.
2. Tap **Fetch Video Information**.
3. When the video details appear, tap the download button.
4. Choose one of the available MP4 video options. Sound is included in the
   video; there is no separate audio download option.
5. Follow progress in **Downloads**. On supported mobile devices, a completed
   video can also be saved to the device Gallery/Photos.

Available quality and watermark options depend on the source video and the
resolver services. YouTube video-only streams are not offered, so the app will
not knowingly select a stream that is missing audio.

## Build

Build a debug Android APK:

```bash
flutter build apk --debug
```

Build a release Android APK:

```bash
flutter build apk --release
```

The APK is written under `build/app/outputs/flutter-apk/`. For store
distribution, configure your own Android release signing key before building a
release. The current Android Gradle configuration uses the debug signing
configuration for release builds.

Build an Android App Bundle:

```bash
flutter build appbundle
```

On macOS with Xcode installed, build for iOS:

```bash
flutter build ios
```

Build the web app:

```bash
flutter build web
```

## Test and analyze

Run the test suite:

```bash
flutter test
```

Analyze the Dart project:

```bash
flutter analyze
```

## Project structure

```text
lib/
  main.dart                 App entry point, themes, and providers
  models/                   Video and download data models
  providers/                Download and theme state
  screens/                  Search, downloads, settings, and navigation
  services/                 YouTube, TikTok, storage, and platform services
  widgets/                  Reusable video and download UI
assets/
  logo.png                  App logo and launcher icon source
android/                    Android application and launcher icons
ios/                        iOS application and launcher icons
web/                        Web app entry point and manifest
test/                       Flutter tests
```

## Main packages

- `youtube_explode_dart` — retrieves YouTube video details and available
  video-with-audio streams on supported native platforms.
- `http` — makes requests to TikTok resolver services and web endpoints.
- `provider` — manages app-wide download and theme state.
- `path_provider`, `path`, and `open_filex` — manage local files and open
  completed downloads.
- `gal` and `permission_handler` — support saving videos to the device Gallery
  and requesting platform permissions where needed.
- `share_plus` and `url_launcher` — share files and open external download
  links.

## Notes and limitations

- Video discovery and downloading require an internet connection.
- YouTube and TikTok link resolution relies on platform behavior and external
  services; those services can change or become temporarily unavailable.
- Video availability, privacy settings, region restrictions, and resolver
  responses can affect whether a link works and which qualities are offered.
- Downloads are intended for content you are authorized to save. Follow the
  applicable platform terms, copyright rules, and local laws.
- The app stores its download history locally on the device.

## Developer

**Engineer Abdiaziz Abdirahman Hassan**
