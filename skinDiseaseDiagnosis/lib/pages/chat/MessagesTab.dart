import 'package:flutter/material.dart';
import '../../service/api_service.dart';
import 'ChatPage.dart';
import '../../models/message_model.dart';
import 'dart:async'; // TimeoutException için bu import gerekli
import 'package:shared_preferences/shared_preferences.dart';

class MessagesTab extends StatefulWidget {
  @override
  _MessagesTabState createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _doctors = [];
  List<Message> _messages = [];
  bool _isLoading = false;
  bool _isAuthenticated = false;
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkAuthentication();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthentication() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final role = prefs.getString('role');

    if (token == null || role != 'doctor') {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    final apiService = ApiService();
    apiService.setToken(token);

    setState(() {
      _isAuthenticated = true;
      _isLoading = false;
    });
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!_isAuthenticated) return;

    setState(() => _isLoading = true);

    try {
      // API'den mesajları getir
      final response = await _apiService.getMessages();

      if (response['status'] == 'success' && response['data'] != null) {
        final List<Message> messages = (response['data'] as List)
            .map((messageData) {
              try {
                return Message.fromJson(messageData as Map<String, dynamic>);
              } catch (e) {
                print('Mesaj dönüştürme hatası: $e');
                return null;
              }
            })
            .where((message) => message != null)
            .cast<Message>()
            .toList();

        // Doktorları getir
        await _fetchDoctors();

        if (mounted) {
          setState(() {
            _messages = messages;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorSnackBar('Mesajlar alınamadı: ${response['message']}');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Veri yüklenirken bir hata oluştu');
      }
    }
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    await _fetchData();
    setState(() => _isRefreshing = false);
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'Tekrar Dene',
          textColor: Colors.white,
          onPressed: _fetchData,
        ),
      ),
    );
  }

  Future<void> _fetchDoctors() async {
    try {
      final response = await _apiService.getDoctors();

      if (response['status'] == 'success' && response['data'] != null) {
        final doctors = List<Map<String, dynamic>>.from(response['data']);

        if (mounted) {
          setState(() {
            _doctors = doctors;
          });
        }
      }
    } catch (e) {
      // Hata durumunu sessizce ele al
    }
  }

  void _navigateToChat(String receiverId, String receiverName) async {
    try {
      final doctorResponse = await _apiService.getDoctor(int.parse(receiverId));

      if (doctorResponse['status'] == 'success') {
        final doctorData = doctorResponse['data'];
        final String receiverSurname = doctorData['surname'] ?? '';

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              receiverId: receiverId,
              receiverName: receiverName,
              receiverSurname: receiverSurname,
            ),
          ),
        ).then((_) => _refreshData());
      } else {
        _showErrorSnackBar('Doktor bilgileri alınamadı');
      }
    } catch (e) {
      _showErrorSnackBar('Bir hata oluştu');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _doctors.isEmpty && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            ),
            SizedBox(height: 16),
            Text(
              'Yükleniyor...',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: Theme.of(context).primaryColor,
        child: Column(
          children: [
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildConversationsTab(),
                  _buildDoctorsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Theme.of(context).primaryColor,
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: Theme.of(context).primaryColor,
        indicatorWeight: 3,
        labelStyle: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
        tabs: [
          Tab(
            icon: Icon(Icons.message_rounded),
            text: 'Mesajlar',
          ),
          Tab(
            icon: Icon(Icons.people_alt_rounded),
            text: 'Doktorlar',
          ),
        ],
      ),
    );
  }

  Widget _buildConversationsTab() {
    if (_isRefreshing) {
      return Center(child: CircularProgressIndicator());
    }

    if (_messages.isEmpty) {
      return _buildEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        text: 'Henüz mesajınız yok',
        subtext:
            'Doktorlar sekmesinden bir doktor seçerek mesajlaşmaya başlayabilirsiniz',
      );
    }

    // Mesajları gruplayalım (her doktor için en son mesaj)
    final Map<String, Message> latestMessagesByDoctor = {};

    for (final message in _messages) {
      final senderId = message.senderId;
      final receiverId = message.receiverId;

      // Bizim dışımızdaki kişinin ID'sini bulalım
      final otherId = senderId == _userId ? receiverId : senderId;

      if (!latestMessagesByDoctor.containsKey(otherId) ||
          message.createdAt
              .isAfter(latestMessagesByDoctor[otherId]!.createdAt)) {
        latestMessagesByDoctor[otherId] = message;
      }
    }

    // En son mesajları tarihe göre sıralayalım
    final latestMessages = latestMessagesByDoctor.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemCount: latestMessages.length,
      itemBuilder: (context, index) {
        final message = latestMessages[index];
        return _buildMessageCard(message);
      },
    );
  }

  String get _userId {
    final prefs = SharedPreferences.getInstance()
        .then((prefs) => prefs.getString('user_id') ?? '');
    return prefs.toString();
  }

  Widget _buildDoctorsTab() {
    if (_isRefreshing) {
      return Center(child: CircularProgressIndicator());
    }

    if (_doctors.isEmpty) {
      return _buildEmptyState(
        icon: Icons.person_search_rounded,
        text: 'Henüz doktor bulunamadı',
        subtext: 'Daha sonra tekrar kontrol edin',
      );
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Doktor ara...',
              prefixIcon:
                  Icon(Icons.search, color: Theme.of(context).primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            onChanged: _filterDoctors,
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: _doctors.length,
            itemBuilder: (context, index) {
              final doctor = _doctors[index];
              return _buildDoctorCard(doctor);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
      {required IconData icon, required String text, String? subtext}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey[300],
          ),
          SizedBox(height: 16),
          Text(
            text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          if (subtext != null) ...[
            SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                subtext,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _filterDoctors(String query) {
    if (query.isEmpty) {
      _fetchDoctors();
      return;
    }

    setState(() {
      _doctors = _doctors.where((doctor) {
        final name = doctor['name'].toString().toLowerCase();
        final specialty = (doctor['specialty'] ?? '').toString().toLowerCase();
        final searchQuery = query.toLowerCase();

        return name.contains(searchQuery) || specialty.contains(searchQuery);
      }).toList();
    });
  }

  Widget _buildMessageCard(Message message) {
    // Gönderen doktoru bul
    final doctor = _doctors.firstWhere(
      (d) =>
          d['id'].toString() ==
          (message.senderId == _userId ? message.receiverId : message.senderId),
      orElse: () => {'name': 'Bilinmeyen Doktor', 'specialty': ''},
    );

    final bool isUnread = false; // Bunu API'den alacağız gerçek uygulamada
    final String doctorName = doctor['name'];
    final String specialty = doctor['specialty'] ?? 'Uzman Doktor';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigateToChat(
          message.senderId == _userId ? message.receiverId : message.senderId,
          doctorName,
        ),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              _buildDoctorAvatar(doctorName, size: 26),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Dr. $doctorName',
                          style: TextStyle(
                            fontWeight:
                                isUnread ? FontWeight.bold : FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _formatDateTime(message.createdAt),
                          style: TextStyle(
                            fontSize: 13,
                            color: isUnread
                                ? Theme.of(context).primaryColor
                                : Colors.grey[600],
                            fontWeight:
                                isUnread ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      specialty,
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color.fromARGB(255, 238, 12, 12),
                      ),
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        message.senderId == _userId
                            ? Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.subdirectory_arrow_left,
                                  size: 16,
                                  color: Colors.grey[500],
                                ),
                              )
                            : SizedBox.shrink(),
                        Expanded(
                          child: Text(
                            message.messageText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  isUnread ? Colors.black87 : Colors.grey[600],
                              fontWeight: isUnread
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            margin: EdgeInsets.only(left: 8),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorAvatar(String name, {double size = 20}) {
    return Hero(
      tag: 'doctor_avatar_$name',
      child: Container(
        width: size * 2,
        height: size * 2,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).primaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Text(
            name[0].toUpperCase(),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: size,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorCard(Map<String, dynamic> doctor) {
    final doctorName = doctor['name'];
    final specialty = doctor['specialty'] ?? 'Uzman Doktor';
    final hospital = doctor['hospital'];
    final rating = doctor['rating'] ?? 4.5; // Örnek rating

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigateToChat(doctor['id'].toString(), doctorName),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).primaryColor.withOpacity(0.8),
                          Theme.of(context).primaryColor,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        doctorName[0].toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dr. $doctorName',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          specialty,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (hospital != null) ...[
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on,
                                  size: 14, color: Colors.grey[600]),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  hospital,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < rating.floor()
                            ? Icons.star_rounded
                            : index < rating
                                ? Icons.star_half_rounded
                                : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 20,
                      );
                    }),
                  ),
                  SizedBox(width: 8),
                  Text(
                    rating.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColor.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Mesaj Gönder',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Şimdi';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} dk';
    } else if (difference.inDays == 0) {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Dün';
    } else if (difference.inDays < 7) {
      final dayNames = [
        'Pazartesi',
        'Salı',
        'Çarşamba',
        'Perşembe',
        'Cuma',
        'Cumartesi',
        'Pazar'
      ];
      return dayNames[dateTime.weekday - 1];
    } else {
      return '${dateTime.day}.${dateTime.month}.${dateTime.year}';
    }
  }
}
