import 'package:shared_preferences/shared_preferences.dart';

class AuthHelper {
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return token != null && token.isNotEmpty;
  }

  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Tüm oturum verilerini temizle
      await prefs.remove('token');
      await prefs.remove('refresh_token');
      await prefs.remove('user_id');
      await prefs.remove('user_role');
      await prefs.remove('user_name');
      await prefs.remove('user_email');
      await prefs.remove('user_tcid');
      await prefs.remove('doctor_id');
      await prefs.remove('doctor_name');
      await prefs.remove('user_password');

      print('Tüm oturum verileri başarıyla temizlendi');
    } catch (e) {
      print('Çıkış yaparken hata: $e');
      throw e;
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }
}
