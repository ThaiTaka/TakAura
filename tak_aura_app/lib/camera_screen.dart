import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.cameras});

  final List<CameraDescription> cameras;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isInitializing = true;
  bool _hasPermission = false;
  CameraDescription? _selectedCamera;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupCameraFlow();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_selectedCamera == null) {
      return;
    }

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
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
    final CameraController? oldController = _cameraController;
    _cameraController = null;
    if (oldController != null) {
      await oldController.dispose();
    }
  }

  Future<void> _handleVisionActivation() async {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã kích hoạt chế độ Tầm nhìn Chim ưng (UI demo).'),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool cameraReady =
        _hasPermission && _cameraController != null && _cameraController!.value.isInitialized;

    return Scaffold(
      body: GestureDetector(
        onTap: _handleVisionActivation,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (cameraReady)
              CameraPreview(_cameraController!)
            else
              Container(color: const Color(0xFF050505)),
            _buildOverlay(context, cameraReady),
          ],
        ),
      ),
    );
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
              color: Colors.black.withOpacity(0.68),
              child: Text(
                'TakAura • Chạm màn hình hoặc nhấn nút lớn để kích hoạt',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFFFFD60A),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _handleVisionActivation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD60A),
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(92),
                textStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: const Text('Kích hoạt Tầm nhìn Chim ưng'),
            ),
          ],
        ),
      ),
    );
  }
}
