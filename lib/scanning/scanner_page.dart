import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
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

  bool _processingImage = false;
  DateTime _lastDetection = DateTime.fromMillisecondsSinceEpoch(0);
  static const _detectionInterval = Duration(milliseconds: 700);

  late final TextRecognizer _textRecognizer;

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
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.korean);
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
      final controller = CameraController(
        camera,
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      _controller = controller;
      _initializeControllerFuture = controller.initialize();
      await _initializeControllerFuture;
      await controller.startImageStream(_processCameraImage);
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
    _controller?.stopImageStream();
    _controller?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_processingImage) return;
    final now = DateTime.now();
    if (now.difference(_lastDetection) < _detectionInterval) return;
    _processingImage = true;
    _lastDetection = now;
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotationValue.fromRawValue(
                _controller!.description.sensorOrientation) ??
            InputImageRotation.rotation0deg,
        format:
            InputImageFormatValue.fromRawValue(image.format.raw) ??
                InputImageFormat.nv21,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      final inputImage =
          InputImage.fromBytes(bytes: bytes, metadata: metadata);
      final recognizedText = await _textRecognizer.processImage(inputImage);

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
          final w = image.width.toDouble();
          final h = image.height.toDouble();
          final rectNorm = Rect.fromLTRB(
            minX / w,
            minY / h,
            maxX / w,
            maxY / h,
          );
          final inter = rectNorm.intersect(_relativeScanRect);
          if (!inter.isEmpty) {
            detected = Rect.fromLTRB(
              (inter.left - _relativeScanRect.left) / _relativeScanRect.width,
              (inter.top - _relativeScanRect.top) / _relativeScanRect.height,
              (inter.right - _relativeScanRect.left) / _relativeScanRect.width,
              (inter.bottom - _relativeScanRect.top) / _relativeScanRect.height,
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          _detectedRect = detected;
        });
      }
    } catch (_) {
      // ignore stream errors
    } finally {
      _processingImage = false;
    }
  }

  Future<void> _scan() async {
    if (_isScanning || _controller == null || _initializeControllerFuture == null) return;
    setState(() {
      _isScanning = true;
      _detectedRect = null;
    });
    try {
      await _initializeControllerFuture;
      await _controller!.stopImageStream();
      final picture = await _controller!.takePicture();
      final file = File(picture.path);
      final bytes = await file.readAsBytes();
      final img.Image? original = img.decodeImage(bytes);
      late final InputImage inputImage;
      Rect? crop;
      String? croppedPath;
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
        croppedPath = '${file.path}_crop.jpg';
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
      await _showResult(croppedPath ?? file.path,
          Size((crop?.width ?? original?.width ?? 1).toDouble(),
              (crop?.height ?? original?.height ?? 1).toDouble()),
          recognizedText,
          question);
      await _controller!.startImageStream(_processCameraImage);
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

  Future<void> _showResult(String imagePath, Size imageSize,
      RecognizedText recognizedText, CSATQuestion question) async {
    await showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: imageSize.width / imageSize.height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(File(imagePath), fit: BoxFit.contain),
                      Positioned.fill(
                        child: CustomPaint(
                          painter:
                              _BlocksPainter(recognizedText.blocks, imageSize),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(question.body),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
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

class _BlocksPainter extends CustomPainter {
  final List<TextBlock> blocks;
  final Size imageSize;

  _BlocksPainter(this.blocks, this.imageSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final block in blocks) {
      final box = block.boundingBox;
      if (box != null) {
        final rect = Rect.fromLTRB(
          box.left / imageSize.width * size.width,
          box.top / imageSize.height * size.height,
          box.right / imageSize.width * size.width,
          box.bottom / imageSize.height * size.height,
        );
        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BlocksPainter oldDelegate) {
    return oldDelegate.blocks != blocks;
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