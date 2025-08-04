import 'package:flutter/material.dart';
import '../../../style/color.dart';
import '../../../service/api_service.dart';
import '../../../service/community_service.dart';
import 'package:skincancer/pages/chat/GroupChat/GroupChatPage.dart';

class CreateGroupPage extends StatefulWidget {
  @override
  _CreateGroupPageState createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _selectedMembers = [];
  List<Map<String, dynamic>> _allDoctors = [];
  List<Map<String, dynamic>> _filteredDoctors = [];
  bool _isLoading = false;
  late final CommunityService _communityService;

  @override
  void initState() {
    super.initState();
    _communityService = CommunityService(context);
    _loadDoctors();
    _searchController.addListener(_filterDoctors);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterDoctors() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredDoctors = List.from(_allDoctors);
      } else {
        _filteredDoctors = _allDoctors.where((doctor) {
          final name = doctor['name'].toString().toLowerCase();
          final surname = doctor['surname']?.toString().toLowerCase() ?? '';
          return name.contains(query) || surname.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadDoctors() async {
    setState(() => _isLoading = true);
    try {
      final doctors = await _communityService.fetchAllDoctors();
      setState(() {
        _allDoctors = doctors
            .where((doctor) =>
                doctor['status']?.toString().toUpperCase() == 'APPROVED')
            .toList();
        _filteredDoctors = List.from(_allDoctors);
      });
    } catch (e) {
      _showSnackBar('Doktorlar yüklenirken hata oluştu');
    }
    setState(() => _isLoading = false);
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade800 : successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  void _addMember(Map<String, dynamic> doctor) {
    if (!_selectedMembers.any((member) => member['id'] == doctor['id'])) {
      setState(() {
        _selectedMembers.add(doctor);
      });
    }
  }

  void _removeMember(Map<String, dynamic> doctor) {
    setState(() {
      _selectedMembers.removeWhere((member) => member['id'] == doctor['id']);
    });
  }

  Future<void> _createGroup() async {
    if (_nameController.text.isEmpty) {
      _showSnackBar('Lütfen grup adı girin');
      return;
    }

    if (_selectedMembers.isEmpty) {
      _showSnackBar('Lütfen en az bir üye ekleyin');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await ApiService().dio.post(
        '/group_chats',
        data: {
          'group_name': _nameController.text,
          'members': _selectedMembers.map((doctor) => doctor['id']).toList(),
        },
      );

      if (response.statusCode == 201) {
        _showSnackBar('Grup başarıyla oluşturuldu', isError: false);

        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Grup oluşturulurken hata oluştu');
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Yeni Grup',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          _isLoading
              ? Center(
                  child: Container(
                    margin: EdgeInsets.only(right: 16),
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : IconButton(
                  icon: Icon(
                    Icons.check,
                    size: 26,
                  ),
                  onPressed: _createGroup,
                  tooltip: 'Grup Oluştur',
                ),
        ],
      ),
      body: _isLoading && _allDoctors.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Doktorlar yükleniyor...',
                    style: TextStyle(
                      color: textColor1,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              physics: BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: primaryColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Group Name Input
                        Container(
                          margin: EdgeInsets.fromLTRB(20, 5, 20, 25),
                          child: TextField(
                            controller: _nameController,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Grup Adı',
                              labelStyle: TextStyle(color: Colors.white70),
                              hintText: 'Grup için bir isim giriniz',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 14,
                              ),
                              prefixIcon:
                                  Icon(Icons.group, color: Colors.white70),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white30),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        if (_selectedMembers.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 15),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(25),
                                topRight: Radius.circular(25),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 6,
                                  offset: Offset(0, -3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Seçilen Üyeler',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: textColor1,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: primaryColor.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${_selectedMembers.length}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  height: 80,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _selectedMembers.length,
                                    physics: BouncingScrollPhysics(),
                                    itemBuilder: (context, index) {
                                      final doctor = _selectedMembers[index];
                                      return Container(
                                        width: 70,
                                        margin: EdgeInsets.only(right: 14),
                                        child: Column(
                                          children: [
                                            Stack(
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: primaryColor
                                                            .withOpacity(0.15),
                                                        blurRadius: 8,
                                                        offset: Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: CircleAvatar(
                                                    radius: 26,
                                                    backgroundColor:
                                                        primaryColor,
                                                    child: Text(
                                                      doctor['name'][0]
                                                          .toUpperCase(),
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 18,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Positioned(
                                                  right: 0,
                                                  top: 0,
                                                  child: GestureDetector(
                                                    onTap: () =>
                                                        _removeMember(doctor),
                                                    child: Container(
                                                      padding:
                                                          EdgeInsets.all(2),
                                                      decoration: BoxDecoration(
                                                        color: secondaryColor,
                                                        shape: BoxShape.circle,
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                    0.1),
                                                            blurRadius: 4,
                                                            offset:
                                                                Offset(0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Icon(
                                                        Icons.close,
                                                        size: 14,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              '${doctor['name']} ${doctor['surname'] ?? ''}'
                                                  .split(' ')[0],
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: textColor1,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    color:
                        _selectedMembers.isEmpty ? primaryColor : Colors.white,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: _selectedMembers.isEmpty
                            ? BorderRadius.only(
                                topLeft: Radius.circular(25),
                                topRight: Radius.circular(25),
                              )
                            : null,
                        boxShadow: _selectedMembers.isEmpty
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 6,
                                  offset: Offset(0, -3),
                                ),
                              ]
                            : null,
                      ),
                      padding: EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Search Bar
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              style: TextStyle(fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'Doktor Ara',
                                hintStyle:
                                    TextStyle(color: Colors.grey.shade400),
                                prefixIcon: Icon(Icons.search,
                                    color: primaryColor, size: 22),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.clear,
                                            color: Colors.grey.shade600,
                                            size: 20),
                                        onPressed: () {
                                          _searchController.clear();
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 15,
                                  horizontal: 16,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: 20),

                          // Doctors Section Header
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.people_alt_outlined,
                                  color: primaryColor,
                                  size: 22,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tüm Doktorlar',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: textColor1,
                                      ),
                                    ),
                                    Text(
                                      'Gruba eklemek için doktorları seçin',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_filteredDoctors.length}',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 5),
                          Divider(),
                        ],
                      ),
                    ),
                  ),
                ),

                // Doctors List
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (_filteredDoctors.isEmpty) {
                        return Container(
                          height: 200,
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 60,
                                  color: Colors.grey.shade400,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Doktor bulunamadı',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (_searchController.text.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      'Arama kriterlerinizi değiştirmeyi deneyin',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }

                      final doctor = _filteredDoctors[index];
                      final isSelected = _selectedMembers
                          .any((member) => member['id'] == doctor['id']);

                      return AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        margin:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryColor.withOpacity(0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: isSelected
                                ? primaryColor
                                : primaryColorLight.withOpacity(0.8),
                            child: Text(
                              doctor['name'][0].toUpperCase(),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          title: Text(
                            '${doctor['name']} ${doctor['surname'] ?? ''}',
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: textColor1,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: doctor['specialty'] != null
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.medical_services_outlined,
                                        size: 14,
                                        color: secondaryColor.withOpacity(0.8),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        doctor['specialty'],
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: textColor2,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : null,
                          trailing: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? primaryColor.withOpacity(0.1)
                                  : Colors.grey.shade100,
                            ),
                            child: IconButton(
                              icon: Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.add_circle_outline_rounded,
                                color: isSelected
                                    ? primaryColor
                                    : Colors.grey.shade600,
                                size: 26,
                              ),
                              onPressed: () => isSelected
                                  ? _removeMember(doctor)
                                  : _addMember(doctor),
                            ),
                          ),
                          onTap: () => isSelected
                              ? _removeMember(doctor)
                              : _addMember(doctor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      );
                    },
                    childCount:
                        _filteredDoctors.isEmpty ? 1 : _filteredDoctors.length,
                  ),
                ),

                // Bottom padding for FloatingActionButton
                SliverToBoxAdapter(
                  child: SizedBox(height: 80),
                ),
              ],
            ),
      floatingActionButton: _selectedMembers.isNotEmpty && !_isLoading
          ? FloatingActionButton(
              heroTag: 'create_group_${DateTime.now().millisecondsSinceEpoch}',
              onPressed: _createGroup,
              child: Icon(Icons.check_rounded, size: 24),
              backgroundColor: secondaryColor,
              elevation: 4,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
