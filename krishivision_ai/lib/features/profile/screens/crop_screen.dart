import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../core/theme/app_theme.dart';

class CropScreen extends StatefulWidget {
  final File imageFile;

  const CropScreen({super.key, required this.imageFile});

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _isCropping = false;

  Future<void> _cropAndFinish() async {
    if (_isCropping) return;
    setState(() {
      _isCropping = true;
    });

    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        setState(() {
          _isCropping = false;
        });
        return;
      }

      // Capture the repaint boundary as a high-quality image
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        setState(() {
          _isCropping = false;
        });
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();

      // Save to a temporary file
      final tempDir = Directory.systemTemp;
      final croppedFile = File('${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.png');
      await croppedFile.writeAsBytes(pngBytes);

      if (mounted) {
        Navigator.of(context).pop(croppedFile);
      }
    } catch (e) {
      debugPrint("Error cropping image: $e");
      if (mounted) {
        setState(() {
          _isCropping = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error cropping image. Please try again.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Edit Profile Photo'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Cancel',
        ),
      ),
      body: Stack(
        children: [
          // Interactive cropping area
          Center(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white38, width: 1),
              ),
              child: RepaintBoundary(
                key: _repaintKey,
                child: Container(
                  color: Colors.black,
                  width: 300,
                  height: 300,
                  child: InteractiveViewer(
                    boundaryMargin: const EdgeInsets.all(150),
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.file(
                      widget.imageFile,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Outer overlay with visual guide (transparent circular viewport)
          IgnorePointer(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.75),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Instruction overlay at the top (to avoid bottom overlaps)
          Positioned(
            top: 20,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: const Text(
                'Pinch to zoom and drag to position.\nThe circular area shows your final profile photo.',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white30),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isCropping ? null : _cropAndFinish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isCropping
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Done',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
