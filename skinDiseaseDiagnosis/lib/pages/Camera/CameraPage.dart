import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:skincancer/style/color.dart';
import 'package:skincancer/service/authService.dart';
import 'package:skincancer/service/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/camera/camera_empty_state.dart';
import '../../widgets/camera/camera_image_preview.dart';
import '../../widgets/camera/image_source_dialog.dart';
import '../../widgets/camera/diagnosis_result_dialog.dart';
import '../../widgets/camera/tc_dialog.dart';
import '../../service/api_service.dart';
import '../../service/token_manager.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  File? _imageFile;
  final _tcController = TextEditingController();
  bool _isAnalyzing = false;
  bool _isSaving = false;
  Map<String, dynamic>? _diagnosisResult;
  late final AuthService _authService;
  late final StorageService _storageService;
  late final TokenManager _tokenManager;
  String? _doctorId;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _storageService = StorageService();
    _tokenManager = TokenManager();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      print('Servisler başlatılıyor...');
      await _tokenManager.initialize();

      String? token = await _tokenManager.getValidToken();

      if (token == null) {
        print('Token bulunamadı veya geçersiz, yeniden giriş gerekiyor');

        final prefs = await SharedPreferences.getInstance();
        final email = prefs.getString('user_email');
        final password = prefs.getString('user_password');

        if (email != null && password != null) {
          print('Kayıtlı kullanıcı bilgileri bulundu, yeniden giriş deneniyor');
          final apiService = ApiService();
          await apiService.initialize();
          final loginResult = await apiService.login(email, password);
          if (loginResult['success'] == true) {
            print('Yeniden giriş başarılı');
            await _loadUserInfo();
            setState(() => _isInitialized = true);
            return;
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Oturum bulunamadı. Lütfen tekrar giriş yapın.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Giriş Yap',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/login', (route) => false);
                },
              ),
            ),
          );
        }
        return;
      }

      await _loadUserInfo();
      setState(() => _isInitialized = true);
      print('Servisler başarıyla başlatıldı');
    } catch (e) {
      print('Servis başlatma hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bir hata oluştu: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Tekrar Dene',
              textColor: Colors.white,
              onPressed: () => _initializeServices(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? doctorId = prefs.getString('doctor_id');
      if (doctorId == null || doctorId.isEmpty) {
        doctorId = prefs.getString('user_id');
      }
      if (doctorId == null || doctorId.isEmpty) {
        throw Exception('Kullanıcı bilgileri bulunamadı');
      }
      setState(() {
        _doctorId = doctorId;
      });
      print('Doktor ID başarıyla yüklendi: $_doctorId');
    } catch (e) {
      print('Kullanıcı bilgileri yüklenirken hata: $e');
      throw e;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? photo = await picker.pickImage(source: source);
      if (photo != null) {
        setState(() {
          _imageFile = File(photo.path);
        });
      }
    } catch (e) {
      _showSnackbar('Fotoğraf seçme hatası: $e', isError: true);
    }
  }

  Future<void> _analyzePicture() async {
    if (_imageFile == null) {
      _showSnackbar('Lütfen önce bir fotoğraf çekin', isError: true);
      return;
    }

    final token = await _tokenManager.getValidToken();
    if (token == null) {
      _showSnackbar('Oturum bulunamadı. Lütfen tekrar giriş yapın.',
          isError: true);
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final result = await _authService.analyzeSkinImage(_imageFile!);

      setState(() {
        _diagnosisResult = result;
        _isAnalyzing = false;
      });

      if (result['success'] == true) {
        _showDiagnosisResult(result);
      } else {
        throw Exception(result['message'] ?? 'Analiz başarısız');
      }
    } catch (e) {
      setState(() => _isAnalyzing = false);
      _showSnackbar('Hata: $e', isError: true);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showDiagnosisResult(Map<String, dynamic> result) {
    DiagnosisResultDialog.show(
      context,
      result,
      () {
        Navigator.pop(context);
        _showTcDialog();
      },
      () {
        Navigator.pop(context);
        setState(() {
          _imageFile = null;
          _diagnosisResult = null;
        });
      },
    );
  }

  void _showTcDialog() {
    TcDialog.show(
      context,
      _tcController,
      _isSaving,
      () async {
        if (_tcController.text.length == 11) {
          _saveDiagnosis();
          Navigator.pop(context);
        } else {
          _showSnackbar('Geçerli bir TC kimlik no giriniz (11 haneli)',
              isError: true);
        }
      },
      () => Navigator.pop(context),
    );
  }

  Future<void> _saveDiagnosis() async {
    if (_imageFile == null || _diagnosisResult == null) {
      _showSnackbar('Hata: Fotoğraf veya sonuç bulunamadı', isError: true);
      return;
    }

    if (_doctorId == null) {
      _showSnackbar('Hata: Doktor bilgisi yüklenemedi', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final String patientTc = _tcController.text;
      final String diagnosisClass =
          _diagnosisResult!['predicted_class'] ?? 'Bilinmiyor';
      final dynamic confidenceValue = _diagnosisResult!['predicted_confidence'];
      String resultPercentage;

      if (confidenceValue is double) {
        resultPercentage = confidenceValue.toString();
      } else if (confidenceValue is int) {
        resultPercentage = confidenceValue.toString();
      } else if (confidenceValue is String) {
        try {
          final double parsed = double.parse(confidenceValue);
          resultPercentage = parsed.toString();
        } catch (e) {
          resultPercentage = "0.0";
        }
      } else {
        resultPercentage = "0.0";
      }

      print(
          'Tanı gönderiliyor - Sınıf: $diagnosisClass, Doğruluk: $resultPercentage');

      final result = await _authService.saveDiagnosis(
        doctorId: _doctorId!,
        patientTc: patientTc,
        diagnosisClass: diagnosisClass,
        resultPercentage: resultPercentage,
        imageFile: _imageFile!,
      );

      if (result['success'] == true) {
        _showSnackbar('Başarılı: ${result['message']}');
        setState(() {
          _imageFile = null;
          _diagnosisResult = null;
          _tcController.clear();
        });
      } else {
        throw Exception(result['message'] ?? 'Beklenmeyen API yanıtı');
      }
    } catch (e) {
      _showSnackbar('Kayıt hatası: $e', isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showImageSourceDialog() {
    ImageSourceDialog.show(context, _pickImage);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Icon(Icons.medical_services_rounded, color: primaryColor),
              SizedBox(width: 8),
              Text(
                'Cilt Analizi',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: primaryColor,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.medical_services_rounded, color: primaryColor),
            SizedBox(width: 8),
            Text(
              'Cilt Analizi',
              style: TextStyle(
                color: primaryColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          if (_imageFile != null)
            IconButton(
              icon: Icon(Icons.refresh, color: primaryColor),
              onPressed: () {
                setState(() {
                  _imageFile = null;
                  _diagnosisResult = null;
                });
              },
              tooltip: 'Yeni Analiz',
            ),
        ],
      ),
      body: _imageFile == null
          ? CameraEmptyState()
          : CameraImagePreview(
              imageFile: _imageFile!,
              isAnalyzing: _isAnalyzing,
              onAnalyzePressed: _analyzePicture,
            ),
      floatingActionButton: _imageFile == null
          ? FloatingActionButton.extended(
              heroTag: 'camera_upload_button',
              onPressed: _showImageSourceDialog,
              backgroundColor: primaryColor,
              icon: Icon(Icons.add_a_photo_rounded, color: Colors.white),
              label:
                  Text('Fotoğraf Yükle', style: TextStyle(color: Colors.white)),
              elevation: 2,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  @override
  void dispose() {
    _tcController.dispose();
    super.dispose();
  }
}
