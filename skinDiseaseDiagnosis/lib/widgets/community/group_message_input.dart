import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../style/color.dart';
import '../../service/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthTokenProvider {
  static String? _cachedToken;

  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;

    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString('token');
    return _cachedToken;
  }

  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    if (token == null) return {};
    return {'Authorization': 'Bearer $token'};
  }
}

class ModernGroupMessageInput extends StatefulWidget {
  final TextEditingController controller;
  final bool isSending;
  final Function(String, File?) onSend;
  final VoidCallback onEmojiToggle;
  final bool showEmoji;
  final String? imageUrl;
  final Future<File?> Function()? onImagePicked;
  final String groupId;

  const ModernGroupMessageInput({
    Key? key,
    required this.controller,
    required this.isSending,
    required this.onSend,
    required this.onEmojiToggle,
    required this.showEmoji,
    required this.groupId,
    this.imageUrl,
    this.onImagePicked,
  }) : super(key: key);

  @override
  State<ModernGroupMessageInput> createState() =>
      _ModernGroupMessageInputState();
}

class _ModernGroupMessageInputState extends State<ModernGroupMessageInput> {
  File? _selectedImage;
  Map<String, String> _authHeaders = {};
  final ApiService _apiService = ApiService();
  final FocusNode _focusNode = FocusNode();
  bool _isCommentValid = false;

  @override
  void initState() {
    super.initState();
    _loadAuthHeaders();
    widget.controller.addListener(_updateCommentValidity);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateCommentValidity);
    super.dispose();
  }

  void _updateCommentValidity() {
    final isValid =
        widget.controller.text.trim().isNotEmpty || _selectedImage != null;
    if (isValid != _isCommentValid) {
      setState(() {
        _isCommentValid = isValid;
      });
    }
  }

  Future<void> _loadAuthHeaders() async {
    try {
      final headers = await AuthTokenProvider.getAuthHeaders();
      if (mounted) {
        setState(() {
          _authHeaders = headers;
        });
      }
    } catch (e) {
      print('Token yükleme hatası: $e');
    }
  }

  Future<void> _refreshTokenAndRetry() async {
    try {
      await _apiService.initializeToken();
      if (mounted) {
        await _loadAuthHeaders();
      }
    } catch (e) {
      print('Token yenileme hatası: $e');
    }
  }

  Future<void> _pickImage() async {
    if (widget.onImagePicked != null) {
      final File? pickedImage = await widget.onImagePicked!();
      if (pickedImage != null && mounted) {
        setState(() {
          _selectedImage = pickedImage;
          _updateCommentValidity();
        });
      }
      return;
    }

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
                      color: cameraColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.camera_alt, color: cameraColor),
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
          final File imageFile = File(image.path);
          setState(() {
            _selectedImage = imageFile;
            _updateCommentValidity();
          });
        }
      }
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
    }
  }

  void _sendMessage() {
    if (widget.isSending) return;

    final message = widget.controller.text.trim();
    if (message.isEmpty && _selectedImage == null) return;

    // Grup ID'sini ve mesajı gönder
    widget.onSend(message, _selectedImage);
    widget.controller.clear();
    setState(() {
      _selectedImage = null;
      _updateCommentValidity();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: backgroundColor),
        ),
      ),
      child: Column(
        children: [
          if (_selectedImage != null)
            Container(
              height: 150,
              padding: EdgeInsets.all(8),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: FileImage(_selectedImage!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedImage = null;
                          _updateCommentValidity();
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
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (widget.showEmoji) _buildEmojiPicker(),
          _buildImagePreview(),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: primaryColorLight.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: _pickImage,
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Icon(
                          Icons.add_photo_alternate_outlined,
                          color: cameraColor,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    maxLines: 5,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) => _updateCommentValidity(),
                    style: TextStyle(fontSize: 15, color: textColor1),
                    decoration: InputDecoration(
                      hintText: "Mesajınızı yazın...",
                      hintStyle: TextStyle(color: textColor2.withOpacity(0.5)),
                      filled: true,
                      fillColor: backgroundColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: primaryColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isCommentValid
                        ? secondaryColor
                        : textColor2.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: (!_isCommentValid || widget.isSending)
                          ? null
                          : _sendMessage,
                      child: Center(
                        child: widget.isSending
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Icon(
                                Icons.send_rounded,
                                color: _isCommentValid
                                    ? Colors.white
                                    : Colors.white54,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiPicker() {
    // This is a placeholder for an emoji picker
    // In a real app, you would integrate a proper emoji picker package
    return Container(
      height: 200,
      color: Colors.grey[100],
      child: GridView.builder(
        padding: EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          childAspectRatio: 1.0,
        ),
        itemCount: 30,
        itemBuilder: (context, index) {
          final emojis = [
            '😊',
            '😂',
            '😍',
            '👍',
            '😒',
            '😭',
            '😘',
            '🤔',
            '😁',
            '😳',
            '🙄',
            '😔',
            '❤️',
            '😎',
            '✌️',
            '😉',
            '🎉',
            '👋',
            '🤦‍♂️',
            '🤷‍♀️',
            '🔥',
            '👏',
            '🙏',
            '💯',
            '🤣',
            '😢',
            '😡',
            '😜',
            '🙂',
            '😋'
          ];
          return InkWell(
            onTap: () {
              // Add emoji to text controller
              widget.controller.text += emojis[index];
            },
            child: Center(
              child: Text(
                emojis[index],
                style: TextStyle(fontSize: 24),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImagePreview() {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty)
      return SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: FutureBuilder<Map<String, String>>(
          future: AuthTokenProvider.getAuthHeaders(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 100,
                width: 100,
                color: Colors.grey[200],
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final headers = snapshot.data ?? {};
            print(
                'Resim önizleme için kullanılan headers: $headers'); // Debug log

            return Image.network(
              widget.imageUrl!.startsWith('http')
                  ? widget.imageUrl!
                  : '${ApiService.baseUrl}/uploads/${widget.imageUrl!}',
              fit: BoxFit.cover,
              headers: headers,
              errorBuilder: (context, error, stackTrace) {
                print('Resim yükleme hatası: $error');
                print('Hata detayı: $stackTrace');

                if (error.toString().contains('401') ||
                    error.toString().contains('unauthorized')) {
                  print('Token hatası tespit edildi, yenileme deneniyor...');
                  _refreshTokenAndRetry();
                }

                return Container(
                  height: 100,
                  width: 100,
                  color: Colors.grey[200],
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.grey[400],
                          size: 24,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Yüklenemedi',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
