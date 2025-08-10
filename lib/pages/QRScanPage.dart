import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class QRScanPage extends StatefulWidget {
  const QRScanPage({Key? key}) : super(key: key);

  @override
  State<QRScanPage> createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? _controller;
  bool _isFlashOn = false;
  bool _isProcessingCode = false;

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      _controller?.pauseCamera();
    } else if (Platform.isIOS) {
      _controller?.resumeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            tooltip: 'Flip Camera',
            onPressed: _flipCamera,
          ),
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
            tooltip: _isFlashOn ? 'Turn Flash Off' : 'Turn Flash On',
            onPressed: _toggleFlash,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              flex: 5,
              child: QRView(
                key: _qrKey,
                onQRViewCreated: _onQRViewCreated,
                overlay: QrScannerOverlayShape(
                  borderColor: Theme.of(context).primaryColor,
                  borderRadius: 10,
                  borderLength: 30,
                  borderWidth: 10,
                  cutOutSize: screenSize.width * 0.8,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Align QR code within the frame',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    _isProcessingCode
                        ? const CircularProgressIndicator()
                        : const SizedBox(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      _controller = controller;
    });

    controller.scannedDataStream.listen((scanData) {
      _processQRCode(scanData);
    });
  }

  void _processQRCode(Barcode scanData) {
    if (_isProcessingCode || scanData.code == null) return;

    setState(() {
      _isProcessingCode = true;
    });

    // Prevent multiple scans by pausing camera
    _controller?.pauseCamera();

    // Return the result after a short delay to show processing state
    Future.delayed(const Duration(milliseconds: 300), () {
      Navigator.pop(context, scanData.code);
    });
  }

  Future<void> _flipCamera() async {
    if (_controller != null) {
      await _controller!.flipCamera();
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller != null) {
      await _controller!.toggleFlash();
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}