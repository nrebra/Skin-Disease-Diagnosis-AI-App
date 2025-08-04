class Comment {
  final String id;
  final String userId;
  final String username;
  final String content;
  final DateTime timestamp;

  Comment({
    required this.id,
    required this.userId,
    required this.username,
    required this.content,
    required this.timestamp,
  });

  // JSON'dan veriyi model sınıfına dönüştürme
  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      username: json['username'] ?? 'Anonim Kullanıcı',
      content: json['comment_text'] ?? '',
      timestamp: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }

  // Modeli JSON'a dönüştürme
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'comment_text': content,
      // timestamp sunucu tarafında oluşturulacak
    };
  }
}
