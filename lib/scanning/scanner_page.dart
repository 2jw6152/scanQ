import 'dart:io';
import 'package:image/image.dart' as img;

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
      final controller =
          CameraController(camera, ResolutionPreset.medium, enableAudio: false);
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
    });
    try {
      await _initializeControllerFuture;
      final picture = await _controller!.takePicture();
      final file = File(picture.path);
      final bytes = await file.readAsBytes();
      final img.Image? original = img.decodeImage(bytes);
      late final InputImage inputImage;
      if (original != null) {
        final crop = _imageCropRect(original.width, original.height);
        final img.Image cropped = img.copyCrop(
          original,
          crop.left.toInt(),
          crop.top.toInt(),
          crop.width.toInt(),
          crop.height.toInt(),
        );
        final croppedPath = '${file.path}_crop.jpg';
        await File(croppedPath).writeAsBytes(img.encodeJpg(cropped));
        inputImage = InputImage.fromFilePath(croppedPath);
      } else {
        inputImage = InputImage.fromFile(file);
      }
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.korean);
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final parser = CSATParser();
      final CSATQuestion question = parser.parse(recognizedText.text);

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
                      Positioned.fromRect(
                        rect: _calculateScanRect(MediaQuery.of(context).size),
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.greenAccent,
                                width: 2,
                              ),
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