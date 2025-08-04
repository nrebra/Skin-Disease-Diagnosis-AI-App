import 'package:flutter/material.dart';
import '../../style/color.dart';
import '../../service/api_service.dart';
import '../../service/community_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GroupSettingsSheet extends StatefulWidget {
  final Map<String, dynamic> group;
  final bool isAdmin;
  final Function() onGroupUpdated;

  const GroupSettingsSheet({
    Key? key,
    required this.group,
    required this.isAdmin,
    required this.onGroupUpdated,
  }) : super(key: key);

  @override
  _GroupSettingsSheetState createState() => _GroupSettingsSheetState();
}

class _GroupSettingsSheetState extends State<GroupSettingsSheet> {
  late final CommunityService _communityService;
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  bool _isRemoving = false;
  bool _isDisposed = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _communityService = CommunityService(context);
    _loadCurrentUserId();
    _loadMembers();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _loadCurrentUserId() async {
    if (_isDisposed) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_isDisposed && mounted) {
        setState(() {
          _currentUserId = prefs.getString('user_id');
        });
      }
    } catch (e) {
      print('Kullanıcı ID yükleme hatası: $e');
    }
  }

  Future<void> _loadMembers() async {
    if (_isDisposed) return;

    try {
      setState(() => _isLoading = true);
      final response =
          await _communityService.getGroupMembers(widget.group['id']);
      if (mounted) {
        setState(() {
          _members = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Üyeler yüklenirken hata oluştu: $e')),
        );
      }
    }
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    if (_isRemoving || _isDisposed) return;

    // Sadece grup sahibi veya kendi üyeliğini silebilir
    if (_currentUserId != widget.group['created_by'] &&
        _currentUserId != member['doctor_id']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bu üyeliği silme yetkiniz yok')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Üyeyi Çıkar'),
        content: Text(
            '${member['name']} adlı üyeyi gruptan çıkarmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Çıkar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true || _isDisposed) return;

    if (!_isDisposed && mounted) {
      setState(() => _isRemoving = true);
    }

    try {
      await _communityService.removeGroupMember(member['membership_id']);

      if (!_isDisposed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${member['name']} gruptan çıkarıldı'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _members.removeWhere(
              (m) => m['membership_id'] == member['membership_id']);
          _isRemoving = false;
        });
        widget.onGroupUpdated();
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() => _isRemoving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Üye çıkarılırken hata oluştu: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          Divider(height: 32),
          _buildSettingsOptions(),
          if (_currentUserId == widget.group['created_by']) ...[
            _buildAdminSection(),
          ],
          _buildMembersList(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(height: 16),
        Text(
          'Grup Ayarları',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsOptions() {
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.people_outline, color: primaryColor),
          title: Text('Grup Üyeleri (${_members.length})'),
          trailing: Icon(Icons.chevron_right),
          onTap: () {
            // Üye listesi zaten gösteriliyor
          },
        ),
        if (_currentUserId == widget.group['created_by']) ...[
          ListTile(
            leading: Icon(Icons.edit_outlined, color: primaryColor),
            title: Text('Grup Adını Düzenle'),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              // Grup adı düzenleme
            },
          ),
        ],
      ],
    );
  }

  Widget _buildAdminSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 32),
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            'Yönetici İşlemleri',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMembersList() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: primaryColor));
    }

    if (_members.isEmpty) {
      return Center(child: Text('Henüz hiç üye yok'));
    }

    return Expanded(
      child: ListView.builder(
        itemCount: _members.length,
        padding: EdgeInsets.symmetric(vertical: 8),
        itemBuilder: (context, index) {
          final member = _members[index];
          final isGroupCreator =
              member['doctor_id'] == widget.group['created_by'];
          final isCurrentUser = member['doctor_id'] == _currentUserId;

          return Card(
            elevation: 0,
            margin: EdgeInsets.symmetric(vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.all(12),
              leading: CircleAvatar(
                backgroundColor: isGroupCreator
                    ? primaryColor
                    : primaryColor.withOpacity(0.1),
                child: Text(
                  member['name'][0].toUpperCase(),
                  style: TextStyle(
                    color: isGroupCreator ? Colors.white : primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                'Dr. ${member['name']} ${member['surname'] ?? ''}',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                isGroupCreator ? 'Grup Kurucusu' : 'Üye',
                style: TextStyle(
                  color: isGroupCreator ? primaryColor : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              trailing: (!isGroupCreator &&
                      (_currentUserId == widget.group['created_by'] ||
                          isCurrentUser))
                  ? IconButton(
                      icon:
                          Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: () => _removeMember(member),
                      tooltip: 'Üyeyi Çıkar',
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}
