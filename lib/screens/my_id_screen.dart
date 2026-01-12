import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MyIdPage extends StatelessWidget {
  final String myId;
  const MyIdPage({super.key, required this.myId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Linker ID')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: QrImageView(
                data: myId,
                version: QrVersions.auto,
                size: 240,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
              ),
            ),
            const SizedBox(height: 40),
            Text(myId, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 6)),
            const SizedBox(height: 12),
            const Text('Anyone can scan this globally', style: TextStyle(color: Colors.white38, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
