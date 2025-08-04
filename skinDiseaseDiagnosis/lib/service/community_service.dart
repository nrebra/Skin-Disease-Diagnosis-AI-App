import 'package:provider/provider.dart';
import 'api_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../provider/post_provider.dart';
import '../pages/chat/ChatPage.dart';
import 'package:skincancer/pages/Community/createPostPage.dart';
import 'package:skincancer/pages/Community/EditPostPage.dart';
import 'package:skincancer/pages/Community/CommentPage.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CommunityService {
  final ApiService _apiService;
  final BuildContext context;

  CommunityService(this.context) : _apiService = ApiService() {
    _initializeApiService();
  }

  Future<void> _initializeApiService() async {
    try {
      print('CommunityService - API servisi başlatılıyor...');

      // SharedPreferences'dan token'ı al
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final email = prefs.getString('user_email');
      final password = prefs.getString('user_password');

      // Token yoksa ve kullanıcı bilgileri varsa yeniden giriş yap
      if (token == null && email != null && password != null) {
        print('CommunityService - Token yok, giriş yapılıyor...');
        try {
          final loginResponse = await _apiService.login(email, password);
          if (loginResponse['success']) {
            print('CommunityService - Giriş başarılı, token alındı');
            await _apiService.initialize();
            return;
          }
        } catch (e) {
          print('CommunityService - Giriş hatası: $e');
          _showLoginError();
          return;
        }
      }

      // Token varsa doğrula
      if (token != null) {
        try {
          print('CommunityService - Token doğrulanıyor...');
          await _apiService.setToken(token);

          // Token'ı test et
          final response = await _apiService.getDoctors();
          if (response['status'] == 'success') {
            print('CommunityService - Token geçerli');
            return;
          }
        } catch (e) {
          print('CommunityService - Token geçersiz, yenileme deneniyor...');

          // Token geçersizse ve kullanıcı bilgileri varsa yeniden giriş yap
          if (email != null && password != null) {
            try {
              final loginResponse = await _apiService.login(email, password);
              if (loginResponse['success']) {
                print('CommunityService - Yeniden giriş başarılı');
                await _apiService.initialize();
                return;
              }
            } catch (loginError) {
              print('CommunityService - Yeniden giriş hatası: $loginError');
            }
          }

          _showLoginError();
        }
      }
    } catch (e) {
      print('CommunityService - Başlatma hatası: $e');
      _showLoginError();
    }
  }

  void _showLoginError() {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Oturum süreniz dolmuş olabilir. Lütfen tekrar giriş yapın.'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Giriş Yap',
          textColor: Colors.white,
          onPressed: () {
            Navigator.of(context).pushReplacementNamed('/login');
          },
        ),
      ),
    );
  }

  // Doktorları getirme
  Future<List<Map<String, dynamic>>> fetchDoctors() async {
    try {
      final response = await _apiService.getDoctors();
      if (response['status'] == 'success' && response['data'] != null) {
        return List<Map<String, dynamic>>.from(response['data']);
      } else {
        print('Doktor verisi alınamadı: ${response['message']}');
        return []; // Boş liste dön
      }
    } catch (e) {
      print('Doktor verisi alınırken hata: $e');
      return []; // Hata durumunda boş liste dön
    }
  }

  // Gönderileri getirme
  Future<void> fetchPosts() async {
    print('CommunityService - fetchPosts başlatılıyor...');

    try {
      await _apiService.initializeToken();

      final postProvider = Provider.of<PostProvider>(context, listen: false);
      await postProvider.fetchPosts();

      // Veri yenileme başarısız olduysa tekrar dene
      if (postProvider.posts.isEmpty || postProvider.error != null) {
        print('CommunityService - İlk deneme başarısız, tekrar deneniyor...');
        await Future.delayed(Duration(seconds: 1));
        await _apiService.initializeToken();
        await postProvider.fetchPosts();
      }
    } catch (e) {
      print('CommunityService - fetchPosts hatası: $e');
      if (e.toString().contains('token') || e.toString().contains('401')) {
        try {
          await _apiService.initializeToken();
          final postProvider =
              Provider.of<PostProvider>(context, listen: false);
          await postProvider.fetchPosts();
        } catch (tokenError) {
          print('Token yenileme hatası: $tokenError');
          _showLoginError();
        }
      }
    }
  }

  // Chat sayfasına yönlendirme
  void navigateToChat(Map<String, dynamic> doctor) {
    final String receiverId = doctor['id']?.toString() ?? '';
    final String receiverName = doctor['name']?.toString() ?? '';
    final String receiverSurname = doctor['surname']?.toString() ?? '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          receiverId: receiverId,
          receiverName: receiverName,
          receiverSurname: receiverSurname,
        ),
      ),
    );
  }

  // Gönderi oluşturma sayfasına yönlendirme
  Future<void> navigateToCreatePost() async {
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: postProvider,
          child: CreatePostPage(),
        ),
      ),
    );
  }

  // Tarih formatlama
  String formatDateString(String dateString) {
    try {
      DateTime parsedDate = DateTime.parse(dateString);
      return DateFormat('dd.MM.yyyy HH:mm').format(parsedDate);
    } catch (e) {
      try {
        final RegExp dateRegex = RegExp(
            r'^[A-Za-z]+, (\d{2}) ([A-Za-z]+) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$');
        final Match? match = dateRegex.firstMatch(dateString);

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

          final DateTime parsedDate = DateTime(
            int.parse(match.group(3)!),
            months[match.group(2)]!,
            int.parse(match.group(1)!),
            int.parse(match.group(4)!),
            int.parse(match.group(5)!),
            int.parse(match.group(6)!),
          );
          return DateFormat('dd.MM.yyyy HH:mm').format(parsedDate);
        }
      } catch (e) {
        print("Tarih dönüştürme hatası: $e");
      }
      return dateString;
    }
  }

  // Hata mesajı gösterme
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // // Post işlemleri
  // Future<bool> toggleLike(String postId, String doctorId, bool isLiked) async {
  //   try {
  //     if (isLiked) {
  //       final response = await _apiService.unlikePost(postId, doctorId);
  //       if (response['message'] == 'Like kaldırıldı.') {
  //         return false;
  //       }
  //     } else {
  //       final response = await _apiService.likePost(postId, doctorId);
  //       if (response['message'] == 'Like eklendi.') {
  //         return true;
  //       }
  //     }
  //     return isLiked;
  //   } catch (e) {
  //     print('Beğeni işlemi hatası: $e');
  //     final error = e.toString().toLowerCase();
  //     if (error.contains('zaten beğendi')) {
  //       _showErrorSnackBar('Bu gönderiyi zaten beğendiniz');
  //       return true;
  //     }
  //     _showErrorSnackBar('Beğeni işlemi sırasında bir hata oluştu');
  //     return isLiked;
  //   }
  // }
// Post beğeni işlemleri
  Future<bool> toggleLike(String postId, String doctorId, bool isLiked) async {
    try {
      final response = isLiked
          ? await _apiService.unlikePost(postId, doctorId)
          : await _apiService.likePost(postId, doctorId);

      if (response['message'] != null) {
        if (response['message'] == 'Like eklendi.') return true;
        if (response['message'] == 'Like kaldırıldı.') return false;
      }

      return isLiked;
    } catch (e) {
      print('Beğeni işlemi hatası: $e');
      _handleLikeError(e.toString(), isLiked);
      return isLiked;
    }
  }

// Hata yönetimi
  void _handleLikeError(String error, bool isLiked) {
    final lowerError = error.toLowerCase();

    if (lowerError.contains('zaten beğendi')) {
      _showErrorSnackBar('Bu gönderiyi zaten beğendiniz');
    } else {
      _showErrorSnackBar('Beğeni işlemi sırasında bir hata oluştu');
    }
  }

  Future<void> deletePost(String postId, String postOwnerId) async {
    try {
      // Mevcut kullanıcı ID'sini al
      final currentDoctorId = await _apiService.getDoctorId();

      // Eğer mevcut kullanıcı bu postun sahibi değilse hata fırlat
      if (currentDoctorId != postOwnerId) {
        _showErrorSnackBar(
            'Bu gönderiyi silme yetkiniz yok. Sadece kendi gönderilerinizi silebilirsiniz.');
        return;
      }

      await _apiService.deletePost(postId);
      await Provider.of<PostProvider>(context, listen: false).fetchPosts();
    } catch (e) {
      // Token hatası kontrolü
      if (e.toString().contains('token') ||
          e.toString().contains('authorization') ||
          e.toString().contains('401')) {
        try {
          await _apiService.initializeToken();
          // Token yenilendiyse işlemi tekrar dene
          await _apiService.deletePost(postId);
          await Provider.of<PostProvider>(context, listen: false).fetchPosts();
        } catch (tokenError) {
          _showErrorSnackBar(
              'Oturum süresi dolmuş olabilir. Lütfen yeniden giriş yapın.');
        }
      } else {
        _showErrorSnackBar('Gönderi silinirken bir hata oluştu');
      }
      throw e;
    }
  }

  Future<int> getCommentCount(String postId) async {
    try {
      final comments = await _apiService.getComments(postId);
      return comments.length;
    } catch (e) {
      print('Yorum sayısı alınırken hata: $e');
      return 0;
    }
  }

  void navigateToEditPost(String postId, String postOwnerId,
      String currentContent, String? currentImageUrl) async {
    try {
      // Mevcut kullanıcı ID'sini al
      final currentDoctorId = await _apiService.getDoctorId();

      // Eğer mevcut kullanıcı bu postun sahibi değilse hata fırlat
      if (currentDoctorId != postOwnerId) {
        _showErrorSnackBar(
            'Bu gönderiyi düzenleme yetkiniz yok. Sadece kendi gönderilerinizi düzenleyebilirsiniz.');
        return;
      }

      // Kullanıcı post sahibi ise düzenleme sayfasına yönlendir
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditPostPage(
            postId: postId,
            currentContent: currentContent,
            currentImageUrl: currentImageUrl,
          ),
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Bir hata oluştu: ${e.toString()}');
    }
  }

  void navigateToComments(String postId, String postOwnerId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentPage(
          postId: postId,
          postOwnerId: postOwnerId,
        ),
      ),
    );
  }

  // void _showSuccessSnackBar(String message) {
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Text(message),
  //       backgroundColor: successColor,
  //       behavior: SnackBarBehavior.floating,
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  //       margin: EdgeInsets.all(12),
  //     ),
  //   );
  // }

  // Beğeni sayısını getir
  Future<int> getLikeCount(String postId) async {
    try {
      final response = await _apiService.getLikeCount(postId);
      if (response['like_count'] != null) {
        return response['like_count'];
      }
      return 0;
    } catch (e) {
      print('Beğeni sayısı alınamadı: $e');
      return 0;
    }
  }

  // Grup mesajlarını getir
  Future<List<Map<String, dynamic>>> fetchGroupMessages(int groupId) async {
    try {
      // Token kontrolü
      await _apiService.initializeToken();

      final response = await _apiService.dio.get(
        '/group_chats/$groupId/messages',
        options: Options(
          headers: await _getHeaders(),
          validateStatus: (status) =>
              status! <
              500, // 404 dahil tüm istemci hataları için geçerli kabul et
        ),
      );

      // 404 hatasını özel olarak kontrol et - grup veya mesaj bulunamadı
      if (response.statusCode == 404) {
        print('Grup veya mesajlar bulunamadı (404). Grup ID: $groupId');
        // Boş liste döndür, hata fırlatma
        return [];
      }

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final messages = List<Map<String, dynamic>>.from(response.data['data']);
        return messages;
      }
      throw Exception(response.data['message'] ?? 'Mesajlar alınamadı');
    } catch (e) {
      print('Grup mesajları alınamadı: $e');
      if (e.toString().contains('token') || e.toString().contains('401')) {
        try {
          await _apiService.initializeToken();
          return await fetchGroupMessages(groupId);
        } catch (tokenError) {
          print('Token yenileme hatası: $tokenError');
        }
      }

      // DioException tipindeki 404 hatasını kontrol et
      if (e is DioException && e.response?.statusCode == 404) {
        print(
            'Grup veya mesajlar bulunamadı (404 DioException). Grup ID: $groupId');
        return []; // Boş liste döndür
      }

      throw Exception('Grup mesajları alınamadı: $e');
    }
  }

  // Grup mesajı gönder
  Future<bool> sendGroupMessage(int groupId, String message,
      [File? imageFile]) async {
    try {
      print('Mesaj gönderme isteği başlatılıyor...');
      print('Grup ID: $groupId');
      print('Mesaj: $message');

      // Form verilerini hazırla
      Map<String, dynamic> formFields = {
        'group_id': groupId, // String'e çevirmeden direkt integer olarak gönder
        'message': message.trim(),
      };

      print('Form verileri hazırlandı:');
      formFields.forEach((key, value) => print('$key: $value'));

      FormData formData;
      if (imageFile != null) {
        print('Resim dosyası ekleniyor...');
        String extension = imageFile.path.split('.').last.toLowerCase();
        if (!['jpg', 'jpeg', 'png'].contains(extension)) {
          extension = 'jpg';
        }

        String fileName =
            'message_image_${DateTime.now().millisecondsSinceEpoch}.$extension';

        formData = FormData.fromMap({
          ...formFields,
          'image': await MultipartFile.fromFile(
            imageFile.path,
            filename: fileName,
          ),
        });
        print('Resim dosyası eklendi: $fileName');
      } else {
        formData = FormData.fromMap(formFields);
      }

      print('API isteği gönderiliyor...');
      print('Form verileri:');
      formData.fields.forEach((field) => print('${field.key}: ${field.value}'));

      final headers = await _getHeaders();
      headers.remove('Content-Type'); // Dio otomatik ayarlayacak

      final response = await _apiService.dio.post(
        '/group_messages',
        data: formData,
        options: Options(
          headers: headers,
          followRedirects: false,
          validateStatus: (status) => status! < 500,
        ),
      );

      print('API yanıtı alındı: ${response.statusCode}');
      print('API yanıt içeriği: ${response.data}');

      if (response.statusCode == 201 && response.data['status'] == 'success') {
        return true;
      }

      throw Exception(response.data['message'] ?? 'Mesaj gönderilemedi');
    } catch (e) {
      print('Mesaj gönderme hatası: $e');
      if (e is DioException) {
        print('Sunucu yanıtı: ${e.response?.data}');
        if (e.response?.statusCode == 400) {
          throw Exception(e.response?.data['message'] ?? 'Geçersiz istek');
        }
      }
      throw Exception('Mesaj gönderilemedi: $e');
    }
  }

  // Grup mesajını güncelle
  Future<bool> updateGroupMessage(int messageId, String newMessage,
      [File? newImageFile]) async {
    try {
      final formData = FormData.fromMap({
        'message': newMessage.trim(),
      });

      if (newImageFile != null) {
        String extension = newImageFile.path.split('.').last.toLowerCase();
        if (!['jpg', 'jpeg', 'png'].contains(extension)) {
          extension = 'jpg';
        }

        String mimeType = 'image/jpeg';
        if (extension == 'png') {
          mimeType = 'image/png';
        }

        String fileName =
            'message_image_${DateTime.now().millisecondsSinceEpoch}.$extension';

        formData.files.add(MapEntry(
          'image',
          await MultipartFile.fromFile(
            newImageFile.path,
            filename: fileName,
            contentType: MediaType.parse(mimeType),
          ),
        ));
      }

      final response = await _apiService.dio.put(
        '/group_messages/$messageId',
        data: formData,
        options: Options(
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return true;
      }

      throw Exception(response.data['message'] ?? 'Mesaj güncellenemedi');
    } catch (e) {
      print('Mesaj güncellenemedi: $e');
      throw Exception('Mesaj güncellenemedi: $e');
    }
  }

  // Grup mesajını sil
  Future<bool> deleteGroupMessage(int messageId) async {
    try {
      final response = await _apiService.dio.delete(
        '/group_messages/$messageId',
        options: Options(
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return true;
      }

      throw Exception(response.data['message'] ?? 'Mesaj silinemedi');
    } catch (e) {
      print('Mesaj silinemedi: $e');
      throw Exception('Mesaj silinemedi: $e');
    }
  }

  // Doktor bilgilerini önbellekle
  final Map<String, Map<String, dynamic>> _doctorCache = {};

  Future<Map<String, dynamic>> getDoctorInfo(dynamic doctorId) async {
    // doctor_id'yi string'e çevir
    String cacheKey = doctorId.toString();

    // Önbellekte varsa direkt dön
    if (_doctorCache.containsKey(cacheKey)) {
      return _doctorCache[cacheKey]!;
    }

    try {
      // id'yi int'e çevirmeye çalış
      int? docId;

      if (doctorId is int) {
        docId = doctorId;
      } else if (doctorId is String) {
        try {
          docId = int.parse(doctorId);
        } catch (e) {
          print('Doktor ID\'si int\'e çevrilemedi: $doctorId');
        }
      }

      // Eğer geçerli bir ID varsa API'ye istek yap
      if (docId != null) {
        final response = await _apiService.getDoctor(docId);
        if (response['status'] == 'success' && response['data'] != null) {
          _doctorCache[cacheKey] = Map<String, dynamic>.from(response['data']);
          return _doctorCache[cacheKey]!;
        }
      }
    } catch (e) {
      print('Doktor bilgisi alınamadı: $e');
    }

    // Hata durumunda varsayılan değeri dön
    return {'name': 'Bilinmeyen Doktor', 'profile_photo': null};
  }

  // Grup üyelerini getir
  Future<List<Map<String, dynamic>>> fetchGroupMembers(int groupId) async {
    try {
      final response = await _handleRequest(() async {
        final response = await _apiService.dio.get(
          '/group_chats/$groupId/members',
          options: Options(headers: await _getHeaders()),
        );
        return response;
      });

      if (response['status'] == 'success' && response['members'] != null) {
        return List<Map<String, dynamic>>.from(response['members']);
      }

      return [];
    } catch (e) {
      print('Grup üyeleri getirme hatası: $e');
      if (e.toString().contains('404')) {
        print('Grup bulunamadı veya üye yok');
        return [];
      }
      throw Exception('Üyeler yüklenirken bir hata oluştu: $e');
    }
  }

  // Tarih başlığı gösterilmeli mi?
  bool shouldShowDateHeader(List<Map<String, dynamic>> messages, int index) {
    if (index == 0) return true;

    final currentDate = parseDate(messages[index]['created_at']);
    final previousDate = parseDate(messages[index - 1]['created_at']);

    return currentDate.year != previousDate.year ||
        currentDate.month != previousDate.month ||
        currentDate.day != previousDate.day;
  }

  // GMT formatındaki tarihi parse et
  DateTime parseDate(String dateStr) {
    try {
      final RegExp dateRegex = RegExp(
          r'^([A-Za-z]{3}), (\d{2}) ([A-Za-z]{3}) (\d{4}) (\d{2}):(\d{2}):\d{2} GMT$');
      final Match? match = dateRegex.firstMatch(dateStr);

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

        return DateTime(
          int.parse(match.group(4)!), // year
          months[match.group(3)]!, // month
          int.parse(match.group(2)!), // day
          int.parse(match.group(5)!), // hour
          int.parse(match.group(6)!), // minute
        );
      }
      return DateTime.parse(dateStr);
    } catch (e) {
      return DateTime.now();
    }
  }

  // Tarih başlığı metni
  String getDateHeaderText(DateTime date) {
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

  // Mesaj saati formatı
  String formatMessageTime(String dateStr) {
    try {
      final date = parseDate(dateStr);
      return DateFormat('HH:mm').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Future<Map<String, dynamic>> addCommentWithImage(
      String postId, String doctorId, String content, File? imageFile) async {
    try {
      // Resim seçilmiş ise kullanıcıya bilgi ver ve resmi göz ardı et
      if (imageFile != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Şu anda yorum resim desteklemiyor. Sadece metniniz gönderilecek.')));
      }

      // Resim olmadan sadece metin yorumu ekle
      final response = await _apiService.addComment(postId, doctorId, content);
      return response;
    } catch (e) {
      print('Yorum eklerken hata: $e');

      // Token sorununu kontrol et
      if (e.toString().contains('token') ||
          e.toString().contains('authorization') ||
          e.toString().contains('401')) {
        // Token yenilemeyi dene
        try {
          await _apiService.initializeToken();
          // Token yenilendiyse işlemi tekrar dene
          final response =
              await _apiService.addComment(postId, doctorId, content);
          return response;
        } catch (tokenError) {
          throw Exception(
              'Oturum süresi dolmuş olabilir. Lütfen yeniden giriş yapın.');
        }
      }

      throw Exception(
          'Yorum eklenirken bir hata oluştu: ${e.toString().replaceAll("Exception: ", "")}');
    }
  }

  // GRUP OLUŞTURMA VE ÜYE YÖNETİMİ İŞLEMLERİ

  // Yeni grup oluştur
  Future<Map<String, dynamic>> createGroup(String groupName) async {
    try {
      final response = await _handleRequest(() async {
        final response = await _apiService.dio.post(
          '/group_chats',
          data: {'group_name': groupName},
          options: Options(headers: await _getHeaders()),
        );
        return response;
      });

      if (response['status'] == 'success' && response['group'] != null) {
        // Yeni grubu döndür
        return {
          'success': true,
          'group': response['group'],
          'message': response['message'] ?? 'Grup başarıyla oluşturuldu'
        };
      }

      return {
        'success': false,
        'message': response['message'] ?? 'Grup oluşturulamadı'
      };
    } catch (e) {
      print('Grup oluşturma hatası: $e');
      return {
        'success': false,
        'message': 'Grup oluşturulurken bir hata oluştu: $e'
      };
    }
  }

  // Grupları getir
  Future<List<Map<String, dynamic>>> fetchGroups() async {
    try {
      final response = await _handleRequest(() async {
        final response = await _apiService.dio.get(
          '/group_chats',
          options: Options(headers: await _getHeaders()),
        );
        return response;
      });

      if (response['status'] == 'success' && response['groups'] != null) {
        return List<Map<String, dynamic>>.from(response['groups']);
      }

      print('Gruplar alınamadı: ${response['message']}');
      return [];
    } catch (e) {
      print('Grupları getirme hatası: $e');
      if (e.toString().contains('token') || e.toString().contains('401')) {
        try {
          await _apiService.initializeToken();
          return await fetchGroups();
        } catch (tokenError) {
          print('Token yenileme hatası: $tokenError');
        }
      }
      return [];
    }
  }

  // Grup detaylarını getir
  Future<Map<String, dynamic>?> fetchGroupDetails(int groupId) async {
    try {
      final response = await _handleRequest(() async {
        final response = await _apiService.dio.get(
          '/group_chats/$groupId',
          options: Options(headers: await _getHeaders()),
        );
        return response;
      });

      if (response['status'] == 'success' && response['group'] != null) {
        return Map<String, dynamic>.from(response['group']);
      }

      return null;
    } catch (e) {
      print('Grup detayları alınamadı: $e');
      return null;
    }
  }

  // Gruba üye ekle
  Future<Map<String, dynamic>> addGroupMember(int groupId, int doctorId) async {
    try {
      final response = await _handleRequest(() async {
        final response = await _apiService.dio.post(
          '/group_chats/$groupId/members',
          data: {'doctor_id': doctorId},
          options: Options(headers: await _getHeaders()),
        );
        return response;
      });
      return Map<String, dynamic>.from(response);
    } catch (e) {
      print('Üye ekleme hatası: $e');
      throw Exception('Üye eklenirken bir hata oluştu: $e');
    }
  }

  // Gruptan üye çıkar
  Future<bool> removeGroupMember(int membershipId) async {
    try {
      await _handleRequest(() async {
        final response = await _apiService.dio.delete(
          '/group_chats/members/$membershipId',
          options: Options(headers: await _getHeaders()),
        );
        return response;
      });
      return true;
    } catch (e) {
      print('Üye çıkarma hatası: $e');
      throw Exception('Üye çıkarılırken bir hata oluştu: $e');
    }
  }

  // Tüm doktorları getir (üye eklemek için seçim yapmak üzere)
  Future<List<Map<String, dynamic>>> fetchAllDoctors() async {
    try {
      final response = await _apiService.getDoctors();
      if (response['status'] == 'success' && response['data'] != null) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      print('Doktorlar alınamadı: $e');
      throw Exception('Doktorlar yüklenirken bir hata oluştu');
    }
  }

  // API için Authentication header'larını al
  Future<Map<String, String>> _getHeaders() async {
    try {
      final token = await _apiService.getToken();
      if (token == null) {
        throw Exception('Token alınamadı');
      }
      return {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
    } catch (e) {
      print('Header oluşturma hatası: $e');
      throw Exception('Oturum bilgileri alınamadı');
    }
  }

  // API isteklerini yönet
  Future<dynamic> _handleRequest(Future<Response> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } catch (e) {
      print('API isteği hatası: $e');
      throw Exception('İstek işlenirken hata oluştu: $e');
    }
  }

  // Resim seçenekleri butonu oluştur
  Widget buildImageOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    bool isSubmitting = false,
  }) {
    return GestureDetector(
      onTap: isSubmitting ? null : onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Auth header'larını getir
  Future<Map<String, String>> getAuthHeaders() async {
    try {
      final token = await _apiService.getToken();
      if (token == null) {
        throw Exception('Token alınamadı');
      }
      return {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
    } catch (e) {
      print('Auth header oluşturma hatası: $e');
      throw Exception('Oturum bilgileri alınamadı');
    }
  }

  // Gönderiyi iptal etme dialogu göster
  void showDiscardPostDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Gönderiyi İptal Et'),
        content: Text('Gönderiyi iptal etmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Dialog'u kapat
              Navigator.pop(context); // EditPostPage'den çık
            },
            child: Text('İptal Et'),
          ),
        ],
      ),
    );
  }

  // Grup üyelerini getir
  Future<List<Map<String, dynamic>>> getGroupMembers(int groupId) async {
    try {
      final response = await _handleRequest(() async {
        final response = await _apiService.dio.get(
          '/group_chats/$groupId/members',
          options: Options(headers: await _getHeaders()),
        );
        return response;
      });
      if (response.containsKey('members') && response['members'] is List) {
        return List<Map<String, dynamic>>.from(response['members']);
      }
      return [];
    } catch (e) {
      print('Grup üyeleri getirme hatası: $e');
      return [];
    }
  }

  // Mevcut doktor ID'sini getir
  Future<String> getCurrentDoctorId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) {
        throw Exception('Kullanıcı ID bulunamadı');
      }
      return userId;
    } catch (e) {
      print('Doktor ID alınamadı: $e');
      throw Exception('Doktor bilgileri alınamadı');
    }
  }

  // Resim seçme işlemi
  Future<File?> pickImage(ImageSource source,
      {required Function(bool) setLoading}) async {
    try {
      setLoading(true);
      final image = await ImagePicker().pickImage(source: source);
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Resim seçme hatası: $e');
      return null;
    } finally {
      setLoading(false);
    }
  }

  // Gönderi güncelleme
  Future<bool> updatePost(
    String postId,
    String content, {
    File? image,
    bool keepCurrentImage = true,
    Function(bool)? setLoading,
  }) async {
    try {
      if (setLoading != null) setLoading(true);

      FormData formData = FormData.fromMap({
        'content': content.trim(),
        'keep_image': keepCurrentImage ? '1' : '0',
      });

      if (image != null) {
        String extension = image.path.split('.').last.toLowerCase();
        if (!['jpg', 'jpeg', 'png'].contains(extension)) {
          extension = 'jpg';
        }

        formData.files.add(MapEntry(
          'image',
          await MultipartFile.fromFile(
            image.path,
            filename:
                'post_${DateTime.now().millisecondsSinceEpoch}.$extension',
          ),
        ));
      }

      final response = await _apiService.dio.put(
        '/posts/$postId',
        data: formData,
        options: Options(headers: await _getHeaders()),
      );

      if (response.statusCode == 200) {
        return true;
      }

      throw Exception(response.data['message'] ?? 'Gönderi güncellenemedi');
    } catch (e) {
      print('Gönderi güncelleme hatası: $e');
      throw Exception('Gönderi güncellenirken bir hata oluştu: $e');
    } finally {
      if (setLoading != null) setLoading(false);
    }
  }
}
