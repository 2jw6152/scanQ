import 'package:flutter/material.dart';
import 'scanning/scanner_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ScanQ')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ScannerPage()),
            );
          },
          child: const Text('Start Scanning'),
        ),
      ),
    );
  }
}
