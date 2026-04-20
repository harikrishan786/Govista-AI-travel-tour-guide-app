import 'dart:convert';
import 'package:http/http.dart' as http;

class GroqService {
  static final GroqService _instance = GroqService._internal();
  factory GroqService() => _instance;
  GroqService._internal();

  // ▼ PUT YOUR GROQ API KEY HERE (get free at console.groq.com) ▼
  final String _apiKey = '';

  final String _model = 'llama-3.3-70b-versatile';
  final String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  final List<Map<String, String>> _messages = [];

  final String _systemPrompt = """
You are GoVista AI — a fun, friendly travel buddy who knows every corner of India like the back of your hand. You talk like a best friend giving travel advice, NOT like a boring guidebook or robot.

YOUR PERSONALITY:
- Warm, cheerful, and enthusiastic 🎒
- Use casual language — short sentences, simple words
- Add emojis naturally (but don't overdo it — 2-3 per response max)
- Be honest about downsides (crowds, bad roads, scams) like a real friend would
- Match whatever language the user uses (Hindi, English, Hinglish — reply in the same)
- Keep responses SHORT and punchy — 3-5 sentences for simple questions, max 8-10 for detailed ones
- Never give long boring paragraphs — break things up, be snappy

WHEN THE USER ASKS FOR PLACES / HOTELS / RESTAURANTS / THINGS TO VISIT:

You MUST respond with EXACTLY this format — a SHORT friendly line, then a JSON block:

Here are some amazing spots you'll love! 🔥

```json
[
  {
    "name": "Place Name",
    "description": "A vivid 40-60 word description with insider tips, what makes it special, best time to visit. Write like telling a friend, not Wikipedia.",
    "rating": "4.5",
    "latitude": 28.6139,
    "longitude": 77.2090,
    "image_url": ""
  }
]
```

IMPORTANT RULES:
1. Always return exactly 5-7 places in the JSON array.
2. Each place MUST have real, accurate latitude & longitude coordinates.
3. Leave "image_url" as empty string "".
4. Rating should be realistic (3.0 - 5.0).
5. Valid JSON — no trailing commas.
6. ONLY a short intro line BEFORE the json block. NOTHING after the closing ```.
7. Always wrap JSON in ```json and ``` markers.
8. Mix popular spots with hidden gems — don't just list tourist traps.
9. Include specific real details: "maggi here costs ₹40", "reach before 7am for sunrise", "closed on Tuesdays".

FOR ALL OTHER QUESTIONS (general chat, travel advice, tips, budgets, etc.):
- Talk like a friend over chai ☕ — not a travel encyclopedia
- Give specific info: actual costs in ₹, distances, timings, transport options
- Keep it SHORT — answer the question directly, then add 1-2 bonus tips
- Use line breaks to make it easy to read
- Include practical insider tips: what to pack, what to avoid, local hacks
- If asked about itinerary, give a simple day-by-day plan with timings and food spots
- Be enthusiastic but real — "the view is insane but the road is terrible 😅"
- Do NOT use JSON format for general chat
- NEVER give walls of text — if your response is getting long, cut it down
""";

  void initialize() {
    _messages.clear();
  }

  /// Non-streaming message - returns full response at once
  /// Better for place queries since JSON needs to be complete
  Future<String> sendMessage(String message) async {
    _messages.add({'role': 'user', 'content': message});

    final allMessages = [
      {'role': 'system', 'content': _systemPrompt},
      ..._messages,
    ];

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': allMessages,
          'temperature': 0.7,
          'max_tokens': 4096,
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final content = json['choices'][0]['message']['content'] as String;
        _messages.add({'role': 'assistant', 'content': content});
        print('GroqService: Got response of length ${content.length}');
        print('GroqService: Contains json block: ${content.contains('```json')}');
        return content;
      } else {
        print('GroqService ERROR: ${response.statusCode} - ${response.body}');
        return "Sorry, I'm having trouble connecting. Please try again.";
      }
    } catch (e) {
      print('GroqService ERROR: $e');
      return "Error connecting to AI: ${e.toString()}";
    }
  }

  /// Streaming version (for regular chat - not place queries)
  Stream<String> streamMessage(String message) async* {
    _messages.add({'role': 'user', 'content': message});

    final allMessages = [
      {'role': 'system', 'content': _systemPrompt},
      ..._messages,
    ];

    try {
      final request = http.Request('POST', Uri.parse(_baseUrl));
      request.headers.addAll({
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      });
      request.body = jsonEncode({
        'model': _model,
        'messages': allMessages,
        'temperature': 0.7,
        'max_tokens': 4096,
        'stream': true,
      });

      final streamedResponse = await http.Client().send(request);
      final fullResponse = StringBuffer();

      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ') && line.trim() != 'data: [DONE]') {
            try {
              final jsonStr = line.substring(6);
              final json = jsonDecode(jsonStr);
              final delta = json['choices']?[0]?['delta']?['content'];
              if (delta != null && delta.isNotEmpty) {
                fullResponse.write(delta);
                yield delta;
              }
            } catch (_) {}
          }
        }
      }

      _messages.add({'role': 'assistant', 'content': fullResponse.toString()});
    } catch (e) {
      yield "Error: ${e.toString()}";
    }
  }

  void clearHistory() {
    _messages.clear();
  }
}