import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'services/tflite_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.cameras});

  final List<CameraDescription> cameras;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  final TFLiteService _tfliteService = TFLiteService();

  CameraController? _cameraController;
  bool _isInitializing = true;
  bool _hasPermission = false;
  bool _isDetecting = false;
  bool _isProcessingFrame = false;
  bool _isModelReady = false;
  CameraDescription? _selectedCamera;
  List<DetectionResult> _detections = <DetectionResult>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prepareModel();
    _setupCameraFlow();
  }

  Future<void> _prepareModel() async {
    try {
      await _tfliteService.loadModel();
      await _tfliteService.loadLabels();
      if (!mounted) {
        return;
      }
      setState(() {
        _isModelReady = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isModelReady = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_selectedCamera == null) {
      return;
    }

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _stopImageStream();
      _disposeController();
      return;
    }

    if (state == AppLifecycleState.resumed && _hasPermission) {
      _initializeController(_selectedCamera!);
    }
  }

  Future<void> _setupCameraFlow() async {
    final PermissionStatus permissionStatus = await Permission.camera.request();

    if (!mounted) {
      return;
    }

    if (!permissionStatus.isGranted) {
      setState(() {
        _hasPermission = false;
        _isInitializing = false;
      });
      return;
    }

    _hasPermission = true;

    if (widget.cameras.isEmpty) {
      setState(() {
        _isInitializing = false;
      });
      return;
    }

    _selectedCamera = widget.cameras.firstWhere(
      (CameraDescription camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => widget.cameras.first,
    );

    await _initializeController(_selectedCamera!);
  }

  Future<void> _initializeController(CameraDescription selectedCamera) async {
    setState(() {
      _isInitializing = true;
    });

    await _disposeController();

    final CameraController controller = CameraController(
      selectedCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _isInitializing = false;
      });

      if (_isDetecting) {
        await _startImageStream();
      }
    } catch (_) {
      await controller.dispose();
      if (!mounted) {
        return;
      }
      setState(() {
        _cameraController = null;
        _isInitializing = false;
      });
    }
  }

  Future<void> _disposeController() async {
    await _stopImageStream();

    final CameraController? oldController = _cameraController;
    _cameraController = null;
    if (oldController != null) {
      await oldController.dispose();
    }
  }

  Future<void> _startImageStream() async {
    final CameraController? controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || controller.value.isStreamingImages) {
      return;
    }

    await controller.startImageStream((CameraImage image) async {
      if (_isProcessingFrame || !_isDetecting) {
        return;
      }

      _isProcessingFrame = true;
      try {
        final List<DetectionResult> detections = await _tfliteService.runInference(image);
        if (!mounted || !_isDetecting) {
          return;
        }
        setState(() {
          _detections = detections;
        });
      } catch (_) {
      } finally {
        _isProcessingFrame = false;
      }
    });
  }

  Future<void> _stopImageStream() async {
    final CameraController? controller = _cameraController;
    if (controller == null || !controller.value.isStreamingImages) {
      return;
    }

    await controller.stopImageStream();
    _isProcessingFrame = false;
  }

  Future<void> _toggleDetection() async {
    final CameraController? controller = _cameraController;
    final bool cameraReady =
        _hasPermission && controller != null && controller.value.isInitialized;

    if (!cameraReady) {
      return;
    }

    if (!_isModelReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mô hình AI chưa sẵn sàng. Vui lòng chờ thêm một chút.'),
        ),
      );
      return;
    }

    if (_isDetecting) {
      await _stopImageStream();
      if (!mounted) {
        return;
      }
      setState(() {
        _isDetecting = false;
        _detections = <DetectionResult>[];
      });
      return;
    }

    setState(() {
      _isDetecting = true;
    });

    await _startImageStream();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopImageStream();
    _tfliteService.dispose();
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool cameraReady =
        _hasPermission && _cameraController != null && _cameraController!.value.isInitialized;

    return Scaffold(
      body: GestureDetector(
        onTap: _toggleDetection,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (cameraReady)
              CameraPreview(_cameraController!)
            else
              Container(color: const Color(0xFF050505)),
            if (cameraReady && _detections.isNotEmpty)
              _buildDetectionsOverlay(_cameraController!, _detections),
            _buildOverlay(context, cameraReady),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionsOverlay(CameraController controller, List<DetectionResult> detections) {
    final Size? previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size screenSize = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          children: detections.map((DetectionResult detection) {
            final Rect rect = _mapDetectionToScreenRect(
              normalizedRect: detection.boundingBox,
              previewSize: previewSize,
              screenSize: screenSize,
            );

            return Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFFFD60A), width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    color: const Color(0xCC000000),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      '${detection.label} ${(detection.confidence * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Color(0xFFFFD60A),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }

  Rect _mapDetectionToScreenRect({
    required Rect normalizedRect,
    required Size previewSize,
    required Size screenSize,
  }) {
    final double previewWidth = previewSize.height;
    final double previewHeight = previewSize.width;

    final double scale =
        (screenSize.width / previewWidth) > (screenSize.height / previewHeight)
            ? (screenSize.width / previewWidth)
            : (screenSize.height / previewHeight);

    final double displayWidth = previewWidth * scale;
    final double displayHeight = previewHeight * scale;

    final double dx = (screenSize.width - displayWidth) / 2;
    final double dy = (screenSize.height - displayHeight) / 2;

    final double left = dx + normalizedRect.left * displayWidth;
    final double top = dy + normalizedRect.top * displayHeight;
    final double width = normalizedRect.width * displayWidth;
    final double height = normalizedRect.height * displayHeight;

    return Rect.fromLTWH(left, top, width, height);
  }

  Widget _buildOverlay(BuildContext context, bool cameraReady) {
    if (_isInitializing) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD60A)));
    }

    if (!_hasPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Cần quyền Camera để sử dụng TakAura',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Vui lòng cấp quyền để hiển thị tầm nhìn thời gian thực.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: openAppSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD60A),
                  foregroundColor: Colors.black,
                  minimumSize: const Size(280, 68),
                  textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Mở Cài đặt quyền'),
              ),
            ],
          ),
        ),
      );
    }

    if (!cameraReady) {
      return Center(
        child: Text(
          'Không thể khởi tạo camera',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: Colors.black.withValues(alpha: 0.68),
              child: Text(
                _isDetecting
                    ? 'TakAura • AI đang phân tích theo thời gian thực'
                    : 'TakAura • Chạm màn hình hoặc nhấn nút lớn để kích hoạt',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFFFFD60A),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _toggleDetection,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isDetecting ? const Color(0xFFFF453A) : const Color(0xFFFFD60A),
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(92),
                textStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(_isDetecting ? 'Dừng Tầm nhìn Chim ưng' : 'Kích hoạt Tầm nhìn Chim ưng'),
            ),
          ],
        ),
      ),
    );
  }
}
