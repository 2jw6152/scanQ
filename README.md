# ScanQ

ScanQ is a Flutter application for scanning CSAT-style questions using OCR.

## Development

This project uses the following folders:

- `lib/scanning` – camera and OCR logic
- `lib/parsing` – parsing scanned text into question components, including
  formula extraction
- `lib/saving` – saving extracted questions
- `lib/review` – reviewing saved questions

Run `flutter pub get` to install dependencies.

Use `flutter run` to launch the app on an Android device or emulator.

On the scanner screen tap the floating camera button to capture a photo. After
processing, the captured image is shown with green boxes around each detected
text block so you can verify what was recognized. While
the camera preview is running the app continuously performs lightweight OCR and
draws a red bounding box over the scan area when text is detected. Only the
scanning region is processed for the final capture which can help prevent
crashes on low-memory devices. The parsed result now includes any mathematical
formulas found in the text so you can verify them separately.

### Improving OCR quality

ScanQ captures photos using the highest available camera resolution and
preprocesses them before OCR. You can tap the preview to manually adjust the
focus point, which briefly shows a yellow circle while focusing. Photos are
enhanced before recognition:

- The captured image orientation is fixed to avoid rotated text.
- The entire photo is processed first, and the question area is detected
  afterward.
- The image is blurred slightly to remove noise then converted to
  grayscale.
- Contrast is increased and the image is binarized with adaptive thresholding
  so text remains clear even under uneven lighting.
- Detected skew is corrected using edge analysis and the image is morphed to
  reduce page curvature and line distortion before recognition.
- The processed image with detected text blocks is shown after each scan so you
  can verify the OCR result visually.

These steps help Google MLKit produce more accurate recognition results.

Additionally the camera image stream now provides the row stride
(bytesPerRow) of the image so MLKit can correctly interpret YUV frames.
This helps reduce recognition errors on some devices.

For mathematical expressions the app now runs OCR twice, once with the Korean
script recognizer and once with the Latin recognizer. The results are merged so
numbers and symbols in formulas are less likely to be missed.

Math formulas detected in the recognized text are extracted and stored with
each question so they can be handled separately in the future.
The formula extractor now recognizes fractions like `1/2` or `a ÷ b` so
expressions with division are parsed correctly.

The Android build requires camera permissions. Ensure that your
`android/app/src/main/AndroidManifest.xml` includes:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

On modern Android versions the app also requests camera access at runtime using
the `permission_handler` plugin. Make sure you grant the permission when
prompted, otherwise the scanner screen will show an error.

If the platform folders are missing, run `flutter create .` to generate them.