import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GeminiService {
  // Singleton instance
  static final GeminiService _instance = GeminiService._internal();

  factory GeminiService() => _instance;

  GeminiService._internal();

  // Sadece backend API endpoint'i
  final String _apiUrl = 'https://berketopbas.com.tr/chats';
  String? _token;

  // Servisi başlat
  Future<void> initialize() async {
    await _loadToken();
  }

  // Token'ı yükle
  Future<void> _loadToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('token');
      print('Token yüklendi: $_token');
    } catch (e) {
      print('Token yükleme hatası: $e');
    }
  }

  // Yeni bir sohbet başlat
  void startNewChat() {
    // Backend'de yeni sohbet başlatma işlemi
  }

  // Mesaj gönder ve yanıt al (backend üzerinden)
  Future<String?> generateResponse(String prompt) async {
    try {
      // Token kontrolü
      if (_token == null) {
        await _loadToken();
      }

      final response = await sendMessageToBackend(prompt, "AI_ASSISTANT");
      return response['text'];
    } catch (e) {
      print('Error generating response: $e');
      return null;
    }
  }

  // Backend üzerinden mesaj gönderme
  Future<Map<String, dynamic>> sendMessageToBackend(
      String message, String receiverId) async {
    try {
      // Token kontrolü
      if (_token == null) {
        await _loadToken();
        if (_token == null) {
          throw Exception('Token bulunamadı. Lütfen giriş yapın.');
        }
      }

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'receiver_id': receiverId,
          'message': message,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'text': data['gemini_message'],
          'audio': data['audio_response'],
        };
      } else if (response.statusCode == 401) {
        // Token geçersiz, yeniden yüklemeyi dene
        await _loadToken();
        throw Exception('Token geçersiz. Lütfen tekrar giriş yapın.');
      } else {
        throw Exception('API yanıt vermedi: ${response.statusCode}');
      }
    } catch (e) {
      print('Backend isteği hatası: $e');
      return {
        'text': 'Üzgünüm, şu anda yanıt veremiyorum. $e',
        'audio': null,
      };
    }
  }

  // Ses yanıtını çal
  Future<void> playAudioResponse(String base64Audio) async {
    // Burada base64 formatındaki ses verisini çalacak kod eklenebilir
  }
}
