import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../engine/doc_parser.dart';
import '../engine/kyc.dart';

/// On-device OCR (Google ML Kit). Images never leave the phone, and every
/// temporary file is deleted as soon as the text is read.
class OcrService {
  /// Developer builds only (--dart-define=EKKO_OCR_DEBUG=true); never in the shared APK.
  static const _debug = bool.fromEnvironment('EKKO_OCR_DEBUG');
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _parser = DocParser();

  Future<ExtractedDoc> readFile(DocType type, File file, {bool deleteAfter = true}) async {
    try {
      final result = await _recognizer.processImage(InputImage.fromFile(file));
      final lines = <OcrLine>[];
      for (final block in result.blocks) {
        for (final line in block.lines) {
          final c = line.cornerPoints;
          if (c.length < 4) continue;
          lines.add(OcrLine(line.text, [for (final pt in c) Point(pt.x.toDouble(), pt.y.toDouble())]));
        }
      }
      if (_debug) {
        for (final l in lines) {
          // ignore: avoid_print
          print('OCR ${type.name} [${l.angleDegrees.toStringAsFixed(1)}] '
              '(${l.corners[0].x.round()},${l.corners[0].y.round()}) ${l.text}');
        }
      }
      return _parser.parse(type, lines);
    } finally {
      if (deleteAfter && await file.exists()) await file.delete();
    }
  }

  /// Specimen images bundled from the case pack (K01–K12).
  Future<ExtractedDoc> readSample(DocType type, String applicant) async {
    final name = '${applicant}_${_sampleSuffix(type)}.png';
    final bytes = await rootBundle.load('assets/samples/$name');
    final dir = await getTemporaryDirectory();
    final f = File(p.join(dir.path, 'ocr_${DateTime.now().microsecondsSinceEpoch}_$name'));
    await f.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return readFile(type, f);
  }

  static Future<bool> sampleExists(DocType type, String applicant) async {
    try {
      await rootBundle.load('assets/samples/${applicant}_${_sampleSuffix(type)}.png');
      return true;
    } catch (_) {
      return false;
    }
  }

  static String _sampleSuffix(DocType t) => const {
        DocType.gstCertificate: 'gst_certificate',
        DocType.udyamCertificate: 'udyam_certificate',
        DocType.signatoryId: 'signatory_id',
        DocType.addressProof: 'address_proof',
      }[t]!;

  void dispose() => _recognizer.close();
}
