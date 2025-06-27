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

On the scanner screen tap the floating camera button to capture a photo. The
recognized text is shown in a dialog so you can verify that OCR succeeded.
After a question is detected the recognized region is highlighted on the
preview. Only that portion of the captured image is processed which can help
prevent crashes on low-memory devices.

### Improving OCR quality

ScanQ captures photos using the highest available camera resolution and
preprocesses them before OCR:

- The captured image orientation is fixed to avoid rotated text.
- Only the region inside the scan box is cropped for processing.
- The cropped image is converted to grayscale and the contrast is increased to
  make characters stand out.

These steps help Google MLKit produce more accurate recognition results.

The Android build requires camera permissions. Ensure that your
`android/app/src/main/AndroidManifest.xml` includes:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

On modern Android versions the app also requests camera access at runtime using
the `permission_handler` plugin. Make sure you grant the permission when
prompted, otherwise the scanner screen will show an error.

If the platform folders are missing, run `flutter create .` to generate them.
