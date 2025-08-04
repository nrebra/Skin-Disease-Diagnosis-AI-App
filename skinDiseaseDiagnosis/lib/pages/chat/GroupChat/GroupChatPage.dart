import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../service/community_service.dart';
import '../../../widgets/community/group_message_bubble.dart';
import '../../../widgets/community/group_message_input.dart';
import '../../../widgets/community/group_member.dart';
import '../../../widgets/community/group_settings.dart';

import '../../../service/api_service.dart';
import 'dart:io';
import '../../../style/color.dart';

class GroupChatPage extends StatefulWidget {
  final Map<String, dynamic> group;

  const GroupChatPage({Key? key, required this.group}) : super(key: key);

  @override
  _GroupChatPageState createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final CommunityService _communityService;

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _currentDoctorId;
  bool _showScrollButton = false;
  bool _showEmoji = false;

  @override
  void initState() {
    super.initState();
    _communityService = CommunityService(context);
    _initialize();

    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        final showButton = _scrollController.position.maxScrollExtent -
                _scrollController.position.pixels >
            300;
        if (showButton != _showScrollButton) {
          setState(() => _showScrollButton = showButton);
        }
      }
    });
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _currentDoctorId = prefs.getString('user_id');
    await _loadMessages();
  }

  Future<void> _loadMessages() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      print('Grup mesajları yükleniyor - Grup ID: ${widget.group['id']}');

      // API'den mesajları getir
      final messages =
          await _communityService.fetchGroupMessages(widget.group['id']);

      print('Grup mesajları alındı - Mesaj sayısı: ${messages.length}');
      print(
          'İlk mesaj örnek: ${messages.isNotEmpty ? messages.first : "Mesaj yok"}');

      if (!mounted) return;

      // UI'ı güncelle
      setState(() {
        _messages = messages;
        _isLoading = false;
      });

      // Eğer mesaj listesi boş değilse en alta kaydır
      if (_messages.isNotEmpty) {
        Future.delayed(Duration(milliseconds: 100), () {
          _scrollToBottom();
        });
      }
    } catch (e) {
      print('Mesajları yükleme hatası: $e');

      // Token hatası kontrolü
      if (e.toString().contains('token') ||
          e.toString().contains('unauthorized') ||
          e.toString().contains('401')) {
        // Token yenileme denemesi
        try {
          print(
              'Token hatası algılandı, API servisini yenilemeye çalışılıyor...');
          final apiService = ApiService();
          await apiService.initializeToken();

          // Tekrar dene
          print('Token yenilendi, mesajlar tekrar yükleniyor...');
          final messages =
              await _communityService.fetchGroupMessages(widget.group['id']);

          if (!mounted) return;
          setState(() {
            _messages = messages;
            _isLoading = false;
          });

          if (_messages.isNotEmpty) {
            Future.delayed(Duration(milliseconds: 100), () {
              _scrollToBottom();
            });
          }
          return;
        } catch (retryError) {
          print('Yeniden deneme hatası: $retryError');
        }
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Hata mesajı göster - 404 hatası için özel mesaj
      String errorMessage = 'Mesajlar yüklenirken hata oluştu';
      String actionLabel = 'Tekrar Dene';

      if (e.toString().contains('404') || e.toString().contains('bulunamadı')) {
        errorMessage =
            'Bu grup için henüz mesaj bulunmuyor veya grup artık mevcut değil.';
        actionLabel = 'Tamam';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          duration: Duration(seconds: 5),
          action: SnackBarAction(
            label: actionLabel,
            textColor: Colors.white,
            onPressed: _loadMessages,
          ),
        ),
      );
    }
  }

  Future<void> _sendMessage(String message, File? imageFile) async {
    if ((message.trim().isEmpty && imageFile == null) || _isSending) return;

    setState(() => _isSending = true);
    try {
      print('Mesaj gönderiliyor...');
      print('Grup ID: ${widget.group['id']}');
      print('Mesaj içeriği: ${message.trim()}');
      print('Resim: ${imageFile?.path ?? 'Resim yok'}');

      final groupId = int.parse(widget.group['id'].toString());
      final success = await _communityService.sendGroupMessage(
        groupId,
        message.trim(),
        imageFile,
      );

      if (success && mounted) {
        // Mesaj gönderildikten sonra, kutuyu temizle
        _messageController.clear();

        // Geçici bir mesaj ekleyerek UI'ı hemen güncelle
        final tempMessage = {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'message': message.trim(),
          'image_url': imageFile != null ? imageFile.path : null,
          'doctor_id': _currentDoctorId,
          'created_at': DateTime.now().toIso8601String(),
          'temp': true // Geçici mesajı işaretliyoruz
        };

        setState(() {
          _messages.add(tempMessage);
        });

        // Mesaj kutusuna odaklan
        Future.delayed(Duration(milliseconds: 100), () {
          _scrollToBottom();
        });

        // Hemen ardından sunucudan güncel mesajları al
        await Future.delayed(Duration(seconds: 1));
        await _loadMessages();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mesaj başarıyla gönderildi'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Mesaj gönderme hatası: $e');

      // Token hatası kontrolü
      if (e.toString().contains('token') || e.toString().contains('401')) {
        try {
          // Token yenileme denemesi
          print('Token hatası algılandı, yenilemeye çalışılıyor...');
          final apiService = ApiService();
          await apiService.initializeToken();

          // Tekrar dene
          print('Token yenilendi, mesaj tekrar gönderiliyor...');
          final groupId = int.parse(widget.group['id'].toString());
          final success = await _communityService.sendGroupMessage(
              groupId, message.trim(), imageFile);

          if (success && mounted) {
            _messageController.clear();
            await _loadMessages();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Mesaj başarıyla gönderildi'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
            return;
          }
        } catch (retryError) {
          print('Yeniden deneme hatası: $retryError');
        }
      }

      if (mounted) {
        String errorMessage = 'Mesaj gönderilemedi';

        if (e.toString().contains('group_id ve message')) {
          errorMessage = 'Grup ID ve mesaj içeriği gereklidir';
        } else if (e.toString().contains('üye olmalısınız')) {
          errorMessage = 'Bu gruba mesaj gönderebilmek için üye olmalısınız';
        } else if (e.toString().contains('token')) {
          errorMessage =
              'Oturum süreniz dolmuş olabilir. Lütfen tekrar giriş yapın';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: Duration(seconds: 4),
            action: e.toString().contains('token')
                ? SnackBarAction(
                    label: 'Giriş Yap',
                    textColor: Colors.white,
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/login');
                    },
                  )
                : null,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _deleteMessage(int messageId) async {
    try {
      final success = await _communityService.deleteGroupMessage(messageId);
      if (success) {
        await _loadMessages();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mesaj başarıyla silindi')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mesaj silinemedi: $e')),
      );
    }
  }

  Future<void> _updateMessage(int messageId, String newMessage,
      [File? newImage]) async {
    try {
      final success = await _communityService.updateGroupMessage(
          messageId, newMessage, newImage);
      if (success) {
        await _loadMessages();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mesaj başarıyla güncellendi')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mesaj güncellenemedi: $e')),
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients && mounted) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmoji = !_showEmoji;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              margin: EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withOpacity(0.7),
                    primaryColorLight,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  widget.group['group_name'][0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.group['group_name'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green[300],
                        ),
                      ),
                      Text(
                        '${_messages.length} mesaj',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, size: 22),
            onPressed: () {},
            tooltip: 'Mesaj Ara',
          ),
          Container(
            margin: EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: _showGroupMembers,
              icon: Icon(Icons.group_outlined, size: 20),
              label: Text('Üyeler'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: primaryColor,
                        strokeWidth: 3,
                      ),
                    )
                  : Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                          ),
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              return Column(
                                children: [
                                  if (_communityService.shouldShowDateHeader(
                                      _messages, index))
                                    _buildDateHeader(message),
                                  GroupMessageBubble(
                                    message: message,
                                    isMe: message['doctor_id'].toString() ==
                                        _currentDoctorId,
                                    communityService: _communityService,
                                    backgroundColor:
                                        message['doctor_id'].toString() ==
                                                _currentDoctorId
                                            ? primaryColor
                                            : Colors.white,
                                    textColor:
                                        message['doctor_id'].toString() ==
                                                _currentDoctorId
                                            ? Colors.white
                                            : textColor1,
                                    onDelete: (messageId) =>
                                        _deleteMessage(messageId),
                                    onUpdate: (messageId, newMessage,
                                            newImage) =>
                                        _updateMessage(
                                            messageId, newMessage, newImage),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        if (_showScrollButton)
                          Positioned(
                            right: 16,
                            bottom: 16,
                            child: Material(
                              elevation: 4,
                              shadowColor: Colors.black26,
                              shape: CircleBorder(),
                              child: InkWell(
                                onTap: _scrollToBottom,
                                customBorder: CircleBorder(),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: primaryColor,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.keyboard_arrow_down,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            _buildMessageComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(Map<String, dynamic> message) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            _communityService.getDateHeaderText(
              _communityService.parseDate(message['created_at']),
            ),
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageComposer() {
    return ModernGroupMessageInput(
      controller: _messageController,
      isSending: _isSending,
      onSend: (message, imageFile) async {
        if (message.isEmpty && imageFile == null) return;
        await _sendMessage(message, imageFile);
      },
      onEmojiToggle: _toggleEmojiPicker,
      showEmoji: _showEmoji,
      imageUrl: null,
      onImagePicked: null,
      groupId: widget.group['id'].toString(),
    );
  }

  void _showGroupMembers() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, controller) => ModernGroupMembersSheet(
          groupId: int.parse(widget.group['id'].toString()),
          groupName: widget.group['group_name'],
          communityService: _communityService,
          scrollController: controller,
          isAdmin: widget.group['created_by'].toString() == _currentDoctorId,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
