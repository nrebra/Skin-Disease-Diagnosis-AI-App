import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:dio/io.dart'; // DefaultHttpClientAdapter için gerekli import
import 'dart:async'; // TimeoutException için bu import gerekli
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart' as dioLib;
import 'token_manager.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  late final dioLib.Dio dio;
  static const String baseUrl = 'https://berketopbas.com.tr';
  final TokenManager _tokenManager = TokenManager();

  String? _cachedToken;
  String? _cachedRefreshToken;
  int? _currentUserId;

  int? get currentUserId => _currentUserId;

  // Yorum sayısı için önbellek ekleyin
  Map<String, List<Map<String, dynamic>>> _commentsCache = {};
  int _commentsCacheTime = 0;

  // Private constructor
  ApiService._internal() {
    // SSL sertifika doğrulamasını devre dışı bırakan HttpClient
    final httpClient = HttpClient()
      ..badCertificateCallback =
          ((X509Certificate cert, String host, int port) => true);

    dio = dioLib.Dio(dioLib.BaseOptions(
      baseUrl: baseUrl,
      contentType: 'application/json',
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 60),
      validateStatus: (status) {
        return status != null && status < 500;
      },
    ));

    // SSL doğrulamasını devre dışı bırakan adapter'ı ekle
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = httpClient;
        client.connectionTimeout = const Duration(seconds: 30);
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      },
    );

    // Token değişikliklerini dinle
    _tokenManager.addTokenChangeListener((token) {
      if (token != null) {
        dio.options.headers['Authorization'] = 'Bearer $token';
      } else {
        dio.options.headers.remove('Authorization');
      }
    });

    // Dio için interceptor ekle
    dio.interceptors.add(dioLib.InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final token = await _tokenManager.getValidToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          options.headers['Accept'] = 'application/json';
          return handler.next(options);
        } catch (e) {
          print('Dio Interceptor - Request Hatası: $e');
          return handler.next(options);
        }
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          try {
            final refreshed = await _tokenManager.refreshToken();
            if (refreshed) {
              final token = _tokenManager.token;
              if (token != null) {
                error.requestOptions.headers['Authorization'] = 'Bearer $token';
                final opts = error.requestOptions;
                final newResponse = await dio.fetch(opts);
                return handler.resolve(newResponse);
              }
            }
          } catch (e) {
            print('Dio Interceptor - Token yenileme hatası: $e');
          }
        }
        return handler.next(error);
      },
    ));

    // Retry interceptor ekle
    dio.interceptors.add(
      dioLib.InterceptorsWrapper(
        onRequest: (options, handler) async {
          print('Dio istek gönderiliyor: ${options.uri}');
          final token = await getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print('Dio yanıt alındı: ${response.statusCode}');
          return handler.next(response);
        },
        onError: (dioLib.DioException e, handler) async {
          print('Dio hata: ${e.message}');
          print('Hata detayı: ${e.error}');

          if (e.type == dioLib.DioExceptionType.connectionTimeout ||
              e.type == dioLib.DioExceptionType.connectionError) {
            // Bağlantı hatası durumunda 3 kez yeniden deneme yap
            var retryCount = 0;
            while (retryCount < 3) {
              try {
                print('Yeniden deneme ${retryCount + 1}/3');
                final response = await dio.request(
                  e.requestOptions.path,
                  options: Options(
                    method: e.requestOptions.method,
                    headers: e.requestOptions.headers,
                  ),
                  data: e.requestOptions.data,
                  queryParameters: e.requestOptions.queryParameters,
                );
                return handler.resolve(response);
              } catch (retryError) {
                retryCount++;
                if (retryCount == 3) {
                  return handler.next(e);
                }
                await Future.delayed(Duration(seconds: 2 * retryCount));
              }
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  // Token'ı ayarla
  Future<void> setToken(String? token) async {
    if (token != null) {
      await _tokenManager.setToken(token);
    } else {
      await _tokenManager.clearToken();
    }
  }

  // Token'ı al
  Future<String?> getToken() async {
    return _tokenManager.getValidToken();
  }

  // Login işleminde token'ı ve user ID'yi kaydet
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      print('ApiService - Login isteği başlatılıyor...');
      print('ApiService - Giriş yapılan email: $email');

      // Önce mevcut oturum bilgilerini temizle
      await _clearSession();
      print('ApiService - Önceki oturum bilgileri temizlendi');

      // Login URL'sini doğrudan baseUrl'den oluştur
      final loginUrl = '$baseUrl/login';
      print('ApiService - Login URL: $loginUrl');

      final response = await dio.post(
        loginUrl,
        data: {
          'email': email,
          'password': password,
        },
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) {
            return status != null && status < 500;
          },
        ),
      );

      print('ApiService - Login yanıt durumu: ${response.statusCode}');
      print('ApiService - Login yanıt içeriği: ${response.data}');

      if (response.statusCode == 200) {
        if (response.data is Map<String, dynamic>) {
          final responseData = response.data;
          print('ApiService - Login yanıt verisi: $responseData');

          if (responseData['token'] != null && responseData['user'] != null) {
            final token = responseData['token'];
            final user = responseData['user'];

            print('ApiService - Alınan token: ${token.substring(0, 10)}...');
            print('ApiService - Alınan kullanıcı bilgileri: $user');

            // Token'ı kaydet
            await setToken(token);
            print('ApiService - Token kaydedildi');

            // Kullanıcı bilgilerini SharedPreferences'a kaydet
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_email', email);
            await prefs.setString('user_password', password);
            await prefs.setString('user_id', user['id'].toString());
            await prefs.setString('user_role', user['role']);
            await prefs.setString('user_name', user['name']);
            await prefs.setString('user_surname', user['surname']);
            await prefs.setString('user_email', user['email']);

            if (user['tcid'] != null) {
              await prefs.setString('user_tcid', user['tcid']);
            }

            // Doktor bilgileri varsa kaydet
            if (user['role'] == 'doctor') {
              await prefs.setString('doctor_id', user['id'].toString());
              await prefs.setString(
                  'doctor_name', '${user['name']} ${user['surname']}');
            }

            _currentUserId = int.tryParse(user['id'].toString());

            print('ApiService - Tüm kullanıcı bilgileri kaydedildi');
            return {
              'success': true,
              'token': token,
              'user': user,
              'message': 'Giriş başarılı'
            };
          }
        }
      }

      final errorMessage = response.data is Map<String, dynamic>
          ? response.data['message'] ?? 'Giriş başarısız'
          : 'Sunucu yanıtı geçersiz format';

      print('ApiService - Login hatası: $errorMessage');

      return {
        'success': false,
        'message': errorMessage,
      };
    } catch (e) {
      print('ApiService - Login hatası: $e');
      return {
        'success': false,
        'message': 'Bağlantı hatası: $e',
      };
    }
  }

  // Oturum bilgilerini temizle
  Future<void> _clearSession() async {
    try {
      print('ApiService - Oturum bilgileri temizleniyor...');

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('refresh_token');
      await prefs.remove('user_email');
      await prefs.remove('user_password');
      await prefs.remove('user_id');
      await prefs.remove('user_role');
      await prefs.remove('user_name');
      await prefs.remove('user_surname');
      await prefs.remove('user_tcid');
      await prefs.remove('doctor_id');
      await prefs.remove('doctor_name');

      _cachedToken = null;
      _cachedRefreshToken = null;
      _currentUserId = null;

      dio.options.headers.remove('Authorization');

      print('ApiService - Oturum bilgileri temizlendi');
    } catch (e) {
      print('ApiService - Oturum temizleme hatası: $e');
    }
  }

  // Login işleminde token'ı ve user ID'yi kaydet
  Future<void> saveLoginData(Map<String, dynamic> data) async {
    print('ApiService - Login verileri kaydediliyor...');

    if (data['token'] != null) {
      await setToken(data['token']);
    }

    final prefs = await SharedPreferences.getInstance();

    if (data['refresh_token'] != null) {
      await prefs.setString('refresh_token', data['refresh_token']);
      _cachedRefreshToken = data['refresh_token'];
    }

    if (data['user_id'] != null) {
      await prefs.setString('user_id', data['user_id'].toString());
      _currentUserId = int.tryParse(data['user_id'].toString());
    }

    if (data['name'] != null) {
      await prefs.setString('user_name', data['name']);
    }
    print('ApiService - Login verileri kaydedildi');
  }

  // Refresh token'ı SharedPreferences'dan al
  Future<String?> getRefreshToken() async {
    if (_cachedRefreshToken != null) return _cachedRefreshToken;

    final prefs = await SharedPreferences.getInstance();
    _cachedRefreshToken = prefs.getString('refresh_token');
    return _cachedRefreshToken;
  }

  // Token'ları SharedPreferences'a kaydet
  Future<void> _saveTokens(String token, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('refresh_token', refreshToken);
    _cachedToken = token;
    _cachedRefreshToken = refreshToken;
    print('ApiService - Token\'lar başarıyla kaydedildi');
  }

  // Token'ları temizle
  Future<void> _clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('refresh_token');
    _cachedToken = null;
    _cachedRefreshToken = null;
    print('ApiService - Token\'lar temizlendi');
  }

  // Token'ı yenile
  Future<void> _refreshToken() async {
    try {
      print('ApiService - Token yenileniyor...');

      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');

      if (refreshToken == null) {
        throw Exception('Refresh token bulunamadı');
      }

      final response = await dio.post(
        '/api/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200 && response.data['token'] != null) {
        final newToken = response.data['token'];
        final newRefreshToken = response.data['refresh_token'];

        // Yeni token'ları kaydet
        await setToken(newToken);
        await prefs.setString('refresh_token', newRefreshToken);

        print('ApiService - Token başarıyla yenilendi');
        return;
      }

      throw Exception('Token yenileme başarısız: Geçersiz yanıt');
    } catch (e) {
      print('ApiService - Token yenileme hatası: $e');
      throw Exception('Token yenilenemedi: $e');
    }
  }

  // Token başlatma/yenileme işlemi
  Future<void> initializeToken() async {
    try {
      print('ApiService - Token başlatılıyor...');

      // Önce mevcut token'ı kontrol et
      final currentToken = await getToken();
      if (currentToken != null) {
        try {
          // Token kontrolü için posts endpoint'ini kullanalım
          // çünkü test-endpoint mevcut değil
          final response = await dio.get('/posts',
              options:
                  Options(headers: {'Authorization': 'Bearer $currentToken'}));

          if (response.statusCode == 200) {
            print('ApiService - Mevcut token geçerli');
            return;
          }
        } catch (e) {
          print('ApiService - Token kontrolü hatası: $e');
        }
      }

      // Token yok veya geçersizse yeniden giriş yap
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email');
      final password = prefs.getString('user_password');

      if (email != null && password != null) {
        try {
          print('ApiService - Yeniden giriş deneniyor...');
          final loginResponse = await login(email, password);
          if (loginResponse['success']) {
            print('ApiService - Yeniden giriş başarılı, token yenilendi');
            return;
          }
        } catch (loginError) {
          print('ApiService - Giriş hatası: $loginError');
        }
      }

      throw Exception('Oturum bilgileri bulunamadı veya giriş başarısız');
    } catch (e) {
      print('ApiService - Token başlatma hatası: $e');
      throw Exception('Token yenilenemedi: ${e.toString()}');
    }
  }

  // Kullanıcı ID'sini al
  String? get userIdFromToken {
    try {
      return _cachedToken?.split('.')[1];
    } catch (e) {
      print('ApiService - User ID alınamadı: $e');
      return null;
    }
  }

  // Token kontrolü
  Future<Map<String, String>> get headers async {
    print('ApiService - Headers oluşturuluyor...');
    final token = await getToken();

    if (token == null) {
      print(
          'ApiService - Token olmadığı için sadece temel headers döndürülüyor');
      return {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
    }

    print('ApiService - Token ile birlikte headers oluşturuldu');
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  // Post işlemleri
  Future<Map<String, dynamic>> createPost(String content, String doctorId,
      {File? image}) async {
    try {
      print('Post oluşturma başlatılıyor...');
      print('İçerik: $content');
      print('Doktor ID: $doctorId');
      print('Resim var mı: ${image != null}');

      // Token kontrolü ve yenileme
      await initializeToken();
      final token = await getToken();
      if (token == null) {
        print('Token bulunamadı, post oluşturulamıyor!');
        throw Exception(
            'Oturum bilgileriniz bulunamadı. Lütfen tekrar giriş yapın.');
      }

      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/posts'));

      // Headers'a token'ı ekle
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // Metin içeriğini ekle
      request.fields['doctor_id'] = doctorId;
      request.fields['content'] = content;

      // Eğer resim varsa ekle
      if (image != null) {
        String extension = image.path.split('.').last.toLowerCase();
        if (!['jpg', 'jpeg', 'png'].contains(extension)) {
          extension = 'jpg';
        }

        String fileName =
            'post_image_${DateTime.now().millisecondsSinceEpoch}.$extension';

        request.files.add(
          await http.MultipartFile.fromPath(
            'image',
            image.path,
            filename: fileName,
          ),
        );
        print('Resim eklendi: $fileName');
      }

      print('İstek gönderiliyor...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('API yanıt durumu: ${response.statusCode}');
      print('API yanıt gövdesi: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Post başarıyla oluşturuldu');

        // Postları yeniden yükle
        await getPosts();

        return {
          'status': 'success',
          'data': responseData,
        };
      } else if (response.statusCode == 401) {
        print('Token geçersiz, yenileme deneniyor...');
        await initializeToken();
        // Yeniden deneme
        return createPost(content, doctorId, image: image);
      } else {
        throw Exception('Post oluşturulamadı: ${response.statusCode}');
      }
    } catch (e) {
      print('Post oluşturma hatası: $e');
      throw Exception('Post oluşturulamadı: $e');
    }
  }

  Future<Map<String, dynamic>> getPosts() async {
    try {
      print('ApiService - Posts alınıyor...');

      await initializeToken();
      final token = await getToken();
      if (token == null) {
        throw Exception('Token bulunamadı');
      }

      // Önbelleği bypass etmek için timestamp ekleyerek benzersiz URL oluştur
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final response = await dio.get(
        '/posts?_t=$timestamp',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'cache-control': 'no-cache',
            'pragma': 'no-cache',
          },
        ),
      );

      print('ApiService - API yanıtı: ${response.data}');

      if (response.data == null) {
        print('ApiService - Post verisi boş');
        return _getStaticPosts();
      }

      // Response'un içeriğini kontrol et ve tarihleri düzelt
      if (response.data is List) {
        final List<Map<String, dynamic>> formattedPosts = [];
        for (var post in response.data) {
          if (post is Map<String, dynamic>) {
            // Tarihi düzelt
            if (post['created_at'] != null) {
              try {
                final DateTime parsedDate = DateTime.parse(post['created_at']);
                post['created_at'] = parsedDate.toIso8601String();
              } catch (e) {
                // GMT formatındaki tarihi parse et
                final RegExp dateRegex = RegExp(
                    r'^([A-Za-z]+), (\d{2}) ([A-Za-z]+) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$');
                final Match? match = dateRegex.firstMatch(post['created_at']);

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
                    int.parse(match.group(4)!), // year
                    months[match.group(3)]!, // month
                    int.parse(match.group(2)!), // day
                    int.parse(match.group(5)!), // hour
                    int.parse(match.group(6)!), // minute
                    int.parse(match.group(7)!), // second
                  );
                  post['created_at'] = parsedDate.toIso8601String();
                }
              }
            }

            // Resim URL'lerinde önbelleği bypass etmek için timestamp ekle
            if (post['image_url'] != null &&
                post['image_url'].toString().isNotEmpty) {
              final imageUrl = post['image_url'].toString();
              if (imageUrl.contains('?')) {
                post['image_url'] = '$imageUrl&_t=$timestamp';
              } else {
                post['image_url'] = '$imageUrl?_t=$timestamp';
              }
            }

            formattedPosts.add(post);
          }
        }

        print('ApiService - ${formattedPosts.length} post alındı');
        return {
          'status': 'success',
          'data': formattedPosts,
        };
      }

      print('ApiService - Geçersiz yanıt formatı');
      return _getStaticPosts();
    } catch (e) {
      print('ApiService - Post getirme hatası: $e');
      if (e is DioException && (e.response?.statusCode == 401)) {
        print('Token geçersiz, yenileme deneniyor...');
        await initializeToken();
        // Yeniden deneme
        return getPosts();
      }
      return _getStaticPosts();
    }
  }

  // Test için statik post verileri
  Map<String, dynamic> _getStaticPosts() {
    print('ApiService - Statik demo verisi kullanılıyor');
    final List<Map<String, dynamic>> demoData = [
      {
        'id': '1',
        'doctor_id': '1',
        'content':
            'Cilt kanseri hakkında güncel bir araştırma yayınlandı. Detaylar için linke tıklayabilirsiniz.',
        'created_at': DateTime.now().toString(),
        'likes': 15,
        'comments': 5,
        'views': 100,
        'image_url': null
      },
      {
        'id': '2',
        'doctor_id': '2',
        'content':
            'Günlük güneş kremleri hakkında önemli bilgilendirme: SPF faktörü en az 30 olan kremleri tercih ediniz.',
        'created_at': DateTime.now().subtract(Duration(days: 1)).toString(),
        'likes': 27,
        'comments': 12,
        'views': 230,
        'image_url': null
      },
      {
        'id': '3',
        'doctor_id': '1',
        'content':
            'Melanom belirtileri ve korunma yöntemleri hakkında yeni bir makale yayınladım.',
        'created_at': DateTime.now().subtract(Duration(days: 2)).toString(),
        'likes': 45,
        'comments': 8,
        'views': 320,
        'image_url': null
      }
    ];

    return {
      'status': 'success',
      'data': demoData,
    };
  }

  // Yorum işlemleri
  Future<Map<String, dynamic>> addComment(
      String postId, String doctorId, String content) async {
    try {
      print('Yorum ekleme isteği başlatılıyor...');
      print('Post ID: $postId');
      print('İçerik: $content');

      // Token kontrolü ve yenileme
      await initializeToken();
      final token = await getToken();
      if (token == null) {
        throw Exception('Token bulunamadı');
      }

      final response = await dio.post(
        '/comments',
        data: {
          'post_id': postId,
          'comment_text': content,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      print('Yanıt durumu: ${response.statusCode}');
      print('Yanıt içeriği: ${response.data}');

      if (response.statusCode == 201) {
        return response.data;
      } else {
        print('Hata: Yorum eklenemedi (${response.statusCode})');
        throw Exception('Yorum eklenemedi: ${response.data}');
      }
    } catch (e) {
      print('Kritik hata: $e');
      throw Exception('Bağlantı hatası: $e');
    }
  }

  Future<Map<String, dynamic>> addCommentWithImage(
      String? postId, String doctorId, String content, File? imageFile) async {
    try {
      print('Resimli yorum ekleme isteği başlatılıyor...');
      print('Post ID: $postId, Doctor ID: $doctorId');
      print('İçerik: $content');

      // Post ID kontrolü
      if (postId == null || postId.isEmpty) {
        throw Exception('Post ID geçerli değil. Yorum eklenemez.');
      }

      // Eğer resim varsa ve içerik boşsa, hata fırlat
      if (imageFile != null && content.trim().isEmpty) {
        throw Exception(
            'Şu anda sadece metin yorumları destekleniyor. Lütfen bir yorum metni ekleyin.');
      }

      // Eğer içerik boşsa hata fırlat
      if (content.trim().isEmpty) {
        throw Exception('Yorum boş olamaz');
      }

      // Resimle ilgili bir uyarı fırlat
      if (imageFile != null) {
        print(
            'Uyarı: API şu anda resim yüklemeyi desteklemiyor, sadece yorum metni gönderiliyor');
      }

      // Token kontrolü
      await initializeToken();
      final token = await getToken();

      if (token == null) {
        throw Exception(
            'Oturum bilgisi bulunamadı. Lütfen tekrar giriş yapın.');
      }

      // Backend API'nin beklediği endpoint'e istek gönder
      // Daha önce API incelemesinde backend'in /comments endpoint'inde
      // post_id parametresi beklediğini görmüştük
      final response = await dio.post(
        '/comments',
        data: {
          'post_id': postId,
          'doctor_id': doctorId,
          'comment_text': content,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      print('Yanıt durumu: ${response.statusCode}');
      print('Yanıt içeriği: ${response.data}');

      if (response.statusCode == 201) {
        // Başarılı yanıt işleme
        final responseData = response.data;
        print('Yanıt verisi: $responseData');

        // Varsayılan olarak image_url null ekle
        Map<String, dynamic> result = responseData is Map
            ? Map<String, dynamic>.from(responseData)
            : {'comment_id': responseData};

        if (!result.containsKey('image_url')) {
          result['image_url'] = null;
        }

        return result;
      } else {
        print('Hata: Yorum eklenemedi (${response.statusCode})');
        throw Exception('Yorum eklenemedi: ${response.data}');
      }
    } catch (e) {
      print('Kritik hata: $e');
      throw Exception(e.toString());
    }
  }

  Future<List<Map<String, dynamic>>> getComments(String postId) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Önbellekteki yorumları kullan (1 dakika geçerli)
    if (_commentsCache.containsKey(postId) &&
        now - _commentsCacheTime < 60 * 1000) {
      print('Önbellekten yorumlar alınıyor - Post ID: $postId');
      return _commentsCache[postId]!;
    }

    try {
      // Token kontrolü
      await initializeToken();
      final token = await getToken();

      // Önbelleği bypass etmek için timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      print('Yorumlar getiriliyor - Post ID: $postId');

      // Doğru endpoint: /comments/post/{post_id}
      final response = await dio.get(
        '/comments/post/$postId?_t=$timestamp',
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : {},
          validateStatus: (status) => status! < 500,
        ),
      );

      print('Yorumlar yanıt durumu: ${response.statusCode}');
      print('Yanıt veri tipi: ${response.data.runtimeType}');
      print('Yanıt içeriği: ${response.data}');

      if (response.statusCode == 200) {
        // Backend'e göre response şu şekilde olmalı: { "post_id": post_id, "comments": [...] }
        if (response.data is Map && response.data['comments'] is List) {
          print(
              'Doğru format: "comments" anahtarı bulundu, ${response.data['comments'].length} yorum var');
          final comments =
              List<Map<String, dynamic>>.from(response.data['comments']);

          // Başarılı olduysa önbelleğe al
          if (comments.isNotEmpty) {
            _commentsCache[postId] = comments;
            _commentsCacheTime = now;
          }

          return comments;
        } else {
          // Alternatif formatları dene
          return await _parseCommentsResponse(response.data);
        }
      } else if (response.statusCode == 404) {
        // 404 hatası - Post veya yorumlar bulunamadı, normal bir durum
        print('Yorumlar bulunamadı (404) - Post ID: $postId');
        return [];
      } else {
        print('Yorumlar alınamadı - Durum kodu: ${response.statusCode}');

        // Token hatası durumunda yenileme denemesi
        if (response.statusCode == 401) {
          print('Token hatası, yenileme deneniyor...');
          await initializeToken();
          return getComments(postId); // Yeniden dene
        }

        return [];
      }
    } catch (e) {
      print('Yorumları alma hatası: $e');
      return [];
    }
  }

  // Yorumları parse etmek için yardımcı fonksiyon
  Future<List<Map<String, dynamic>>> _parseCommentsResponse(
      dynamic data) async {
    try {
      if (data is List) {
        print('Yanıt bir liste, liste uzunluğu: ${data.length}');
        return List<Map<String, dynamic>>.from(data);
      } else if (data is Map) {
        // Backend kodunda belirtilen anahtarlar
        if (data['comments'] is List) {
          print(
              'Yanıt "comments" anahtarı içeriyor, liste uzunluğu: ${data['comments'].length}');
          return List<Map<String, dynamic>>.from(data['comments']);
        } else if (data['data'] is List) {
          print(
              'Yanıt "data" anahtarı içeriyor, liste uzunluğu: ${data['data'].length}');
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          // Diğer olası anahtarları kontrol et
          print('Yanıt bir Map, içerdiği anahtarlar: ${data.keys.toList()}');

          // Map'teki anahtarları dolaş ve liste türünde değer ara
          for (var key in data.keys) {
            if (data[key] is List) {
              print('$key anahtarı bir liste, uzunluğu: ${data[key].length}');
              if (data[key].isNotEmpty && data[key].first is Map) {
                print(
                    '$key listesi Map tipinde elemanlar içeriyor, bu listeyi kullanıyoruz');
                return List<Map<String, dynamic>>.from(data[key]);
              }
            }
          }
        }
      }

      print('Uygun veri formatı bulunamadı: $data');
      return [];
    } catch (e) {
      print('Yorumları parse ederken hata: $e');
      return [];
    }
  }

  // Mesaj işlemleri
  Future<Map<String, dynamic>> getMessages() async {
    try {
      print('ApiService - Mesajlar getiriliyor...');
      final token = await getToken();
      print('ApiService - Kullanılan token: $token');

      if (token == null) {
        print('ApiService - Token eksik!');
        return {
          'status': 'error',
          'message': 'Token bulunamadı',
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('ApiService - API yanıt kodu: ${response.statusCode}');
      print('ApiService - API yanıt içeriği: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] == null) {
          print('ApiService - API yanıtında data alanı yok!');
          return {
            'status': 'error',
            'message': 'API yanıtında data alanı bulunamadı',
          };
        }
        return {
          'status': 'success',
          'data': data['data'],
        };
      } else if (response.statusCode == 401) {
        print('ApiService - Yetkilendirme hatası!');
        return {
          'status': 'error',
          'message': 'Yetkilendirme hatası',
        };
      } else {
        print('ApiService - Beklenmeyen yanıt kodu: ${response.statusCode}');
        return {
          'status': 'error',
          'message': 'Mesajlar alınamadı: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('ApiService - Hata: $e');
      return {
        'status': 'error',
        'message': 'Mesaj getirme hatası: $e',
      };
    }
  }

  Future<Map<String, dynamic>> sendMessage(
      String receiverId, String messageText,
      {String? imageUrl, String? token, File? imageFile}) async {
    try {
      print('Mesaj gönderme isteği yapılıyor');
      print('Alıcı ID: $receiverId');
      print('Mesaj: $messageText');

      // Token kontrolü
      final token = await getToken();
      if (token == null) {
        throw Exception('Token bulunamadı. Lütfen tekrar giriş yapın.');
      }

      var request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/messages'));

      // Headers ekle
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      // Mesaj alanlarını ekle
      request.fields['receiver_id'] = receiverId;
      request.fields['message_text'] = messageText;

      // Eğer resim varsa ekle
      if (imageFile != null) {
        String extension = imageFile.path.split('.').last.toLowerCase();
        if (!['jpg', 'jpeg', 'png'].contains(extension)) {
          extension = 'jpg';
        }

        String fileName =
            'message_image_${DateTime.now().millisecondsSinceEpoch}.$extension';

        request.files.add(
          await http.MultipartFile.fromPath(
            'image',
            imageFile.path,
            filename: fileName,
          ),
        );
        print('Resim eklendi: $fileName');
      }

      // İsteği gönder
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('API yanıt durumu: ${response.statusCode}');
      print('API yanıt gövdesi: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        print('Mesaj başarıyla gönderildi');
        return {'status': 'success', 'data': responseData};
      } else if (response.statusCode == 400) {
        print('Geçersiz istek: ${responseData['message']}');
        return {'status': 'error', 'message': responseData['message']};
      } else if (response.statusCode == 401) {
        print('Yetkilendirme hatası');
        return {'status': 'error', 'message': 'Lütfen tekrar giriş yapın'};
      } else if (response.statusCode == 404) {
        print('Alıcı bulunamadı');
        return {'status': 'error', 'message': 'Belirtilen alıcı bulunamadı'};
      } else {
        print('Beklenmeyen yanıt kodu: ${response.statusCode}');
        return {
          'status': 'error',
          'message': 'Mesaj gönderilemedi: ${response.statusCode}'
        };
      }
    } catch (e, stackTrace) {
      print('Mesaj gönderilirken hata oluştu:');
      print('Hata: $e');
      print('Stack trace: $stackTrace');
      return {'status': 'error', 'message': 'Mesaj gönderilemedi: $e'};
    }
  }

  // Dosya yükleme metodu
  Future<Map<String, dynamic>> uploadFile(
      FormData formData, String token) async {
    try {
      print('Dosya yükleme isteği başlatılıyor...');

      final dio = Dio();
      dio.options.headers['Authorization'] = 'Bearer $token';
      dio.options.headers['Accept'] = 'application/json';
      dio.options.headers['Content-Type'] = 'multipart/form-data';

      // SSL sertifika doğrulamasını devre dışı bırak
      (dio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate =
          (client) {
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      };

      // Mesajlar için özel endpoint kullan
      final response = await dio.post(
        '$baseUrl/messages/upload', // Endpoint'i değiştirdim
        data: formData,
        options: Options(
          validateStatus: (status) => status! < 500,
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      print('Dosya yükleme yanıtı: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data is Map && response.data.containsKey('url')) {
          return {'status': 'success', 'url': response.data['url']};
        } else if (response.data is Map &&
            response.data.containsKey('image_url')) {
          return {'status': 'success', 'url': response.data['image_url']};
        } else if (response.data is String && response.data.contains('http')) {
          return {'status': 'success', 'url': response.data};
        } else {
          return {
            'status': 'error',
            'message': 'Geçersiz API yanıtı: ${response.data}'
          };
        }
      } else {
        print('Hata yanıtı: ${response.data}');
        return {
          'status': 'error',
          'message': 'Dosya yükleme başarısız: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('Dosya yükleme hatası: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // Doktor listesini getir
  Future<Map<String, dynamic>> getDoctors(
      {String? name, String? specialty}) async {
    try {
      print('ApiService - Doktorlar getiriliyor...');
      print('ApiService - Kullanılan token: ${await getToken()}');

      if (await getToken() == null) {
        print('ApiService - Token eksik, token yenileniyor...');
        await initializeToken();
      }

      // Query parametrelerini oluştur
      String url = '$baseUrl/doctors';
      if (name != null || specialty != null) {
        List<String> params = [];
        if (name != null) params.add('name=$name');
        if (specialty != null) params.add('specialty=$specialty');
        url += '?' + params.join('&');
      }

      print('ApiService - İstek URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: await headers,
      );

      print('ApiService - Doktorlar yanıt durumu: ${response.statusCode}');
      print('ApiService - Doktorlar yanıt içeriği: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          print('ApiService - ${responseData['data'].length} doktor alındı');
          return responseData;
        } else {
          print('ApiService - Başarılı yanıt ama veri yok');
          return {
            'status': 'error',
            'message': 'Doktor verisi bulunamadı',
            'data': []
          };
        }
      } else if (response.statusCode == 401) {
        print('ApiService - Yetkilendirme hatası! Token yenileme denenecek.');
        try {
          // Token yenilemeyi dene
          await _refreshToken();
          // Yeni token ile tekrar istek gönder
          final retryResponse = await http.get(
            Uri.parse(url),
            headers: await headers,
          );

          if (retryResponse.statusCode == 200) {
            final responseData = json.decode(retryResponse.body);
            if (responseData['status'] == 'success' &&
                responseData['data'] != null) {
              return responseData;
            }
          }
          throw Exception('Yetkilendirme hatası: Token yenileme başarısız');
        } catch (refreshError) {
          print('ApiService - Token yenilemede hata: $refreshError');
          throw Exception('Yetkilendirme hatası: Token yenilenemedi');
        }
      } else {
        print('ApiService - Doktorlar alınamadı: ${response.statusCode}');
        throw Exception('Doktorlar alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      print('ApiService - API hatası: $e');
      throw Exception('API hatası: $e');
    }
  }

  // Belirli bir doktoru getir
  Future<Map<String, dynamic>> getDoctor(dynamic doctorId) async {
    try {
      print('ApiService - Doktor bilgisi getiriliyor (ID: $doctorId)...');
      print('ApiService - Kullanılan token: ${await getToken()}');

      if (await getToken() == null) {
        print('ApiService - Token eksik, token yenileniyor...');
        await initializeToken();
      }

      // Doktor ID'sini int'e dönüştür (eğer zaten int değilse)
      int docId;
      if (doctorId is int) {
        docId = doctorId;
      } else {
        try {
          docId = int.parse(doctorId.toString());
        } catch (e) {
          print(
              'ApiService - Doktor ID ($doctorId) int\'e dönüştürülemedi: $e');
          return {'status': 'error', 'message': 'Geçersiz doktor ID\'si'};
        }
      }

      final response = await http.get(
        Uri.parse('$baseUrl/doctors/$docId'),
        headers: await headers,
      );

      print('ApiService - Doktor yanıt durumu: ${response.statusCode}');
      print('ApiService - Doktor yanıt içeriği: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          print('ApiService - Doktor bilgisi alındı');
          return responseData;
        } else {
          print('ApiService - Başarılı yanıt ama veri yok');
          return {'status': 'error', 'message': 'Doktor bilgisi bulunamadı'};
        }
      } else if (response.statusCode == 404) {
        print('ApiService - Doktor bulunamadı');
        return {'status': 'error', 'message': 'Doktor bulunamadı'};
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        print('ApiService - Yetki hatası, token yenileniyor...');
        await initializeToken();
        return {
          'status': 'error',
          'message': 'Yetki hatası, lütfen tekrar deneyiniz'
        };
      } else {
        print('ApiService - Beklenmeyen hata: ${response.statusCode}');
        return {
          'status': 'error',
          'message': 'Sunucu hatası: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('ApiService - Doktor bilgisi alınırken hata: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // Login işleminde token'ı ve user ID'yi kaydet
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      print('ApiService - Profil bilgileri getiriliyor...');

      // Token kontrolü
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final savedEmail = prefs.getString('user_email');
      final savedUserId = prefs.getString('user_id');

      print(
          'ApiService - Mevcut token: ${token != null ? token.substring(0, 10) : 'null'}...');
      print('ApiService - Kayıtlı email: $savedEmail');
      print('ApiService - Kayıtlı user_id: $savedUserId');

      if (token == null || token.isEmpty) {
        print('ApiService - Token bulunamadı, yeniden giriş gerekiyor');
        return {
          'success': false,
          'message': 'Oturum bulunamadı. Lütfen tekrar giriş yapın.',
        };
      }

      final profileUrl = '$baseUrl/profile';
      print('ApiService - Profil URL: $profileUrl');

      final response = await dio.get(
        profileUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );

      print('ApiService - Profil yanıt durumu: ${response.statusCode}');
      print('ApiService - Profil yanıt içeriği: ${response.data}');

      if (response.statusCode == 200) {
        final responseData = response.data;
        print('ApiService - Profil yanıt verisi: $responseData');

        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final userData = responseData['data'];
          print('ApiService - Alınan kullanıcı bilgileri: $userData');

          // Gelen kullanıcı bilgilerini mevcut kayıtlı bilgilerle karşılaştır
          if (userData['email'] != savedEmail) {
            print(
                'ApiService - UYARI: Gelen email ($userData[email]) ile kayıtlı email ($savedEmail) farklı!');
          }

          if (userData['id'].toString() != savedUserId) {
            print(
                'ApiService - UYARI: Gelen user_id (${userData['id']}) ile kayıtlı user_id ($savedUserId) farklı!');
          }

          // Kullanıcı bilgilerini güncelle
          await prefs.setString('user_id', userData['id'].toString());
          await prefs.setString('user_role', userData['role']);
          await prefs.setString('user_name', userData['name']);
          await prefs.setString('user_surname', userData['surname']);
          await prefs.setString('user_email', userData['email']);
          if (userData['tcid'] != null) {
            await prefs.setString('user_tcid', userData['tcid']);
          }

          print('ApiService - Profil bilgileri güncellendi');
          return {
            'success': true,
            'data': userData,
            'role': userData['role'],
          };
        }
      } else if (response.statusCode == 401) {
        print('ApiService - Token geçersiz, yenileme deneniyor...');
        // Token yenileme
        await initializeToken();
        return getUserProfile(); // Profil bilgilerini tekrar getir
      }

      print('ApiService - Profil bilgileri alınamadı');
      return {
        'success': false,
        'message': 'Profil bilgileri alınamadı',
      };
    } catch (e) {
      print('ApiService - Profil bilgileri alma hatası: $e');
      return {
        'success': false,
        'message': 'Bağlantı hatası: $e',
      };
    }
  }

  // Grup üyelerini getir
  Future<Map<String, dynamic>> getGroupMembers(int groupId) async {
    try {
      final response = await dio.get('/group_members/group/$groupId');

      if (response.statusCode == 200) {
        print('Grup üyeleri yanıtı: ${response.data}');
        return {
          'status': 'success',
          'members': response.data['members'] ??
              [], // 'data' yerine direkt 'members' kullanıyoruz
        };
      } else {
        throw dioLib.DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Grup üyeleri alınamadı: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Grup üyeleri alınamadı: $e');
      return {
        'status': 'error',
        'members': [],
        'message': e.toString(),
      };
    }
  }

  // Gruba üye ekle
  Future<void> addGroupMember(int groupId, int doctorId) async {
    try {
      await dio.post('/group_members', data: {
        'group_id': groupId,
        'doctor_id': doctorId,
      });
    } catch (e) {
      print('Üye eklenemedi: $e');
      throw e;
    }
  }

  // Gruptan üye çıkar
  Future<void> removeGroupMember(int groupId, int doctorId) async {
    try {
      await dio.delete('/group_members/$groupId/$doctorId');
    } catch (e) {
      print('Üye çıkarılamadı: $e');
      throw e;
    }
  }

  // Grup yöneticisi yap/çıkar
  Future<void> toggleGroupAdmin(int groupId, int doctorId, bool isAdmin) async {
    try {
      await dio.put('/group_members/$groupId/$doctorId', data: {
        'is_admin': isAdmin,
      });
    } catch (e) {
      print('Yönetici durumu güncellenemedi: $e');
      throw e;
    }
  }

  // API servisini başlat
  Future<void> initialize() async {
    try {
      print('ApiService - Başlatılıyor...');
      await _tokenManager.initialize();
      print('ApiService başarıyla başlatıldı');
    } catch (e) {
      print('ApiService başlatma hatası: $e');
      throw Exception('API servisi başlatılamadı: $e');
    }
  }

  Future<Map<String, dynamic>> deleteComment(String commentId) async {
    try {
      // Token'ı al
      final token = await getToken();
      if (token == null) {
        print('Token bulunamadı, yorum silinemiyor!');
        throw Exception(
            'Oturum bilgileriniz bulunamadı. Lütfen tekrar giriş yapın.');
      }

      print('Yorum silme isteği gönderiliyor: $baseUrl/comments/$commentId');
      print('Token: Bearer $token');

      final response = await http.delete(
        Uri.parse('$baseUrl/comments/$commentId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('Yanıt alındı: ${response.statusCode}');
      print('Yanıt verisi: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Yorum silinemedi: ${response.body}');
      }
    } catch (e) {
      print('API hatası: $e');
      throw Exception('Bağlantı hatası: $e');
    }
  }

  Future<String> getDoctorId() async {
    try {
      // Önce sınıftaki değişkeni kontrol et
      if (_currentUserId != null) {
        return _currentUserId.toString();
      }

      // Değer yoksa SharedPreferences'tan al
      final prefs = await SharedPreferences.getInstance();
      final doctorId = prefs.getString('doctor_id');

      if (doctorId != null && doctorId.isNotEmpty) {
        return doctorId;
      }

      // Doktor ID değeri yoksa kullanıcı ID'sini dene
      final userId = prefs.getString('user_id');
      if (userId != null && userId.isNotEmpty) {
        return userId;
      }

      print('ApiService - Doktor ID bulunamadı, varsayılan değer dönüyor: "1"');
      return "1";
    } catch (e) {
      print('ApiService - Doktor ID alınırken hata: $e');
      return "1";
    }
  }

  // Resim yükleme metodu
  Future<String> loadImage(String imageUrl) async {
    try {
      print('ApiService - Resim URL işleniyor: $imageUrl');

      // URL'yi temizle
      imageUrl = imageUrl.replaceAll('//', '/').trim();
      if (imageUrl.startsWith('/')) {
        imageUrl = imageUrl.substring(1);
      }

      // Eğer tam URL ise ve 404 hatası alınmıyorsa direkt kullan
      if (imageUrl.startsWith('http')) {
        try {
          final response = await http.head(Uri.parse(imageUrl));
          if (response.statusCode == 200) {
            return imageUrl;
          }
        } catch (e) {
          print('ApiService - Tam URL kontrolü başarısız: $e');
        }
      }

      // Dosya adını al
      final fileName = imageUrl.split('/').last;

      // Olası dizinleri kontrol et
      final possiblePaths = [
        '/uploads/',
        '/storage/app/public/',
        '/storage/',
        '/images/',
        '/public/',
        '/assets/',
        '/media/',
        '/',
        '/uploads/images/',
        '/storage/images/',
        '/public/images/',
        '/public/uploads/',
        '/public/storage/',
      ];

      // Token'ı al
      final token = await getToken();
      final Map<String, String> headers =
          token != null ? {'Authorization': 'Bearer $token'} : {};

      // Her bir olası dizini dene
      for (var path in possiblePaths) {
        try {
          // İki farklı URL formatını dene
          final urls = [
            baseUrl + path + fileName, // Sadece dosya adıyla
            baseUrl + path + imageUrl, // Tam yolla
          ];

          for (var testUrl in urls) {
            print('ApiService - URL deneniyor: $testUrl');

            try {
              final response = await http
                  .head(
                    Uri.parse(testUrl),
                    headers: headers,
                  )
                  .timeout(Duration(seconds: 3));

              if (response.statusCode == 200) {
                print('ApiService - Resim bulundu: $testUrl');
                return testUrl;
              }
            } catch (e) {
              print('ApiService - URL denemesi başarısız: $testUrl - Hata: $e');
              continue;
            }
          }
        } catch (e) {
          print('ApiService - Dizin denemesi başarısız: $path - Hata: $e');
          continue;
        }
      }

      // Hiçbir yerde bulunamadıysa, varsayılan yolu dene
      final defaultUrl = baseUrl + '/uploads/' + fileName;
      print('ApiService - Varsayılan URL deneniyor: $defaultUrl');

      try {
        final response = await http
            .head(
              Uri.parse(defaultUrl),
              headers: headers,
            )
            .timeout(Duration(seconds: 3));

        if (response.statusCode == 200) {
          print('ApiService - Resim varsayılan URL\'de bulundu');
          return defaultUrl;
        }
      } catch (e) {
        print('ApiService - Varsayılan URL denemesi başarısız: $e');
      }

      // Son çare olarak orijinal URL'yi döndür
      print(
          'ApiService - Hiçbir alternatif bulunamadı, orijinal URL kullanılacak');
      return baseUrl + '/' + imageUrl;
    } catch (e) {
      print('ApiService - Resim URL işleme hatası: $e');
      throw e;
    }
  }

  Future<dioLib.Response<dynamic>> _handleRequest(
      Future<dioLib.Response<dynamic>> Function() requestFn) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Token bulunamadı');
      }
      return await requestFn();
    } catch (e) {
      if (e is dioLib.DioException && e.response?.statusCode == 401) {
        await _refreshToken();
        return await requestFn();
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deletePost(String postId) async {
    try {
      print('Post silme isteği başlatılıyor...');
      await initializeToken();

      // Önbelleği bypass etmek için timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final response = await dio.delete(
        '/posts/$postId?_t=$timestamp',
        options: Options(headers: await headers),
      );

      if (response.statusCode == 200) {
        return {'status': 'success', 'message': 'Post başarıyla silindi'};
      }

      throw Exception(response.data['message'] ?? 'Post silinemedi');
    } catch (e) {
      print('Post silme hatası: $e');
      throw Exception('Post silinirken bir hata oluştu: $e');
    }
  }

  Future<Map<String, dynamic>> likePost(String postId, String doctorId) async {
    try {
      await initializeToken();

      // Önbelleği bypass etmek için timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final response = await dio.post(
        '/likes?_t=$timestamp',
        data: {'post_id': postId, 'doctor_id': doctorId},
        options: Options(headers: await headers),
      );

      if (response.statusCode == 201) {
        return {'status': 'success', 'message': 'Like eklendi.'};
      }
      throw Exception(response.data['message'] ?? 'Like eklenemedi');
    } catch (e) {
      print('Like ekleme hatası: $e');
      throw Exception('Like eklenirken bir hata oluştu: $e');
    }
  }

  Future<Map<String, dynamic>> unlikePost(
      String postId, String doctorId) async {
    try {
      await initializeToken();

      // Önbelleği bypass etmek için timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final response = await dio.delete(
        '/likes/$postId/$doctorId?_t=$timestamp',
        options: Options(headers: await headers),
      );

      if (response.statusCode == 200) {
        return {'status': 'success', 'message': 'Like kaldırıldı.'};
      }
      throw Exception(response.data['message'] ?? 'Like kaldırılamadı');
    } catch (e) {
      print('Like kaldırma hatası: $e');
      throw Exception('Like kaldırılırken bir hata oluştu: $e');
    }
  }

  Future<Map<String, dynamic>> getLikeCount(String postId) async {
    try {
      await initializeToken();

      // Önbelleği bypass etmek için timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final response = await dio.get(
        '/likes/count/$postId?_t=$timestamp',
        options: Options(headers: await headers),
      );

      if (response.statusCode == 200) {
        return {'like_count': response.data['like_count'] ?? 0};
      }
      return {'like_count': 0};
    } catch (e) {
      print('Like sayısı alma hatası: $e');
      return {'like_count': 0};
    }
  }

  Future<Map<String, dynamic>> updatePost(String postId, String content,
      {File? image, bool keepCurrentImage = true}) async {
    try {
      await initializeToken();

      // Önbelleği bypass etmek için timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      FormData formData = FormData.fromMap({
        'content': content.trim(),
        'keep_image': keepCurrentImage ? '1' : '0',
        '_t': timestamp.toString(), // Form verisi olarak da ekle
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

      final response = await dio.put(
        '/posts/$postId?_t=$timestamp',
        data: formData,
        options: Options(headers: await headers),
      );

      if (response.statusCode == 200) {
        return {'status': 'success', 'message': 'Post güncellendi'};
      }

      throw Exception(response.data['message'] ?? 'Post güncellenemedi');
    } catch (e) {
      print('Post güncelleme hatası: $e');
      throw Exception('Post güncellenirken bir hata oluştu: $e');
    }
  }

  // GET metodu
  Future<http.Response> get(String path, {Map<String, String>? headers}) async {
    await initialize();
    final token = await _tokenManager.getValidToken();

    final Map<String, String> requestHeaders = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'cache-control': 'no-cache', // Önbelleği devre dışı bırak
      'pragma': 'no-cache',
    };

    if (headers != null) {
      requestHeaders.addAll(headers);
    }

    try {
      print('ApiService - GET isteği: $path');
      final response = await http.get(
        Uri.parse(baseUrl + path),
        headers: requestHeaders,
      );

      print('ApiService - GET yanıt durumu: ${response.statusCode}');
      if (response.statusCode == 401) {
        print('ApiService - Token geçersiz, yenileme deneniyor...');
        final refreshed = await _tokenManager.refreshToken();
        if (refreshed) {
          final newToken = _tokenManager.token;
          if (newToken != null) {
            final newHeaders = Map<String, String>.from(requestHeaders);
            newHeaders['Authorization'] = 'Bearer $newToken';
            return await http.get(
              Uri.parse(baseUrl + path),
              headers: newHeaders,
            );
          }
        }
      }
      return response;
    } catch (e) {
      print('ApiService - GET hatası: $e');
      throw Exception('GET isteği başarısız: $e');
    }
  }

  Future<bool> getLikePost(String postId) async {
    try {
      await initializeToken();
      final doctorId = await getDoctorId();

      // Önbelleği bypass etmek için timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final response = await dio.get(
        '/likes/$postId/$doctorId?_t=$timestamp',
        options: Options(
          headers: await headers,
          validateStatus: (status) => status! < 500, // 404 hatalarını kabul et
        ),
      );

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 404) {
        // 404 hatası - beğeni yok, normal bir durum
        return false;
      } else {
        print('Like kontrolü yanıt kodu: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Like kontrolü hatası: $e');
      return false;
    }
  }
}
