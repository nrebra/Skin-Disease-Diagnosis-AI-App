import 'package:flutter/material.dart';
import '../../service/community_service.dart';
import 'package:skincancer/style/color.dart';
import 'package:skincancer/service/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;

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

class PostCard extends StatefulWidget {
  final String postId;
  final String userId;
  final String message;
  final String time;
  final int likes;
  final int comments;
  final int views;
  final String? imageUrl;
  final CommunityService communityService;

  const PostCard({
    required this.postId,
    required this.userId,
    required this.message,
    required this.time,
    required this.likes,
    required this.comments,
    required this.views,
    required this.communityService,
    this.imageUrl,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
  late final CommunityService _communityService;
  late final AnimationController _likeAnimationController;
  bool _isLiked = false;
  bool _isLoading = false;
  int _likeCount = 0;
  int _commentCount = 0;
  bool _isExpanded = false;
  Map<String, String> _authHeaders = {};
  late final ApiService _apiService;
  String? _alternativeImageUrl;

  @override
  void initState() {
    super.initState();
    _communityService = widget.communityService;
    _likeCount = widget.likes;
    _commentCount = widget.comments;
    _likeAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    // Build işlemi tamamlandıktan sonra veri yüklemeyi yap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateCommentCount();
        _checkLikeStatus();
        _loadAuthHeaders();
      }
    });

    _apiService = ApiService();
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    super.dispose();
  }

  Future<void> _updateCommentCount() async {
    final count = await _communityService.getCommentCount(widget.postId);
    if (mounted) setState(() => _commentCount = count);
  }

  Future<void> _checkLikeStatus() async {
    try {
      final likeCount = await _communityService.getLikeCount(widget.postId);
      if (mounted) {
        setState(() {
          _likeCount = likeCount;
        });
      }
    } catch (e) {
      print('Beğeni durumu kontrol edilemedi: $e');
    }
  }

  Future<void> _handleLikePress() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final newLikeStatus = await _communityService.toggleLike(
        widget.postId,
        '1', // doctorId
        _isLiked,
      );

      if (mounted) {
        setState(() {
          _isLiked = newLikeStatus;
          _likeCount += newLikeStatus ? 1 : -1;
          if (_likeCount < 0) _likeCount = 0;
        });

        if (newLikeStatus) {
          _likeAnimationController.forward();
        } else {
          _likeAnimationController.reverse();
        }
      }
    } catch (e) {
      print('Beğeni işlemi başarısız: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  Widget _buildImage() {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty)
      return SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(maxHeight: 350),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
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

              return FutureBuilder<String>(
                future: _apiService.loadImage(widget.imageUrl!),
                builder: (context, urlSnapshot) {
                  if (urlSnapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingContainer();
                  }

                  if (urlSnapshot.hasError) {
                    print(
                        'PostCard - Resim URL işleme hatası: ${urlSnapshot.error}');
                    return _buildErrorContainer('Resim yüklenemedi');
                  }

                  final imageUrl = urlSnapshot.data!;
                  print('PostCard - Yüklenen resim URL: $imageUrl');

                  return Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    headers: {'Authorization': 'Bearer $token'},
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
                      print('PostCard - Resim yükleme hatası: $error');
                      print('PostCard - Hata detayı: $stackTrace');

                      if (error.toString().contains('404')) {
                        print(
                            'PostCard - 404 hatası tespit edildi, alternatif yollar deneniyor...');
                        return _buildErrorContainer('Resim bulunamadı');
                      }

                      if (error.toString().contains('401') ||
                          error.toString().contains('unauthorized')) {
                        _apiService.initializeToken().then((_) {
                          if (mounted) setState(() {});
                        });
                      }

                      return _buildErrorContainer('Resim yüklenemedi');
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingContainer({double? progress}) {
    return Container(
      height: 200,
      color: Colors.grey.withOpacity(0.1),
      child: Center(
        child: CircularProgressIndicator(
          value: progress,
          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildErrorContainer(String message) {
    return Container(
      height: 200,
      color: Colors.grey.withOpacity(0.1),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.image_not_supported_outlined,
                color: Colors.grey.shade400,
                size: 40,
              ),
            ),
            SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Görsel sunucuda bulunmuyor veya silinmiş',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _alternativeImageUrl = null;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                minimumSize: Size(120, 36),
                padding: EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: Icon(Icons.refresh, size: 18),
              label: Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            spreadRadius: 1,
            offset: Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header kısmı
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Row(
              children: [
                // Profil Avatarı
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor.withOpacity(0.8), primaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.25),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      widget.userId[0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 10),

                // Kullanıcı bilgileri
                Expanded(
                  child: FutureBuilder<Map<String, dynamic>>(
                      future: _communityService
                          .getDoctorInfo(int.tryParse(widget.userId) ?? 1),
                      builder: (context, snapshot) {
                        final doctorName = snapshot.hasData &&
                                snapshot.data!.containsKey('name')
                            ? "Dr. ${snapshot.data!['name']}"
                            : "Dr. ${widget.userId}";

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  doctorName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: textColor1,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  widget.time,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.visibility_outlined,
                                  size: 12,
                                  color: Colors.grey,
                                ),
                                SizedBox(width: 2),
                                Text(
                                  '${widget.views}',
                                  style: TextStyle(
                                    color: textColor1,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }),
                ),

                // Ayarlar menüsü - sadece kullanıcı kendi gönderisindeyse göster
                FutureBuilder<String?>(
                    future: _apiService.getDoctorId(),
                    builder: (context, snapshot) {
                      final currentUserId = snapshot.data;
                      final isPostOwner = currentUserId == widget.userId;

                      if (!isPostOwner) {
                        return SizedBox
                            .shrink(); // Eğer kullanıcı post sahibi değilse menüyü gösterme
                      }

                      return IconButton(
                        icon: Icon(Icons.more_horiz,
                            color: Colors.grey.shade700, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                        splashRadius: 24,
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20)),
                            ),
                            builder: (context) => Container(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 4,
                                    margin: EdgeInsets.only(bottom: 20),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  ListTile(
                                    leading: Icon(
                                      Icons.edit_outlined,
                                      color: primaryColor,
                                    ),
                                    title: Text('Düzenle'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _communityService.navigateToEditPost(
                                        widget.postId,
                                        widget.userId,
                                        widget.message,
                                        widget.imageUrl,
                                      );
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    title: Text('Sil'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _communityService.deletePost(
                                          widget.postId, widget.userId);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }),
              ],
            ),
          ),

          // Mesaj içeriği
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Text(
                widget.message,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black.withOpacity(0.8),
                  height: 1.35,
                  letterSpacing: 0.2,
                ),
                maxLines: _isExpanded ? null : 3,
                overflow: _isExpanded ? null : TextOverflow.ellipsis,
              ),
            ),
          ),

          if (!_isExpanded && widget.message.length > 100)
            Padding(
              padding: EdgeInsets.only(left: 14, bottom: 6),
              child: Text(
                'Daha fazla',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),

          _buildImage(),

          // Etkileşim butonları
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Beğeni butonu
                TextButton.icon(
                  onPressed: _isLoading ? null : _handleLikePress,
                  style: TextButton.styleFrom(
                    foregroundColor:
                        _isLiked ? Colors.red : Colors.grey.shade600,
                    minimumSize: Size.zero,
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: _isLoading
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                _isLiked ? Colors.red : Colors.grey.shade600),
                          ),
                        )
                      : Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_outline,
                          size: 18,
                        ),
                  label: Text(
                    _likeCount.toString(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // Yorum butonu
                TextButton.icon(
                  onPressed: () => _communityService.navigateToComments(
                    widget.postId,
                    widget.userId,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    minimumSize: Size.zero,
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(
                    Icons.chat_bubble_outline,
                    size: 18,
                  ),
                  label: Text(
                    _commentCount.toString(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // Paylaş butonu
                IconButton(
                  icon: Icon(
                    Icons.share_outlined,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  constraints: BoxConstraints(),
                  splashRadius: 24,
                  onPressed: () {
                    // Paylaşma işlemi
                  },
                ),
              ],
            ),
          ),

          // İnce ayraç çizgisi
          Container(
            height: 1,
            color: Colors.grey.withOpacity(0.06),
          ),
        ],
      ),
    );
  }
}
