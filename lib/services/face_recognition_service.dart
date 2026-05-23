import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  FaceRecognitionService
//
//  On-device face embedding comparison using MobileFaceNet (TFLite).
//  Inference runs inside a compute() isolate so the UI thread is never blocked.
//
//  Model spec:
//    Input : [1, 112, 112, 3]  float32  — normalised (pixel − 127.5) / 127.5
//    Output: [1, 128]          float32  — L2-normalised face embedding
//
//  Similarity: cosine_similarity(embA, embB)
//    ≥ 0.65  → Match confirmed
//    ≥ 0.40  → Possible match (review manually)
//    < 0.40  → No match
//
//  Model file required at: assets/models/MobileFaceNet.tflite
// ═══════════════════════════════════════════════════════════════════════════════

class FaceMatchResult {
  final double? score;
  final bool matched;
  final String? error;
  const FaceMatchResult({this.score, required this.matched, this.error});
}

class FaceRecognitionService {
  static bool _initialized = false;
  static bool _modelAvailable = false;

  /// Absolute path to the model in the temp directory — passed to compute().
  static String? _modelTempPath;

  /// Load and cache the TFLite model from assets. Safe to call multiple times.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      // Load model bytes via rootBundle (main isolate only)
      final byteData =
          await rootBundle.load('assets/models/MobileFaceNet.tflite');
      final bytes = byteData.buffer.asUint8List();

      // Write to a temp file so compute() isolates can load it via fromFile()
      final tmpDir = await getTemporaryDirectory();
      final tmpFile = File('${tmpDir.path}/mobilefacenet.tflite');
      await tmpFile.writeAsBytes(bytes);
      _modelTempPath = tmpFile.path;
      _modelAvailable = true;
    } catch (_) {
      _modelAvailable = false;
    }
  }

  static bool get isAvailable => _modelAvailable;

  /// Compare two face images and return a [FaceMatchResult].
  /// Inference runs in a background isolate via [compute].
  static Future<FaceMatchResult> compareFaces({
    required Uint8List idFaceBytes,
    required Uint8List selfieBytes,
  }) async {
    if (!_modelAvailable || _modelTempPath == null) {
      return const FaceMatchResult(
        score: null,
        matched: false,
        error: 'Face recognition model not available.',
      );
    }

    try {
      final score = await compute(_isolateCompare, <String, Object>{
        'modelPath': _modelTempPath!,
        'idBytes': idFaceBytes,
        'selfieBytes': selfieBytes,
      });

      if (score == null) {
        return const FaceMatchResult(
          score: null,
          matched: false,
          error: 'Could not generate embedding from one or both images.',
        );
      }

      return FaceMatchResult(score: score, matched: score >= 0.65);
    } catch (e) {
      return FaceMatchResult(score: null, matched: false, error: 'Error: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Top-level functions — must be top-level to be passed to compute()
// ═══════════════════════════════════════════════════════════════════════════════

/// Entry point for the compute() isolate.
double? _isolateCompare(Map<String, Object> args) {
  final modelPath = args['modelPath'] as String;
  final idBytes = args['idBytes'] as Uint8List;
  final selfieBytes = args['selfieBytes'] as Uint8List;

  Interpreter? interpreter;
  try {
    interpreter = Interpreter.fromFile(File(modelPath));
    final embA = _isolateEmbedding(interpreter, idBytes);
    final embB = _isolateEmbedding(interpreter, selfieBytes);
    if (embA == null || embB == null) return null;
    return _cosineSimilarity(embA, embB);
  } catch (_) {
    return null;
  } finally {
    interpreter?.close();
  }
}

/// Decode → resize to 112×112 → normalise → run MobileFaceNet.
List<double>? _isolateEmbedding(Interpreter interpreter, Uint8List imageBytes) {
  try {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return null;
    final resized = img.copyResize(decoded, width: 112, height: 112);

    // Build [1][112][112][3] input tensor
    final input = List.generate(
      1,
      (_) => List.generate(
        112,
        (y) => List.generate(
          112,
          (x) {
            final px = resized.getPixel(x, y);
            return [
              (px.r.toDouble() - 127.5) / 127.5,
              (px.g.toDouble() - 127.5) / 127.5,
              (px.b.toDouble() - 127.5) / 127.5,
            ];
          },
        ),
      ),
    );

    final output = [List<double>.filled(128, 0.0)];
    interpreter.run(input, output);
    return List<double>.from(output[0]);
  } catch (_) {
    return null;
  }
}

/// Cosine similarity in [-1, 1].
double _cosineSimilarity(List<double> a, List<double> b) {
  double dot = 0.0, nA = 0.0, nB = 0.0;
  for (int i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    nA += a[i] * a[i];
    nB += b[i] * b[i];
  }
  if (nA == 0.0 || nB == 0.0) return 0.0;
  return dot / (sqrt(nA) * sqrt(nB));
}
