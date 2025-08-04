import 'package:intl/intl.dart';

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String messageText;
  final DateTime createdAt;
  final String? imageUrl;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.messageText,
    required this.createdAt,
    this.imageUrl,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    try {
      final DateFormat apiDateFormat =
          DateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'", 'en_US');
      DateTime parsedDate;

      try {
        parsedDate = apiDateFormat.parse(json['created_at']);
      } catch (e) {
        // Eğer özel format başarısız olursa, ISO formatını dene
        try {
          parsedDate = DateTime.parse(json['created_at']);
        } catch (e2) {
          // Her iki format da başarısız olursa şu anki zamanı kullan
          parsedDate = DateTime.now();
        }
      }

      return Message(
        id: json['id'].toString(),
        senderId: json['sender_id'].toString(),
        receiverId: json['receiver_id'].toString(),
        messageText: json['message_text'] as String,
        createdAt: parsedDate,
        imageUrl: json['image_url'],
      );
    } catch (e) {
      throw Exception('Mesaj dönüştürme hatası: $e');
    }
  }

  Map<String, dynamic> toJson() {
    final DateFormat apiDateFormat =
        DateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'", 'en_US');

    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message_text': messageText,
      'created_at': apiDateFormat.format(createdAt),
      'image_url': imageUrl,
    };
  }
}
