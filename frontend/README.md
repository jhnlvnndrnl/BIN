# BIN — Frontend

> Flutter codebase for the BIN waste management system.  
> Compiles to two targets from a single Dart codebase: **mobile app** (iOS + Android) for residents and **web dashboard** for LGU officers.

---

## Requirements

| Tool | Minimum Version |
|------|----------------|
| Flutter | 3.22.0 |
| Dart | 3.4.0 |
| Android SDK | API 21 (Android 5.0) |
| Xcode | 15.0 (iOS builds only) |
| Node.js | Not required |

Verify your environment:

```bash
flutter doctor
```

All items should be green before proceeding. Fix any issues `flutter doctor` flags before running the app.

---

## Installation

**1. Clone the repository**

```bash
git clone https://github.com/your-org/bin.git
cd bin/frontend
```

**2. Install dependencies**

```bash
flutter pub get
```

**3. Set up environment variables**

Copy the example env file and fill in your values:

```bash
cp .env.example .env
```

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
API_BASE_URL=https://api.bin.app
```

> The Supabase anon key is intentionally public — it is safe to include in the app. Row Level Security enforces all access control on the database side.

**4. Add the TFLite model**

Place the EfficientNet-Lite waste classification model in:

```
assets/models/waste_classifier.tflite
assets/models/waste_labels.txt
```

> Contact the team for the model file — it is not committed to the repository due to file size.

---

## Running the App

### Mobile (Android)

```bash
# List connected devices
flutter devices

# Run on a connected Android device or emulator
flutter run -d android
```

### Mobile (iOS)

```bash
# Run on a connected iOS device or simulator
flutter run -d ios
```

> iOS builds require Xcode and a valid signing certificate. For local development, use a simulator.

### Web Dashboard (LGU)

```bash
flutter run -d chrome
```

Or target a specific browser:

```bash
flutter run -d web-server --web-port 8080
# Then open http://localhost:8080
```

---

## Building for Production

### Android APK

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle (Play Store)

```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### iOS

```bash
flutter build ios --release
# Then archive and distribute via Xcode
```

### Web

```bash
flutter build web --release
# Output: build/web/
# Deploy the build/web/ directory to any static file host
```

---

## Dependencies

All dependencies are defined in `pubspec.yaml`. Key packages:

### Core

| Package | Version | Purpose |
|---------|---------|---------|
| `supabase_flutter` | ^2.5.0 | Supabase client — auth, database, storage, realtime |
| `flutter_riverpod` | ^2.5.1 | State management |
| `go_router` | ^14.2.0 | Navigation and routing |

### Maps

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_map` | ^7.0.2 | Map rendering (mobile + web) |
| `latlong2` | ^0.9.1 | Latitude/longitude utilities |

### Camera and Media

| Package | Version | Purpose |
|---------|---------|---------|
| `camera` | ^0.11.0 | Native camera access for report submission |
| `image_picker` | ^1.1.2 | Photo selection from gallery |
| `image` | ^4.2.0 | Image processing before upload |

### AI / On-Device Inference

| Package | Version | Purpose |
|---------|---------|---------|
| `tflite_flutter` | ^0.10.4 | TensorFlow Lite — runs EfficientNet-Lite on device |

### Location

| Package | Version | Purpose |
|---------|---------|---------|
| `geolocator` | ^12.0.0 | GPS coordinate capture |
| `geocoding` | ^3.0.0 | Reverse geocoding (coordinates → address) |

### Notifications

| Package | Version | Purpose |
|---------|---------|---------|
| `firebase_core` | ^3.3.0 | Firebase initialization |
| `firebase_messaging` | ^15.1.0 | FCM push notifications |
| `flutter_local_notifications` | ^17.2.2 | Display notifications when app is in foreground |

### Offline Storage

| Package | Version | Purpose |
|---------|---------|---------|
| `drift` | ^2.20.2 | SQLite ORM — offline report queue |
| `sqlite3_flutter_libs` | ^0.5.24 | SQLite native bindings |

### Security

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_secure_storage` | ^9.2.2 | Secure JWT storage (iOS Keychain / Android Keystore) |

### Utilities

| Package | Version | Purpose |
|---------|---------|---------|
| `envied` | ^0.5.4 | Compile-time env variable injection |
| `dio` | ^5.7.0 | HTTP client for FastAPI backend |
| `freezed` | ^2.5.7 | Immutable data classes |
| `json_serializable` | ^6.8.0 | JSON serialization |
| `intl` | ^0.19.0 | Localization (Filipino + English) |

---

## Project Structure

```
lib/
├── main.dart                   # Entry point
├── app.dart                    # App root, router setup
│
├── core/
│   ├── env/                    # Environment config (envied)
│   ├── router/                 # go_router route definitions
│   ├── theme/                  # App colors, typography
│   └── utils/                  # Shared utilities
│
├── features/
│   ├── auth/                   # Registration, login, OTP
│   ├── home/                   # Heatmap screen
│   ├── report/                 # Camera, AI classification, submission
│   ├── track/                  # Report history and status
│   ├── dashboard/              # LGU web dashboard (web target only)
│   └── notifications/          # FCM + local notification handling
│
├── ai/
│   ├── classifier.dart         # TFLite inference wrapper
│   └── model_labels.dart       # Waste type label mapping
│
└── shared/
    ├── widgets/                # Shared UI components
    ├── models/                 # Shared data models (freezed)
    └── services/               # Supabase, API, SMS services

assets/
├── models/
│   ├── waste_classifier.tflite
│   └── waste_labels.txt
└── i18n/
    ├── en.arb                  # English strings
    └── fil.arb                 # Filipino strings
```

---

## Code Generation

Several packages require code generation. Run this after adding new models or routes, or after a fresh clone:

```bash
dart run build_runner build --delete-conflicting-outputs
```

For continuous generation during development:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

Affected packages: `freezed`, `json_serializable`, `drift`, `envied`, `riverpod_generator`.

---

## Localization

Generate localization files after editing `.arb` files in `assets/i18n/`:

```bash
flutter gen-l10n
```

Output is generated into `lib/core/l10n/`. Do not edit generated files directly.

---

## Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run a specific test file
flutter test test/features/report/classifier_test.dart
```

---

## Linting and Formatting

```bash
# Analyze for issues
flutter analyze

# Format all Dart files
dart format .
```

The project uses `flutter_lints` and a custom `analysis_options.yaml`. CI will fail on any lint errors.

---

## Platform-Specific Setup

### Android

Minimum SDK and permissions are configured in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

Google Services file required for FCM:

```
android/app/google-services.json
```

> Get this from the Firebase Console. Do not commit it to version control.

### iOS

Location and camera usage descriptions are set in `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>BIN needs camera access to photograph waste for reporting.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>BIN uses your location to tag waste reports accurately.</string>
```

Firebase config file required:

```
ios/Runner/GoogleService-Info.plist
```

> Get this from the Firebase Console. Do not commit it to version control.

### Web

No additional platform setup required. The web build uses the same Supabase and API credentials from `.env`.

---

## Common Issues

**`flutter pub get` fails on tflite_flutter**  
Ensure your Flutter version is ≥ 3.22.0. TFLite Flutter has known compatibility issues with older Flutter versions.

**Camera not working on Android emulator**  
Use a physical device for the full report submission flow. Android emulators have limited camera support.

**`build_runner` conflicts**  
Run with `--delete-conflicting-outputs`:
```bash
dart run build_runner build --delete-conflicting-outputs
```

**Web map tiles not loading locally**  
OpenStreetMap tiles require an internet connection. The map will not render in an offline local environment.

---

## Related

- Backend API: `../backend/`
- System specifications: `../specs/`
- AI model training: `../ai/mobile/`