import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:skincancer/style/color.dart';

class MessageOptionsMenu extends StatelessWidget {
  final String sessionId;
  final Map<String, dynamic> message;
  final VoidCallback onDelete;

  const MessageOptionsMenu({
    super.key,
    required this.sessionId,
    required this.message,
    required this.onDelete,
  });

  Future<void> _copyMessage(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: message['text'] ?? ''));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mesaj kopyalandı')),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.copy, color: primaryColor),
            title: const Text('Kopyala'),
            onTap: () {
              Navigator.pop(context);
              _copyMessage(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete, color: primaryColor),
            title: const Text('Sil'),
            onTap: () {
              Navigator.pop(context);
            
            },
          ),
        ],
      ),
    );
  }
}
