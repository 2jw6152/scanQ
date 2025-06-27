import 'dart:io';
import 'package:image/image.dart' as img;
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';

import '../parsing/csat_parser.dart';
import '../models/csat_question.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({Key? key}) : super(key: key);

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isScanning = false;
  Rect? _detectedRect; // normalized rect within the scan area

  // Relative scan area (percent of preview) shown with a bounding box.
  static const Rect _relativeScanRect =
      Rect.fromLTWH(0.1, 0.25, 0.8, 0.5); // left, top, width, height

  Rect _calculateScanRect(Size size) {
    return Rect.fromLTWH(
      size.width * _relativeScanRect.left,
      size.height * _relativeScanRect.top,
      size.width * _relativeScanRect.width,
      size.height * _relativeScanRect.height,
    );
  }

  Rect _imageCropRect(int width, int height) {
    return Rect.fromLTWH(
      width * _relativeScanRect.left,
      height * _relativeScanRect.top,
      width * _relativeScanRect.width,
      height * _relativeScanRect.height,
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission denied')),
        );
      }
      return;
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No camera found')),
          );
        }
        return;
      }
      final camera = cameras.first;
      // Use the highest available resolution to improve OCR accuracy.
      final controller =
          CameraController(camera, ResolutionPreset.max, enableAudio: false);
      _controller = controller;
      _initializeControllerFuture = controller.initialize();
      await _initializeControllerFuture;
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize camera: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    if (_isScanning || _controller == null || _initializeControllerFuture == null) return;
    setState(() {
      _isScanning = true;
      _detectedRect = null;
    });
    try {
      await _initializeControllerFuture;
      final picture = await _controller!.takePicture();
      final file = File(picture.path);
      final bytes = await file.readAsBytes();
      final img.Image? original = img.decodeImage(bytes);
      late final InputImage inputImage;
      Rect? crop;
      if (original != null) {
        // Correct the orientation and enhance the image for better recognition.
        img.Image processed = img.bakeOrientation(original);
        crop = _imageCropRect(processed.width, processed.height);
        processed = img.copyCrop(
          processed,
          x: crop.left.toInt(),
          y: crop.top.toInt(),
          width: crop.width.toInt(),
          height: crop.height.toInt(),
        );
        processed = img.grayscale(processed);
        processed = img.adjustColor(processed, contrast: 1.2);
        final croppedPath = '${file.path}_crop.jpg';
        await File(croppedPath).writeAsBytes(img.encodeJpg(processed));
        inputImage = InputImage.fromFilePath(croppedPath);
      } else {
        inputImage = InputImage.fromFile(file);
      }
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.korean);
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      Rect? detected;
      if (recognizedText.blocks.isNotEmpty) {
        double minX = double.infinity;
        double minY = double.infinity;
        double maxX = 0;
        double maxY = 0;
        for (final block in recognizedText.blocks) {
          final box = block.boundingBox;
          if (box != null) {
            minX = math.min(minX, box.left.toDouble());
            minY = math.min(minY, box.top.toDouble());
            maxX = math.max(maxX, box.right.toDouble());
            maxY = math.max(maxY, box.bottom.toDouble());
          }
        }
        if (maxX > minX && maxY > minY) {
          final w = crop?.width ?? original?.width ?? 1;
          final h = crop?.height ?? original?.height ?? 1;
          detected = Rect.fromLTRB(
            minX / w,
            minY / h,
            maxX / w,
            maxY / h,
          );
        }
      }

      final parser = CSATParser();
      final CSATQuestion question = parser.parse(recognizedText.text);
      setState(() {
        _detectedRect = detected;
      });

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Recognized Question'),
          content: SingleChildScrollView(child: Text(question.body)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'))
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to scan: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Question')),
      body: _controller == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return Stack(
                    children: [
                      CameraPreview(_controller!),
                      if (_detectedRect != null)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _BoundingBoxPainter(
                                _detectedRect!,
                                MediaQuery.of(context).size,
                                _calculateScanRect(MediaQuery.of(context).size),
                              ),
                            ),
                          ),
                        ),
                      if (_isScanning)
                        Container(
                          color: Colors.black45,
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: FloatingActionButton(
                            onPressed: _scan,
                            child: const Icon(Icons.camera_alt),
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
    );
  }
}

class _BoundingBoxPainter extends CustomPainter {
  final Rect rect;
  final Size screenSize;
  final Rect scanRect;

  _BoundingBoxPainter(this.rect, this.screenSize, this.scanRect);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final converted = Rect.fromLTRB(
      scanRect.left + rect.left * scanRect.width,
      scanRect.top + rect.top * scanRect.height,
      scanRect.left + rect.right * scanRect.width,
      scanRect.top + rect.bottom * scanRect.height,
    );
    canvas.drawRect(converted, paint);
  }

  @override
  bool shouldRepaint(covariant _BoundingBoxPainter oldDelegate) {
    return oldDelegate.rect != rect;
  }
}