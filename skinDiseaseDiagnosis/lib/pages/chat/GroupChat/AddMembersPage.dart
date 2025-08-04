import 'package:flutter/material.dart';
import '../../../service/community_service.dart';
import '../../../style/color.dart';

class AddMembersPage extends StatefulWidget {
  final int groupId;
  final String groupName;
  final List<Map<String, dynamic>> existingMembers;

  const AddMembersPage({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.existingMembers,
  }) : super(key: key);

  @override
  _AddMembersPageState createState() => _AddMembersPageState();
}

class _AddMembersPageState extends State<AddMembersPage> {
  List<Map<String, dynamic>> _selectedDoctors = [];
  List<Map<String, dynamic>> _availableDoctors = [];
  List<Map<String, dynamic>> _filteredDoctors = [];
  bool _isLoading = false;
  bool _isAdding = false;
  late final CommunityService _communityService;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _communityService = CommunityService(context);
    _loadDoctors();
    _searchController.addListener(_filterDoctors);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterDoctors);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    setState(() => _isLoading = true);

    try {
      // Tüm doktorları al
      final allDoctors = await _communityService.fetchAllDoctors();

      // Mevcut üyeleri filtrele
      final existingMemberIds =
          widget.existingMembers.map((m) => m['doctor_id'].toString()).toSet();
      final available = allDoctors
          .where(
              (doctor) => !existingMemberIds.contains(doctor['id'].toString()))
          .toList();

      if (mounted) {
        setState(() {
          _availableDoctors = available;
          _filteredDoctors = List.from(available);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Doktorlar yüklenirken hata oluştu', true);
      }
    }
  }

  void _filterDoctors() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredDoctors = List.from(_availableDoctors);
      } else {
        _filteredDoctors = _availableDoctors.where((doctor) {
          final name = doctor['name'].toString().toLowerCase();
          final surname = doctor['surname'] != null
              ? doctor['surname'].toString().toLowerCase()
              : '';
          return name.contains(query) || surname.contains(query);
        }).toList();
      }
    });
  }

  void _toggleDoctorSelection(Map<String, dynamic> doctor) {
    setState(() {
      final isSelected = _selectedDoctors.any((d) => d['id'] == doctor['id']);
      if (isSelected) {
        _selectedDoctors.removeWhere((d) => d['id'] == doctor['id']);
      } else {
        _selectedDoctors.add(doctor);
      }
    });
  }

  void _showSnackBar(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
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

  Future<void> _addMembers() async {
    if (_selectedDoctors.isEmpty) {
      _showSnackBar('Lütfen en az bir doktor seçin', true);
      return;
    }

    setState(() => _isAdding = true);

    try {
      List<Map<String, dynamic>> addedMembers = [];
      List<String> failedMembers = [];

      // Seçilen her doktoru ekle
      for (var doctor in _selectedDoctors) {
        try {
          final response = await _communityService.addGroupMember(
              widget.groupId, int.parse(doctor['id'].toString()));

          addedMembers.add({
            'doctor_id': doctor['id'],
            'name': doctor['name'],
            'surname': doctor['surname'] ?? '',
            'membership_id': response['membership_id']
          });
        } catch (e) {
          print('Üye eklenirken hata: ${doctor['name']} - $e');
          failedMembers.add('Dr. ${doctor['name']} ${doctor['surname'] ?? ''}');
        }
      }

      if (mounted) {
        setState(() => _isAdding = false);

        // Başarılı mesajı göster
        if (addedMembers.isNotEmpty) {
          _showSnackBar('${addedMembers.length} doktor gruba eklendi', false);
        }

        // Başarısız olanları da göster
        if (failedMembers.isNotEmpty) {
          _showSnackBar(
              'Bazı doktorlar eklenemedi: ${failedMembers.join(", ")}', true);
        }

        Navigator.pop(context, addedMembers.isNotEmpty);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAdding = false);
        _showSnackBar('Üyeler eklenirken hata oluştu', true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Üye Ekle',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Container(
            padding: EdgeInsets.only(left: 20, bottom: 16, right: 20),
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.groupName,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  '${widget.existingMembers.length} mevcut üye',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Arama kutusu
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Doktor ara...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      prefixIcon:
                          Icon(Icons.search, color: primaryColor, size: 22),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear,
                                  color: Colors.grey.shade600),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
                    ),
                  ),
                ),

                // Seçilen doktorlar
                if (_selectedDoctors.isNotEmpty) ...[
                  SizedBox(height: 20),
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
                          size: 18,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Seçilen doktorlar',
                        style: TextStyle(
                          color: textColor1,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
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
                          '${_selectedDoctors.length}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _selectedDoctors.map((doctor) {
                        return Container(
                          decoration: BoxDecoration(
                            color: primaryColorLight.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: primaryColor.withOpacity(0.2),
                            ),
                          ),
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: primaryColor.withOpacity(0.8),
                                child: Text(
                                  doctor['name'][0].toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Dr. ${doctor['name']} ${doctor['surname'] ?? ''}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: textColor1,
                                ),
                              ),
                              SizedBox(width: 4),
                              InkWell(
                                onTap: () => _toggleDoctorSelection(doctor),
                                borderRadius: BorderRadius.circular(50),
                                child: Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Doktor listesi başlığı
          Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Eklenebilecek Doktorlar',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColor1,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_filteredDoctors.length}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textColor2,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Doktorlar listesi
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Doktorlar yükleniyor...',
                          style: TextStyle(
                            color: textColor2,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  )
                : _filteredDoctors.isEmpty
                    ? Center(
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
                              'Eklenebilecek doktor bulunamadı',
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
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: _filteredDoctors.length,
                        physics: BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final doctor = _filteredDoctors[index];
                          final isSelected = _selectedDoctors
                              .any((d) => d['id'] == doctor['id']);

                          return AnimatedContainer(
                            duration: Duration(milliseconds: 300),
                            margin: EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryColor.withOpacity(0.08)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                onTap: () => _toggleDoctorSelection(doctor),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      // Avatar
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
                                          backgroundColor: isSelected
                                              ? primaryColor
                                              : primaryColorLight,
                                          child: Text(
                                            doctor['name'][0].toUpperCase(),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 16),

                                      // Doctor info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Dr. ${doctor['name']} ${doctor['surname'] ?? ''}',
                                              style: TextStyle(
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                                fontSize: 16,
                                                color: textColor1,
                                              ),
                                            ),
                                            if (doctor['specialty'] !=
                                                null) ...[
                                              SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .medical_services_outlined,
                                                    size: 14,
                                                    color: secondaryColor
                                                        .withOpacity(0.8),
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
                                            ],
                                          ],
                                        ),
                                      ),

                                      // Selection indicator
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected
                                              ? primaryColor.withOpacity(0.1)
                                              : Colors.grey.shade100,
                                          border: Border.all(
                                            color: isSelected
                                                ? primaryColor
                                                : Colors.grey.shade300,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.all(2),
                                          child: isSelected
                                              ? Icon(
                                                  Icons.check,
                                                  color: primaryColor,
                                                  size: 20,
                                                )
                                              : SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: _selectedDoctors.isNotEmpty && !_isAdding
          ? Container(
              margin: EdgeInsets.only(bottom: 16),
              child: FloatingActionButton.extended(
                heroTag: 'add_members_button',
                onPressed: _addMembers,
                backgroundColor: successColor,
                elevation: 4,
                highlightElevation: 8,
                icon: Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 24,
                ),
                label: Row(
                  children: [
                    Text(
                      'Üyeleri Ekle',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (_selectedDoctors.isNotEmpty)
                      Container(
                        margin: EdgeInsets.only(left: 8),
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_selectedDoctors.length}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                extendedPadding: EdgeInsets.symmetric(horizontal: 20),
              ),
            )
          : _isAdding
              ? Container(
                  margin: EdgeInsets.only(bottom: 16),
                  child: FloatingActionButton.extended(
                    heroTag: 'adding_members_button',
                    onPressed: null,
                    backgroundColor: successColor.withOpacity(0.7),
                    elevation: 0,
                    icon: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    label: Text(
                      'Ekleniyor...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
