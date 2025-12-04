# Hugo - Voice Assistant App

A Flutter-based voice assistant app for Android that records voice clips and provides an AI-powered chat interface.

## Features

- Record three 5-second voice clips
- Chat interface with bot responses
- Microphone permission handling
- Clean architecture with isolated AI logic for easy integration

## Prerequisites

- Flutter SDK (3.10.0 or higher)
- Dart SDK (3.10.0 or higher)
- Android Studio or VS Code with Flutter extensions
- Android device or emulator (minSdk 21+)

## Installation

1. **Clone or extract the project:**
   ```bash
   cd hugo
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Clean build (if needed):**
   ```bash
   flutter clean
   flutter pub get
   ```

## Build Instructions

### Debug Build (for testing)

1. **Connect your Android device via USB** or start an Android emulator

2. **Check connected devices:**
   ```bash
   flutter devices
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

### Release Build (APK)

1. **Build APK:**
   ```bash
   flutter build apk --release
   ```

2. **Find your APK at:**
   ```
   build/app/outputs/flutter-apk/app-release.apk
   ```

3. **Install on device:**
   ```bash
   flutter install
   ```
   Or manually transfer the APK to your device.

### Release Build (App Bundle for Google Play)

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

## Project Structure

```
hugo/
├── lib/
│   └── main.dart          # Main app code
├── android/
│   ├── app/
│   │   ├── build.gradle   # Android build configuration
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       └── kotlin/com/example/hugo/
│   │           └── MainActivity.kt
├── pubspec.yaml           # Dependencies
└── README.md
```

## Key Dependencies

- `record: ^5.1.2` - Audio recording
- `path_provider: ^2.1.2` - File storage
- `permission_handler: ^11.3.1` - Microphone permissions

## Permissions

The app requires microphone permission to record voice clips. This is declared in `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

## AI Integration

The bot response logic is isolated in the `BotService` class:

```dart
class BotService {
  Future<String> getBotReply(String userMessage) async {
    // TODO: Replace with real AI API call
    // Currently returns demo responses
  }
}
```

To integrate a real AI service (OpenAI, Claude, Gemini, etc.), simply replace the `getBotReply()` method body without changing any UI code.

## Troubleshooting

### Build Errors

If you encounter dependency conflicts:

```bash
flutter clean
rm pubspec.lock
flutter pub get
```

### Permission Issues

If microphone permission doesn't work:
1. Check `AndroidManifest.xml` has `RECORD_AUDIO` permission
2. Manually grant permission in device settings: Settings → Apps → Hugo → Permissions

### Record Linux Error

If you see `record_linux` compilation errors, ensure your `pubspec.yaml` has:

```yaml
dependency_overrides:
  record_linux: ^1.0.4
```

## Development

### Running in Debug Mode

```bash
flutter run
```

### Hot Reload

Press `r` in the terminal while app is running, or use your IDE's hot reload button.

### Checking for Issues

```bash
flutter doctor
flutter analyze
```

## Next Steps

1. **Voice Clip Processing**: Implement transcription of recorded audio
2. **AI Integration**: Replace `getBotReply()` with real AI API
3. **Voice Playback**: Add ability to play back recorded clips
4. **Cloud Storage**: Upload voice clips to server

## Support

For Flutter issues, visit: https://flutter.dev/docs

---

**Version:** 1.0.0+1  
**Platform:** Android (API 21+)  
**License:** [Your License]# flutter-hugo
