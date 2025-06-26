import 'package:flutter/material.dart';
import 'home_page.dart';

void main() {
  runApp(const ScanQApp());
}

class ScanQApp extends StatelessWidget {
  const ScanQApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScanQ',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}
