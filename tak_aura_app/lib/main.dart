import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'camera_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  List<CameraDescription> cameras = <CameraDescription>[];

  try {
    cameras = await availableCameras();
  } catch (_) {
    cameras = <CameraDescription>[];
  }

  runApp(TakAuraApp(cameras: cameras));
}

class TakAuraApp extends StatelessWidget {
  const TakAuraApp({super.key, required this.cameras});

  final List<CameraDescription> cameras;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TakAura',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050505),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD60A),
          secondary: Color(0xFFFFFFFF),
          surface: Color(0xFF0B0B0B),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: Color(0xFFFFD60A),
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
          titleLarge: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      home: CameraScreen(cameras: cameras),
    );
  }
}
