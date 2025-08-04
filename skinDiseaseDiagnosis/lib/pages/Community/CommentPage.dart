import 'package:flutter/material.dart';
import 'dart:async';
import 'package:skincancer/style/color.dart';
import '../../service/api_service.dart';
import 'package:provider/provider.dart';
import '../../provider/post_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
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

class CommentPage extends StatefulWidget {
  final String postId;
  final String postOwnerId;
  const CommentPage({
    Key? key,
    required this.postId,
    required this.postOwnerId,
  }) : super(key: key);

  @override
  State<CommentPage> createState() => _CommentPageState();
}

class _CommentPageState extends State<CommentPage> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _comments = [];
  Map<String, String> _doctorNames = {};
  bool _isLoading = false;
  Timer? _refreshTimer;
  bool _isDisposed = false;
  File? _selectedImage;
  Map<String, String> _authHeaders = {};
  String? _currentUserId;
  bool _isCommentValid = false;

  Color _getAvatarColor(String userId) {
    final colors = [
      primaryColor,
      secondaryColor,
      galleryColor,
      cameraColor,
      comment1Color,
      comment2Color,
      comment3Color,
      textColor1,
    ];
    final index = userId.hashCode % colors.length;
    return colors[index];
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _fetchComments();
    _loadAuthHeaders();
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (!_isDisposed) {
        _fetchComments();
      }
    });

    // Yorum metni değişikliklerini dinle
    _commentController.addListener(() {
      setState(() {
        _isCommentValid =
            _commentController.text.trim().isNotEmpty || _selectedImage != null;
      });
    });
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _currentUserId = prefs.getString('user_id');
        });
      }
    } catch (e) {
      print('Kullanıcı kimliği yükleme hatası: $e');
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

  @override
  void dispose() {
    _isDisposed = true;
    _refreshTimer?.cancel();
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> showDeleteDialog(String commentId) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yorumu Sil'),
        content: const Text('Bu yorumu silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteComment(commentId);
            },
            child: Text('Sil', style: TextStyle(color: primaryColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      setState(() => _isLoading = true);
      final response = await _apiService.deleteComment(commentId);

      if (response['message'] != null) {
        // Yorumu listeden kaldır
        setState(() {
          _comments
              .removeWhere((comment) => comment['id'].toString() == commentId);
        });

        // Post Provider'ı ve yorum sayısını güncelle
        if (context.mounted) {
          final postProvider =
              Provider.of<PostProvider>(context, listen: false);
          await postProvider.updatePostCommentCount(widget.postId);
          await postProvider.fetchPosts();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yorum silinirken hata oluştu: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDoctorName(String doctorId) async {
    if (_doctorNames.containsKey(doctorId)) return;

    try {
      final response = await _apiService.getDoctor(int.parse(doctorId));
      if (response['status'] == 'success' && response['data'] != null) {
        final doctorData = response['data'];
        final doctorName = '${doctorData['name']} ${doctorData['surname']}';
        setState(() {
          _doctorNames[doctorId] = doctorName;
        });
      }
    } catch (e) {
      print('Doktor bilgisi yüklenirken hata: $e');
      // int.parse hatası durumunda varsayılan değeri kullan
      if (e is FormatException) {
        setState(() {
          _doctorNames[doctorId] = 'Dr. $doctorId';
        });
      }
    }
  }

  Future<void> _fetchComments() async {
    if (_isLoading || _isDisposed) return;

    setState(() => _isLoading = true);
    try {
      print('Yorumlar alınıyor - Post ID: ${widget.postId}');
      final comments = await _apiService.getComments(widget.postId);

      print('Alınan yorum sayısı: ${comments.length}');

      if (!_isDisposed) {
        setState(() {
          _comments = comments;
          _isLoading = false;
        });

        if (comments.isEmpty) {
          print('Hiç yorum alınamadı veya hiç yorum yok');

          // Test için yorum ekliyorsak buradan kaldır
          // Yorum bulunamadığında daha iyi bir kullanıcı deneyimi için ScaffoldMessenger kullanabilirsiniz
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(content: Text('Bu gönderiye henüz yorum yapılmamış')),
          // );
        } else {
          print('İlk yorumun içeriği: ${comments.first}');

          // Her yorum için doktor ismini yükle
          for (var comment in comments) {
            if (comment.containsKey('doctor_id')) {
              final doctorId = comment['doctor_id'].toString();
              _loadDoctorName(doctorId);
            } else {
              print('Uyarı: Yorumda doctor_id alanı yok: $comment');
            }
          }
        }
      }
    } catch (e) {
      print('Yorumlar yüklenirken hata: $e');
      if (!_isDisposed) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => Container(
        height: 150,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      try {
        final XFile? image = await picker.pickImage(
          source: source,
          imageQuality: 70,
        );

        if (image != null) {
          setState(() {
            _selectedImage = File(image.path);
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Resim seçilirken bir hata oluştu')),
        );
      }
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yorum veya resim ekleyin')),
      );
      return;
    }

    // Post ID kontrolü ekleyelim
    if (widget.postId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Post ID bulunamadı. Lütfen tekrar deneyin.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('Post ID kontrolü: ${widget.postId}'); // Debug log

      final response = await _apiService.addCommentWithImage(
        widget.postId,
        _currentUserId ?? '',
        _commentController.text.trim(),
        _selectedImage,
      );

      if (!_isDisposed) {
        final now = DateTime.now().toUtc();
        final formattedDate =
            '${now.toIso8601String().split('T')[0]} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} GMT';

        final commentId = response['comment_id'] ??
            response['id'] ??
            DateTime.now().millisecondsSinceEpoch.toString();

        setState(() {
          _comments.add({
            'id': commentId,
            'doctor_id': _currentUserId,
            'comment_text': _commentController.text.trim(),
            'image_url': response['image_url'],
            'created_at': formattedDate,
          });
          _isLoading = false;
          _selectedImage = null;
        });

        _commentController.clear();
        setState(() {
          _isCommentValid = false;
        });

        // Post Provider'ı ve yorum sayısını güncelle
        if (context.mounted) {
          final postProvider =
              Provider.of<PostProvider>(context, listen: false);
          await postProvider.updatePostCommentCount(widget.postId);
          await postProvider.fetchPosts();
        }
      }
    } catch (e) {
      if (!_isDisposed) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  DateTime parseDateTime(String dateStr) {
    try {
      final RegExp pattern = RegExp(
          r'^[A-Za-z]+, (\d{2}) ([A-Za-z]+) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$');
      final Match? match = pattern.firstMatch(dateStr);

      if (match != null) {
        final Map<String, int> months = {
          'Jan': 1,
          'Feb': 2,
          'Mar': 3,
          'Apr': 4,
          'May': 5,
          'Jun': 6,
          'Jul': 7,
          'Aug': 8,
          'Sep': 9,
          'Oct': 10,
          'Nov': 11,
          'Dec': 12
        };

        final int day = int.parse(match.group(1)!);
        final int month = months[match.group(2)!]!;
        final int year = int.parse(match.group(3)!);
        final int hour = int.parse(match.group(4)!);
        final int minute = int.parse(match.group(5)!);
        final int second = int.parse(match.group(6)!);

        return DateTime.utc(year, month, day, hour, minute, second);
      }
    } catch (e) {
      print('Tarih parse hatası: $e');
    }

    return DateTime.now();
  }

  // Basit tarih farkı hesaplayıcı
  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} yıl önce';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} ay önce';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Az önce';
    }
  }

  Widget _buildCommentImage(String imageUrl) {
    return Container(
      height: 150,
      margin: EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.withOpacity(0.1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl.startsWith('http')
              ? imageUrl
              : '${ApiService.baseUrl}/uploads/$imageUrl',
          fit: BoxFit.cover,
          headers: _authHeaders,
          errorBuilder: (context, error, stackTrace) {
            print('Resim yükleme hatası: $error');
            // Token hatası kontrolü
            if (error.toString().contains('401') ||
                error.toString().contains('unauthorized')) {
              // Token'ı yenilemeyi dene
              _apiService.initializeToken().then((_) {
                if (mounted) {
                  setState(() {
                    _loadAuthHeaders();
                  });
                }
              }).catchError((tokenError) {
                print('Token yenileme hatası: $tokenError');
              });
            }
            return Center(
              child: Icon(Icons.error_outline, color: Colors.grey),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        centerTitle: false,
        title: const Text(
          "Yorumlar",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort, color: Colors.white),
            onPressed: () {
              // Sıralama seçenekleri
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading && _comments.isEmpty
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: secondaryColor,
                    ),
                  )
                : _comments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: primaryColorLight.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.chat_bubble_outline,
                                size: 48,
                                color: textColor2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "İlk yorumu sen yap :)",
                              style: TextStyle(
                                fontSize: 16,
                                color: textColor2,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: secondaryColor,
                        onRefresh: _fetchComments,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _comments.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final comment = _comments[index];
                            final doctorId = comment['doctor_id'].toString();
                            final doctorName =
                                _doctorNames[doctorId] ?? 'Dr. $doctorId';
                            final isCommentOwner = _currentUserId != null &&
                                _currentUserId == doctorId;
                            final isPostOwner = _currentUserId != null &&
                                _currentUserId == widget.postOwnerId;

                            return Card(
                              elevation: 0,
                              margin: EdgeInsets.zero,
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                    color: primaryColorLight.withOpacity(0.1)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor:
                                              _getAvatarColor(doctorId),
                                          child: Text(
                                            doctorName[0].toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                doctorName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: textColor1,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _getTimeAgo(parseDateTime(
                                                    comment['created_at'])),
                                                style: TextStyle(
                                                  color: textColor2
                                                      .withOpacity(0.7),
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isCommentOwner || isPostOwner)
                                          Material(
                                            color: Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(50),
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(50),
                                              onTap: () => showDeleteDialog(
                                                  comment['id'].toString()),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: Icon(
                                                  Icons.more_vert,
                                                  color: textColor2,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (comment['comment_text'] != null &&
                                        comment['comment_text']
                                            .toString()
                                            .trim()
                                            .isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            top: 12, left: 4),
                                        child: Text(
                                          comment['comment_text'],
                                          style: TextStyle(
                                            fontSize: 15,
                                            height: 1.4,
                                            color: textColor1,
                                          ),
                                        ),
                                      ),
                                    if (comment['image_url'] != null &&
                                        comment['image_url']
                                            .toString()
                                            .isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: GestureDetector(
                                            onTap: () {
                                              // Resmi tam ekran görüntüleme
                                            },
                                            child: Hero(
                                              tag:
                                                  'comment_image_${comment['id']}',
                                              child: Image.network(
                                                comment['image_url'].toString(),
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: 200,
                                                loadingBuilder: (context, child,
                                                    loadingProgress) {
                                                  if (loadingProgress == null)
                                                    return child;
                                                  return Container(
                                                    height: 200,
                                                    width: double.infinity,
                                                    color: backgroundColor,
                                                    child: Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: primaryColor,
                                                        value: loadingProgress
                                                                    .expectedTotalBytes !=
                                                                null
                                                            ? loadingProgress
                                                                    .cumulativeBytesLoaded /
                                                                loadingProgress
                                                                    .expectedTotalBytes!
                                                            : null,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return Container(
                                                    height: 150,
                                                    width: double.infinity,
                                                    color: backgroundColor,
                                                    child: Center(
                                                      child: Icon(
                                                        Icons.error_outline,
                                                        color: primaryColor,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Row(
                                        children: [
                                          Material(
                                            color: Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              onTap: () {
                                                // Beğenme fonksiyonu
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8.0,
                                                        vertical: 4.0),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.favorite_border,
                                                      size: 18,
                                                      color: secondaryColor,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      "Beğen",
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: secondaryColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Material(
                                            color: Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              onTap: () {
                                                // Cevaplama fonksiyonu
                                                _focusNode.requestFocus();
                                                _commentController.text =
                                                    "@Dr.${doctorName} ";
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8.0,
                                                        vertical: 4.0),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.reply,
                                                      size: 18,
                                                      color: primaryColor,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      "Yanıtla",
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: primaryColor,
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
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
          if (_selectedImage != null)
            Container(
              height: 100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
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
                        onTap: () => setState(() => _selectedImage = null),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: secondaryColor.withOpacity(0.8),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                    controller: _commentController,
                    focusNode: _focusNode,
                    maxLines: 5,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(fontSize: 15, color: textColor1),
                    decoration: InputDecoration(
                      hintText: "Yorumunuzu yazın...",
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
                      onTap: (_isLoading || !_isCommentValid)
                          ? null
                          : () => _submitComment(),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
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
}
