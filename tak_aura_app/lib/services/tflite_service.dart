import 'dart:developer';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class TFLiteService {
  TFLiteService({
    this.confidenceThreshold = 0.35,
    this.iouThreshold = 0.45,
  });

  Interpreter? _interpreter;
  List<String> _labels = <String>[];
  int _inputWidth = 640;
  int _inputHeight = 640;

  final double confidenceThreshold;
  final double iouThreshold;

  Interpreter? get interpreter => _interpreter;
  List<String> get labels => List<String>.unmodifiable(_labels);

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('assets/models/best_float16.tflite');
    final List<int> inputShape = _interpreter!.getInputTensor(0).shape;
    if (inputShape.length == 4) {
      _inputHeight = inputShape[1];
      _inputWidth = inputShape[2];
    }

    log('TFLite model loaded: assets/models/best_float16.tflite');
    log('Input shape: ${_interpreter!.getInputTensor(0).shape}');
    log('Output shape: ${_interpreter!.getOutputTensor(0).shape}');
  }

  Future<void> loadLabels() async {
    final String rawLabels = await rootBundle.loadString('assets/models/labels.txt');
    _labels = rawLabels
        .split('\n')
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList(growable: false);

    log('Labels loaded: ${_labels.length} classes');
  }

  Future<List<DetectionResult>> runInference(CameraImage image) async {
    if (_interpreter == null) {
      return const <DetectionResult>[];
    }

    final Float32List inputBuffer = _preprocessYuv420ToRgb(image);
    final List<List<List<List<double>>>> input =
        <List<List<List<double>>>>[_reshapeInput(inputBuffer, _inputHeight, _inputWidth)];

    final List<int> outputShape = _interpreter!.getOutputTensor(0).shape;
    final dynamic output = _createNestedList(outputShape);

    _interpreter!.run(input, output);

    final List<double> flatOutput = <double>[];
    _flattenOutput(output, flatOutput);

    final List<DetectionResult> detections = _parseYoloOutput(
      flatOutput: flatOutput,
      outputShape: outputShape,
    );

    return detections;
  }

  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
  }

  List<List<List<double>>> _reshapeInput(Float32List input, int h, int w) {
    int index = 0;
    final List<List<List<double>>> tensor = List<List<List<double>>>.generate(
      h,
      (int _) => List<List<double>>.generate(
        w,
        (int _) => List<double>.generate(3, (int _) => input[index++], growable: false),
        growable: false,
      ),
      growable: false,
    );

    return tensor;
  }

  Float32List _preprocessYuv420ToRgb(CameraImage image) {
    final int srcWidth = image.width;
    final int srcHeight = image.height;

    final Plane planeY = image.planes[0];
    final Plane planeU = image.planes[1];
    final Plane planeV = image.planes[2];

    final Float32List buffer = Float32List(_inputWidth * _inputHeight * 3);

    int outIndex = 0;
    for (int y = 0; y < _inputHeight; y++) {
      final int srcY = (y * srcHeight / _inputHeight).floor().clamp(0, srcHeight - 1);

      for (int x = 0; x < _inputWidth; x++) {
        final int srcX = (x * srcWidth / _inputWidth).floor().clamp(0, srcWidth - 1);

        final int yIndex = srcY * planeY.bytesPerRow + srcX;

        final int uvX = (srcX / 2).floor();
        final int uvY = (srcY / 2).floor();
        final int uIndex = uvY * planeU.bytesPerRow + uvX * planeU.bytesPerPixel!;
        final int vIndex = uvY * planeV.bytesPerRow + uvX * planeV.bytesPerPixel!;

        final int yValue = planeY.bytes[yIndex];
        final int uValue = planeU.bytes[uIndex];
        final int vValue = planeV.bytes[vIndex];

        final double yFloat = yValue.toDouble();
        final double uFloat = uValue.toDouble() - 128.0;
        final double vFloat = vValue.toDouble() - 128.0;

        double r = yFloat + 1.402 * vFloat;
        double g = yFloat - 0.344136 * uFloat - 0.714136 * vFloat;
        double b = yFloat + 1.772 * uFloat;

        r = r.clamp(0.0, 255.0);
        g = g.clamp(0.0, 255.0);
        b = b.clamp(0.0, 255.0);

        buffer[outIndex++] = (r / 255.0).toDouble();
        buffer[outIndex++] = (g / 255.0).toDouble();
        buffer[outIndex++] = (b / 255.0).toDouble();
      }
    }

    return buffer;
  }

  dynamic _createNestedList(List<int> shape) {
    if (shape.isEmpty) {
      return 0.0;
    }

    return List<dynamic>.generate(shape[0], (int _) => _createNestedList(shape.sublist(1)));
  }

  void _flattenOutput(dynamic value, List<double> out) {
    if (value is List) {
      for (final dynamic item in value) {
        _flattenOutput(item, out);
      }
      return;
    }

    if (value is num) {
      out.add(value.toDouble());
    }
  }

  List<DetectionResult> _parseYoloOutput({
    required List<double> flatOutput,
    required List<int> outputShape,
  }) {
    if (outputShape.length != 3 || outputShape[0] != 1) {
      return const <DetectionResult>[];
    }

    final int d1 = outputShape[1];
    final int d2 = outputShape[2];

    int candidateCount;
    int channelCount;
    bool channelFirst;

    if (d1 > d2) {
      channelFirst = true;
      channelCount = d1;
      candidateCount = d2;
    } else {
      channelFirst = false;
      candidateCount = d1;
      channelCount = d2;
    }

    if (channelCount < 6) {
      return const <DetectionResult>[];
    }

    final int classCount = channelCount - 4;
    final List<DetectionResult> detections = <DetectionResult>[];

    for (int i = 0; i < candidateCount; i++) {
      final double cx = channelFirst ? flatOutput[0 * candidateCount + i] : flatOutput[i * channelCount + 0];
      final double cy = channelFirst ? flatOutput[1 * candidateCount + i] : flatOutput[i * channelCount + 1];
      final double w = channelFirst ? flatOutput[2 * candidateCount + i] : flatOutput[i * channelCount + 2];
      final double h = channelFirst ? flatOutput[3 * candidateCount + i] : flatOutput[i * channelCount + 3];

      int bestClass = -1;
      double bestScore = 0.0;

      for (int c = 0; c < classCount; c++) {
        final int channelIndex = 4 + c;
        final double score =
            channelFirst ? flatOutput[channelIndex * candidateCount + i] : flatOutput[i * channelCount + channelIndex];

        if (score > bestScore) {
          bestScore = score;
          bestClass = c;
        }
      }

      if (bestClass < 0 || bestScore < confidenceThreshold) {
        continue;
      }

      double normCx = cx;
      double normCy = cy;
      double normW = w;
      double normH = h;

      if (normCx > 1 || normCy > 1 || normW > 1 || normH > 1) {
        normCx /= _inputWidth;
        normCy /= _inputHeight;
        normW /= _inputWidth;
        normH /= _inputHeight;
      }

      final double left = (normCx - normW / 2).clamp(0.0, 1.0);
      final double top = (normCy - normH / 2).clamp(0.0, 1.0);
      final double right = (normCx + normW / 2).clamp(0.0, 1.0);
      final double bottom = (normCy + normH / 2).clamp(0.0, 1.0);

      final Rect box = Rect.fromLTRB(left, top, right, bottom);
      if (box.width <= 0 || box.height <= 0) {
        continue;
      }

      final String label = bestClass < _labels.length ? _labels[bestClass] : 'class_$bestClass';

      detections.add(
        DetectionResult(
          classIndex: bestClass,
          label: label,
          confidence: bestScore,
          boundingBox: box,
        ),
      );
    }

    detections.sort((DetectionResult a, DetectionResult b) => b.confidence.compareTo(a.confidence));
    return _applyNms(detections);
  }

  List<DetectionResult> _applyNms(List<DetectionResult> detections) {
    final List<DetectionResult> selected = <DetectionResult>[];

    for (final DetectionResult candidate in detections) {
      bool keep = true;
      for (final DetectionResult existing in selected) {
        if (candidate.classIndex != existing.classIndex) {
          continue;
        }
        if (_iou(candidate.boundingBox, existing.boundingBox) > iouThreshold) {
          keep = false;
          break;
        }
      }

      if (keep) {
        selected.add(candidate);
      }
    }

    return selected.take(20).toList(growable: false);
  }

  double _iou(Rect a, Rect b) {
    final Rect intersection = a.intersect(b);
    final double interArea = math.max(0.0, intersection.width) * math.max(0.0, intersection.height);
    if (interArea <= 0.0) {
      return 0.0;
    }

    final double unionArea = a.width * a.height + b.width * b.height - interArea;
    if (unionArea <= 0.0) {
      return 0.0;
    }

    return interArea / unionArea;
  }
}

class DetectionResult {
  const DetectionResult({
    required this.classIndex,
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });

  final int classIndex;
  final String label;
  final double confidence;
  final Rect boundingBox;
}
