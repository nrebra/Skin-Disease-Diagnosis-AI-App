import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../../style/color.dart';
import '../../service/community_service.dart';
import '../../widgets/community/doctorCard.dart';
import 'package:provider/provider.dart';
import '../../provider/post_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../service/api_service.dart';

import 'createPostPage.dart';
import '../../widgets/community/post_card.dart';

import '../../widgets/community/community_tab.dart';
import '../../widgets/community/create_post_button.dart';

class CommunityScreen extends StatefulWidget {
  @override
  _CommunityScreenState createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late CommunityService _communityService;
  late ApiService _apiService;
  List<Map<String, dynamic>> _doctors = [];
  bool _isLoading = false;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _communityService = CommunityService(context);
    _apiService = ApiService();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);

    // Token kontrolü ve yenileme
    await _checkAndInitializeToken();

    // Veriyi yükle
    try {
      await _loadInitialData();
    } catch (e) {
      print('Servis başlatma hatası: $e');
      if (mounted) {
        _showTokenError();
      }
    }
  }

  Future<void> _checkAndInitializeToken() async {
    try {
      await _apiService.initialize();
      String? token = await _apiService.getToken();

      if (token == null) {
        final prefs = await SharedPreferences.getInstance();
        final email = prefs.getString('user_email');
        final password = prefs.getString('user_password');

        if (email != null && password != null) {
          print('CommunityPage - Token yok, yeniden giriş yapılıyor...');
          final loginResponse = await _apiService.login(email, password);
          if (!loginResponse['success']) {
            throw Exception('Yeniden giriş başarısız');
          }
          print('CommunityPage - Yeniden giriş başarılı');
        } else {
          throw Exception('Oturum bilgileri bulunamadı');
        }
      }
    } catch (e) {
      print('CommunityPage - Token kontrolü hatası: $e');
      if (mounted) {
        _showTokenError();
      }
    }
  }

  void _showTokenError() {
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

  void _handleTabChange() {
    if (mounted) setState(() => _currentTabIndex = _tabController.index);
  }

  Future<void> _loadInitialData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final doctors = await _communityService.fetchDoctors();
      if (mounted) setState(() => _doctors = doctors);
    } catch (e) {
      print('Veri yükleme hatası: $e');
      if (e.toString().contains('token') || e.toString().contains('oturum')) {
        await _checkAndInitializeToken();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: [
          PostsTab(communityService: _communityService),
          _buildDoctorsTab(),
          CommunitiesTab(tabController: _tabController),
        ],
      ),
      floatingActionButton: CreatePostButton(
        communityService: _communityService,
        isVisible: _currentTabIndex == 0,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      title: Text(
        'Topluluk',
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      actions: [
        // Yenileme butonu ekle
        if (_currentTabIndex == 0) // Sadece Posts tab'inde göster
          IconButton(
            icon: Icon(Icons.refresh, color: primaryColor),
            onPressed: () {
              if (mounted) {
                Provider.of<PostProvider>(context, listen: false)
                    .refreshPosts();
              }
            },
            tooltip: 'Gönderileri Yenile',
          ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: primaryColor,
        indicatorWeight: 3,
        labelColor: primaryColor,
        unselectedLabelColor: Colors.grey[600],
        labelStyle: TextStyle(fontWeight: FontWeight.bold),
        tabs: _buildTabs(),
      ),
    );
  }

  List<Widget> _buildTabs() {
    return [
      Tab(
        icon: Icon(
          Icons.post_add_rounded,
          color: textColor2,
        ),
        text: _currentTabIndex == 0 ? 'Gönderiler' : null,
      ),
      Tab(
        icon: Icon(Icons.people_alt_rounded),
        text: _currentTabIndex == 1 ? 'Doktorlar' : null,
      ),
      Tab(
        icon: Icon(Icons.groups_rounded),
        text: _currentTabIndex == 2 ? 'Topluluklar' : null,
      ),
    ];
  }

  Widget _buildDoctorsTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: primaryColor));
    }

    if (_doctors.isEmpty) {
      return EmptyDoctorsView();
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _doctors.length,
      itemBuilder: (context, index) {
        return DoctorCard(
          doctor: _doctors[index],
          onTap: _communityService.navigateToChat,
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class PostsTab extends StatefulWidget {
  final CommunityService communityService;

  const PostsTab({required this.communityService});

  @override
  _PostsTabState createState() => _PostsTabState();
}

class _PostsTabState extends State<PostsTab> {
  @override
  void initState() {
    super.initState();
    // Build işlemi tamamlandıktan sonra fetchPosts'u çağır
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PostProvider>().fetchPosts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await Provider.of<PostProvider>(context, listen: false).refreshPosts();
        return;
      },
      color: primaryColor,
      child: Consumer<PostProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.posts.isEmpty) {
            // Sadece ilk yüklemede tam loading göster
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Gönderiler yükleniyor...',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      shape: BoxShape.circle,
                    ),
                    child:
                        Icon(Icons.error_outline, size: 48, color: Colors.red),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Hata',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      '${provider.error}',
                      style: TextStyle(color: Colors.grey[700]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => provider.fetchPosts(),
                    icon: Icon(Icons.refresh),
                    label: Text('Tekrar Dene'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          if (provider.posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.post_add, size: 64, color: primaryColor),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Henüz gönderi yok',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'İlk gönderiyi siz oluşturun ve toplulukla paylaşın!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 32),
                  CreatePostButton(
                    communityService: widget.communityService,
                    isVisible: true,
                  ),
                ],
              ),
            );
          }

          // Eğer loading ve veriler varsa, loading göstermeden verileri göster
          return Stack(
            children: [
              ListView.builder(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                itemCount: provider.posts.length,
                itemBuilder: (context, index) {
                  final post = provider.posts[index];
                  return PostCard(
                    postId: post['id'].toString(),
                    userId: post['doctor_id'].toString(),
                    message: post['content'] ?? '',
                    time: post['created_at'] != null
                        ? widget.communityService
                            .formatDateString(post['created_at'].toString())
                        : 'Şimdi',
                    likes: post['likes'] ?? 0,
                    comments: post['comments'] ?? 0,
                    views: post['views'] ?? 0,
                    imageUrl: post['image_url'],
                    communityService: widget.communityService,
                  );
                },
              ),

              // Compact loading indicator - sadece yenileme durumunda göster
              if (provider.isLoading && provider.posts.isNotEmpty)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String formatDateString(String dateString) {
    try {
      // ISO 8601 formatında tarih parse etme
      DateTime parsedDate = DateTime.parse(dateString);
      return DateFormat('dd.MM.yyyy HH:mm').format(parsedDate);
    } catch (e) {
      try {
        // GMT formatında tarih parse etme
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

          final int day = int.parse(match.group(1)!);
          final int month = months[match.group(2)]!;
          final int year = int.parse(match.group(3)!);
          final int hour = int.parse(match.group(4)!);
          final int minute = int.parse(match.group(5)!);
          final int second = int.parse(match.group(6)!);

          final DateTime parsedDate =
              DateTime(year, month, day, hour, minute, second);
          return DateFormat('dd.MM.yyyy HH:mm').format(parsedDate);
        }
      } catch (e) {
        print("Tarih dönüştürme hatası: $e");
      }
      return dateString; // Eğer parse edilemezse orijinal string'i döndür
    }
  }
}
