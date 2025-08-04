import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../models/message_model.dart';
import '../pages/Chat/ChatPage.dart';

class MessageService {
  final ApiService _apiService;
  final BuildContext context;
  String? _currentUserId;

  MessageService(this._apiService, this.context) {
    _initializeUserId();
  }

  Future<void> _initializeUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');
  }

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token != null) {
        await _apiService.setToken(token);
      }
      await _initializeUserId();
    } catch (e) {
      _showErrorSnackBar('Oturum başlatılamadı. Lütfen tekrar giriş yapın.');
    }
  }

  Future<List<Message>> fetchMessages() async {
    try {
      final response = await _apiService.getMessages();

      if (response['status'] == 'success' && response['data'] != null) {
        final List<dynamic> data = response['data'];
        final messages = data.map((json) => Message.fromJson(json)).toList();

        // Mesajları tarihe göre sırala
        messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return messages;
      } else {
        throw Exception('Mesajlar getirilemedi');
      }
    } catch (e) {
      throw Exception('Mesajlar getirilemedi: $e');
    }
  }

  Future<void> sendMessage(String receiverId, String messageText) async {
    try {
      final response = await _apiService.sendMessage(receiverId, messageText);

      if (response['status'] != 'success') {
        throw Exception('Mesaj gönderilemedi');
      }
    } catch (e) {
      throw Exception('Mesaj gönderilemedi: $e');
    }
  }

  void navigateToChat(String receiverId, String receiverName,
      {String receiverSurname = ''}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          receiverId: receiverId,
          receiverName: receiverName,
          receiverSurname: receiverSurname,
        ),
      ),
    );
  }

  String formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Şimdi';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} dk';
    } else if (difference.inDays < 1) {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      final dayNames = [
        'Pazartesi',
        'Salı',
        'Çarşamba',
        'Perşembe',
        'Cuma',
        'Cumartesi',
        'Pazar'
      ];
      return dayNames[dateTime.weekday - 1];
    } else {
      return '${dateTime.day}.${dateTime.month}.${dateTime.year}';
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
