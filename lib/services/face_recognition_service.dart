import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  // Persistent cache path (survives app restarts, unlike tmp)
  static const _cachedModelName = 'mobilefacenet_cached.tflite';

  /// Load and cache the TFLite model. Resolution order:
  ///   1. Persistent document-directory cache (fastest on repeat launches)
  ///   2. Supabase Storage bucket "models" (download on demand, then cache)
  ///   3. Bundled asset as last resort (requires file to exist in assets/)
  ///
  /// Safe to call multiple times — subsequent calls return immediately.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final docDir    = await getApplicationDocumentsDirectory();
    final cacheFile = File('${docDir.path}/$_cachedModelName');

    // ── 1. Use existing on-device cache ──────────────────────────────────
    if (await cacheFile.exists()) {
      _modelTempPath  = cacheFile.path;
      _modelAvailable = true;
      return;
    }

    // ── 2. Download from Supabase Storage ────────────────────────────────
    try {
      final bytes = await Supabase.instance.client.storage
          .from('models')
          .download('MobileFaceNet.tflite');
      await cacheFile.writeAsBytes(bytes);
      _modelTempPath  = cacheFile.path;
      _modelAvailable = true;
      return;
    } catch (_) {
      // Storage unavailable or model not uploaded yet — fall through
    }

    // ── 3. Fall back to bundled asset ─────────────────────────────────────
    try {
      final byteData =
          await rootBundle.load('assets/models/MobileFaceNet.tflite');
      final bytes = byteData.buffer.asUint8List();
      // Write to cache so future launches skip this path
      await cacheFile.writeAsBytes(bytes);
      _modelTempPath  = cacheFile.path;
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
