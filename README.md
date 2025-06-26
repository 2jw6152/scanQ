# ScanQ

ScanQ is a Flutter application for scanning CSAT-style questions using OCR.

## Development

This project uses the following folders:

- `lib/scanning` – camera and OCR logic
- `lib/parsing` – parsing scanned text into question components
- `lib/saving` – saving extracted questions
- `lib/review` – reviewing saved questions

Run `flutter pub get` to install dependencies.

Use `flutter run` to launch the app on an Android device or emulator.

The Android build requires camera permissions. Ensure that your
`android/app/src/main/AndroidManifest.xml` includes:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

If the platform folders are missing, run `flutter create .` to generate them.