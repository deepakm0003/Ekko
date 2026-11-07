import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Client for the Ekko AI backend. The AI only understands free text and
/// writes explanations; prices and eligibility always come from the on-device
/// engine. Every call fails soft (returns null) so the app falls back offline.
class AdvisorBackend {
  static const baseUrl = String.fromEnvironment('EKKO_API', defaultValue: '');
  static const _appKey = String.fromEnvironment('EKKO_APP_KEY', defaultValue: '');
  static const _timeout = Duration(seconds: 12);

  bool? _healthy;
  bool get configured => baseUrl.startsWith('https://');
  bool get online => _healthy == true;

  Map<String, String> get _headers => {'Content-Type': 'application/json', 'X-Ekko-App-Key': _appKey};

  Future<bool> checkHealth() async {
    if (!configured) return _healthy = false;
    try {
      final r = await http.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 6));
      return _healthy = r.statusCode == 200;
    } catch (_) {
      return _healthy = false;
    }
  }

  Future<Map<String, dynamic>?> _post(String path, Map<String, dynamic> body) async {
    if (!configured || _healthy == false) return null;
    try {
      final r = await http
          .post(Uri.parse('$baseUrl$path'), headers: _headers, body: jsonEncode(body))
          .timeout(_timeout);
      if (r.statusCode != 200) return null;
      return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Understand a free-text answer (any language) for the current question.
  /// Returns profile fields, e.g. {"employees": 12, "city": "Pune"}.
  Future<Map<String, dynamic>?> understand(
      {required String step, required String text, required String language, required Map<String, dynamic> profile}) async {
    final r = await _post('/v1/advisor/understand',
        {'step': step, 'text': text, 'language': language, 'profile': profile});
    return r?['fields'] as Map<String, dynamic>?;
  }

  /// Plain-language explanation of an already-validated bundle.
  Future<String?> explain(
      {required String language, required Map<String, dynamic> profile, required List<Map<String, dynamic>> items,
      required int monthly, required List<String> notices}) async {
    final r = await _post('/v1/advisor/explain', {
      'language': language,
      'profile': profile,
      'items': items,
      'monthly': monthly,
      'notices': notices,
    });
    return r?['text'] as String?;
  }

  /// Free-form question ("what is a static IP?") answered in the owner's language.
  Future<String?> ask({required String language, required String question, Map<String, dynamic>? context}) async {
    final r = await _post('/v1/advisor/ask', {'language': language, 'question': question, 'context': context ?? {}});
    return r?['text'] as String?;
  }
}
