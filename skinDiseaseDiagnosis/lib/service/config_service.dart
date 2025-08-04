import 'dart:convert';
import 'package:flutter/services.dart';

class ConfigService {
  static Map<String, dynamic> _config = {};
  static bool _isLoaded = false;

  // Singleton instance
  static final ConfigService _instance = ConfigService._internal();

  factory ConfigService() {
    return _instance;
  }

  ConfigService._internal();

  static Future<void> initialize() async {
    if (_isLoaded) return;

    try {
      final jsonString = await rootBundle.loadString('assets/env.json');
      _config = json.decode(jsonString);
      _isLoaded = true;
      print('Config yüklendi: ${_config.keys}');
    } catch (e) {
      print('Config yüklenirken hata: $e');
      _config = {};
    }
  }

  static const String baseUrl = 'https://berketopbas.com.tr';

  static String get geminiApiKey => _config['gemini_api_key'] as String? ?? '';

  static String getApiUrl(String service, String endpoint) {
    // Endpoint'i düzgün formatta oluştur
    String formattedEndpoint = endpoint;
    if (!endpoint.startsWith('/')) {
      formattedEndpoint = '/$endpoint';
    }

    // Service parametresi varsa ekle
    String servicePath = '';
    if (service == 'auth') {
      // Auth servisi için özel endpoint'ler
      switch (endpoint) {
        case 'check':
          return '$baseUrl/auth/check-token';
        case 'refresh':
          return '$baseUrl/auth/refresh-token';
        case 'login':
          return '$baseUrl/login';
        case 'logout':
          return '$baseUrl/logout';
        case 'signup':
          return '$baseUrl/signup';
        case 'signup-doctor':
          return '$baseUrl/signup-doctor';
        case 'upload-document':
          return '$baseUrl/upload-document';
        default:
          servicePath = '/auth';
      }
    } else {
      servicePath = service.isNotEmpty ? '/$service' : '';
    }

    // Debug için
    final url = '$baseUrl$servicePath$formattedEndpoint';
    print('ConfigService - Generated URL: $url');
    return url;
  }

  static String getFullUrl(String path) {
    return baseUrl + (path.startsWith('/') ? path : '/$path');
  }

  static dynamic getValue(String key, [dynamic defaultValue]) {
    _checkInitialized();
    return _config[key] ?? defaultValue;
  }

  static void _checkInitialized() {
    if (!_isLoaded) {
      print('Uyarı: Config henüz yüklenmedi. Önce initialize() çağrılmalı.');
    }
  }
}
