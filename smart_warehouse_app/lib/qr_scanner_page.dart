import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerPage extends StatefulWidget {
  final String expectedSku;

  const QrScannerPage({super.key, required this.expectedSku});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController cameraController = MobileScannerController();
  bool _isScanned = false;

  String get baseUrl => kIsWeb ? "http://localhost:8080" : (Platform.isAndroid ? "http://10.0.2.2:8080" : "http://localhost:8080");

  Future<void> _sendQrErrorToBackend(String scannedCode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    try {
      await http.post(
        Uri.parse('$baseUrl/api/admin/logs'),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token"
        },
        body: jsonEncode({
          "message": "Geçersiz QR Kod Okutuldu! Beklenen: ${widget.expectedSku}, Okutulan: $scannedCode",
          "stackTrace": "qr_scanner_page.dart - Mobil Cihaz Yanlış Ürün Okutma (Flutter Frontend)"
        }),
      );
    } catch (e) {
      debugPrint("QR Hata logu sunucuya iletilemedi: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
            "Ürün Doğrulama",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.flashlight_on, color: Colors.white),
            onPressed: () => cameraController.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (_isScanned) return;

              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  setState(() => _isScanned = true);
                  final String scannedCode = barcode.rawValue!;

                  if (scannedCode == widget.expectedSku) {
                    Navigator.pop(context, true);
                  } else {
                    _sendQrErrorToBackend(scannedCode);
                    Navigator.pop(context, false);
                  }
                  break;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}