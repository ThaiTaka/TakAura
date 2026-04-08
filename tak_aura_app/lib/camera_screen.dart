import 'dart:math' as math;

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

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  final TFLiteService _tfliteService = TFLiteService();
  final ValueNotifier<List<DetectionResult>> _detectionsNotifier =
      ValueNotifier<List<DetectionResult>>(<DetectionResult>[]);

  static const int _minInferenceIntervalMs = 75;
  static const int _overlayUpdateIntervalMs = 45;
  static const int _hudUpdateIntervalMs = 220;
  static const int _trackHoldMs = 1200;
  static const int _predictionLeadMs = 260;
  static const double _trackIoUStickiness = 0.18;
  static const double _positionSmoothingAlpha = 0.24;
  static const double _confidenceSmoothingAlpha = 0.35;
  static const double _moneyAspectTarget = 2.1;
  static const Set<String> _moneyLabels = <String>{
    '500',
    '1000',
    '2000',
    '5000',
    '10000',
    '20000',
    '50000',
    '100000',
    '200000',
    '500000',
  };

  CameraController? _cameraController;
  bool _isInitializing = true;
  bool _isDisposed = false;
  bool _hasPermission = false;
  bool _isDetecting = false;
  bool _isProcessingFrame = false;
  bool _isModelReady = false;
  CameraDescription? _selectedCamera;
  DateTime? _lastInferenceAt;
  DateTime? _lastOverlayUpdateAt;
  DateTime? _lastHudUpdateAt;
  int _lastInferenceMs = 0;
  int _lastDetectionCount = 0;
  String _lastDetectionLabel = 'Chưa thấy tiền';
  DetectionResult? _stableMoneyDetection;
  DateTime? _lastMoneySeenAt;
  String? _pendingLabel;
  int _pendingLabelHits = 0;
  int _moneyMissStreak = 0;
  final _MotionBoxFilter _motionFilter = _MotionBoxFilter();

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

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
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
      (CameraDescription camera) =>
          camera.lensDirection == CameraLensDirection.back,
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
      ResolutionPreset.medium,
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
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isStreamingImages) {
      return;
    }

    await controller.startImageStream((CameraImage image) async {
      if (_isProcessingFrame || !_isDetecting) {
        return;
      }

      final DateTime now = DateTime.now();
      if (_lastInferenceAt != null &&
          now.difference(_lastInferenceAt!).inMilliseconds <
              _minInferenceIntervalMs) {
        return;
      }
      _lastInferenceAt = now;

      _isProcessingFrame = true;
      try {
        final Stopwatch stopwatch = Stopwatch()..start();
        final List<DetectionResult> rawDetections =
            await _tfliteService.runInference(image);
        stopwatch.stop();
        final List<DetectionResult> detections =
            _refineMoneyDetections(rawDetections);
        if (!mounted || _isDisposed || !_isDetecting) {
          return;
        }
        final DateTime uiNow = DateTime.now();
        final bool shouldRefreshOverlay = _lastOverlayUpdateAt == null ||
            uiNow.difference(_lastOverlayUpdateAt!).inMilliseconds >=
                _overlayUpdateIntervalMs;
        if (shouldRefreshOverlay) {
          _lastOverlayUpdateAt = uiNow;
          if (!_isDisposed) {
            _detectionsNotifier.value = detections;
          }
        }

        final bool shouldRefreshHud = _lastHudUpdateAt == null ||
            uiNow.difference(_lastHudUpdateAt!).inMilliseconds >=
                _hudUpdateIntervalMs;
        if (shouldRefreshHud) {
          _lastHudUpdateAt = uiNow;
          setState(() {
            _lastInferenceMs = stopwatch.elapsedMilliseconds;
            _lastDetectionCount = detections.length;
            _lastDetectionLabel = detections.isNotEmpty
                ? detections.first.label
                : 'Chưa thấy tiền';
          });
        }
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
    _lastInferenceAt = null;
    _lastOverlayUpdateAt = null;
    _lastHudUpdateAt = null;
    if (!_isDisposed) {
      _detectionsNotifier.value = <DetectionResult>[];
    }
    _stableMoneyDetection = null;
    _lastMoneySeenAt = null;
    _pendingLabel = null;
    _pendingLabelHits = 0;
    _motionFilter.reset();
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
          content:
              Text('Mô hình AI chưa sẵn sàng. Vui lòng chờ thêm một chút.'),
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
        _lastDetectionCount = 0;
        _lastDetectionLabel = 'Chưa thấy tiền';
      });
      return;
    }

    setState(() {
      _isDetecting = true;
    });

    await _startImageStream();
  }

  List<DetectionResult> _refineMoneyDetections(
      List<DetectionResult> rawDetections) {
    final DateTime now = DateTime.now();
    final double minArea = _moneyMissStreak >= 4 ? 0.0035 : 0.010;

    final List<DetectionResult> moneyDetections = rawDetections
        .where((DetectionResult detection) =>
        _moneyLabels.contains(_canonicalMoneyLabel(detection.label)) ||
            _isLikelyMoneyLabel(detection.label))
      .map(_normalizeMoneyOrientation)
        .where((DetectionResult detection) =>
            detection.boundingBox.width * detection.boundingBox.height >=
            minArea)
        .toList(growable: false);

    if (moneyDetections.isEmpty) {
      _moneyMissStreak += 1;
      if (_stableMoneyDetection != null && _lastMoneySeenAt != null) {
        final int missingMs =
            now.difference(_lastMoneySeenAt!).inMilliseconds;
        if (missingMs <= _trackHoldMs) {
          final Rect predictedRect = _motionFilter.predict(
            at: now,
            maxLeadMs: _predictionLeadMs,
          );
          final double decayFactor =
              (1.0 - (missingMs / _trackHoldMs)).clamp(0.25, 1.0);
          final DetectionResult decayed = DetectionResult(
            classIndex: _stableMoneyDetection!.classIndex,
            label: _stableMoneyDetection!.label,
            confidence: _stableMoneyDetection!.confidence * decayFactor,
            boundingBox: predictedRect,
          );
          _stableMoneyDetection = decayed;
          return <DetectionResult>[decayed];
        }
      }
      _stableMoneyDetection = null;
      return const <DetectionResult>[];
    }

    _moneyMissStreak = 0;

    DetectionResult candidate = moneyDetections.first;
    double bestScore = _moneyCandidateScore(candidate);
    for (final DetectionResult detection in moneyDetections.skip(1)) {
      final double score = _moneyCandidateScore(detection);
      if (score > bestScore) {
        bestScore = score;
        candidate = detection;
      }
    }

    if (_stableMoneyDetection != null &&
        candidate.label != _stableMoneyDetection!.label) {
      if (_pendingLabel != candidate.label) {
        _pendingLabel = candidate.label;
        _pendingLabelHits = 1;
        candidate = _stableMoneyDetection!;
      } else {
        _pendingLabelHits += 1;
        if (_pendingLabelHits < 3) {
          candidate = _stableMoneyDetection!;
        } else {
          _pendingLabel = null;
          _pendingLabelHits = 0;
        }
      }
    } else {
      _pendingLabel = null;
      _pendingLabelHits = 0;
    }

    if (_stableMoneyDetection != null &&
        candidate.label == _stableMoneyDetection!.label) {
      final double movement = _rectCenterDistance(
          _stableMoneyDetection!.boundingBox, candidate.boundingBox);
      final double adaptiveAlpha = movement > 0.08
          ? 0.36
          : (movement > 0.04 ? 0.30 : _positionSmoothingAlpha);
      final Rect smoothedRect = Rect.fromLTRB(
        _lerp(_stableMoneyDetection!.boundingBox.left,
          candidate.boundingBox.left, adaptiveAlpha),
        _lerp(_stableMoneyDetection!.boundingBox.top, candidate.boundingBox.top,
          adaptiveAlpha),
        _lerp(_stableMoneyDetection!.boundingBox.right,
          candidate.boundingBox.right, adaptiveAlpha),
        _lerp(_stableMoneyDetection!.boundingBox.bottom,
          candidate.boundingBox.bottom, adaptiveAlpha),
      );

      candidate = DetectionResult(
        classIndex: candidate.classIndex,
        label: candidate.label,
        confidence: _lerp(
          _stableMoneyDetection!.confidence,
          candidate.confidence,
          _confidenceSmoothingAlpha),
        boundingBox: smoothedRect,
      );
    }

    final Rect motionRect = _motionFilter.update(
      measurement: candidate.boundingBox,
      at: now,
    );
    candidate = DetectionResult(
      classIndex: candidate.classIndex,
      label: candidate.label,
      confidence: candidate.confidence,
      boundingBox: motionRect,
    );

    _stableMoneyDetection = candidate;
    _lastMoneySeenAt = now;

    return <DetectionResult>[candidate];
  }

  double _lerp(double from, double to, double alpha) {
    return from + (to - from) * alpha;
  }

  bool _isLikelyMoneyLabel(String label) {
    return double.tryParse(_canonicalMoneyLabel(label)) != null;
  }

  String _canonicalMoneyLabel(String label) {
    return label
        .replaceAll(RegExp(r'[^0-9]'), '')
        .trim();
  }

  double _moneyCandidateScore(DetectionResult detection) {
    final Rect box = detection.boundingBox;
    final double area = (box.width * box.height).clamp(0.0, 1.0);
    final double normalizedArea = (area / 0.25).clamp(0.0, 1.0);

    final double aspect =
        box.height > 0 ? (box.width / box.height).clamp(0.1, 10.0) : 0.1;
    final double aspectDelta = (aspect - _moneyAspectTarget).abs();
    final double aspectScore = (1.0 - (aspectDelta / 1.4)).clamp(0.0, 1.0);

    final double margin = [box.left, box.top, 1 - box.right, 1 - box.bottom]
        .reduce((double a, double b) => a < b ? a : b);
    final double edgePenalty = margin < 0.02 ? 0.2 : 0.0;

    double trackingBonus = 0.0;
    if (_stableMoneyDetection != null &&
        detection.label == _stableMoneyDetection!.label) {
      final double overlap = _iou(box, _stableMoneyDetection!.boundingBox);
      trackingBonus = overlap >= _trackIoUStickiness ? overlap * 0.20 : 0.0;
    }

    return detection.confidence * 0.55 +
        normalizedArea * 0.30 +
        aspectScore * 0.15 -
        edgePenalty +
        trackingBonus;
  }

  DetectionResult _normalizeMoneyOrientation(DetectionResult detection) {
    final Rect original = detection.boundingBox;
    final Rect rotateCw = _rotateRect90Cw(original);
    final Rect rotateCcw = _rotateRect90Ccw(original);

    Rect bestRect = original;
    double bestScore = _orientationScore(original);

    final double cwScore = _orientationScore(rotateCw);
    if (cwScore > bestScore) {
      bestScore = cwScore;
      bestRect = rotateCw;
    }

    final double ccwScore = _orientationScore(rotateCcw);
    if (ccwScore > bestScore) {
      bestRect = rotateCcw;
    }

    if (bestRect == original) {
      return detection;
    }

    return DetectionResult(
      classIndex: detection.classIndex,
      label: detection.label,
      confidence: detection.confidence,
      boundingBox: bestRect,
    );
  }

  double _orientationScore(Rect rect) {
    final double width = rect.width.clamp(0.001, 1.0);
    final double height = rect.height.clamp(0.001, 1.0);
    final double aspect = (width / height).clamp(0.1, 10.0);
    final double aspectDelta = (aspect - _moneyAspectTarget).abs();
    final double aspectScore = (1.0 - (aspectDelta / 1.4)).clamp(0.0, 1.0);

    double trackScore = 0.0;
    if (_stableMoneyDetection != null) {
      trackScore = _iou(rect, _stableMoneyDetection!.boundingBox).clamp(0.0, 1.0);
    }

    return aspectScore * 0.70 + trackScore * 0.30;
  }

  Rect _rotateRect90Cw(Rect rect) {
    final double left = (1.0 - rect.bottom).clamp(0.0, 1.0);
    final double top = rect.left.clamp(0.0, 1.0);
    final double right = (1.0 - rect.top).clamp(0.0, 1.0);
    final double bottom = rect.right.clamp(0.0, 1.0);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  Rect _rotateRect90Ccw(Rect rect) {
    final double left = rect.top.clamp(0.0, 1.0);
    final double top = (1.0 - rect.right).clamp(0.0, 1.0);
    final double right = rect.bottom.clamp(0.0, 1.0);
    final double bottom = (1.0 - rect.left).clamp(0.0, 1.0);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  double _iou(Rect a, Rect b) {
    final Rect intersection = a.intersect(b);
    final double interArea =
        intersection.width.clamp(0.0, 1.0) * intersection.height.clamp(0.0, 1.0);
    if (interArea <= 0.0) {
      return 0.0;
    }

    final double unionArea = a.width * a.height + b.width * b.height - interArea;
    if (unionArea <= 0.0) {
      return 0.0;
    }

    return interArea / unionArea;
  }

  double _rectCenterDistance(Rect a, Rect b) {
    final double ax = (a.left + a.right) * 0.5;
    final double ay = (a.top + a.bottom) * 0.5;
    final double bx = (b.left + b.right) * 0.5;
    final double by = (b.top + b.bottom) * 0.5;
    final double dx = ax - bx;
    final double dy = ay - by;
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _stopImageStream();
    _detectionsNotifier.dispose();
    _tfliteService.dispose();
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool cameraReady = _hasPermission &&
        _cameraController != null &&
        _cameraController!.value.isInitialized;

    return Scaffold(
      body: GestureDetector(
        onTap: _toggleDetection,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (cameraReady)
              RepaintBoundary(child: CameraPreview(_cameraController!))
            else
              Container(color: const Color(0xFF050505)),
            if (cameraReady && _isDetecting)
              ValueListenableBuilder<List<DetectionResult>>(
                valueListenable: _detectionsNotifier,
                builder: (
                  BuildContext context,
                  List<DetectionResult> detections,
                  Widget? child,
                ) {
                  if (detections.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return _buildDetectionsOverlay(_cameraController!, detections);
                },
              ),
            _buildOverlay(context, cameraReady),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionsOverlay(
      CameraController controller, List<DetectionResult> detections) {
    final Size? previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size screenSize =
            Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          children: detections.map((DetectionResult detection) {
            final Rect rect = _mapDetectionToScreenRect(
              normalizedRect: detection.boundingBox,
              previewSize: previewSize,
              screenSize: screenSize,
            );

            return AnimatedPositioned(
              key: ValueKey<String>('${detection.label}_${detection.classIndex}'),
              duration: const Duration(milliseconds: 60),
              curve: Curves.linear,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

    return Rect.fromLTWH(left, top, width, height).intersect(
      Rect.fromLTWH(0, 0, screenSize.width, screenSize.height),
    );
  }

  Widget _buildOverlay(BuildContext context, bool cameraReady) {
    if (_isInitializing) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFFD60A)));
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
                  textStyle: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
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
                    ? 'TakAura • AI đang phân tích theo thời gian thực\n$_lastInferenceMs ms • $_lastDetectionCount khung • $_lastDetectionLabel'
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
                backgroundColor: _isDetecting
                    ? const Color(0xFFFF453A)
                    : const Color(0xFFFFD60A),
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(92),
                textStyle:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(_isDetecting
                  ? 'Dừng Tầm nhìn Chim ưng'
                  : 'Kích hoạt Tầm nhìn Chim ưng'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MotionBoxFilter {
  Rect? _lastRect;
  DateTime? _lastTime;
  double _vx = 0.0;
  double _vy = 0.0;
  double _vw = 0.0;
  double _vh = 0.0;

  Rect update({required Rect measurement, required DateTime at}) {
    final Rect next = _clampRect(measurement);
    if (_lastRect == null || _lastTime == null) {
      _lastRect = next;
      _lastTime = at;
      return next;
    }

    final double dtMs =
        (at.difference(_lastTime!).inMilliseconds).clamp(1, 120).toDouble();
    final double dt = dtMs / 1000.0;

    final double prevCx = (_lastRect!.left + _lastRect!.right) * 0.5;
    final double prevCy = (_lastRect!.top + _lastRect!.bottom) * 0.5;
    final double prevW = _lastRect!.width;
    final double prevH = _lastRect!.height;

    final double measCx = (next.left + next.right) * 0.5;
    final double measCy = (next.top + next.bottom) * 0.5;
    final double measW = next.width;
    final double measH = next.height;

    final double instVx = (measCx - prevCx) / dt;
    final double instVy = (measCy - prevCy) / dt;
    final double instVw = (measW - prevW) / dt;
    final double instVh = (measH - prevH) / dt;

    const double velocityAlpha = 0.30;
    _vx = _vx + (instVx - _vx) * velocityAlpha;
    _vy = _vy + (instVy - _vy) * velocityAlpha;
    _vw = _vw + (instVw - _vw) * velocityAlpha;
    _vh = _vh + (instVh - _vh) * velocityAlpha;

    final Rect predicted = _predictRect(_lastRect!, dt);

    const double blendAlpha = 0.45;
    final Rect fused = Rect.fromLTRB(
      _lerp(predicted.left, next.left, blendAlpha),
      _lerp(predicted.top, next.top, blendAlpha),
      _lerp(predicted.right, next.right, blendAlpha),
      _lerp(predicted.bottom, next.bottom, blendAlpha),
    );

    final Rect clamped = _clampRect(fused);
    _lastRect = clamped;
    _lastTime = at;
    return clamped;
  }

  Rect predict({required DateTime at, required int maxLeadMs}) {
    if (_lastRect == null || _lastTime == null) {
      return const Rect.fromLTRB(0, 0, 0, 0);
    }

    final int dtMsRaw = at.difference(_lastTime!).inMilliseconds;
    final double dt = dtMsRaw.clamp(0, maxLeadMs).toDouble() / 1000.0;
    return _clampRect(_predictRect(_lastRect!, dt));
  }

  void reset() {
    _lastRect = null;
    _lastTime = null;
    _vx = 0.0;
    _vy = 0.0;
    _vw = 0.0;
    _vh = 0.0;
  }

  Rect _predictRect(Rect rect, double dt) {
    final double cx = (rect.left + rect.right) * 0.5 + _vx * dt;
    final double cy = (rect.top + rect.bottom) * 0.5 + _vy * dt;
    final double width = (rect.width + _vw * dt).clamp(0.02, 1.0);
    final double height = (rect.height + _vh * dt).clamp(0.02, 1.0);

    return Rect.fromCenter(
      center: Offset(cx, cy),
      width: width,
      height: height,
    );
  }

  Rect _clampRect(Rect rect) {
    final double left = rect.left.clamp(0.0, 1.0);
    final double top = rect.top.clamp(0.0, 1.0);
    final double right = rect.right.clamp(0.0, 1.0);
    final double bottom = rect.bottom.clamp(0.0, 1.0);
    if (right <= left || bottom <= top) {
      return _lastRect ?? const Rect.fromLTRB(0, 0, 0, 0);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  double _lerp(double from, double to, double alpha) {
    return from + (to - from) * alpha;
  }
}
