import 'package:flutter/material.dart';
import '../../service/community_service.dart';
import '../../style/color.dart';
import '../../service/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

// Uygulama içinde kullanılan token sağlayıcı sınıf
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

class GroupMessageBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final CommunityService communityService;
  final Color backgroundColor;
  final Color textColor;
  final Function(int)? onDelete;
  final Function(int, String, File?)? onUpdate;

  const GroupMessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    required this.communityService,
    required this.backgroundColor,
    required this.textColor,
    this.onDelete,
    this.onUpdate,
  }) : super(key: key);

  @override
  State<GroupMessageBubble> createState() => _GroupMessageBubbleState();
}

class _GroupMessageBubbleState extends State<GroupMessageBubble> {
  final DateFormat timeFormatter = DateFormat('HH:mm');
  bool _isExpanded = false;
  late final ApiService _apiService;
  final TextEditingController _editController = TextEditingController();
  bool _isEditing = false;
  File? _newImage;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  void _showMessageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit, color: primaryColor),
              title: Text('Düzenle'),
              onTap: () {
                Navigator.pop(context);
                _startEditing();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Sil'),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _startEditing() {
    _editController.text = widget.message['message'] ?? '';
    setState(() {
      _isEditing = true;
      _newImage = null;
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _newImage = File(image.path);
      });
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mesajı Sil'),
        content: Text('Bu mesajı silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (widget.onDelete != null) {
                widget.onDelete!(widget.message['id']);
              }
            },
            child: Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _saveEdit() {
    if (_editController.text.trim().isEmpty && _newImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mesaj boş olamaz')),
      );
      return;
    }

    if (widget.onUpdate != null) {
      widget.onUpdate!(
        widget.message['id'],
        _editController.text.trim(),
        _newImage,
      );
    }

    setState(() {
      _isEditing = false;
      _newImage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<Map<String, dynamic>>(
      future:
          widget.communityService.getDoctorInfo(widget.message['doctor_id']),
      builder: (context, snapshot) {
        final doctorInfo =
            snapshot.data ?? {'name': 'Yükleniyor...', 'profile_photo': null};

        return Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment:
                widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!widget.isMe) ...[
                _buildUserAvatar(doctorInfo),
                SizedBox(width: 8),
              ],
              Flexible(
                child: GestureDetector(
                  onLongPress: widget.isMe ? _showMessageOptions : null,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.backgroundColor,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                          bottomLeft: widget.isMe
                              ? Radius.circular(20)
                              : Radius.circular(5),
                          bottomRight: widget.isMe
                              ? Radius.circular(5)
                              : Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: widget.isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          if (!widget.isMe) ...[
                            Padding(
                              padding:
                                  EdgeInsets.only(left: 16, top: 10, right: 16),
                              child: Text(
                                'Dr. ${doctorInfo['name']}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: theme.primaryColor,
                                ),
                              ),
                            ),
                            SizedBox(height: 4),
                          ],
                          if (_isEditing) ...[
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  TextField(
                                    controller: _editController,
                                    maxLines: null,
                                    style: TextStyle(
                                      color: widget.isMe
                                          ? Colors.white
                                          : widget.textColor,
                                    ),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'Mesajınızı düzenleyin...',
                                      hintStyle: TextStyle(
                                        color: widget.isMe
                                            ? Colors.white70
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.photo_library),
                                        color: widget.isMe
                                            ? Colors.white70
                                            : primaryColor,
                                        onPressed: _pickImage,
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _isEditing = false;
                                            _newImage = null;
                                          });
                                        },
                                        child: Text(
                                          'İptal',
                                          style: TextStyle(
                                            color: widget.isMe
                                                ? Colors.white70
                                                : Colors.grey,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _saveEdit,
                                        child: Text(
                                          'Kaydet',
                                          style: TextStyle(
                                            color: widget.isMe
                                                ? Colors.white
                                                : primaryColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            if (widget.message['image_url'] != null)
                              _buildImage(),
                            if (widget.message['message'] != null &&
                                widget.message['message'].trim().isNotEmpty)
                              Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  widget.message['message'],
                                  style: TextStyle(
                                    color: widget.isMe
                                        ? Colors.white
                                        : widget.textColor,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                          ],
                          Padding(
                            padding: EdgeInsets.only(
                              left: 16,
                              right: 16,
                              bottom: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.communityService.formatMessageTime(
                                      widget.message['created_at']),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: widget.isMe
                                        ? Colors.white.withOpacity(0.8)
                                        : Colors.grey[600],
                                  ),
                                ),
                                if (widget.isMe) ...[
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.done_all,
                                    size: 14,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.isMe) SizedBox(width: 8),
              if (widget.isMe) _buildUserAvatar(doctorInfo),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserAvatar(Map<String, dynamic> doctorInfo) {
    return Stack(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[200],
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: doctorInfo['profile_photo'] != null
              ? _getProfileImage(doctorInfo['profile_photo'])
              : Center(
                  child: Text(
                    doctorInfo['name'] != null && doctorInfo['name'].isNotEmpty
                        ? doctorInfo['name'][0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
        if (widget.isMe)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _getProfileImage(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) {
      return Image.asset(
        'assets/images/default_avatar.png',
        fit: BoxFit.cover,
      );
    }

    String imageUrl = photoUrl;
    if (!imageUrl.startsWith('http')) {
      imageUrl = imageUrl.startsWith('/')
          ? '${ApiService.baseUrl}$imageUrl'
          : '${ApiService.baseUrl}/$imageUrl';
    }

    return FutureBuilder<String?>(
      future: AuthTokenProvider.getToken(),
      builder: (context, tokenSnapshot) {
        if (tokenSnapshot.connectionState == ConnectionState.waiting) {
          return Container(color: Colors.grey[200]);
        }

        final token = tokenSnapshot.data;
        if (token == null) {
          return Container(color: Colors.grey[200]);
        }

        return Image.network(
          imageUrl,
          fit: BoxFit.cover,
          headers: {
            'Authorization': 'Bearer $token',
          },
          errorBuilder: (context, error, stackTrace) {
            print('Profil resmi yükleme hatası: $error');

            if (error.toString().contains('401') ||
                error.toString().contains('unauthorized')) {
              _apiService.initializeToken().then((_) {
                if (mounted) setState(() {});
              });
            }

            return Container(color: Colors.grey[200]);
          },
        );
      },
    );
  }

  Widget _buildImage() {
    if (widget.message['image_url'] == null) return SizedBox.shrink();

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
        maxHeight: 300,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FutureBuilder<String?>(
          future: AuthTokenProvider.getToken(),
          builder: (context, tokenSnapshot) {
            if (tokenSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingContainer();
            }

            final token = tokenSnapshot.data;
            if (token == null) {
              return _buildErrorContainer('Oturum bilgisi bulunamadı');
            }

            String imageUrl = widget.message['image_url']!;
            final List<String> alternativeUrls = [];

            if (!imageUrl.startsWith('http')) {
              if (!imageUrl.startsWith('${ApiService.baseUrl}')) {
                // Ana yol
                imageUrl = imageUrl.startsWith('/uploads/')
                    ? '${ApiService.baseUrl}$imageUrl'
                    : '${ApiService.baseUrl}/uploads/messages/$imageUrl';

                print('Ana resim URL\'si deneniyor: $imageUrl');

                // Alternatif yolları da deneyelim
                alternativeUrls.addAll([
                  '$imageUrl',
                  '${ApiService.baseUrl}/storage/app/public/messages/$imageUrl',
                  '${ApiService.baseUrl}/public/uploads/messages/$imageUrl',
                  '${ApiService.baseUrl}/storage/messages/$imageUrl'
                ]);

                print('Alternatif resim URL\'leri: $alternativeUrls');
              }
            }

            return Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                headers: {'Authorization': 'Bearer $token'},
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded) return child;
                  return AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    child: child,
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildLoadingContainer(
                    progress: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  print('Resim yükleme hatası: $error');
                  print('Hata detayı: $stackTrace');

                  if (error.toString().contains('404')) {
                    print(
                        '404 hatası tespit edildi, alternatif yollar deneniyor...');

                    // Alternatif yolları asenkron olarak dene
                    _tryAlternativeUrls(alternativeUrls, token);
                  }

                  if (error.toString().contains('401') ||
                      error.toString().contains('unauthorized')) {
                    print('Token hatası tespit edildi, yenileme deneniyor...');
                    _apiService.initializeToken().then((_) {
                      if (mounted) setState(() {});
                    });
                  }

                  return Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.grey[400],
                            size: 40,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Resim yüklenemedi\nURL: $imageUrl',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingContainer({double? progress}) {
    return Container(
      height: 200,
      width: 300,
      color: Colors.grey[200],
      child: Center(
        child: CircularProgressIndicator(
          value: progress,
          color: primaryColor,
        ),
      ),
    );
  }

  Widget _buildErrorContainer(String message) {
    return Container(
      height: 200,
      width: 300,
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.grey[400],
              size: 40,
            ),
            SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _tryAlternativeUrls(List<String> urls, String token) async {
    for (var altUrl in urls) {
      try {
        final response = await http.head(Uri.parse(altUrl),
            headers: {'Authorization': 'Bearer $token'});
        if (response.statusCode == 200) {
          if (mounted) {
            setState(() {
              // Başarılı URL'yi kullan
              widget.message['image_url'] = altUrl;
            });
            return;
          }
        }
      } catch (e) {
        print('Alternatif URL denemesi başarısız: $altUrl');
        print('Hata: $e');
      }
    }
  }
}
