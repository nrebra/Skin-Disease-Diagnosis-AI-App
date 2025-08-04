import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'config_service.dart';
import 'api_service.dart';
import 'storage_service.dart';
import '../models/user_model.dart';
import 'package:http_parser/http_parser.dart';

class AuthService {
  static final Map<String, dynamic> tempRegistrationData = {};
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  String _errorMessage = '';

  String get errorMessage => _errorMessage;

  // Giriş işlemi - API Service kullanarak
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      print('AuthService - Login işlemi başlatılıyor...');
      final loginResponse = await _apiService.login(email, password);
      print('Login yanıtı: $loginResponse');

      if (loginResponse['success'] == true || loginResponse['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        final token = loginResponse['token'];

        // Token'ı güvenli depoya kaydet
        await _storageService.saveToken(token);

        if (loginResponse['user'] != null) {
          final user = UserModel.fromJson(loginResponse['user']);
          // Kullanıcı bilgilerini Hive'a kaydet
          await _storageService.saveUser(user);

          // Email ve şifreyi SharedPreferences'a kaydet
          await _storageService.saveSetting('user_email', email);
          await _storageService.saveSetting('user_password', password);
        }

        await fetchUserData(); // Kullanıcı bilgilerini güncelle

        print('Kullanıcı bilgileri başarıyla kaydedildi');
        return loginResponse;
      } else {
        return {
          'success': false,
          'message': loginResponse['message'] ?? 'Giriş başarısız',
        };
      }
    } catch (e) {
      print('AuthService - Login hatası: $e');
      return {
        'success': false,
        'message': 'Giriş yapılamadı: $e',
      };
    }
  }

  // Token kontrolü
  Future<bool> checkToken(String token) async {
    try {
      final checkUrl = ConfigService.getApiUrl('auth', 'check');
      print('Token kontrolü yapılıyor: $checkUrl');

      final response = await http.get(
        Uri.parse(checkUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Token kontrol yanıtı: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Token kontrol hatası: $e');
      return false;
    }
  }

  // Token yenileme işlemi
  Future<Map<String, dynamic>> refreshToken() async {
    try {
      final currentToken = await _storageService.getToken();
      final email = _storageService.getSetting<String>('user_email');
      final password = _storageService.getSetting<String>('user_password');

      if (email == null || password == null) {
        return {'success': false, 'message': 'Kullanıcı bilgileri bulunamadı'};
      }

      // Önce mevcut token'ı kontrol et
      if (currentToken != null) {
        final isValid = await checkToken(currentToken);
        if (isValid) {
          return {'success': true, 'token': currentToken};
        }
      }

      // Token geçersizse veya yoksa yeniden giriş yap
      final loginResponse = await signIn(email: email, password: password);
      if (loginResponse['success'] && loginResponse['token'] != null) {
        return {'success': true, 'token': loginResponse['token']};
      }

      return {'success': false, 'message': 'Token yenilenemedi'};
    } catch (e) {
      print('Token yenileme hatası: $e');
      return {'success': false, 'message': 'Token yenileme hatası: $e'};
    }
  }

  // Çıkış işlemi
  Future<Map<String, dynamic>> signOut() async {
    try {
      print('AuthService - Çıkış işlemi başlatılıyor...');
      final logoutUrl = ConfigService.getApiUrl('auth', 'logout');
      final token = await _storageService.getToken();

      if (token != null) {
        try {
          print('AuthService - Çıkış API isteği gönderiliyor: $logoutUrl');
          final response = await http.post(
            Uri.parse(logoutUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );

          print('AuthService - Çıkış API yanıtı: ${response.statusCode}');

          if (response.statusCode == 200 || response.statusCode == 201) {
            print('AuthService - API çıkış başarılı, oturum temizleniyor...');
            await _storageService.clearSession();
          } else {
            print('AuthService - API çıkış başarısız: ${response.statusCode}');
          }
        } catch (e) {
          print('AuthService - Çıkış API çağrısı hatası: $e');
        }
      }

      // Her durumda oturumu temizle
      await _storageService.clearSession();

      return {
        'success': true,
        'message': 'Çıkış yapıldı',
      };
    } catch (e) {
      print('AuthService - Çıkış işlemi hatası: $e');
      return {
        'success': false,
        'message': 'Çıkış yapılamadı: $e',
      };
    }
  }

  // İlk kayıt aşaması (SignupPage'den)
  Future<Map<String, dynamic>> initializeSignUp({
    required String email,
    required String password,
    required String name,
    required String surname,
    required String userType,
  }) async {
    // İlk aşama bilgilerinin kontrolü
    if (email.isEmpty || password.isEmpty || name.isEmpty || surname.isEmpty) {
      return {
        'success': false,
        'message': 'Lütfen tüm alanları doldurunuz',
      };
    }

    // Bilgileri static değişkene sakla
    AuthService.tempRegistrationData.clear(); // Önce temizle
    AuthService.tempRegistrationData['email'] = email;
    AuthService.tempRegistrationData['password'] = password;
    AuthService.tempRegistrationData['name'] = name;
    AuthService.tempRegistrationData['surname'] = surname;
    AuthService.tempRegistrationData['userType'] = userType;

    print(
        'Kaydedilen ilk aşama bilgileri: ${AuthService.tempRegistrationData}');

    return {
      'success': true,
      'message': 'İlk aşama tamamlandı',
    };
  }

  // Kayıt işlemini tamamla (Information sayfasından)
  Future<Map<String, dynamic>> completeSignUp({
    required String tcid,
    required String phone,
    required int age,
    required String gender,
    String? experience,
    String? expert,
    String? clinic,
    String? diplomaPath,
    String? specialtyPath,
  }) async {
    try {
      if (AuthService.tempRegistrationData.isEmpty) {
        return {
          'success': false,
          'message': 'Kayıt bilgileri bulunamadı.',
        };
      }

      final userType = AuthService.tempRegistrationData['userType'];
      final signupUrl = ConfigService.getApiUrl('auth', 'signup');
      print('Kayıt URL: $signupUrl');

      // MultiPart request oluştur
      var request = http.MultipartRequest('POST', Uri.parse(signupUrl));

      // Debug için URL'yi yazdır
      print('Tam URL: ${Uri.parse(signupUrl)}');

      // Ortak form alanlarını ekle
      request.fields['name'] = AuthService.tempRegistrationData['name'] ?? '';
      request.fields['surname'] =
          AuthService.tempRegistrationData['surname'] ?? '';
      request.fields['phone'] = phone;
      request.fields['email'] = AuthService.tempRegistrationData['email'] ?? '';
      request.fields['password'] =
          AuthService.tempRegistrationData['password'] ?? '';
      request.fields['tcid'] = tcid;
      request.fields['age'] = age.toString();
      request.fields['gender'] = gender;
      request.fields['role'] = userType == 'doctor' ? 'doctor' : 'user';

      // Doktor için ek alanları ekle
      if (userType == 'doctor') {
        if (experience == null || expert == null || clinic == null) {
          return {
            'success': false,
            'message': 'Doktor kaydı için tüm alanlar zorunludur.',
          };
        }

        request.fields['experience'] = experience;
        request.fields['expert'] = expert;
        request.fields['clinic'] = clinic;
        request.fields['status'] = 'pending';

        // Diploma dosyasını ekle
        if (diplomaPath != null) {
          final file = File(diplomaPath);
          if (await file.exists()) {
            final stream = http.ByteStream(file.openRead());
            final length = await file.length();
            final multipartFile = http.MultipartFile(
              'document',
              stream,
              length,
              filename:
                  'diploma_${DateTime.now().millisecondsSinceEpoch}.${diplomaPath.split('.').last}',
            );
            request.files.add(multipartFile);
          } else {
            return {
              'success': false,
              'message': 'Diploma dosyası bulunamadı.',
            };
          }
        } else {
          return {
            'success': false,
            'message': 'Doktor kaydı için diploma yüklemeniz gerekiyor.',
          };
        }
      }

      print('Gönderilen form verileri:');
      print(request.fields);
      if (request.files.isNotEmpty) {
        print('Eklenen dosya: ${request.files.first.filename}');
      }

      // İsteği gönder
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Signup yanıt durumu: ${response.statusCode}');
      print('Signup yanıt içeriği: ${response.body}');

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final token = responseData['token'];

        // Token'ı sakla
        await _storageService.saveToken(token);

        // SharedPreferences'a token'ı ve kullanıcı bilgilerini kaydet
        await _storageService.saveSetting(
            'user_email', AuthService.tempRegistrationData['email'] ?? '');
        await _storageService.saveSetting(
            'user_role', userType == 'doctor' ? 'doctor' : 'user');

        print('Kayıt başarılı, token alındı: $token');
        AuthService.tempRegistrationData.clear();

        return {
          'success': true,
          'message': 'Kayıt başarılı.',
          'token': token,
        };
      } else {
        try {
          final errorData = jsonDecode(response.body);
          return {
            'success': false,
            'message': errorData['error'] ?? 'Kayıt başarısız',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Kayıt başarısız: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      print('Kayıt hatası: $e');
      return {
        'success': false,
        'message': 'Bağlantı hatası: $e',
      };
    }
  }

  // API yanıtlarını işle
  Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final token = responseData['token'];
        return {
          'success': true,
          'message': 'Kayıt başarılı.',
          'token': token,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message':
              errorData['message'] ?? errorData['error'] ?? 'Kayıt başarısız',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Kayıt başarısız: ${response.statusCode}',
      };
    }
  }

  Future<String?> getToken() async {
    try {
      // Önce statik token'ı kontrol et
      final token = await _storageService.getToken();
      if (token != null) {
        // Token geçerli mi kontrol et
        final isValid = await checkToken(token);
        if (isValid) {
          return token;
        }
      }

      // SharedPreferences'dan token'ı al
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString('token');

      // Token varsa geçerliliğini kontrol et
      if (storedToken != null && storedToken.isNotEmpty) {
        final isValid = await checkToken(storedToken);
        if (isValid) {
          await _storageService.saveToken(storedToken);
          return storedToken;
        }
      }

      // Token yoksa veya geçersizse yenilemeyi dene
      final refreshResult = await refreshToken();
      if (refreshResult['success']) {
        return refreshResult['token'];
      }

      // Hiçbir şekilde token alınamadıysa null dön
      return null;
    } catch (e) {
      print('Token alma hatası: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> analyzeSkinImage(File imageFile) async {
    try {
      print('AuthService - Görüntü analizi başlatılıyor...');

      // API URL'sini sabit olarak ayarla
      final url = 'https://berketopbas-smartderm.hf.space/predict';
      print('AuthService - İstek URL: $url');

      // MultiPart request oluştur
      var request = http.MultipartRequest('POST', Uri.parse(url));

      // Fotoğrafı ekle
      var stream = http.ByteStream(imageFile.openRead());
      var length = await imageFile.length();
      var multipartFile = http.MultipartFile(
        'image',
        stream,
        length,
        filename: 'analysis_image.jpg',
        contentType: MediaType('image', 'jpeg'),
      );
      request.files.add(multipartFile);

      print('AuthService - Görüntü yükleniyor...');

      // İsteği gönder
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print(
          'AuthService - Yanıt durumu:  [32m [1m [4m${response.statusCode} [0m');
      print('AuthService - Yanıt içeriği: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'predicted_class': data['predicted_class'],
          'predicted_confidence': data['predicted_confidence'],
          'all_classes': data['all_classes'],
        };
      } else {
        try {
          final data = json.decode(response.body);
          return {
            'success': false,
            'message':
                data['error'] ?? 'Analiz başarısız: ${response.statusCode}'
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Analiz başarısız: ${response.statusCode}'
          };
        }
      }
    } catch (e) {
      print('AuthService - Hata: $e');
      return {
        'success': false,
        'message': 'Görüntü analizi sırasında bir hata oluştu: $e'
      };
    }
  }

  Future<Map<String, dynamic>> saveDiagnosis({
    required String doctorId,
    required String patientTc,
    required String diagnosisClass,
    required String resultPercentage,
    required File imageFile,
  }) async {
    try {
      print('AuthService - Teşhis kaydediliyor...');

      // API URL'sini oluştur
      final url = '${ConfigService.baseUrl}/add_diagnosis';
      print('AuthService - İstek URL: $url');

      // Token'ı direkt SharedPreferences'dan al
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('AuthService - Token bulunamadı');
        return {
          'success': false,
          'message': 'Oturum bulunamadı. Lütfen tekrar giriş yapın.'
        };
      }

      print('AuthService - Token bulundu: ${token.substring(0, 10)}...');

      // MultiPart request oluştur
      var request = http.MultipartRequest('POST', Uri.parse(url));

      // Token ve diğer header'ları ekle
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // Form verilerini ekle
      request.fields['doctor_id'] = doctorId;
      request.fields['patient_tc'] = patientTc;
      request.fields['diagnosis_class'] = diagnosisClass;
      request.fields['result_percentage'] = resultPercentage;

      // Fotoğrafı ekle
      var stream = http.ByteStream(imageFile.openRead());
      var length = await imageFile.length();
      var multipartFile = http.MultipartFile(
        'image',
        stream,
        length,
        filename: 'diagnosis_image.jpg',
        contentType: MediaType('image', 'jpeg'),
      );
      request.files.add(multipartFile);

      print('AuthService - Gönderilen veriler:');
      print('- Doktor ID: $doctorId');
      print('- TC: $patientTc');
      print('- Tanı: $diagnosisClass');
      print('- Doğruluk: $resultPercentage');

      // İsteği gönder
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('AuthService - Yanıt durumu: ${response.statusCode}');
      print('AuthService - Yanıt içeriği: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Teşhis başarıyla kaydedildi',
          'image_path': data['image_path']
        };
      } else if (response.statusCode == 401) {
        // Token geçersiz ise yeniden giriş yapmayı öner
        print('AuthService - Token geçersiz');
        return {
          'success': false,
          'message': 'Oturum süresi dolmuş olabilir. Lütfen tekrar giriş yapın.'
        };
      } else {
        try {
          final data = json.decode(response.body);
          return {
            'success': false,
            'message':
                data['error'] ?? 'Teşhis kaydedilemedi: ${response.statusCode}'
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Teşhis kaydedilemedi: ${response.statusCode}'
          };
        }
      }
    } catch (e) {
      print('AuthService - Hata: $e');
      return {
        'success': false,
        'message': 'Teşhis kaydedilirken bir hata oluştu: $e'
      };
    }
  }

  void showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Hata"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Tamam"),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      // Token kontrolü
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Oturum bulunamadı. Lütfen tekrar giriş yapın.',
        };
      }

      final profileUrl = '${ConfigService.baseUrl}/profile';
      print('Profil bilgileri alınıyor: $profileUrl');

      final response = await http.get(
        Uri.parse(profileUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Profil yanıt durumu: ${response.statusCode}');
      print('Profil yanıt içeriği: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);
          if (responseData['status'] == 'success' &&
              responseData['data'] != null) {
            // Kullanıcı bilgilerini SharedPreferences'a kaydet
            await prefs.setString(
                'user_id', responseData['data']['id'].toString());
            await prefs.setString('user_role', responseData['data']['role']);
            await prefs.setString('user_name', responseData['data']['name']);
            await prefs.setString(
                'user_surname', responseData['data']['surname']);
            await prefs.setString('user_email', responseData['data']['email']);
            await prefs.setString(
                'user_tcid', responseData['data']['tcid'] ?? '');

            return {
              'success': true,
              'data': responseData['data'],
              'role': responseData['data']['role'],
            };
          } else {
            return {
              'success': false,
              'message': 'Profil bilgileri alınamadı: Geçersiz yanıt formatı',
            };
          }
        } catch (e) {
          print('Profil bilgileri alma hatası: $e');
          return {
            'success': false,
            'message': 'Profil bilgileri alınamadı: $e',
          };
        }
      } else if (response.statusCode == 401) {
        // Token geçersiz, yenilemeyi dene
        final refreshResult = await refreshToken();
        if (refreshResult['success']) {
          // Token yenilendi, profil bilgilerini tekrar al
          return getUserProfile();
        } else {
          return {
            'success': false,
            'message': 'Oturum süresi dolmuş. Lütfen tekrar giriş yapın.',
          };
        }
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Profil bilgileri alınamadı',
        };
      }
    } catch (e) {
      print('Profil bilgileri alma hatası: $e');
      return {
        'success': false,
        'message': 'Bağlantı hatası: $e',
      };
    }
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    try {
      // Token kontrolü
      if (_storageService.getToken() == null) {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        if (token == null) {
          return {
            'success': false,
            'message': 'Oturum bulunamadı. Lütfen tekrar giriş yapın.',
          };
        }
        await _storageService.saveToken(token);
      }

      final updateUrl = '${ConfigService.baseUrl}/profile';
      print('Profil güncelleme isteği gönderiliyor: $updateUrl');
      print('Gönderilen veriler: $data');

      final response = await http.put(
        Uri.parse(updateUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_storageService.getToken()}',
        },
        body: jsonEncode(data),
      );

      print('Profil güncelleme yanıt durumu: ${response.statusCode}');
      print('Profil güncelleme yanıt içeriği: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          return {
            'success': true,
            'message': 'Profil başarıyla güncellendi',
          };
        }
      } else if (response.statusCode == 401) {
        // Token geçersiz, yenilemeyi dene
        final refreshResult = await refreshToken();
        if (refreshResult['success']) {
          // Token yenilendi, güncellemeyi tekrar dene
          return updateProfile(data);
        } else {
          return {
            'success': false,
            'message': 'Oturum süresi dolmuş. Lütfen tekrar giriş yapın.',
          };
        }
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Profil güncellenemedi',
      };
    } catch (e) {
      print('Profil güncelleme hatası: $e');
      return {
        'success': false,
        'message': 'Bağlantı hatası: $e',
      };
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      final loginResponse = await _apiService.login(username, password);

      if (loginResponse['success'] == true) {
        final token = loginResponse['token'];
        final doctorId = loginResponse['doctor_id'];
        final doctorName = loginResponse['name'];
        final doctorSurname = loginResponse['surname'];

        // Token ve doktor bilgilerini kaydet
        await _apiService.setToken(token);

        final prefs = await SharedPreferences.getInstance();
        if (doctorId != null) {
          await prefs.setString('doctor_id', doctorId);
        }
        await prefs.setString('doctor_name', '$doctorName $doctorSurname');

        return true;
      } else {
        _errorMessage = loginResponse['message'] ?? 'Giriş başarısız';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Giriş yapılamadı: $e';
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Tüm local verileri temizle
    // Diğer çıkış işlemleri
  }

  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final doctorId = prefs.getString('doctor_id');
      return token != null && doctorId != null;
    } catch (e) {
      print('Oturum kontrolü yapılırken hata: $e');
      return false;
    }
  }

  Future<String?> getDoctorName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('doctor_name');
    } catch (e) {
      print('Doktor adı alınırken hata: $e');
      return null;
    }
  }

  Future<void> fetchUserData() async {
    try {
      final userProfile = await getUserProfile();
      if (userProfile['success']) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', userProfile['data']['id'].toString());
        await prefs.setString('user_role', userProfile['role']);
        await prefs.setString('user_name', userProfile['data']['name']);
        await prefs.setString('user_surname', userProfile['data']['surname']);
        await prefs.setString('user_email', userProfile['data']['email']);
        await prefs.setString('user_tcid', userProfile['data']['tcid'] ?? '');
      }
    } catch (e) {
      print('Kullanıcı bilgileri güncellenirken hata: $e');
    }
  }
}
