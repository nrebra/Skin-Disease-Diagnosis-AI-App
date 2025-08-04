import 'dart:async';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'dart:convert';
import 'config_service.dart';
import 'token_manager.dart';

class HomeService {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _errorMessage = '';
  final TokenManager _tokenManager = TokenManager();
  final ApiService _apiService = ApiService();

  String get errorMessage => _errorMessage;
  TextEditingController get usernameController => _usernameController;
  TextEditingController get passwordController => _passwordController;

  Future<void> initialize() async {
    try {
      await _tokenManager.initialize();
    } catch (error) {
      print("HomeService - Initialize hatası: $error");
    }
  }

  Future<List<Map<String, dynamic>>> getDiagnoses() async {
    try {
      // Önbelleği bypass etmek için timestamp ekleyerek benzersiz URL oluştur
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await _apiService.get('/get-diagnosis?_t=$timestamp');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('HomeService - ${data.length} tanı verisi alındı');

        return data.map((diagnosis) {
          final Map<String, dynamic> diagnosisMap =
              Map<String, dynamic>.from(diagnosis);
          String? imagePath = diagnosisMap['image_path']?.toString();
          // Dosya yolunu API URL'sine çevir
          if (imagePath != null && imagePath.isNotEmpty) {
            final fileName = imagePath.split('/').last;
            // Önbelleği bypass etmek için timestamp ekle
            imagePath =
                '${ConfigService.baseUrl}/uploads/ai_uploads/$fileName?_t=$timestamp';
          }

          diagnosisMap['image_path'] = imagePath;
          return diagnosisMap;
        }).toList();
      } else {
        throw Exception('Tanılar alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      print('Tanılar alınırken hata: $e');
      throw e;
    }
  }

  Future<Map<String, dynamic>> getDiagnosisDetail(int diagnosisId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response =
          await _apiService.get('/diagnosis/$diagnosisId?_t=$timestamp');
      if (response.statusCode == 200) {
        return json.decode(response.body)['diagnosis'];
      } else {
        throw Exception('Tanı detayı alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      print('Tanı detayı alınırken hata: $e');
      throw e;
    }
  }

  Future<List<Map<String, dynamic>>> getFilteredDiagnoses({
    String? patientTc,
    String? diagnosisClass,
    String? startDate,
    String? endDate,
  }) async {
    try {
      String queryParams = '';
      if (patientTc != null) queryParams += '&patient_tc=$patientTc';
      if (diagnosisClass != null)
        queryParams += '&diagnosis_class=$diagnosisClass';
      if (startDate != null) queryParams += '&start_date=$startDate';
      if (endDate != null) queryParams += '&end_date=$endDate';

      // Önbelleği bypass etmek için timestamp ekle
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      queryParams += '&_t=$timestamp';

      final response = await _apiService.get(
          '/doctor/diagnoses?${queryParams.isEmpty ? '_t=$timestamp' : queryParams.substring(1)}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['diagnoses']);
      } else {
        throw Exception(
            'Filtrelenmiş tanılar alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      print('Filtrelenmiş tanılar alınırken hata: $e');
      throw e;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
  }
}
