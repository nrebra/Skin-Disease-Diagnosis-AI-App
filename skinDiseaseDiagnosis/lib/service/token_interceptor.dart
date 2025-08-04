import 'package:http_interceptor/http_interceptor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config_service.dart';

class TokenInterceptor implements InterceptorContract {
  @override
  Future<BaseRequest> interceptRequest({required BaseRequest request}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Accept'] = 'application/json';

      return request;
    } catch (e) {
      print('Token Interceptor - Request Hatası: $e');
      return request;
    }
  }

  @override
  Future<BaseResponse> interceptResponse(
      {required BaseResponse response}) async {
    if (response.statusCode == 401) {
      print('Token Interceptor - 401 Yetkisiz erişim, token yenileniyor...');
      try {
        // Önce mevcut oturum bilgilerini kontrol et
        final prefs = await SharedPreferences.getInstance();
        final email = prefs.getString('user_email');
        final password = prefs.getString('user_password');

        if (email == null || password == null) {
          print('Token Interceptor - Oturum bilgileri eksik');
          await _clearSession();
          return response;
        }

        final loginUrl = ConfigService.getApiUrl('auth', 'login');
        print('Token Interceptor - Login URL: $loginUrl');

        final loginResponse = await http.post(
          Uri.parse(loginUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'password': password,
          }),
        );

        print(
            'Token Interceptor - Login yanıt kodu: ${loginResponse.statusCode}');

        if (loginResponse.statusCode == 200) {
          final responseData = jsonDecode(loginResponse.body);
          final newToken = responseData['token'];
          final user = responseData['user'];

          if (newToken != null && user != null) {
            // Önce mevcut oturum bilgilerini temizle
            await _clearSession();

            // Yeni token ve kullanıcı bilgilerini kaydet
            await prefs.setString('token', newToken);
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

            print('Token Interceptor - Token ve kullanıcı bilgileri yenilendi');

            // Yeni token ile isteği tekrar dene
            final request = response.request;
            if (request != null) {
              request.headers['Authorization'] = 'Bearer $newToken';
              print(
                  'Token Interceptor - İstek yeniden deneniyor: ${request.url}');
            }
          }
        } else {
          print('Token Interceptor - Token yenileme başarısız');
          await _clearSession();
        }
      } catch (e) {
        print('Token Interceptor - Token yenileme hatası: $e');
        await _clearSession();
      }
    }
    return response;
  }

  @override
  bool shouldInterceptRequest() {
    return true;
  }

  @override
  bool shouldInterceptResponse() {
    return true;
  }

  // Oturum bilgilerini temizle
  Future<void> _clearSession() async {
    try {
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
    } catch (e) {
      print('Token Interceptor - Oturum temizleme hatası: $e');
    }
  }
}

class TokenExpiredRetryPolicy implements RetryPolicy {
  @override
  Future<bool> shouldAttemptRetryOnResponse(BaseResponse response) async {
    if (response.statusCode == 401) {
      print('RetryPolicy - 401 hatası tespit edildi, yeniden deneme yapılacak');
      return true;
    }
    return false;
  }

  @override
  int get maxRetryAttempts => 3; // Maksimum deneme sayısı arttırıldı

  @override
  Future<bool> shouldAttemptRetryOnException(
      Exception exception, BaseRequest request) async {
    print('RetryPolicy - İstisna nedeniyle yeniden deneme: $exception');
    return true; // İstisnalarda da yeniden dene
  }

  @override
  Duration delayRetryAttemptOnResponse({required int retryAttempt}) {
    return Duration(seconds: retryAttempt); // Artan bekleme süresi
  }

  @override
  Duration delayRetryAttemptOnException({required int retryAttempt}) {
    return Duration(seconds: retryAttempt); // Artan bekleme süresi
  }
}
