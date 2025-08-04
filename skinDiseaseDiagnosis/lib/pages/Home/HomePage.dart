import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:skincancer/style/color.dart';
import 'package:skincancer/service/home_service.dart';
import 'package:skincancer/pages/A%C4%B0/chat_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:skincancer/service/api_service.dart';
import 'package:skincancer/service/config_service.dart';
import 'package:skincancer/pages/Camera/CameraPage.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  const HomeScreen({super.key, required this.userName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HomeService _homeService = HomeService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _diagnosisList = [];
  List<Map<String, dynamic>> _filteredDiagnosisList = [];
  bool _isLoading = false;
  String _errorMessage = '';
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _homeService.initialize();
  }

  @override
  void dispose() {
    _homeService.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDiagnoses() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      print('Tanı sonuçları yükleniyor...');

      final diagnoses = await _homeService.getDiagnoses();

      if (!mounted) return;

      final formattedDiagnoses = diagnoses.map((diagnosis) {
        return {
          'id': diagnosis['id']?.toString(),
          'patientTc': diagnosis['patient_tc']?.toString() ?? '',
          'patientName':
              '${diagnosis['patient_name'] ?? ''} ${diagnosis['patient_surname'] ?? ''}'
                  .trim(),
          'diagnosisClass': diagnosis['diagnosis_class']?.toString() ?? '',
          'accuracy': double.tryParse(
                  diagnosis['result_percentage']?.toString() ?? '0') ??
              0.0,
          'date': diagnosis['created_at'] ?? DateTime.now().toIso8601String(),
          'imageUrl': diagnosis['image_path'] ?? '',
        };
      }).toList();

      setState(() {
        _diagnosisList = formattedDiagnoses;
        _filteredDiagnosisList = List.from(_diagnosisList);
        _isLoading = false;
        _errorMessage =
            formattedDiagnoses.isEmpty ? 'Henüz tanı kaydı bulunmuyor' : '';
      });
    } catch (e) {
      print('Tanı sonuçları yüklenirken hata: $e');
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'Tanı sonuçları yüklenirken bir hata oluştu. Lütfen daha sonra tekrar deneyin.';
        _isLoading = false;
      });
    }
  }

  void _filterDiagnoses(String query) {
    setState(() {
      _filteredDiagnosisList = _diagnosisList.where((diagnosis) {
        final tc = diagnosis['patientTc'].toString().toLowerCase();
        final diagnosisClass =
            diagnosis['diagnosisClass'].toString().toLowerCase();
        final searchLower = query.toLowerCase();
        return tc.contains(searchLower) || diagnosisClass.contains(searchLower);
      }).toList();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDiagnoses();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> featureCards = [
      // Fotoğraf Yükleme Kartı
      _buildFeatureCard(
        title: "Cilt Fotoğrafını Yükle",
        subtitle: "Yapay Zeka ile Analiz",
        icon: Icons.camera_alt_outlined,
        iconColor: cameraColor,
        backgroundColor: Colors.blue.shade50,
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CameraScreen(),
            ),
          );

          if (result == true) {
            _loadDiagnoses();
          }
        },
      ),

      // Chatbot Kartı
      _buildFeatureCard(
        title: "Chatbot ile Konuş",
        subtitle: "Sorularına Anında Yanıt",
        icon: Icons.chat_bubble_outline,
        iconColor: primaryColor,
        backgroundColor: Colors.teal.shade50,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(),
            ),
          );
        },
      ),

      // Doktor İletişim Kartı
      _buildFeatureCard(
        title: "Doktorlarla İletişim",
        subtitle: "Uzmanlarla Görüşün",
        icon: Icons.local_hospital_outlined,
        iconColor: secondaryColor,
        backgroundColor: Colors.orange.shade50,
        onTap: () {
          Navigator.pushNamed(context, '/community');
        },
      ),
    ];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        title: Text(
          "Merhaba ${widget.userName}",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white, size: 24),
            onPressed: () {
              _loadDiagnoses();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Tanı kayıtları yenileniyor...'),
                  duration: Duration(seconds: 1),
                  backgroundColor: primaryColor,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            tooltip: 'Tanı Kayıtlarını Yenile',
          ),
          IconButton(
            icon: Icon(Icons.notifications_none, color: Colors.white, size: 27),
            onPressed: () {
              // Bildirimler işlevi buraya eklenebilir
            },
            splashRadius: 24,
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Üst kısım renkli panel
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Cilt sağlığınızı takip edin!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 20),
                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _filterDiagnoses,
                        decoration: InputDecoration(
                          hintText: "TC veya Tanı Türü ile Arama Yapın",
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          prefixIcon: Icon(Icons.search, color: primaryColor),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 15),
                        ),
                        style: TextStyle(color: textColor1, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Özellik Kartları
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 10),
              child: CarouselSlider(
                options: CarouselOptions(
                  height: 130,
                  autoPlay: true,
                  enlargeCenterPage: true,
                  viewportFraction: 0.9,
                  aspectRatio: 16 / 9,
                  autoPlayCurve: Curves.easeInOut,
                  autoPlayAnimationDuration: Duration(milliseconds: 800),
                  enlargeFactor: 0.2,
                ),
                items: featureCards,
              ),
            ),

            // Tanı Kayıtları Başlığı
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Tanı Kayıtları",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor1,
                    ),
                  ),
                  if (_isLoading)
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    ),
                ],
              ),
            ),

            // Hata Mesajı
            if (_errorMessage.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red.shade800),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // Diagnosis Cards
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    )
                  : _buildDiagnosisCardPager(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              spreadRadius: 1,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 32,
                ),
              ),
              SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: textColor1,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primaryColorLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.arrow_forward_ios,
                  color: primaryColorLight,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiagnosisCardPager() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadDiagnoses();
        // Kullanıcıya geri bildirim sağla
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tanı kayıtları güncellendi'),
              duration: Duration(seconds: 1),
              backgroundColor: primaryColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      color: primaryColor,
      child: _filteredDiagnosisList.isEmpty
          ? ListView(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.medical_information_outlined,
                          size: 70,
                          color: Colors.grey[400],
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Henüz tanı kaydı bulunmuyor',
                        style: TextStyle(
                          fontSize: 17,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Yeni bir tanı için cilt fotoğrafı yükleyin',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                      SizedBox(height: 20),
                      TextButton.icon(
                        onPressed: _loadDiagnoses,
                        icon: Icon(Icons.refresh, color: primaryColor),
                        label: Text('Yenile',
                            style: TextStyle(color: primaryColor)),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                            side: BorderSide(
                                color: primaryColor.withOpacity(0.3)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: _filteredDiagnosisList.length,
              itemBuilder: (context, index) {
                final diagnosis = _filteredDiagnosisList[index];
                return Container(
                  margin: EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Üst kısım (Hasta Bilgileri)
                      Padding(
                        padding: EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.person_outline,
                                    color: primaryColor,
                                    size: 22,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        diagnosis['patientName'] ??
                                            'İsimsiz Hasta',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          color: textColor1,
                                        ),
                                      ),
                                      Text(
                                        'TC: ${diagnosis['patientTc']}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Text(
                                  'Tanı:',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: secondaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    diagnosis['diagnosisClass'],
                                    style: TextStyle(
                                      color: secondaryColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Alt kısım (Görsel)
                      if (diagnosis['imageUrl'] != null &&
                          diagnosis['imageUrl'].isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Colors.grey.shade100),
                              Padding(
                                padding: EdgeInsets.only(
                                    left: 18, top: 12, bottom: 8),
                                child: Text(
                                  'Tanı Görseli',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: textColor1,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              FutureBuilder<String?>(
                                future: _apiService.getToken(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Container(
                                      height: 180,
                                      width: double.infinity,
                                      color: Colors.grey.shade100,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  primaryColor),
                                        ),
                                      ),
                                    );
                                  }

                                  final token = snapshot.data;
                                  final imageUrl = diagnosis['imageUrl'];

                                  if (imageUrl == null || imageUrl.isEmpty) {
                                    return Container(
                                      height: 180,
                                      width: double.infinity,
                                      color: Colors.grey.shade200,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.image_not_supported,
                                            color: Colors.grey.shade400,
                                            size: 40,
                                          ),
                                          SizedBox(height: 12),
                                          Text(
                                            'Görsel bulunamadı',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  return Container(
                                    height: 220,
                                    child: Image.network(
                                      imageUrl,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      headers: token != null
                                          ? {
                                              'Authorization': 'Bearer $token',
                                            }
                                          : null,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return Container(
                                          height: 220,
                                          width: double.infinity,
                                          color: Colors.grey.shade100,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                  : null,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      primaryColor),
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        print('Görsel yükleme hatası: $error');
                                        print('Görsel URL: $imageUrl');
                                        return Container(
                                          height: 180,
                                          width: double.infinity,
                                          color: Colors.grey.shade200,
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.image_not_supported,
                                                color: Colors.grey.shade400,
                                                size: 40,
                                              ),
                                              SizedBox(height: 12),
                                              Text(
                                                'Görsel yüklenemedi',
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // CameraScreen'e gidip gelince yenilemek için
  void _onNewDiagnosis() {
    _loadDiagnoses();
  }
}
