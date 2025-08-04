import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:intl/intl.dart';
import '../../style/color.dart';
import '../../service/api_service.dart';
import '../../pages/chat/GroupChat/GroupChatPage.dart';
import '../../pages/chat/GroupChat/CreateGroupPage.dart';
import 'package:dio/dio.dart';
import 'dart:math' show min;
import 'dart:async';

class CommunitiesTab extends StatefulWidget {
  final TabController tabController;

  const CommunitiesTab({Key? key, required this.tabController})
      : super(key: key);

  @override
  _CommunitiesTabState createState() => _CommunitiesTabState();
}

class _CommunitiesTabState extends State<CommunitiesTab> {
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadGroups();

    // 30 saniyede bir grupları yeniden yükle
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadGroups();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final ApiService apiService = ApiService();
      print('CommunitiesTab - Token başlatılıyor...');
      await apiService.initializeToken();
      print('CommunitiesTab - Token başlatıldı');

      print('CommunitiesTab - Gruplar için API isteği yapılıyor: /group_chats');
      final response = await apiService.dio.get(
        '/group_chats',
        options: Options(
          headers: await _getAuthHeaders(),
          validateStatus: (status) => status! < 500,
        ),
      );

      // 404 hata kodu özel olarak işle
      if (response.statusCode == 404) {
        print(
            'CommunitiesTab - 404 hatası: Grup bulunamadı veya henüz oluşturulmamış');
        setState(() {
          _groups = [];
          _error = "404 - Henüz bir grup bulunamadı"; // Özel hata mesajı
        });
        return;
      }

      // Yanıtı detaylı inceleme
      print('API Yanıtı: ${response.data}');
      print('Gruplar mevcut mu: ${response.data.containsKey("groups")}');
      if (response.data.containsKey("groups")) {
        print('Grup sayısı: ${response.data["groups"].length}');
      }

      if (response.statusCode == 200 && response.data['groups'] != null) {
        setState(() {
          _groups = List<Map<String, dynamic>>.from(response.data['groups']);
          print('CommunitiesTab - Yüklenen grup sayısı: ${_groups.length}');
          if (_groups.isNotEmpty) {
            print('CommunitiesTab - İlk grup örneği: ${_groups.first}');
          }
        });
      } else {
        print(
            'CommunitiesTab - Grup yanıtı hata: ${response.statusCode} - ${response.data}');
        setState(() {
          _error = 'Gruplar yüklenemedi: ${response.statusCode}';
        });
      }
    } catch (e) {
      print('CommunitiesTab - Grupları yükleme hatası: $e');

      // DioException içindeki 404 hatasını özel olarak işle
      if (e is DioException && e.response?.statusCode == 404) {
        setState(() {
          _groups = [];
          _error = "404 - Henüz bir grup bulunamadı"; // Özel hata mesajı
        });
        return;
      }

      setState(() {
        _error = 'Gruplar yüklenirken hata oluştu: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final ApiService apiService = ApiService();
    final token = await apiService.getToken();
    if (token == null) {
      throw Exception('Token alınamadı');
    }
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_groups.isEmpty) {
      return _buildEmptyState();
    }

    return _buildGroupsList();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: primaryColor,
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'Gruplar Yükleniyor...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    bool isGroupsNotFoundError = _error != null &&
        (_error!.contains('404') ||
            _error!.contains('bulunamadı') ||
            _error!.contains('Not Found'));

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isGroupsNotFoundError ? Colors.amber[50] : Colors.red[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
                isGroupsNotFoundError
                    ? Icons.info_outline
                    : Icons.error_outline,
                size: 48,
                color: isGroupsNotFoundError ? Colors.amber : Colors.red),
          ),
          SizedBox(height: 16),
          Text(
            isGroupsNotFoundError ? 'Henüz Grup Yok' : 'Bir Hata Oluştu',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color:
                  isGroupsNotFoundError ? Colors.amber[700] : Colors.red[700],
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              isGroupsNotFoundError
                  ? 'Henüz hiç grup oluşturulmamış veya katıldığınız bir grup bulunmuyor.'
                  : _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _loadGroups,
                icon: Icon(Icons.refresh),
                label: Text('Tekrar Dene'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (isGroupsNotFoundError) ...[
                SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateGroupPage(),
                      ),
                    );
                    if (result == true) {
                      _loadGroups();
                    }
                  },
                  icon: Icon(Icons.add),
                  label: Text('Grup Oluştur'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.group_add_rounded,
              size: 64,
              color: primaryColor,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Henüz Bir Gruba Üye Değilsiniz',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Yeni bir grup oluşturarak veya mevcut gruplara katılarak diğer doktorlarla iletişime geçebilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
          SizedBox(height: 32),
          _buildCreateGroupButton(),
        ],
      ),
    );
  }

  Widget _buildGroupsList() {
    return RefreshIndicator(
      onRefresh: _loadGroups,
      color: primaryColor,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _groups.length + 1, // +1 for the create group button
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: _buildCreateGroupButton(),
            );
          }
          final group = _groups[index - 1];
          return _buildGroupCard(group);
        },
      ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupChatPage(group: group),
              ),
            );
            // Sohbet sayfasından dönüldüğünde listeyi yenile
            await _loadGroups();
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                _buildGroupAvatar(group),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group['group_name'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 4),
                      FutureBuilder<Map<String, dynamic>>(
                        future: ApiService()
                            .dio
                            .get('/group_members/group/${group['id']}')
                            .then((response) => response.data),
                        builder: (context, snapshot) {
                          int memberCount = 0;
                          if (snapshot.hasData) {
                            memberCount =
                                (snapshot.data?['members'] as List?)?.length ??
                                    0;
                          }
                          return Row(
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              SizedBox(width: 4),
                              Text(
                                '$memberCount üye',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 20,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupAvatar(Map<String, dynamic> group) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withOpacity(0.7),
            primaryColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Center(
        child: Text(
          group['group_name'][0].toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCreateGroupButton() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton.icon(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateGroupPage(),
            ),
          );

          if (result == true) {
            // Yeni grupları yükle
            _loadGroups();
          }
        },
        icon: Icon(Icons.add_rounded),
        label: Text('Yeni Grup Oluştur'),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final RegExp dateRegex = RegExp(
          r'^[A-Za-z]+, (\d{2}) ([A-Za-z]+) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$');
      final Match? match = dateRegex.firstMatch(dateStr);

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

        final DateTime parsedDate = DateTime(
          int.parse(match.group(3)!),
          months[match.group(2)]!,
          int.parse(match.group(1)!),
        );
        return DateFormat('dd.MM.yyyy').format(parsedDate);
      }

      final DateTime date = DateTime.parse(dateStr);
      return DateFormat('dd.MM.yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }
}
