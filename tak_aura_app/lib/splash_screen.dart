import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'camera_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.cameras});

  final List<CameraDescription> cameras;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _goToCamera();
  }

  Future<void> _goToCamera() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute<CameraScreen>(
        builder: (BuildContext context) => CameraScreen(cameras: widget.cameras),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'TakAura',
              style: TextStyle(
                color: Colors.yellow,
                fontSize: 48,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Đang khởi động hệ thống...',
              style: TextStyle(
                color: Colors.yellow,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Colors.yellow),
          ],
        ),
      ),
    );
  }
}
