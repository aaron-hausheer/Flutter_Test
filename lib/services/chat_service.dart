// lib/services/chat_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ChatService {
  static const String _kUrlKey = 'ai_server_url';
  static const String _kKeyKey = 'ai_api_key';
  static const String _kModelKey = 'ai_model';

  /// Liest Settings (URL/Key/Modell) aus SharedPreferences.
  static Future<({Uri? url, String apiKey, String model})> _loadConfig() async {
    final sp = await SharedPreferences.getInstance();
    final raw = (sp.getString(_kUrlKey) ?? 'http://localhost:8081/chat').trim();
    final apiKey = (sp.getString(_kKeyKey) ?? '').trim();
    final model  = (sp.getString(_kModelKey) ?? 'gpt-4o-mini').trim();
    Uri? url;
    try { url = Uri.parse(raw); } catch (_) { url = null; }
    return (url: url, apiKey: apiKey, model: model);
  }

  /// Schickt eine Unterhaltung an dein Chat-Backend.
  /// Unterstützt:
  /// - OpenAI-kompatibel (/v1/chat/completions)
  /// - „einfaches“ Endpoint (z.B. dein lokaler Server unter /chat), das {message: "..."} zurückgibt
  Future<String> send(List<Map<String, String>> messages) async {
    final conf = await _loadConfig();
    if (conf.url == null) {
      throw Exception('Ungültige Server-URL in den Einstellungen.');
    }

    // Header bauen
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (conf.apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${conf.apiKey}';
    }

    // Body (OpenAI-kompatibel)
    final body = jsonEncode({
      'model': conf.model,
      'messages': messages,
      'stream': false,
      // Falls dein eigener Server andere Felder erwartet, hier ggf. anpassen
    });

    final res = await http.post(conf.url!, headers: headers, body: body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Chat-Server Fehler ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body);

    // 1) OpenAI-kompatibel
    if (data is Map && data['choices'] is List && (data['choices'] as List).isNotEmpty) {
      final choice0 = data['choices'][0];
      final msg = (choice0['message'] ?? {}) as Map<String, dynamic>;
      final content = (msg['content'] ?? '').toString();
      if (content.isNotEmpty) return content;
    }

    // 2) Alternativ: sehr simples Schema
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    if (data is Map && data['reply'] != null) {
      return data['reply'].toString();
    }
    if (data is Map && data['content'] != null) {
      return data['content'].toString();
    }

    // 3) Letzter Fallback
    return res.body.toString();
  }
}
