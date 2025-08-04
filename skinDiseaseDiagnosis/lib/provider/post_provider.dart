import 'dart:io';
import 'package:flutter/foundation.dart';
import '../service/api_service.dart';

class PostProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get posts => _posts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<bool> _ensureValidToken() async {
    try {
      await _apiService.initialize();
      final token = await _apiService.getToken();
      if (token == null) {
        _error = 'Oturum bilgisi bulunamadı';
        notifyListeners();
        return false;
      }
      return true;
    } catch (e) {
      print('Token kontrolü hatası: $e');
      _error = 'Oturum doğrulama hatası: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchPosts() async {
    if (_isLoading) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Token kontrolü
      if (!await _ensureValidToken()) {
        return;
      }

      final response = await _apiService.getPosts();
      if (response['status'] == 'success' && response['data'] != null) {
        _posts = List<Map<String, dynamic>>.from(response['data']);
        _posts.sort((a, b) => DateTime.parse(b['created_at'].toString())
            .compareTo(DateTime.parse(a['created_at'].toString())));
        _error = null;
      } else {
        _error = 'Postlar alınamadı';
        print('Post getirme yanıtı başarısız: $response');
      }
    } catch (e) {
      print('Post getirme hatası: $e');
      _error = 'Postlar alınamadı: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addPost(String content, String doctorId, {File? image}) async {
    if (_isLoading) return false;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Token kontrolü
      if (!await _ensureValidToken()) {
        return false;
      }

      final response =
          await _apiService.createPost(content, doctorId, image: image);

      if (response['status'] == 'success') {
        print('Post başarıyla eklendi, postlar yenileniyor...');

        // Yeni postu direkt listeye ekle
        if (response['data'] != null) {
          final newPost = Map<String, dynamic>.from(response['data']);
          if (newPost['created_at'] == null) {
            newPost['created_at'] = DateTime.now().toIso8601String();
          }
          _posts.insert(0, newPost);
          notifyListeners();

          // Tüm listeyi gereksiz yere hemen yenileme, optimizasyon için
          // Arka planda sadece gerektiğinde yenile
          Future.delayed(Duration(seconds: 5), () {
            // Kullanıcı 5 saniye içinde herhangi bir işlem yapmadıysa hafifçe güncelle
            if (!_isLoading) {
              fetchPosts();
            }
          });

          return true;
        }

        // Veri gelmezse yine de tüm listeyi güncelle
        await fetchPosts();
        return true;
      } else {
        _error = 'Post eklenemedi: ${response['message'] ?? 'Bilinmeyen hata'}';
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('Post ekleme hatası: $e');
      _error = 'Post eklenemedi: $e';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatePost(
    String postId,
    String content, {
    File? image,
    bool keepCurrentImage = true,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      print('PostProvider - Post güncelleniyor: $postId');
      await _apiService.initializeToken();

      // API'yi çağır ve sonucu direkt kullan (response değişkeni ile atama yapmadan)
      await _apiService.updatePost(
        postId,
        content,
        image: image,
        keepCurrentImage: keepCurrentImage,
      );

      // Post başarıyla güncellendi, şimdi tüm postları yeniden yükle
      await fetchPosts();

      _error = null;
    } catch (e) {
      print('PostProvider - Post güncelleme hatası: $e');
      _error = e.toString();
      throw e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Belirli bir postun yorum sayısını güncelle
  Future<void> updatePostCommentCount(String postId) async {
    try {
      print('Yorum sayısı güncelleniyor - Post ID: $postId');
      final comments = await _apiService.getComments(postId);

      // Post ID'yi string olarak karşılaştır
      final postIndex =
          _posts.indexWhere((post) => post['id'].toString() == postId);

      if (postIndex != -1) {
        Future.microtask(() {
          _posts[postIndex]['comments'] = comments.length;
          notifyListeners();
        });
      }
    } catch (e) {
      print('Yorum sayısı güncellenirken hata: $e');
      // Hata durumunda state güncelleme yapmıyoruz, uygulama çökmesini engelliyoruz
    }
  }

  Future<void> refreshPosts() async {
    if (_isLoading) return; // Eğer zaten yüklüyorsa, yeni yükleme yapma

    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      // Token kontrolü
      if (!await _ensureValidToken()) {
        return;
      }

      // Yeni postları al
      final response = await _apiService.getPosts();

      if (response['status'] == 'success' && response['data'] != null) {
        final newPosts = List<Map<String, dynamic>>.from(response['data']);

        // Sadece değişiklik varsa state'i güncelle
        final bool hasDifference = _checkIfPostsChanged(newPosts);

        if (hasDifference) {
          // Postları güncelle
          _posts = newPosts;
          _posts.sort((a, b) => DateTime.parse(b['created_at'].toString())
              .compareTo(DateTime.parse(a['created_at'].toString())));
          print('PostProvider - ${_posts.length} post yenilendi');
        } else {
          print('PostProvider - Postlarda değişiklik yok, state güncellenmedi');
        }

        _error = null;
      } else {
        _error = 'Postlar yenilenemedi';
        print('Post yenileme yanıtı başarısız: $response');
      }
    } catch (e) {
      print('Post yenileme hatası: $e');
      _error = 'Postlar yenilenemedi: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Mevcut postlarla yeni postlar arasında değişiklik olup olmadığını kontrol et
  bool _checkIfPostsChanged(List<Map<String, dynamic>> newPosts) {
    if (_posts.length != newPosts.length) {
      return true; // Post sayısı değişmiş
    }

    // Post ID'lerini ve son güncelleme zamanlarını karşılaştır
    for (int i = 0; i < newPosts.length; i++) {
      bool found = false;

      for (int j = 0; j < _posts.length; j++) {
        if (newPosts[i]['id'].toString() == _posts[j]['id'].toString()) {
          found = true;

          // Postların içeriği, beğeni sayısı veya yorum sayısı değişmiş mi kontrol et
          if (newPosts[i]['content'] != _posts[j]['content'] ||
              newPosts[i]['likes'] != _posts[j]['likes'] ||
              newPosts[i]['comments'] != _posts[j]['comments']) {
            return true;
          }

          break;
        }
      }

      if (!found) {
        return true; // Yeni bir post eklenmiş
      }
    }

    return false; // Değişiklik yok
  }
}
