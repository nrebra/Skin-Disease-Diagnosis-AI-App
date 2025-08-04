import 'api_service.dart';

Future<Map<String, dynamic>> login(String email, String password) async {
  try {
    print('AuthService - Login işlemi başlatılıyor...');

    // API servisinin başlatıldığından emin ol
    await ApiService().initialize();

    // Login işlemini gerçekleştir
    final response = await ApiService().login(email, password);

    print('AuthService - Login yanıtı: $response');
    return response;
  } catch (e) {
    print('AuthService - Login hatası: $e');
    return {
      'success': false,
      'message': 'Giriş yapılamadı: $e',
    };
  }
}
