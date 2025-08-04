import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:skincancer/service/chat_service.dart';
import 'package:skincancer/widgets/AIchat/app_bar_widget.dart';
import 'package:skincancer/widgets/AIchat/chat_message_widget.dart';
import 'package:skincancer/widgets/AIchat/chat_input_widget.dart';
import 'package:skincancer/widgets/AIchat/chat_history_drawer.dart';
import 'package:skincancer/widgets/AIchat/chat_options_menu.dart';
import 'package:skincancer/style/color.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  // Doğrudan ChatScreen açma metodu
  static void openDirectly(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ChatScreen(),
      ),
    );
  }

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  late AnimationController _drawerAnimationController;
  late Animation<double> _drawerAnimation;
  bool _isDrawerOpen = false;
  List<Map<String, dynamic>> _chatHistory = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _loadChatHistory();
    _drawerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _drawerAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _drawerAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _chatService.dispose();
    _drawerAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    try {
      await _chatService.initializeChat();
    } catch (e) {
      _showSnackBar(e.toString());
    }
  }

  Future<void> _loadChatHistory() async {
    if (_isLoadingHistory || !mounted) return;

    setState(() => _isLoadingHistory = true);
    try {
      final response = await _chatService.fetchChatHistory();
      if (!mounted) return;

      if (response['success']) {
        setState(() {
          _chatHistory = List<Map<String, dynamic>>.from(response['chats']);
        });
      } else {
        if (mounted) {
          _showSnackBar(response['error'] ?? 'Sohbet geçmişi yüklenemedi');
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Sohbet geçmişi yüklenirken hata oluştu: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  Future<void> _deleteChat(String chatId) async {
    try {
      final response = await _chatService.removeChat(int.parse(chatId));
      if (!mounted) return;

      if (response['success']) {
        _showSnackBar('Sohbet silindi');
        _loadChatHistory();
      } else {
        _showSnackBar(response['error'] ?? 'Sohbet silinemedi');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Sohbet silinirken hata oluştu: $e');
      }
    }
  }

  Future<void> _deleteAllChats() async {
    try {
      final response = await _chatService.clearAllChats();
      if (!mounted) return;

      if (response['success']) {
        _showSnackBar('Tüm sohbetler silindi');
        setState(() {
          _chatHistory = [];
        });
      } else {
        _showSnackBar(response['error'] ?? 'Sohbetler silinemedi');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Sohbetler silinirken hata oluştu: $e');
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.1,
          left: 10,
          right: 10,
        ),
      ),
    );
  }

  Future<void> _startNewChat() async {
    try {
      await _chatService.startNewChat();
      _closeDrawer();
    } catch (e) {
      _showSnackBar(e.toString());
    }
  }

  void _toggleDrawer() {
    setState(() {
      _isDrawerOpen = !_isDrawerOpen;
      if (_isDrawerOpen) {
        _drawerAnimationController.forward();
      } else {
        _drawerAnimationController.reverse();
      }
    });
  }

  void _closeDrawer() {
    if (_isDrawerOpen) {
      setState(() {
        _isDrawerOpen = false;
        _drawerAnimationController.reverse();
      });
    }
  }

  void _loadChatSession(String chatId) {
    _chatService.loadChatSession(chatId);
    _closeDrawer();
  }

  Future<void> _sendMessage() async {
    if (!mounted) return;

    if (_chatService.messageController.text.trim().isEmpty &&
        _chatService.selectedImage == null) {
      _showSnackBar('Lütfen bir mesaj yazın veya görsel seçin');
      return;
    }

    final messageText = _chatService.messageController.text;
    final File? selectedImage = _chatService.selectedImage;

    // Önce mesajı UI'da göster
    setState(() {
      _chatService.addMessage(messageText, true,
          imagePath: selectedImage?.path);
    });

    // Mesaj gönderilmeden önce UI'ı temizle
    _chatService.messageController.clear();
    setState(() {
      _chatService.selectedImage = null;
      _chatService.isTyping = true;
    });

    try {
      final response = await _chatService.sendMessage(
        message: messageText,
        imagePath: selectedImage?.path,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        print('Mesaj başarıyla gönderildi');
      } else {
        _showSnackBar(response['error'] ?? 'Mesaj gönderilemedi');
        // Hata durumunda son eklenen kullanıcı mesajını kaldır
        setState(() {
          _chatService.messages.removeLast();
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Mesaj gönderilirken hata oluştu: $e');
      // Hata durumunda son eklenen kullanıcı mesajını kaldır
      setState(() {
        _chatService.messages.removeLast();
      });
    } finally {
      if (mounted) {
        setState(() => _chatService.isTyping = false);
      }
    }
  }

  void _handleBackPress() {
    if (_isDrawerOpen) {
      _closeDrawer();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _showMessageOptions(BuildContext context, String messageId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Mesajı Sil'),
                onTap: () {
                  Navigator.pop(context);
                  _chatService.deleteMessage(messageId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatHistoryDrawer() {
    return Drawer(
      child: Column(
        children: [
          AppBar(
            backgroundColor: primaryColor,
            title: const Text(
              'Sohbet Geçmişi',
              style: TextStyle(color: Colors.white),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadChatHistory,
              ),
            ],
          ),
          if (_isLoadingHistory)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (_chatHistory.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Henüz sohbet geçmişi yok',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _chatHistory.length,
                itemBuilder: (context, index) {
                  final chat = _chatHistory[index];
                  final bool isUserMessage =
                      chat['sender_id'].toString() != '-1';
                  final String message = chat['message'] ?? '';
                  final String formattedDate =
                      _formatTimestamp(chat['created_at'] ?? '');
                  final bool hasImage = chat['image_path'] != null;
                  final bool hasAudio = chat['audio_path'] != null;

                  return Dismissible(
                    key: Key(chat['id'].toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                      ),
                    ),
                    onDismissed: (direction) {
                      _deleteChat(chat['id'].toString());
                    },
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            isUserMessage ? primaryColor : secondaryColor,
                        child: Icon(
                          isUserMessage ? Icons.person : Icons.android,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Text(formattedDate),
                          if (hasImage)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Icon(Icons.image,
                                  size: 16, color: Colors.grey),
                            ),
                          if (hasAudio)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child:
                                  Icon(Icons.mic, size: 16, color: Colors.grey),
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            _showDeleteConfirmation(chat['id'].toString()),
                      ),
                      onTap: () => _loadChatSession(chat['id'].toString()),
                    ),
                  );
                },
              ),
            ),
          Divider(height: 1),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_sweep,
                color: Colors.red,
              ),
            ),
            title: const Text('Tüm Sohbetleri Sil'),
            onTap: _showDeleteAllConfirmation,
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final DateTime dateTime = DateTime.parse(timestamp);
      final DateTime now = DateTime.now();
      final Duration difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays} gün önce';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} saat önce';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} dakika önce';
      } else {
        return 'Az önce';
      }
    } catch (e) {
      return 'Tarih bilinmiyor';
    }
  }

  void _showDeleteConfirmation(String chatId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sohbeti Sil'),
        content: const Text('Bu sohbeti silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteChat(chatId);
            },
            child: const Text(
              'Sil',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAllConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tüm Sohbetleri Sil'),
        content: const Text(
            'Tüm sohbet geçmişini silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAllChats();
            },
            child: const Text(
              'Tümünü Sil',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Öncelikle klavye açık mı kontrol et
        final FocusScopeNode currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus &&
            currentFocus.focusedChild != null) {
          // Klavye açıksa, sadece klavyeyi kapat
          FocusManager.instance.primaryFocus?.unfocus();
          return false; // Geri tuşunun normal davranışını engelle
        }

        // Klavye kapalıysa ve çekmece açıksa, çekmeceyi kapat
        if (_isDrawerOpen) {
          _closeDrawer();
          return false; // Geri tuşunun normal davranışını engelle
        }

        // Diğer durumlarda, normal geri davranışını uygula
        Navigator.of(context).pop();
        return false; // WillPopScope ile ele aldığımız için false döndürüyoruz
      },
      child: Scaffold(
        extendBody: true,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF9F9F9),
                Color(0xFFF2F2F2),
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Column(
                  children: [
                    AppBarWidget(
                      onMenuPressed: _toggleDrawer,
                      onMorePressed: () => _showOptionsMenu(context),
                    ),
                    Expanded(
                      child: _chatService.messages.isEmpty
                          ? _buildEmptyState()
                          : _buildChatList(),
                    ),
                    if (_chatService.isTyping) _buildTypingIndicator(),
                    if (_chatService.selectedImage != null)
                      _buildImagePreview(),
                    ChatInputWidget(
                      chatService: _chatService,
                      onSendMessage: _sendMessage,
                      onTextChanged: (text) => setState(() {}),
                      onImageSelected: (image) => setState(() {
                        _chatService.selectedImage = image;
                      }),
                    ),
                  ],
                ),
                ChatHistoryDrawer(
                  animation: _drawerAnimation,
                  chatService: _chatService,
                  onNewChat: _startNewChat,
                  onChatSelected: _loadChatSession,
                  onCloseDrawer: _closeDrawer,
                  onShowOptions: () => _showOptionsMenu(context),
                ),
              ],
            ),
          ),
        ),
        drawer: _buildChatHistoryDrawer(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chat_bubble_outline,
                  size: 60,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Sohbete Başlayın',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Merak ettiğiniz konuları sorabilir veya görsel yükleyebilirsiniz',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatList() {
    return Container(
      color: Colors.white,
      child: ListView.builder(
        controller: _chatService.scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _chatService.messages.length,
        physics: const AlwaysScrollableScrollPhysics(),
        cacheExtent: 1000,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemBuilder: (context, index) {
          final message = _chatService.messages[index];
          final bool showTimestamp = index == 0 ||
              _chatService.shouldShowTimestamp(
                  message['timestamp'],
                  index > 0
                      ? _chatService.messages[index - 1]['timestamp']
                      : null);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showTimestamp) _buildTimestampDivider(message['timestamp']),
              ChatMessageWidget(
                message: message['text'] ?? '',
                isUser: message['isUser'] ?? false,
                timestamp: message['timestamp'],
                onLongPress: () => _showMessageOptions(context, message['id']),
                imagePath: message['imagePath'],
                audioPath: message['audioPath'],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimestampDivider(DateTime timestamp) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[300], thickness: 0.5)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _chatService.formatTimestamp(timestamp),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[300], thickness: 0.5)),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      margin: EdgeInsets.only(left: 16, right: 16, bottom: 8),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _chatService.selectedImage!,
              width: 70,
              height: 70,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Görsel mesaja eklenecek',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.grey[600]),
            onPressed: () {
              setState(() {
                _chatService.selectedImage = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 3,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SpinKitThreeBounce(
            color: primaryColor,
            size: 16,
          ),
          SizedBox(width: 12),
          Text(
            'AI düşünüyor...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return ChatOptionsMenu(
          chatService: _chatService,
          onClearChat: () async {
            Navigator.pop(context);
            try {
              await _deleteAllChats();
              _startNewChat();
            } catch (e) {
              _showSnackBar(e.toString());
            }
          },
          onSaveChat: () async {
            Navigator.pop(context);
            try {
              await _chatService.saveChatSession(_chatService.currentChatId);
              _showSnackBar('Sohbet kaydedildi: ${_chatService.currentChatId}');
            } catch (e) {
              _showSnackBar(e.toString());
            }
          },
        );
      },
    );
  }
}
