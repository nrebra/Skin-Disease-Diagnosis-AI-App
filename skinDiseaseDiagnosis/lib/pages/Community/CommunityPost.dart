import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skincancer/pages/Community/CommentPage.dart';
import 'package:skincancer/pages/Community/EditPostPage.dart';
import 'package:skincancer/pages/Community/ImageDetailPage.dart';
import '../../service/api_service.dart';
import '../../provider/post_provider.dart';
import '../../service/community_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Assuming you have a theme colors file

class CommunityPost extends StatefulWidget {
  final String postId;
  final String userId;
  final String message;
  final String time;
  final int likes;
  final int comments;
  final int views;
  final String? imageUrl;

  const CommunityPost({
    required this.postId,
    required this.userId,
    required this.message,
    required this.time,
    required this.likes,
    required this.comments,
    required this.views,
    this.imageUrl,
  });

  @override
  State<CommunityPost> createState() => _CommunityPostState();
}

class _CommunityPostState extends State<CommunityPost>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late final CommunityService _communityService;
  bool _isLiked = false;
  int _likeCount = 0;
  int _commentCount = 0;
  bool _isLoading = false;
  late final AnimationController _likeAnimationController;

  // Token önbelleği için statik değişkenler (uygulama kapanınca sıfırlanır)
  static String? _cachedToken;
  static Map<String, String>? _cachedHeaders;
  static int _lastHeaderTime = 0;

  // Beğeni durumu için statik önbellek
  static Map<String, bool> _likesCache = {}; // post_id -> beğeni durumu
  static Map<String, int> _likesCacheTime = {}; // post_id -> zaman damgası

  // Yorum sayısı için statik önbellek
  static Map<String, int> _commentsCountCache = {}; // post_id -> yorum sayısı
  static Map<String, int> _commentsCountCacheTime =
      {}; // post_id -> zaman damgası

  @override
  void initState() {
    super.initState();
    _communityService = CommunityService(context);
    _likeCount = widget.likes;
    _commentCount = widget.comments;
    _likeAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    // Beğeni durumunu kontrol et (isteğe bağlı ve önbelleklenmiş)
    _checkLikeStatus();
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      String doctorId = '1';
      if (_isLiked) {
        await _apiService.unlikePost(widget.postId, doctorId);
        setState(() {
          _isLiked = false;
          _likeCount--;
        });
        _likeAnimationController.reverse();
      } else {
        await _apiService.likePost(widget.postId, doctorId);
        setState(() {
          _isLiked = true;
          _likeCount++;
        });
        _likeAnimationController.forward();
      }
    } catch (e) {
      _showErrorSnackbar('İşlem sırasında bir hata oluştu');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(12),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showDeleteDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Gönderiyi Sil'),
        content: Text('Bu gönderiyi silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                Navigator.pop(context);
                await _apiService.deletePost(widget.postId);

                if (context.mounted) {
                  await Provider.of<PostProvider>(context, listen: false)
                      .fetchPosts();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gönderi başarıyla silindi'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      margin: EdgeInsets.all(12),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  _showErrorSnackbar('Gönderi silinirken bir hata oluştu');
                }
              }
            },
            child: Text('Sil'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 26, 1, 1),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(String timeString) {
    try {
      final DateTime postTime = DateTime.parse(timeString);
      final now = DateTime.now();
      final difference = now.difference(postTime);

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
    } catch (e) {
      return widget.time;
    }
  }

  Future<void> _updateCommentCount() async {
    final String postId = widget.postId;
    final now = DateTime.now().millisecondsSinceEpoch;

    // 3 saat geçerli önbellek kontrolü
    if (_commentsCountCacheTime.containsKey(postId) &&
        now - _commentsCountCacheTime[postId]! < 3 * 60 * 60 * 1000) {
      final cachedCount = _commentsCountCache[postId];
      if (cachedCount != null) {
        setState(() {
          _commentCount = cachedCount;
        });
        return;
      }
    }

    try {
      final comments = await _apiService.getComments(widget.postId);
      if (mounted) {
        setState(() {
          _commentCount = comments.length;
        });

        // Statik önbelleğe kaydet
        _commentsCountCache[postId] = comments.length;
        _commentsCountCacheTime[postId] = now;
      }
    } catch (e) {
      print('Yorum sayısı güncellenirken hata: $e');
    }
  }

  Future<void> _navigateToComments() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentPage(
          postId: widget.postId,
          postOwnerId: widget.userId,
        ),
      ),
    );

    if (mounted) {
      await _updateCommentCount();
    }
  }

  // Beğeni durumunu kontrol et - statik değişkenlerle önbellek (3 saat)
  Future<void> _checkLikeStatus() async {
    final String postId = widget.postId;
    final now = DateTime.now().millisecondsSinceEpoch;

    // 3 saat geçerli önbellek kontrolü
    if (_likesCacheTime.containsKey(postId) &&
        now - _likesCacheTime[postId]! < 3 * 60 * 60 * 1000) {
      final cachedStatus = _likesCache[postId];
      if (cachedStatus != null) {
        setState(() {
          _isLiked = cachedStatus;
        });
        return;
      }
    }

    // Önbellekte yoksa istek yap
    try {
      final isLiked = await _apiService.getLikePost(widget.postId);
      setState(() {
        _isLiked = isLiked;
      });

      // Statik önbelleğe kaydet
      _likesCache[postId] = isLiked;
      _likesCacheTime[postId] = now;
    } catch (e) {
      print('Beğeni durumu kontrol edilirken hata: $e');
    }
  }

  // Token almak için optimize edilmiş metot - 3 saat geçerlilik
  Future<Map<String, String>> _getAuthHeaders() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Önbellekteki tokenı kullan (3 saat geçerli)
    if (_cachedHeaders != null && now - _lastHeaderTime < 3 * 60 * 60 * 1000) {
      return _cachedHeaders!;
    }

    try {
      final apiService = ApiService();
      await apiService.initialize();
      String? token = await apiService.getToken();

      if (token == null) {
        final prefs = await SharedPreferences.getInstance();
        final email = prefs.getString('user_email');
        final password = prefs.getString('user_password');

        if (email != null && password != null) {
          final loginResponse = await apiService.login(email, password);
          if (loginResponse['success']) {
            token = loginResponse['token'];
          }
        }
      }

      if (token != null) {
        _cachedHeaders = {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        };
        _lastHeaderTime = now;
        return _cachedHeaders!;
      }

      return {};
    } catch (e) {
      print('Token alma hatası: $e');
      return {};
    }
  }

  Widget _buildImage() {
    if (widget.imageUrl == null) return SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImageDetailPage(
              imageUrl: widget.imageUrl!,
            ),
          ),
        );
      },
      child: Container(
        constraints: BoxConstraints(
          maxHeight: 350,
        ),
        width: double.infinity,
        margin: EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FutureBuilder<Map<String, String>>(
            future: _getAuthHeaders(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor),
                    ),
                  ),
                );
              }

              final headers = snapshot.data ?? {};
              print(
                  'CommunityPost - Resim yükleme için kullanılan headers: $headers'); // Debug log

              final imageUrl = widget.imageUrl!.startsWith('http')
                  ? widget.imageUrl!
                  : widget.imageUrl!.startsWith('/uploads/')
                      ? 'https://ebranursayar.com${widget.imageUrl!}'
                      : 'https://ebranursayar.com/uploads/${widget.imageUrl!}';

              print(
                  'CommunityPost - Yüklenen resim URL: $imageUrl'); // Debug log

              return Image.network(
                imageUrl,
                fit: BoxFit.cover,
                headers: headers,
                errorBuilder: (context, error, stackTrace) {
                  print('CommunityPost - Resim yükleme hatası: $error');
                  print('CommunityPost - Hata detayı: $stackTrace');

                  if (error.toString().contains('401') ||
                      error.toString().contains('unauthorized')) {
                    print(
                        'CommunityPost - Token hatası tespit edildi, yenileme deneniyor...');
                    _apiService.initializeToken().then((_) {
                      if (mounted) {
                        setState(() {});
                      }
                    }).catchError((tokenError) {
                      print(
                          'CommunityPost - Token yenileme hatası: $tokenError');
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
                            'Resim yüklenemedi',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).primaryColor),
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
            child: Row(
              children: [
                // Profile avatar
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor.withOpacity(0.7), primaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      widget.userId[0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 12),

                // Author info
                Expanded(
                  child: FutureBuilder<Map<String, dynamic>>(
                      future: _communityService.getDoctorInfo(widget.userId),
                      builder: (context, snapshot) {
                        final doctorName = snapshot.hasData &&
                                snapshot.data!.containsKey('name')
                            ? "Dr. ${snapshot.data!['name']}"
                            : "Dr. ${widget.userId}";

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doctorName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              _getTimeAgo(widget.time),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        );
                      }),
                ),

                // Options menu
                Material(
                  color: Colors.transparent,
                  child: PopupMenuButton(
                    icon: Icon(Icons.more_horiz, color: Colors.grey[600]),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined,
                                size: 20, color: primaryColor),
                            SizedBox(width: 12),
                            Text('Düzenle'),
                          ],
                        ),
                        onTap: () async {
                          await Future.delayed(Duration.zero);
                          if (!context.mounted) return;

                          final edited = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditPostPage(
                                postId: widget.postId,
                                currentContent: widget.message,
                                currentImageUrl: widget.imageUrl,
                              ),
                            ),
                          );

                          if (edited == true && context.mounted) {
                            await Provider.of<PostProvider>(context,
                                    listen: false)
                                .fetchPosts();
                          }
                        },
                      ),
                      PopupMenuItem(
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                size: 20, color: Colors.redAccent),
                            SizedBox(width: 12),
                            Text('Sil',
                                style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                        onTap: () async {
                          await Future.delayed(Duration.zero);
                          if (context.mounted) _showDeleteDialog();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Post content
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              widget.message,
              style: TextStyle(
                fontSize: 15.5,
                height: 1.4,
                color: Colors.black87,
              ),
            ),
          ),
          SizedBox(height: 12),

          // Post image
          _buildImage(),

          SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: Colors.grey[200]),

          // Engagement section
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                // Like button
                InkWell(
                  onTap: _toggleLike,
                  borderRadius: BorderRadius.circular(30),
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Row(
                      children: [
                        ScaleTransition(
                          scale: Tween<double>(begin: 1.0, end: 1.2).animate(
                            CurvedAnimation(
                              parent: _likeAnimationController,
                              curve: Curves.elasticOut,
                            ),
                          ),
                          child: Icon(
                            _isLiked
                                ? Icons.favorite
                                : Icons.favorite_border_outlined,
                            color:
                                _isLiked ? Colors.redAccent : Colors.grey[600],
                            size: 22,
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '$_likeCount',
                          style: TextStyle(
                            color:
                                _isLiked ? Colors.redAccent : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(width: 8),

                // Comment button
                InkWell(
                  onTap: _navigateToComments,
                  borderRadius: BorderRadius.circular(30),
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '$_commentCount',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Spacer(),

                // Views counter
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 18,
                        color: Colors.grey[500],
                      ),
                      SizedBox(width: 4),
                      Text(
                        '${widget.views}',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
