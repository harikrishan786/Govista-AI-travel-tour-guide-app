import 'dart:convert';
import 'package:http/http.dart' as http;

/// Voice Service using Groq's Whisper API for Speech-to-Text
/// Supports both Hindi and English
///
/// USAGE:
///   1. Record audio using a package like `record` or `flutter_sound`
///   2. Pass the file path to transcribe()
///   3. Get text back → feed it to GroqService.streamMessage()
///
/// SETUP: Add these to pubspec.yaml:
///   - record: ^5.0.0  (or flutter_sound)
///   - permission_handler: ^11.0.0
///
class GroqVoiceService {
  static final GroqVoiceService _instance = GroqVoiceService._internal();
  factory GroqVoiceService() => _instance;
  GroqVoiceService._internal();

  // Same API key as GroqService
  final String _apiKey =
      ''; // ← PUT YOUR GROQ KEY HERE

  final String _sttUrl = 'https://api.groq.com/openai/v1/audio/transcriptions';
  final String _ttsUrl = 'https://api.groq.com/openai/v1/audio/speech';

  /// ─── SPEECH TO TEXT ───
  /// Transcribes audio file to text (supports Hindi + English)
  /// [filePath] - path to the recorded audio file (wav, mp3, flac, etc.)
  /// [language] - 'hi' for Hindi, 'en' for English, or null for auto-detect
  Future<String> transcribe(String filePath, {String? language}) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_sttUrl));

      request.headers['Authorization'] = 'Bearer $_apiKey';

      // Use whisper-large-v3-turbo for best multilingual support
      request.fields['model'] = 'whisper-large-v3-turbo';

      if (language != null) {
        request.fields['language'] = language;
      }

      // Attach audio file
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['text'] ?? '';
      } else {
        return 'Error: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      return 'Voice error: ${e.toString()}';
    }
  }

  /// ─── TEXT TO SPEECH ───
  /// Converts text to speech audio bytes
  /// Returns raw audio bytes that you can play with an audio player
  Future<List<int>?> textToSpeech(String text) async {
    try {
      final response = await http.post(
        Uri.parse(_ttsUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'playai-tts',
          'input': text,
          'voice': 'Arista-PlayAI', // Change voice as needed
          'response_format': 'wav',
        }),
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      print('TTS Error: $e');
      return null;
    }
  }
}
