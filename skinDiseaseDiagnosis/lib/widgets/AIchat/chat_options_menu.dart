import 'package:flutter/material.dart';
import 'package:skincancer/style/color.dart';
import 'package:skincancer/service/chat_service.dart';

class ChatOptionsMenu extends StatelessWidget {
  final ChatService chatService;
  final VoidCallback onClearChat;
  final VoidCallback onSaveChat;

  const ChatOptionsMenu({
    Key? key,
    required this.chatService,
    required this.onClearChat,
    required this.onSaveChat,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Sohbet Seçenekleri',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Divider(height: 1),
          _buildOptionTile(
            icon: Icons.delete_outline,
            title: 'Sohbeti Temizle',
            description: 'Tüm mesaj geçmişini sil',
            onTap: onClearChat,
            iconColor: Colors.red,
          ),
          _buildOptionTile(
            icon: Icons.save_alt,
            title: 'Sohbeti Kaydet',
            description: 'Bu sohbeti kaydedin',
            onTap: onSaveChat,
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: (iconColor ?? primaryColor).withOpacity(0.1),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(
          icon,
          color: iconColor ?? primaryColor,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(description),
      onTap: onTap,
    );
  }
}
