import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:skincancer/pages/Aİ/message_handler.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:skincancer/config.dart';
import 'package:skincancer/service/auth_helper.dart';

class ChatService extends ChangeNotifier {
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final just_audio.AudioPlayer _audioPlayer = just_audio.AudioPlayer();
  final ImagePicker _imagePicker = ImagePicker();
  final String _baseUrl = Config.API_URL;
  final MessageHandler _messageHandler = MessageHandler();

  List<Map<String, dynamic>> messages = [];
  List<ChatSession> chatHistory = [];
  String currentChatId = '';
  bool isTyping = false;
  bool _isListening = false;
  File? selectedImage;

  // Getter ve Setter'lar
  bool get isListening => _isListening;
  set isListening(bool value) {
    _isListening = value;
    notifyListeners();
  }

  // API istekleri için header'ları hazırla
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
      };

  Future<Map<String, String>> get headers async => {
        'Authorization': 'Bearer ${await AuthHelper.getToken()}',
        'Content-Type': 'application/json',
      };

  // Tüm sohbetleri getir
  Future<List<dynamic>> getAllChats() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/chats'),
        headers: await headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['chats'];
      } else {
        throw Exception('Sohbetler alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Sohbetler alınırken hata oluştu: $e');
    }
  }

  // Yeni mesaj gönder
  Future<Map<String, dynamic>> sendMessage({
    required String message,
    String? imagePath,
    String? audioPath,
  }) async {
    if (message.trim().isEmpty && imagePath == null) {
      return {
        'success': false,
        'error': 'Lütfen bir mesaj yazın veya görsel seçin',
      };
    }

    try {
      final token = await AuthHelper.getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${Config.API_URL}/chats'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields['message'] = message;

      if (imagePath != null) {
        final imageFile = File(imagePath);
        if (await imageFile.exists()) {
          request.files.add(
            await http.MultipartFile.fromPath('image', imagePath),
          );
        }
      }

      if (audioPath != null) {
        final audioFile = File(audioPath);
        if (await audioFile.exists()) {
          request.files.add(
            await http.MultipartFile.fromPath('audio', audioPath),
          );
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Gemini yanıtını ekle
        if (responseData['gemini_message'] != null) {
          addMessage(responseData['gemini_message'], false);
        }

        return {
          'success': true,
          'gemini_message': responseData['gemini_message'],
        };
      } else {
        print(
            'Mesaj gönderilemedi! Status: ${response.statusCode}, Body: ${response.body}');
        return {
          'success': false,
          'error': 'Mesaj gönderilemedi: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Mesaj gönderme sırasında hata: $e');
      return {
        'success': false,
        'error': 'Mesaj gönderilirken hata oluştu: $e',
      };
    }
  }

  // Ses tanıma işlemini başlat
  Future<void> startListening(Function(String) onResult) async {
    if (!await _speech.initialize()) {
      throw Exception('Ses tanıma başlatılamadı');
    }

    isListening = true;
    notifyListeners();

    try {
      await _speech.listen(
        onResult: (result) {
          // Konuşma devam ederken bile metni güncelle
          onResult(result.recognizedWords);

          // finalResult=true olan kısmı kaldırıyoruz çünkü
          // konuşma basılı tutma boyunca devam etmeli
          // Kullanıcı parmağını çektiğinde stopListening zaten çağrılacak
        },
        listenMode:
            stt.ListenMode.dictation, // confirmation yerine dictation kullan
        localeId: 'tr_TR',
        cancelOnError: true,
      );
    } catch (e) {
      isListening = false;
      notifyListeners();
      throw Exception('Ses tanıma hatası: $e');
    }
  }

  // Ses tanıma işlemini durdur
  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
    isListening = false;
    notifyListeners();
  }

  // Ses dosyasını oynat
  Future<void> playAudio(String audioPath) async {
    try {
      await _audioPlayer.setFilePath(audioPath);
      await _audioPlayer.play();
    } catch (e) {
      throw Exception('Ses oynatma hatası: $e');
    }
  }

  // Belirli bir sohbeti sil
  Future<void> deleteChat(int chatId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/chats/$chatId'),
        headers: await headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Sohbet silinemedi: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Sohbet silinirken hata oluştu: $e');
    }
  }

  // Tüm sohbetleri sil
  Future<void> deleteAllChats() async {
    messages = [];
    chatHistory = [];
    notifyListeners();
  }

  // Görsel seç
  Future<File?> pickImage() async {
    final XFile? image =
        await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      return File(image.path);
    }
    return null;
  }

  // Kaynakları temizle
  @override
  void dispose() {
    _audioPlayer.dispose();
    _speech.stop();
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  // Yardımcı fonksiyonlar
  String generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  String formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Az önce';
    }
  }

  bool shouldShowTimestamp(DateTime current, DateTime? previous) {
    if (previous == null) return true;
    final difference = current.difference(previous);
    return difference.inMinutes >= 5;
  }

  Future<void> saveChat(String chatId) async {
    try {
      // Sohbeti kaydetme işlemi
      // Burada API çağrısı yapılabilir veya yerel depolama kullanılabilir
      await Future.delayed(Duration(milliseconds: 500)); // Simüle edilmiş işlem
    } catch (e) {
      throw 'Sohbet kaydedilemedi: ${e.toString()}';
    }
  }

  // Yeni sohbet başlat
  Future<void> startNewChat() async {
    currentChatId = DateTime.now().millisecondsSinceEpoch.toString();
    messages = [];
    notifyListeners();
  }

  // Mesaj ekle
  void addMessage(String? message, bool isUser,
      {String? imagePath, String? audioPath}) {
    final timestamp = DateTime.now();
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    messages.add({
      'id': id,
      'text': message ?? '', // Default to an empty string
      'isUser': isUser,
      'timestamp': timestamp,
      'imagePath': imagePath, // Allow null
      'audioPath': audioPath, // Allow null
    });

    notifyListeners();

    // Her yeni mesaj eklendiğinde scroll'u en alta getir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Sohbet oturumunu yükle
  Future<void> loadChatSession(String chatId) async {
    currentChatId = chatId;
    // Sohbet geçmişini yükleme işlemleri
    notifyListeners();
  }

  // Mesaj sil
  void deleteMessage(String messageId) {
    messages.removeWhere((message) => message['id'] == messageId);
    notifyListeners();
  }

  Future<File?> takePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      selectedImage = File(pickedFile.path);
      return selectedImage;
    }
    return null;
  }

  // Sohbeti kaydet
  Future<void> saveChatSession(String chatId) async {
    try {
      await saveChat(chatId);
    } catch (e) {
      throw 'Sohbet kaydedilemedi: ${e.toString()}';
    }
  }

  // Sohbeti başlat
  Future<void> initializeChat() async {
    try {
      _messageHandler.initialize();
      currentChatId = 'chat_${DateTime.now().millisecondsSinceEpoch}';
      addMessage('Merhaba! Size nasıl yardımcı olabilirim?', false);
      chatHistory.add(ChatSession(
        id: currentChatId,
        title: 'Yeni Sohbet',
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      throw 'Sohbet başlatılamadı: ${e.toString()}';
    }
  }

  void scrollToBottom() {
    // Önce scrollController'ın hazır olup olmadığını kontrol et
    if (!scrollController.hasClients) {
      // Controller henüz bağlı değilse, kısa bir gecikme sonra tekrar dene
      Future.delayed(const Duration(milliseconds: 100), scrollToBottom);
      return;
    }

    // Frame oluşturulduktan sonra scroll işlemini gerçekleştir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        // En son pozisyona kaydırma işlemini yapacak kodun etrafına try-catch bloğu eklendi
        if (scrollController.hasClients) {
          // Animasyon olmadan önce en son pozisyona atla
          scrollController.jumpTo(scrollController.position.maxScrollExtent);

          // Daha sonra animasyonlu bir şekilde son pozisyona kaydır
          // Bu, kullanıcının en son mesajı görmesini sağlar
          Future.delayed(const Duration(milliseconds: 50), () {
            if (scrollController.hasClients) {
              scrollController.animateTo(
                scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
            }
          });
        }
      } catch (e) {
        print("Otomatik kaydırma hatası: $e");
        // Hata durumunda bir kez daha dene
        Future.delayed(const Duration(milliseconds: 200), scrollToBottom);
      }
    });
  }

  Future<Map<String, dynamic>> fetchChatHistory() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.API_URL}/chats'),
        headers: await headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('API yanıtı: ${response.body}');
        return {
          'success': true,
          'chats': data['chats'],
        };
      } else {
        return {
          'success': false,
          'error': 'Sohbet geçmişi alınamadı: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> removeChat(int chatId) async {
    try {
      final response = await http.delete(
        Uri.parse('${Config.API_URL}/chats/$chatId'),
        headers: await headers,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Sohbet silindi',
        };
      } else {
        return {
          'success': false,
          'error': 'Sohbet silinemedi',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> clearAllChats() async {
    try {
      final response = await http.delete(
        Uri.parse('${Config.API_URL}/chats/all'),
        headers: await headers,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Tüm sohbetler silindi',
        };
      } else {
        return {
          'success': false,
          'error': 'Sohbetler silinemedi',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

class ChatSession {
  final String id;
  final String title;
  final DateTime timestamp;

  ChatSession({
    required this.id,
    required this.title,
    required this.timestamp,
  });
}

class ApiService {
  Future<Map<String, dynamic>> getMessages() async {
    try {
      print('API isteği yapılıyor...');
      final response = await http.get(
        Uri.parse('${Config.API_URL}/messages'),
        headers: await headers,
      );

      print('API yanıt kodu: ${response.statusCode}');
      print('API yanıt içeriği: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'status': 'success',
          'data': data['data'] ?? [],
        };
      } else {
        print('API hata yanıtı: ${response.statusCode} - ${response.body}');
        return {
          'status': 'error',
          'message': 'Mesajlar alınamadı: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('API çağrısı hatası: $e');
      return {
        'status': 'error',
        'message': 'Mesaj getirme hatası: $e',
      };
    }
  }

  Future<Map<String, dynamic>> deleteMessage(String messageId) async {
    try {
      final response = await http.delete(
        Uri.parse('${Config.API_URL}/messages/$messageId'),
        headers: await headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Mesaj silinemedi: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Mesaj silme hatası: $e');
    }
  }

  Future<Map<String, String>> get headers async => {
        'Authorization': 'Bearer ${await AuthHelper.getToken()}',
        'Content-Type': 'application/json',
      };
}

Future<String?> fetchTtsAudio(String text) async {
  final url = Uri.parse('https://senin-api-urlin.com/tts'); // API endpoint'in
  final response = await http.post(
    url,
    body: {'text': text},
  );

  if (response.statusCode == 200) {
    // Eğer API doğrudan dosya dönüyorsa (Content-Type: audio/mpeg)
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/tts_audio.mp3';
    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  } else {
    // Hata yönetimi
    print('TTS API hatası: ${response.body}');
    return null;
  }
}

Future<void> playTtsAudio(String filePath) async {
  final player = AudioPlayer();
  await player.play(DeviceFileSource(filePath));
}
