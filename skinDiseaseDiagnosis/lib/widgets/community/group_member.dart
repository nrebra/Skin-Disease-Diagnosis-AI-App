// import 'package:flutter/material.dart';
// import '../../service/community_service.dart';
// import '../../style/color.dart';
// import '../../pages/chat/GroupChat/AddMembersPage.dart';

// class ModernGroupMembersSheet extends StatefulWidget {
//   final int groupId;
//   final String groupName;
//   final CommunityService communityService;
//   final ScrollController scrollController;
//   final bool isAdmin;

//   const ModernGroupMembersSheet({
//     Key? key,
//     required this.groupId,
//     required this.groupName,
//     required this.communityService,
//     required this.scrollController,
//     this.isAdmin = false,
//   }) : super(key: key);

//   @override
//   _ModernGroupMembersSheetState createState() =>
//       _ModernGroupMembersSheetState();
// }

// class _ModernGroupMembersSheetState extends State<ModernGroupMembersSheet> {
//   List<Map<String, dynamic>> _members = [];
//   bool _isLoading = true;
//   bool _isRemoving = false;
//   bool _isDisposed = false;
//   String? _currentDoctorId;
//   final TextEditingController _searchController = TextEditingController();
//   List<Map<String, dynamic>> _filteredMembers = [];

//   @override
//   void initState() {
//     super.initState();
//     _loadCurrentUser();
//     _loadMembers();
//     _searchController.addListener(_filterMembers);
//   }

//   @override
//   void dispose() {
//     _isDisposed = true;
//     _searchController.dispose();
//     super.dispose();
//   }

//   void _filterMembers() {
//     final query = _searchController.text.toLowerCase();
//     setState(() {
//       if (query.isEmpty) {
//         _filteredMembers = List.from(_members);
//       } else {
//         _filteredMembers = _members.where((member) {
//           final name = member['name'].toString().toLowerCase();
//           final surname = member['surname']?.toString().toLowerCase() ?? '';
//           return name.contains(query) || surname.contains(query);
//         }).toList();
//       }
//     });
//   }

//   Future<void> _loadCurrentUser() async {
//     _currentDoctorId = await widget.communityService.getCurrentDoctorId();
//     if (mounted) setState(() {});
//   }

//   Future<void> _loadMembers() async {
//     if (_isDisposed) return;

//     try {
//       final members =
//           await widget.communityService.fetchGroupMembers(widget.groupId);
//       if (!_isDisposed && mounted) {
//         setState(() {
//           _members = members;
//           _filteredMembers = List.from(members);
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       if (!_isDisposed && mounted) {
//         setState(() => _isLoading = false);
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//                 'Üyeler yüklenirken hata oluştu: ${e.toString().replaceAll("Exception: ", "")}'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }

//   Future<void> _addNewMembers() async {
//     if (_isDisposed) return;

//     final result = await Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => AddMembersPage(
//           groupId: widget.groupId,
//           groupName: widget.groupName,
//           existingMembers: _members,
//         ),
//       ),
//     );

//     if (result == true && !_isDisposed && mounted) {
//       _loadMembers();
//     }
//   }

//   Future<void> _removeMember(Map<String, dynamic> member) async {
//     if (_isRemoving || _isDisposed) return;

//     final confirm = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Üyeyi Çıkar'),
//         content: Text(
//             'Dr. ${member['name']} ${member['surname'] ?? ''} adlı üyeyi gruptan çıkarmak istediğinize emin misiniz?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, false),
//             child: Text('İptal'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.pop(context, true),
//             child: Text('Çıkar', style: TextStyle(color: Colors.red)),
//           ),
//         ],
//       ),
//     );

//     if (confirm != true || _isDisposed) return;

//     setState(() => _isRemoving = true);

//     try {
//       await widget.communityService.removeGroupMember(member['membership_id']);

//       if (!_isDisposed && mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//                 'Dr. ${member['name']} ${member['surname'] ?? ''} gruptan çıkarıldı'),
//             backgroundColor: Colors.green,
//           ),
//         );

//         setState(() {
//           _members.removeWhere(
//               (m) => m['membership_id'] == member['membership_id']);
//           _filteredMembers = List.from(_members);
//           _isRemoving = false;
//         });
//       }
//     } catch (e) {
//       if (!_isDisposed && mounted) {
//         setState(() => _isRemoving = false);
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//                 'Üye çıkarılırken hata oluştu: ${e.toString().replaceAll("Exception: ", "")}'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//       ),
//       child: Column(
//         children: [
//           // Başlık ve çentik
//           Container(
//             width: 40,
//             height: 5,
//             margin: EdgeInsets.only(top: 10),
//             decoration: BoxDecoration(
//               color: Colors.grey[300],
//               borderRadius: BorderRadius.circular(5),
//             ),
//           ),
//           Padding(
//             padding: EdgeInsets.all(20),
//             child: Column(
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       'Grup Üyeleri',
//                       style: TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     Text(
//                       '${_members.length} üye',
//                       style: TextStyle(
//                         color: Colors.grey[600],
//                         fontSize: 14,
//                       ),
//                     ),
//                   ],
//                 ),
//                 if (widget.isAdmin) ...[
//                   SizedBox(height: 16),
//                   InkWell(
//                     onTap: _addNewMembers,
//                     child: Container(
//                       padding:
//                           EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//                       decoration: BoxDecoration(
//                         color: primaryColor.withOpacity(0.1),
//                         borderRadius: BorderRadius.circular(12),
//                         border:
//                             Border.all(color: primaryColor.withOpacity(0.3)),
//                       ),
//                       child: Row(
//                         children: [
//                           Icon(Icons.person_add, color: primaryColor),
//                           SizedBox(width: 12),
//                           Text(
//                             'Yeni Üye Ekle',
//                             style: TextStyle(
//                               color: primaryColor,
//                               fontWeight: FontWeight.w600,
//                               fontSize: 16,
//                             ),
//                           ),
//                           Spacer(),
//                           Icon(
//                             Icons.arrow_forward_ios,
//                             color: primaryColor,
//                             size: 16,
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ],
//               ],
//             ),
//           ),

//           // Arama kutusu
//           Padding(
//             padding: EdgeInsets.symmetric(horizontal: 20),
//             child: Card(
//               elevation: 2,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: Padding(
//                 padding: EdgeInsets.symmetric(horizontal: 12),
//                 child: TextField(
//                   controller: _searchController,
//                   decoration: InputDecoration(
//                     hintText: 'Üye Ara',
//                     prefixIcon: Icon(Icons.search),
//                     suffixIcon: _searchController.text.isNotEmpty
//                         ? IconButton(
//                             icon: Icon(Icons.clear),
//                             onPressed: () {
//                               _searchController.clear();
//                             },
//                           )
//                         : null,
//                     border: InputBorder.none,
//                   ),
//                 ),
//               ),
//             ),
//           ),

//           // Üye listesi
//           Expanded(
//             child: _isLoading
//                 ? Center(child: CircularProgressIndicator(color: primaryColor))
//                 : _filteredMembers.isEmpty
//                     ? Center(
//                         child: Column(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Icon(
//                               Icons.group_off,
//                               size: 48,
//                               color: Colors.grey[400],
//                             ),
//                             SizedBox(height: 16),
//                             Text(
//                               'Henüz hiç üye yok',
//                               style: TextStyle(
//                                 color: Colors.grey[600],
//                                 fontSize: 16,
//                               ),
//                             ),
//                             if (widget.isAdmin) ...[
//                               SizedBox(height: 24),
//                               ElevatedButton.icon(
//                                 onPressed: _addNewMembers,
//                                 icon: Icon(Icons.person_add),
//                                 label: Text('Üye Ekle'),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: primaryColor,
//                                   foregroundColor: Colors.white,
//                                   padding: EdgeInsets.symmetric(
//                                     horizontal: 24,
//                                     vertical: 12,
//                                   ),
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(12),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ],
//                         ),
//                       )
//                     : ListView.builder(
//                         controller: widget.scrollController,
//                         padding: EdgeInsets.symmetric(horizontal: 16),
//                         itemCount: _filteredMembers.length,
//                         itemBuilder: (context, index) {
//                           final member = _filteredMembers[index];
//                           final bool isCurrentUser =
//                               member['doctor_id'].toString() ==
//                                   _currentDoctorId;
//                           final bool canRemove =
//                               widget.isAdmin || isCurrentUser;

//                           return Card(
//                             elevation: 0,
//                             margin: EdgeInsets.symmetric(vertical: 4),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(12),
//                               side: BorderSide(color: Colors.grey[200]!),
//                             ),
//                             child: ListTile(
//                               contentPadding: EdgeInsets.all(12),
//                               leading: CircleAvatar(
//                                 backgroundColor: primaryColor.withOpacity(0.1),
//                                 child: Text(
//                                   member['name'][0].toUpperCase(),
//                                   style: TextStyle(
//                                     color: primaryColor,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                               ),
//                               title: Text(
//                                 'Dr. ${member['name']} ${member['surname'] ?? ''}',
//                                 style: TextStyle(fontWeight: FontWeight.w600),
//                               ),
//                               subtitle: Text(
//                                 isCurrentUser ? 'Siz' : 'Üye',
//                                 style: TextStyle(
//                                   color: isCurrentUser
//                                       ? primaryColor
//                                       : Colors.grey[600],
//                                   fontSize: 12,
//                                 ),
//                               ),
//                               trailing: canRemove
//                                   ? Row(
//                                       mainAxisSize: MainAxisSize.min,
//                                       children: [
//                                         if (widget.isAdmin &&
//                                             !isCurrentUser) ...[
//                                           IconButton(
//                                             icon: Icon(Icons.edit_outlined,
//                                                 color: primaryColor),
//                                             onPressed: () {
//                                               // Üye düzenleme işlevi
//                                             },
//                                             tooltip: 'Düzenle',
//                                           ),
//                                         ],
//                                         IconButton(
//                                           icon: Icon(
//                                               Icons.remove_circle_outline,
//                                               color: Colors.red),
//                                           onPressed: () =>
//                                               _removeMember(member),
//                                           tooltip: 'Çıkar',
//                                         ),
//                                       ],
//                                     )
//                                   : null,
//                             ),
//                           );
//                         },
//                       ),
//           ),
//         ],
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import '../../service/community_service.dart';
import '../../style/color.dart';
import '../../pages/chat/GroupChat/AddMembersPage.dart';

class ModernGroupMembersSheet extends StatefulWidget {
  final int groupId;
  final String groupName;
  final CommunityService communityService;
  final ScrollController scrollController;
  final bool isAdmin;

  const ModernGroupMembersSheet({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.communityService,
    required this.scrollController,
    this.isAdmin = false,
  }) : super(key: key);

  @override
  _ModernGroupMembersSheetState createState() =>
      _ModernGroupMembersSheetState();
}

class _ModernGroupMembersSheetState extends State<ModernGroupMembersSheet> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  bool _isRemoving = false;
  bool _isDisposed = false;
  String? _currentDoctorId;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredMembers = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadMembers();
    _searchController.addListener(_filterMembers);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _searchController.dispose();
    super.dispose();
  }

  void _filterMembers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMembers = List.from(_members);
      } else {
        _filteredMembers = _members.where((member) {
          final name = member['name'].toString().toLowerCase();
          final surname = member['surname']?.toString().toLowerCase() ?? '';
          return name.contains(query) || surname.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadCurrentUser() async {
    _currentDoctorId = await widget.communityService.getCurrentDoctorId();
    if (mounted) setState(() {});
  }

  Future<void> _loadMembers() async {
    if (_isDisposed) return;

    try {
      final members =
          await widget.communityService.fetchGroupMembers(widget.groupId);
      if (!_isDisposed && mounted) {
        setState(() {
          _members = members;
          _filteredMembers = List.from(members);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar(
            'Üyeler yüklenirken hata oluştu: ${e.toString().replaceAll("Exception: ", "")}');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(12),
        duration: Duration(seconds: 4),
        action: SnackBarAction(
          label: 'TAMAM',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(12),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _addNewMembers() async {
    if (_isDisposed) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMembersPage(
          groupId: widget.groupId,
          groupName: widget.groupName,
          existingMembers: _members,
        ),
      ),
    );

    if (result == true && !_isDisposed && mounted) {
      _loadMembers();
    }
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    if (_isRemoving || _isDisposed) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Üyeyi Çıkar'),
        content: Text(
            'Dr. ${member['name']} ${member['surname'] ?? ''} adlı üyeyi gruptan çıkarmak istediğinize emin misiniz?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Çıkar'),
          ),
        ],
      ),
    );

    if (confirm != true || _isDisposed) return;

    setState(() => _isRemoving = true);

    try {
      await widget.communityService.removeGroupMember(member['membership_id']);

      if (!_isDisposed && mounted) {
        _showSuccessSnackBar(
            'Dr. ${member['name']} ${member['surname'] ?? ''} gruptan çıkarıldı');

        setState(() {
          _members.removeWhere(
              (m) => m['membership_id'] == member['membership_id']);
          _filteredMembers = List.from(_members);
          _isRemoving = false;
        });
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() => _isRemoving = false);
        _showErrorSnackBar(
            'Üye çıkarılırken hata oluştu: ${e.toString().replaceAll("Exception: ", "")}');
      }
    }
  }

  // Avatarlar için rastgele renkler üretmek için yardımcı metod
  Color _getAvatarColor(String name) {
    // Her isim için tutarlı bir renk döndürür
    final List<Color> colors = [
      Colors.blue.shade300,
      Colors.purple.shade300,
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.pink.shade300,
      Colors.teal.shade400,
      Colors.indigo.shade300,
      Colors.amber.shade600,
    ];

    int hashCode = name.hashCode;
    int colorIndex = hashCode.abs() % colors.length;
    return colors[colorIndex];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Çentik ve başlık
          Column(
            children: [
              Container(
                width: 40,
                height: 5,
                margin: EdgeInsets.only(top: 12, bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 12, 24, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${widget.groupName}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_members.length} üye',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Grup Üyeleri',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Arama ve Ekleme
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Üye Ara',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        prefixIcon:
                            Icon(Icons.search, color: Colors.grey.shade500),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear,
                                    color: Colors.grey.shade500),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                if (widget.isAdmin) ...[
                  SizedBox(width: 12),
                  InkWell(
                    onTap: _addNewMembers,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.person_add_alt_1_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Üye listesi
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: primaryColor,
                          strokeWidth: 3,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Üyeler yükleniyor...',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : _filteredMembers.isEmpty
                    ? Center(
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
                                Icons.group_off_rounded,
                                size: 56,
                                color: Colors.grey[400],
                              ),
                            ),
                            SizedBox(height: 20),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'Arama sonucu bulunamadı'
                                  : 'Henüz hiç üye yok',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'Farklı bir arama terimi deneyin'
                                  : 'Gruba üye ekleyerek başlayın',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                            ),
                            if (widget.isAdmin &&
                                _searchController.text.isEmpty) ...[
                              SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _addNewMembers,
                                icon: Icon(Icons.person_add_alt_1_rounded),
                                label: Text('Üye Ekle'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: widget.scrollController,
                        padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
                        itemCount: _filteredMembers.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final member = _filteredMembers[index];
                          final bool isCurrentUser =
                              member['doctor_id'].toString() ==
                                  _currentDoctorId;
                          final bool canRemove =
                              widget.isAdmin || isCurrentUser;
                          final Color avatarColor =
                              _getAvatarColor(member['name']);

                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: isCurrentUser
                                  ? primaryColor.withOpacity(0.06)
                                  : Colors.white,
                              border: Border.all(
                                color: isCurrentUser
                                    ? primaryColor.withOpacity(0.2)
                                    : Colors.grey.shade200,
                                width: 1.5,
                              ),
                            ),
                            child: IntrinsicHeight(
                              child: Row(
                                children: [
                                  // Sol taraftaki renkli şerit (sadece mevcut kullanıcı için)
                                  if (isCurrentUser)
                                    Container(
                                      width: 5,
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(16),
                                          bottomLeft: Radius.circular(16),
                                        ),
                                      ),
                                    ),

                                  // Üye bilgileri
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          // Avatar
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: LinearGradient(
                                                colors: [
                                                  avatarColor,
                                                  avatarColor.withOpacity(0.7),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                member['name'][0].toUpperCase(),
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 16),

                                          // İsim ve durumu
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'Dr. ${member['name']} ${member['surname'] ?? ''}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Container(
                                                      width: 8,
                                                      height: 8,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: isCurrentUser
                                                            ? primaryColor
                                                            : Colors
                                                                .grey.shade400,
                                                      ),
                                                    ),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      isCurrentUser
                                                          ? 'Siz'
                                                          : 'Üye',
                                                      style: TextStyle(
                                                        color: isCurrentUser
                                                            ? primaryColor
                                                            : Colors.grey[600],
                                                        fontSize: 13,
                                                        fontWeight:
                                                            isCurrentUser
                                                                ? FontWeight
                                                                    .w500
                                                                : FontWeight
                                                                    .normal,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),

                                          // İşlem butonları
                                          if (canRemove) ...[
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (widget.isAdmin &&
                                                    !isCurrentUser) ...[
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade100,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: IconButton(
                                                      icon: Icon(
                                                          Icons.edit_outlined,
                                                          size: 20),
                                                      color:
                                                          Colors.grey.shade700,
                                                      tooltip: 'Düzenle',
                                                      onPressed: () {
                                                        // Üye düzenleme işlevi
                                                      },
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                ],
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.red.shade50,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: IconButton(
                                                    icon: Icon(
                                                        Icons.person_remove,
                                                        size: 20),
                                                    color: Colors.red.shade600,
                                                    tooltip: 'Çıkar',
                                                    onPressed: () =>
                                                        _removeMember(member),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Alt kısım - Yükleniyor veya işlem yapılıyorsa gösterilecek
          if (_isRemoving)
            Container(
              padding: EdgeInsets.symmetric(vertical: 12),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryColor,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'İşlem yapılıyor...',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
