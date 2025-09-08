import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// ==== HIER DEINE FESTEN WERTE EINTRAGEN ====
/// OpenRouter Chat Completions Endpoint:
const String kChatEndpoint = 'https://openrouter.ai/api/v1/chat/completions';

/// Dein OpenRouter API-Key (im Code = öffentlich! Nur zu Testen/Prototyping verwenden)
const String kOpenRouterApiKey = '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';

/// Ein Model-Slug von OpenRouter (z.B. 'openai/gpt-4o-mini', 'anthropic/claude-3.5-sonnet')
const String kModelSlug = 'openai/gpt-3.5-turbo';

/// Optional, schöne Metadaten (werden bei Web akzeptiert, kein Muss)
const String kXTitle = 'My Flutter Notes Chat';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<Map<String, String>> _messages = <Map<String, String>>[];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String text = _input.text.trim();
    if (text.isEmpty || _busy) return;

    _input.clear();
    setState(() {
      _messages.add(<String, String>{"role": "user", "content": text});
      _busy = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }

    try {
      final http.Response res = await http.post(
        Uri.parse(kChatEndpoint),
        headers: <String, String>{
          'Authorization': 'Bearer $kOpenRouterApiKey',
          'Content-Type': 'application/json',
          'X-Title': kXTitle,
        },
        body: jsonEncode(<String, dynamic>{
          'model': kModelSlug,
          'messages': _messages, // ganzer Verlauf
        }),
      );

      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body) as Map<String, dynamic>;
        final String reply =
            (data['choices'] as List).first['message']['content'] as String? ??
            '(keine Antwort)';
        setState(() {
          _messages.add(<String, String>{"role": "assistant", "content": reply});
          _busy = false;
        });
      } else {
        setState(() {
          _messages.add(<String, String>{
            "role": "assistant",
            "content": "API-Fehler ${res.statusCode}: ${res.body}",
          });
          _busy = false;
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(<String, String>{
          "role": "assistant",
          "content": "Netzwerkfehler: $e",
        });
        _busy = false;
      });
    }
  }

  Widget _bubble(Map<String, String> m) {
    final bool isUser = m['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        constraints: const BoxConstraints(maxWidth: 720),
        decoration: BoxDecoration(
          color: isUser ? Colors.indigo.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(m['content'] ?? ''),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool missingKey = kOpenRouterApiKey.isEmpty || kOpenRouterApiKey.contains('XXXX');

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: <Widget>[
          if (missingKey)
            const MaterialBanner(
              content: Text('Trage einen gültigen OpenRouter API-Key in chat_page.dart ein.'),
              actions: <Widget>[],
            ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.only(top: 12, bottom: 12),
              itemCount: _messages.length,
              itemBuilder: (_, int i) => _bubble(_messages[i]),
            ),
          ),
          if (_busy) const Padding(padding: EdgeInsets.only(bottom: 8), child: CircularProgressIndicator()),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _input,
                      onSubmitted: (_) => _send(),
                      minLines: 1,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: 'Nachricht eingeben…',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(
                    heroTag: 'send',
                    onPressed: _busy ? null : _send,
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
