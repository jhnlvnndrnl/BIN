# Frontend Prerequisites

## Prerequisites

Before setting up the frontend, ensure you have the following installed:

### Flutter SDK
- **Version:** 3.19.0 or later
- **Installation:** Follow the official Flutter installation guide at [flutter.dev](https://flutter.dev/docs/get-started/install)
- **Verify:** Run `flutter doctor` in your terminal to check the installation

### Dart SDK
- **Included with Flutter:** Dart comes bundled with Flutter
- **Version:** 3.3.0 or later

### Development Environment
- **IDE:** Visual Studio Code with Flutter and Dart extensions, or Android Studio
- **Git:** For version control

### Platform-Specific Requirements
- **Android:** Android Studio with Android SDK (API level 21 or higher)
- **iOS:** macOS with Xcode 14.0 or later (for iOS development)
- **Web:** Any modern web browser

### Additional Dependencies
- **Firebase CLI:** For Firebase configuration
  ```bash
  npm install -g firebase-tools
  ```
- **Supabase CLI:** For local development (optional)
  ```bash
  npm install -g supabase
  ```

## Setup Instructions

1. Clone the repository
2. Navigate to the frontend directory
3. Run `flutter pub get` to install dependencies
4. Configure Firebase (see firebase.json)
5. Run `flutter run` to start the development server

## Environment Variables

Create a `.env` file in the frontend directory with the following variables:

```
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
BACKEND_URL=your_backend_url
```

## Testing

Run tests with:
```bash
flutter test
```

## Building

Build for production:
```bash
flutter build apk  # For Android
flutter build ios  # For iOS
flutter build web  # For Web
```