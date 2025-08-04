import 'package:flutter/material.dart';
import 'package:skincancer/style/color.dart';

class ChatOptionsMenu extends StatelessWidget {
  final String sessionId;
  final List<Map<String, dynamic>> messages;
  final VoidCallback onClearChat;
  final VoidCallback onSaveChat;

  const ChatOptionsMenu({
    super.key,
    required this.sessionId,
    required this.messages,
    required this.onClearChat,
    required this.onSaveChat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.delete_sweep, color: primaryColor),
            title: const Text('Sohbeti Temizle'),
            onTap: () {
              Navigator.pop(context);
              onClearChat();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sohbet silindi')),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.save_alt, color: primaryColor),
            title: const Text('Sohbeti Kaydet'),
            onTap: () {
              Navigator.pop(context);
              onSaveChat();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sohbet kaydedildi')),
              );
            },
          ),
        ],
      ),
    );
  }
}
