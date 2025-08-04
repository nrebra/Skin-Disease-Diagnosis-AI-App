import 'package:flutter/material.dart';
import 'package:skincancer/style/color.dart';
import '../../service/api_service.dart';
import 'dart:async';
import '../../models/message_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../../widgets/community/group_message_input.dart';

class ChatPage extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String receiverSurname;

  const ChatPage({
    Key? key,
    required this.receiverId,
    required this.receiverName,
    required this.receiverSurname,
  }) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _isLoading = false;
  Timer? _refreshTimer;
  bool _isDisposed = false;
  String? _userId;
  String? _token;
  bool _isSending = false;
  bool _showScrollToBottom = false;
  File? _selectedImage;
  bool _isUploadingImage = false;
  bool _showAttachmentOptions = false;

  @override
  void initState() {
    super.initState();
    _getUserData();
    _startMessageRefresh();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      setState(() {
        _showScrollToBottom = currentScroll < maxScroll - 300;
      });
    }
  }

  Future<void> _getUserData() async {
    print('ChatPage - Kullanıcı verileri alınıyor...');
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final token = prefs.getString('token');

    print('ChatPage - SharedPreferences\'dan alınan userId: $userId');
    print('ChatPage - SharedPreferences\'dan alınan token: $token');

    if (mounted) {
      setState(() {
        _userId = userId;
        _token = token;
      });

      if (token != null && userId != null) {
        print('ChatPage - Token ve UserId mevcut, mesajlar getiriliyor...');
        _apiService.setToken(token);
        await _fetchMessages();
      } else {
        print(
            'ChatPage - Token veya UserId eksik, login sayfasına yönlendiriliyor...');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Oturum süresi dolmuş. Lütfen tekrar giriş yapın.'),
            duration: Duration(seconds: 2),
          ),
        );

        Future.delayed(Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        });
      }
    }
  }

  void _startMessageRefresh() {
    _refreshTimer = Timer.periodic(Duration(seconds: 5), (_) {
      if (!_isDisposed && !_isSending) {
        _fetchMessages();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    if (_isLoading || _isDisposed || _userId == null || _token == null) return;

    setState(() => _isLoading = true);

    try {
      final response = await _apiService.getMessages();

      if (response['status'] == 'success' && response['data'] != null) {
        final List<Message> allMessages = [];

        for (var messageData in response['data'] as List) {
          try {
            final message =
                Message.fromJson(messageData as Map<String, dynamic>);
            // Bu sohbete ait mesajları filtrele
            if ((message.senderId == _userId &&
                    message.receiverId == widget.receiverId) ||
                (message.senderId == widget.receiverId &&
                    message.receiverId == _userId)) {
              allMessages.add(message);
            }
          } catch (e) {
            // Hatalı mesajı atla ve devam et
            continue;
          }
        }

        // Mesajları tarihe göre sırala (en yeni mesajlar en altta)
        allMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        if (mounted) {
          setState(() {
            _messages = allMessages;
            _isLoading = false;
          });

          // Mesajlar yüklendikten sonra en alta kaydır
          if (_messages.isNotEmpty) {
            Future.delayed(Duration(milliseconds: 100), _scrollToBottom);
          }
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Mesajlar alınamadı'),
              action: SnackBarAction(
                label: 'Tekrar Dene',
                onPressed: _fetchMessages,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mesajlar yüklenirken hata oluştu'),
            action: SnackBarAction(
              label: 'Tekrar Dene',
              onPressed: _fetchMessages,
            ),
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      } catch (e) {
        print("Otomatik kaydırma hatası: $e");
      }
    });
  }

  Future<void> _sendMessage() async {
    final String text = _messageController.text.trim();
    if ((text.isEmpty && _selectedImage == null) || _isSending) return;

    setState(() => _isSending = true);

    try {
      final response = await _apiService.sendMessage(
        widget.receiverId,
        text,
        imageFile: _selectedImage,
      );

      if (_isDisposed) return;

      if (response['status'] == 'success') {
        _messageController.clear();
        _selectedImage = null;
        await _fetchMessages();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Mesaj gönderilemedi')),
          );
        }
      }
    } catch (e) {
      if (e.toString().contains('token') || e.toString().contains('401')) {
        try {
          await _apiService.initializeToken();
          final response = await _apiService.sendMessage(
            widget.receiverId,
            text,
            imageFile: _selectedImage,
          );

          if (response['status'] == 'success') {
            await _fetchMessages();
          } else {
            await _handleSendError(e.toString());
          }
        } catch (retryError) {
          await _handleSendError(retryError.toString());
          if (retryError.toString().contains('token')) {
            _handleTokenError();
          }
        }
      } else {
        await _handleSendError(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _handleSendError(String errorMessage) async {
    if (mounted) {
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mesaj gönderilemedi'),
          duration: Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Tekrar Dene',
            onPressed: _sendMessage,
          ),
        ),
      );
    }
  }

  // Token hatası için yardımcı metod
  void _handleTokenError() {
    if (mounted && !_isDisposed) {
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Oturum süresi dolmuş. Lütfen tekrar giriş yapın.'),
          duration: Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Giriş Yap',
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ),
      );

      Future.delayed(Duration(seconds: 3), () {
        if (mounted && !_isDisposed) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      });
    }
  }

  String _getTimeString(DateTime dateTime) {
    return DateFormat.Hm().format(dateTime);
  }

  bool _showDateHeader(int index) {
    if (index == 0) return true;

    final currentDate = _messages[index].createdAt;
    final previousDate = _messages[index - 1].createdAt;

    return currentDate.year != previousDate.year ||
        currentDate.month != previousDate.month ||
        currentDate.day != previousDate.day;
  }

  String _getDateHeaderText(DateTime date) {
    final now = DateTime.now();
    final yesterday = DateTime.now().subtract(Duration(days: 1));

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Bugün';
    } else if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Dün';
    } else {
      return DateFormat.yMMMd('tr_TR').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: null,
      body: SafeArea(
        child: Column(
          children: [
            // Özel başlık çubuğu
            Container(
              color: textColor2,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Dr. ${widget.receiverName} ${widget.receiverSurname}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color.fromARGB(255, 234, 230, 230),
                        ),
                      ),
                      Text(
                        'Çevrimiçi',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _userId == null
                  ? Center(child: CircularProgressIndicator())
                  : Stack(
                      children: [
                        Column(
                          children: [
                            Expanded(
                              child: _isLoading && _messages.isEmpty
                                  ? Center(
                                      child: CircularProgressIndicator(
                                        color: primaryColor,
                                      ),
                                    )
                                  : GestureDetector(
                                      onTap: () =>
                                          FocusScope.of(context).unfocus(),
                                      child: ListView.builder(
                                        controller: _scrollController,
                                        padding: EdgeInsets.only(
                                            top: 16,
                                            bottom: 16,
                                            left: 8,
                                            right: 8),
                                        itemCount: _messages.length,
                                        addAutomaticKeepAlives: false,
                                        addRepaintBoundaries: false,
                                        itemBuilder: (context, index) {
                                          final message = _messages[index];
                                          final isMe =
                                              message.senderId == _userId;
                                          return RepaintBoundary(
                                            child: _buildMessageBubble(
                                                message, isMe),
                                          );
                                        },
                                      ),
                                    ),
                            ),
                            _buildMessageComposer(),
                          ],
                        ),
                        if (_showScrollToBottom)
                          Positioned(
                            right: 16,
                            bottom: 80,
                            child: FloatingActionButton(
                              heroTag: 'chat_scroll_button',
                              mini: true,
                              backgroundColor: primaryColor,
                              elevation: 2,
                              child: Icon(Icons.arrow_downward,
                                  color: Colors.white),
                              onPressed: _scrollToBottom,
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(DateTime date) {
    return Container(
      margin: EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getDateHeaderText(date),
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsSheet() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: primaryColor.withOpacity(0.1),
              child: Icon(
                Icons.report_problem_outlined,
                color: primaryColor,
              ),
            ),
            title: Text('Bildir'),
            subtitle: Text('Bu konuşmayı moderatörlere bildir'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Bildirim alındı, incelenecek')),
              );
            },
          ),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: primaryColor.withOpacity(0.1),
              child: Icon(
                Icons.delete_outline,
                color: Colors.red,
              ),
            ),
            title: Text('Konuşmayı Sil', style: TextStyle(color: Colors.red)),
            subtitle: Text('Bu konuşmayı tamamen sil'),
            onTap: () {
              Navigator.pop(context);
              _showDeleteConfirmation();
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Konuşmayı Sil'),
        content: Text(
            'Bu konuşmayı silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            child: Text('İptal'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('Sil', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(context);
              // TODO: API'ye silme isteği gönderilebilir
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Konuşma silindi')),
              );
              Navigator.pop(context); // Chat sayfasından çık
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isSender) {
    print('Mesaj balonu oluşturuluyor:');
    print('- Mesaj ID: ${message.id}');
    print('- İçerik: ${message.messageText}');
    print('- Gönderen mi: $isSender');

    final bubbleColor = isSender ? primaryColor : Colors.grey[200];
    final textColor = isSender ? Colors.white : Colors.black87;
    final alignment =
        isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Align(
      alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: alignment,
          children: [
            Text(
              message.messageText,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _getTimeString(message.createdAt),
                style: TextStyle(
                  color: isSender ? Colors.white70 : Colors.black54,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatImageUrl(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return imageUrl;
    }

    // Backend'in uploads klasör yolu
    const String uploadPath = 'uploads/';

    // Base URL'yi ApiService'den al
    final baseUrl = ApiService.baseUrl;

    // URL'yi temizle ve formatla
    imageUrl = imageUrl.trim();
    if (imageUrl.startsWith('/')) {
      imageUrl = imageUrl.substring(1);
    }

    // Tam URL oluştur
    String fullUrl = baseUrl;
    if (!fullUrl.endsWith('/')) {
      fullUrl += '/';
    }
    fullUrl += uploadPath + imageUrl;

    print('Formatlanmış resim URL: $fullUrl'); // Debug için
    return fullUrl;
  }

  void _showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black.withOpacity(0.7),
              ),
            ),
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: Image(
                image: NetworkImage(
                  _formatImageUrl(imageUrl),
                  headers: {
                    'Authorization': 'Bearer $_token',
                  },
                ),
                fit: BoxFit.contain,
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.8,
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<File?> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      ImageSource? source;

      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
        ),
        builder: (BuildContext context) {
          return Container(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.photo_library, color: primaryColor),
                  ),
                  title: Text('Galeriden Seç'),
                  onTap: () {
                    source = ImageSource.gallery;
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.camera_alt, color: primaryColor),
                  ),
                  title: Text('Fotoğraf Çek'),
                  onTap: () {
                    source = ImageSource.camera;
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          );
        },
      );

      if (source != null) {
        final XFile? image = await picker.pickImage(
          source: source!,
          imageQuality: 70,
          maxWidth: 1024,
          maxHeight: 1024,
        );

        if (image != null && mounted) {
          setState(() {
            _selectedImage = File(image.path);
          });
          return _selectedImage;
        }
      }
      return null;
    } catch (e) {
      print('Resim seçme hatası: $e');
      if (mounted) {
        String errorMessage = 'Resim seçilirken bir hata oluştu';
        if (e.toString().contains('camera')) {
          errorMessage = 'Kameraya erişilemiyor. Lütfen galeriyi kullanın.';
        } else if (e.toString().contains('permission')) {
          errorMessage =
              'Gerekli izinler verilmedi. Ayarlardan izin vermeniz gerekiyor.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            action: SnackBarAction(
              label: 'Tamam',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
      return null;
    }
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            offset: Offset(0, -2),
            blurRadius: 6.0,
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedImage != null)
            Container(
              height: 100,
              margin: EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Image.file(
                      _selectedImage!,
                      height: 100,
                      width: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedImage = null;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.photo_camera, color: primaryColor),
                onPressed: () async {
                  final image = await _pickImage();
                  if (image != null) {
                    setState(() {
                      _selectedImage = image;
                    });
                  }
                },
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Mesaj yazın...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24.0),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                ),
              ),
              SizedBox(width: 8),
              AnimatedOpacity(
                opacity: _messageController.text.trim().isNotEmpty ||
                        _selectedImage != null
                    ? 1.0
                    : 0.6,
                duration: Duration(milliseconds: 200),
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor: primaryColor,
                  elevation: 2,
                  onPressed: (_messageController.text.trim().isNotEmpty ||
                          _selectedImage != null)
                      ? _sendMessage
                      : null,
                  child: Icon(Icons.send, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentOptions() {
    final options = [
      {'icon': Icons.photo, 'color': Colors.green, 'label': 'Fotoğraf'},
      {'icon': Icons.camera_alt, 'color': Colors.blue, 'label': 'Kamera'},
      {
        'icon': Icons.insert_drive_file,
        'color': Colors.orange,
        'label': 'Dosya'
      },
      {'icon': Icons.location_on, 'color': Colors.red, 'label': 'Konum'},
    ];

    return Container(
      height: 180,
      padding: EdgeInsets.symmetric(vertical: 30),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 1,
        ),
        itemCount: options.length,
        itemBuilder: (context, index) {
          final option = options[index];
          return GestureDetector(
            onTap: () {
              Navigator.pop(context);
              if (option['icon'] == Icons.photo) {
                _pickImage();
              } else if (option['icon'] == Icons.camera_alt) {
                _takePhoto();
              } else if (option['icon'] == Icons.insert_drive_file) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Dosya ekleme yakında gelecek'),
                  ),
                );
              } else if (option['icon'] == Icons.location_on) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Konum ekleme yakında gelecek'),
                  ),
                );
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: textColor1,
                  child: Icon(
                    option['icon'] as IconData,
                    color: option['color'] as Color,
                    size: 24,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  option['label'] as String,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _showAttachmentOptions = false;
      });
      await _uploadAndSendImage();
    }
  }

  Future<void> _uploadAndSendImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      // Doğrudan _sendMessage metodunu çağır
      await _sendMessage();
    } catch (e) {
      print("Resim yükleme hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resim yüklenemedi: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            action: SnackBarAction(
              label: 'Tekrar Dene',
              textColor: Colors.white,
              onPressed: _uploadAndSendImage,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }
}

// Extend Message model to add isOptimistic property for UI state tracking
extension on Message {
  bool get isOptimistic => this.id.startsWith('temp_');
}
