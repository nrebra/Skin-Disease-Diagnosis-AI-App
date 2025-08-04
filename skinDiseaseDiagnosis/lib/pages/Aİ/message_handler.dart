import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../service/gemini_service.dart';

class UserMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? imageUrl;
  final String userId;
  final String username;

  UserMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.imageUrl,
    required this.userId,
    required this.username,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp,
      'imageUrl': imageUrl,
      'userId': userId,
      'username': username,
    };
  }

  static UserMessage fromMap(Map<String, dynamic> map) {
    return UserMessage(
      text: map['text'],
      isUser: map['isUser'],
      timestamp:
          map['timestamp'] is DateTime ? map['timestamp'] : DateTime.now(),
      imageUrl: map['imageUrl'],
      userId: map['userId'],
      username: map['username'] ?? 'Anonim Kullanıcı',
    );
  }
}

class UserMessageHandler {
  final GeminiService gemini = GeminiService();
  final TextEditingController textEditingController;
  final FocusNode focusNode;
  final ScrollController listScrollController;
  final Function(UserMessage) onMessageAdded;
  final Function(bool) onTypingStatusChanged;
  final Function() onScrollToBottom;
  String currentChatId;
  final ImagePicker _imagePicker = ImagePicker();

  UserMessageHandler({
    required this.textEditingController,
    required this.focusNode,
    required this.listScrollController,
    required this.onMessageAdded,
    required this.onTypingStatusChanged,
    required this.onScrollToBottom,
    required this.currentChatId,
  });

  Future<String?> _getUserName() async {
    return 'Kullanıcı';
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      return 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
    } catch (e) {
      print('Image upload error: $e');
      return null;
    }
  }

  Future<void> pickAndSendImage() async {
    final XFile? image =
        await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final imageUrl = await _uploadImage(File(image.path));
      final username = await _getUserName();

      if (imageUrl != null && username != null) {
        final message = UserMessage(
          text: '',
          isUser: true,
          timestamp: DateTime.now(),
          imageUrl: imageUrl,
          userId: 'user_id',
          username: username,
        );

        onMessageAdded(message);

        final response = await gemini.generateResponse("Bu görseli analiz et");

        if (response != null) {
          final aiResponse = UserMessage(
            text: response,
            isUser: false,
            timestamp: DateTime.now(),
            userId: 'AI',
            username: 'AI Assistant',
          );

          onMessageAdded(aiResponse);
        }
      }
    }
  }

  Future<void> saveMessage(UserMessage message) async {
    print('Mesaj kaydedildi: ${message.text}');
  }

  Future<void> clearChat() async {
    // Sohbet geçmişini temizle
    print('Sohbet temizlendi');
  }

  Widget buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -4),
            blurRadius: 10,
            color: Colors.black.withOpacity(0.1),
          ),
        ],
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.add_photo_alternate_outlined,
                  color: Colors.blueAccent),
              onPressed: pickAndSendImage,
            ),
            Expanded(
              child: TextField(
                controller: textEditingController,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: "Bir mesaj yazın...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.send_rounded, color: Colors.blueAccent),
              onPressed: sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> sendMessage() async {
    if (textEditingController.text.isEmpty) return;

    final username = await _getUserName();
    if (username == null) return;

    final userMessage = UserMessage(
      text: textEditingController.text,
      isUser: true,
      timestamp: DateTime.now(),
      userId: 'user_id',
      username: username,
    );

    await saveMessage(userMessage);
    onMessageAdded(userMessage);
    onTypingStatusChanged(true);

    textEditingController.clear();
    focusNode.unfocus();
    onScrollToBottom();

    try {
      final response = await gemini.generateResponse(userMessage.text);

      final aiMessage = UserMessage(
        text: response ?? "Üzgünüm, bir yanıt oluşturulamadı.",
        isUser: false,
        timestamp: DateTime.now(),
        userId: 'AI',
        username: 'AI Assistant',
      );

      await saveMessage(aiMessage);
      onMessageAdded(aiMessage);
    } catch (e) {
      print('Error: $e');
      final errorMessage = UserMessage(
        text: "Üzgünüm, bir hata oluştu. Lütfen tekrar deneyin.",
        isUser: false,
        timestamp: DateTime.now(),
        userId: 'AI',
        username: 'AI Assistant',
      );

      await saveMessage(errorMessage);
      onMessageAdded(errorMessage);
    }

    onTypingStatusChanged(false);
    onScrollToBottom();
  }

  void updateCurrentChatId(String newChatId) {
    currentChatId = newChatId;
  }

  void initialize() {
    gemini.initialize();
  }

  void startNewChat() {
    gemini.startNewChat();
  }

  Future<String?> sendMessageToAI(String message) async {
    try {
      return await gemini.generateResponse(message);
    } catch (e) {
      print('Error sending message: $e');
      return null;
    }
  }
}

class MessageHandler {
  final GeminiService _geminiService = GeminiService();

  // Gemini servisini başlat
  void initialize() {
    _geminiService.initialize();
  }

  // Yeni sohbet başlat
  void startNewChat() {
    _geminiService.startNewChat();
  }

  // Mesaj gönder ve yanıt al (doğrudan Gemini API)
  Future<String?> sendMessage(String message) async {
    try {
      return await _geminiService.generateResponse(message);
    } catch (e) {
      print('Error sending message: $e');
      return null;
    }
  }

  // Backend üzerinden mesaj gönder (ses yanıtı da alabilir)
  Future<Map<String, dynamic>> sendMessageWithAudio(
      String message, String receiverId) async {
    try {
      return await _geminiService.sendMessageToBackend(message, receiverId);
    } catch (e) {
      print('Error sending message with audio: $e');
      return {
        'text': 'Üzgünüm, bir hata oluştu.',
        'audio': null,
      };
    }
  }

  // Base64 formatındaki ses yanıtını çal
  Future<void> playAudioResponse(String base64Audio) async {
    if (base64Audio != null && base64Audio.isNotEmpty) {
      await _geminiService.playAudioResponse(base64Audio);
    }
  }
}
