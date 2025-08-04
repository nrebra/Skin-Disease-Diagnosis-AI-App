import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:skincancer/style/color.dart';
import 'package:skincancer/service/chat_service.dart';

class ChatHistoryDrawer extends StatelessWidget {
  final Animation<double> animation;
  final ChatService chatService;
  final VoidCallback onNewChat;
  final Function(String) onChatSelected;
  final VoidCallback onCloseDrawer;
  final VoidCallback onShowOptions;

  const ChatHistoryDrawer({
    Key? key,
    required this.animation,
    required this.chatService,
    required this.onNewChat,
    required this.onChatSelected,
    required this.onCloseDrawer,
    required this.onShowOptions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double drawerWidth = MediaQuery.of(context).size.width * 0.7;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Stack(
          children: [
            if (animation.value > 0)
              GestureDetector(
                onTap: onCloseDrawer,
                child: Container(
                  color: Colors.black.withOpacity(0.4 * animation.value),
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                ),
              ),
            Positioned(
              left: -drawerWidth * (1 - animation.value),
              top: 0,
              bottom: 0,
              width: drawerWidth,
              child: Material(
                elevation: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              primaryColor,
                              primaryColor.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(24),
                          ),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.arrow_back,
                                        color: Colors.white),
                                    onPressed: onCloseDrawer,
                                  ),
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.chat_bubble_outline,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                  SizedBox(
                                      width: 48), // Geri tuşu ile simetri için
                                ],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Sohbet Geçmişi',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.add,
                            color: primaryColor,
                          ),
                        ),
                        title: Text(
                          'Yeni Sohbet',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: onNewChat,
                      ),
                      Divider(),
                      Expanded(
                        child: chatService.chatHistory.isEmpty
                            ? Center(
                                child: Text(
                                  'Henüz sohbet geçmişi yok',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                itemCount: chatService.chatHistory.length,
                                itemBuilder: (context, index) {
                                  final session =
                                      chatService.chatHistory[index];
                                  final isActive =
                                      session.id == chatService.currentChatId;

                                  return Container(
                                    margin: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? primaryColor.withOpacity(0.1)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      leading: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? primaryColor.withOpacity(0.2)
                                              : Colors.grey[200],
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Icon(
                                          Icons.chat_bubble_outline,
                                          color: isActive
                                              ? primaryColor
                                              : Colors.grey[700],
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(
                                        session.title.length > 25
                                            ? '${session.title.substring(0, 25)}...'
                                            : session.title,
                                        style: TextStyle(
                                          fontWeight: isActive
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: isActive
                                              ? primaryColor
                                              : Colors.black87,
                                        ),
                                      ),
                                      subtitle: Text(
                                        DateFormat('dd/MM/yyyy HH:mm')
                                            .format(session.timestamp),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      onTap: () => onChatSelected(session.id),
                                    ),
                                  );
                                },
                              ),
                      ),
                      Container(
                        padding: EdgeInsets.all(16),
                        child: InkWell(
                          onTap: () {
                            onCloseDrawer();
                            onShowOptions();
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.settings_outlined,
                                  color: Colors.grey[700],
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Ayarlar',
                                  style: TextStyle(
                                    color: Colors.grey[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
