import 'package:flutter/material.dart';
import '../../service/api_service.dart';
import '../../service/message_service.dart';
import '../../models/message_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MessagesTab extends StatefulWidget {
  @override
  _MessagesTabState createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  late final MessageService _messageService;
  List<Message> _messages = [];
  bool _isLoading = false;
  String? _userId;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _messageService = MessageService(ApiService(), context);
    _initialize();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id');
    print('MessagesTab - Kullanıcı ID: $_userId');
    await _messageService.initialize();
    await _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    if (_isLoading || _isDisposed) return;

    setState(() => _isLoading = true);

    try {
      final messages = await _messageService.fetchMessages();

      // Tekrarlanan mesajları filtrele
      final uniqueMessages = <String, Message>{};
      for (var message in messages) {
        uniqueMessages[message.id] = message;
      }

      // Mesajları tarihe göre sırala (en yeni en üstte)
      final sortedMessages = uniqueMessages.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          _messages = sortedMessages;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Mesaj getirme hatası: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isMessageFromCurrentUser(Message message) {
    print('Mesaj sahiplik kontrolü:');
    print('Mesaj gönderen ID: ${message.senderId}');
    print('Mevcut kullanıcı ID: $_userId');
    return message.senderId == _userId;
  }

  Widget _buildMessageBubble(Message message) {
    final isSender = _isMessageFromCurrentUser(message);

    print('Mesaj Görüntüleme:');
    print('- ID: ${message.id}');
    print('- Gönderen ID: ${message.senderId}');
    print('- Kullanıcı ID: $_userId');
    print('- Gönderen mi: $isSender');

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(message.messageText),
        subtitle: Text(_messageService.formatDateTime(message.createdAt)),
        tileColor: isSender ? Colors.blue[50] : Colors.grey[50],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.message_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'Henüz mesajınız yok',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchMessages,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Icon(Icons.person, color: Theme.of(context).primaryColor),
            ),
            title: Text(
              'Dr. ${message.senderId}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              message.messageText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              _messageService.formatDateTime(message.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            onTap: () => _messageService.navigateToChat(
              message.senderId,
              'Dr. ${message.senderId}',
            ),
          );
        },
      ),
    );
  }
}
