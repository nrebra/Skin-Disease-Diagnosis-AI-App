import 'package:flutter/material.dart';
import 'package:skincancer/style/color.dart';
import 'package:skincancer/service/authService.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:skincancer/style/color.dart';
import 'package:skincancer/service/auth_helper.dart';
import '../../widgets/profile/LogoutButton.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  final _authService = AuthService();
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshUserData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sayfa her görünür olduğunda verileri yenile
    _loadUserData();
  }

  Future<void> refreshUserData() async {
    setState(() => isLoading = true);
    await fetchUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);
    await fetchUserData();
  }

  Future<void> fetchUserData() async {
    try {
      final result = await _authService.getUserProfile();

      if (result['success']) {
        if (mounted) {
          setState(() {
            userData = result['data'];
            isLoading = false;
          });
        }
      } else {
        print('Profil bilgileri alınamadı: ${result['message']}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'])),
          );
          setState(() => isLoading = false);
        }
      }
    } catch (e) {
      print('Profil bilgileri alınamadı: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil bilgileri alınamadı: $e')),
        );
        setState(() => isLoading = false);
      }
    }
  }

  void _showEditProfileDialog() {
    final TextEditingController nameController =
        TextEditingController(text: userData?['name']);
    final TextEditingController surnameController =
        TextEditingController(text: userData?['surname']);
    final TextEditingController phoneController =
        TextEditingController(text: userData?['phone']);
    final TextEditingController ageController =
        TextEditingController(text: userData?['age'].toString());
    final TextEditingController genderController =
        TextEditingController(text: userData?['gender']);

    // Doktor için ek kontrolcüler
    final TextEditingController experienceController =
        TextEditingController(text: userData?['experience']);
    final TextEditingController expertController =
        TextEditingController(text: userData?['expert']);
    final TextEditingController clinicController =
        TextEditingController(text: userData?['clinic']);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.edit_rounded,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Profili Düzenle',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Kişisel Bilgiler'),
                      _buildTextField(
                        controller: nameController,
                        label: 'Ad',
                        icon: Icons.person_outline,
                      ),
                      _buildTextField(
                        controller: surnameController,
                        label: 'Soyad',
                        icon: Icons.person_outline,
                      ),
                      _buildTextField(
                        controller: phoneController,
                        label: 'Telefon',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      _buildTextField(
                        controller: ageController,
                        label: 'Yaş',
                        icon: Icons.cake_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      _buildTextField(
                        controller: genderController,
                        label: 'Cinsiyet',
                        icon: Icons.wc_outlined,
                      ),
                      if (userData?['role']?.toLowerCase() == 'doctor') ...[
                        const SizedBox(height: 16),
                        _buildSectionTitle('Mesleki Bilgiler'),
                        _buildTextField(
                          controller: experienceController,
                          label: 'Tecrübe',
                          icon: Icons.work_outline,
                        ),
                        _buildTextField(
                          controller: expertController,
                          label: 'Uzmanlık',
                          icon: Icons.medical_services_outlined,
                        ),
                        _buildTextField(
                          controller: clinicController,
                          label: 'Klinik',
                          icon: Icons.local_hospital_outlined,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(
                    top: BorderSide(
                      color: Colors.grey[200]!,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        'İptal',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        // Güncelleme verilerini hazırla
                        Map<String, dynamic> updateData = {
                          'name': nameController.text,
                          'surname': surnameController.text,
                          'phone': phoneController.text,
                          'age': int.tryParse(ageController.text) ??
                              userData?['age'],
                          'gender': genderController.text,
                        };

                        // Doktor ise ek alanları ekle
                        if (userData?['role']?.toLowerCase() == 'doctor') {
                          updateData.addAll({
                            'experience': experienceController.text,
                            'expert': expertController.text,
                            'clinic': clinicController.text,
                            'status': userData?['status'], // Mevcut durumu koru
                          });
                        }

                        // Güncelleme isteğini gönder
                        final result =
                            await _authService.updateProfile(updateData);

                        if (!mounted) return;
                        Navigator.pop(context); // Dialog'u kapat

                        // Sonucu göster
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result['message']),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor:
                                result['success'] ? Colors.green : Colors.red,
                          ),
                        );

                        // Başarılı ise profili yenile
                        if (result['success']) {
                          fetchUserData();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Kaydet',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          color: primaryColor,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey[300]!,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey[300]!,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: primaryColor,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: primaryColor,
            strokeWidth: 3,
          ),
        ),
      );
    }

    return userData?['role']?.toLowerCase() == 'doctor'
        ? _buildDoctorProfile()
        : _buildPatientProfile();
  }

  // Doktor profil sayfası (modernleştirilmiş tasarım)
  Widget _buildDoctorProfile() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: refreshUserData,
        color: primaryColor,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverAppBar(isDoctor: true),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildDoctorStatusCards(),
                    const SizedBox(height: 24),
                    _buildProfileSection(
                      title: 'Kişisel Bilgiler',
                      icon: Icons.person_rounded,
                      children: [
                        _buildInfoRow(
                          icon: Icons.account_circle_rounded,
                          title: 'Ad Soyad',
                          value:
                              'Dr. ${userData?['name']} ${userData?['surname']}',
                        ),
                        _buildDivider(),
                        _buildInfoRow(
                          icon: Icons.fingerprint_rounded,
                          title: 'T.C. Kimlik No',
                          value: userData?['tcid'] ?? '',
                        ),
                        _buildDivider(),
                        _buildInfoRow(
                          icon: Icons.cake_rounded,
                          title: 'Yaş',
                          value: '${userData?['age']}',
                        ),
                        _buildDivider(),
                        _buildInfoRow(
                          icon: Icons.wc_rounded,
                          title: 'Cinsiyet',
                          value: userData?['gender'] ?? '',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildProfileSection(
                      title: 'İletişim Bilgileri',
                      icon: Icons.contact_mail_rounded,
                      children: [
                        _buildInfoRow(
                          icon: Icons.email_rounded,
                          title: 'E-posta',
                          value: userData?['email'] ?? '',
                          isAction: true,
                        ),
                        _buildDivider(),
                        _buildInfoRow(
                          icon: Icons.phone_rounded,
                          title: 'Telefon',
                          value: userData?['phone'] ?? '',
                          isAction: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildProfileSection(
                      title: 'Klinik Bilgileri',
                      icon: Icons.local_hospital_rounded,
                      children: [
                        _buildInfoRow(
                          icon: Icons.medical_services_rounded,
                          title: 'Uzmanlık Alanı',
                          value: userData?['expert'] ?? '',
                        ),
                        _buildDivider(),
                        _buildInfoRow(
                          icon: Icons.timeline_rounded,
                          title: 'Tecrübe',
                          value: userData?['experience'] ?? '',
                        ),
                        _buildDivider(),
                        _buildInfoRow(
                          icon: Icons.business_rounded,
                          title: 'Klinik',
                          value: userData?['clinic'] ?? '',
                        ),
                        _buildDivider(),
                        _buildInfoRow(
                          icon: Icons.verified_user_rounded,
                          title: 'Durum',
                          value: userData?['status'] ?? '',
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const LogoutButton(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Hasta profil sayfası (modernleştirilmiş tasarım)
  Widget _buildPatientProfile() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: refreshUserData,
        color: primaryColor,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverAppBar(isDoctor: false),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildPatientStatusCards(),
                    const SizedBox(height: 24),
                    _buildProfileSection(
                      title: 'Kişisel Bilgiler',
                      icon: Icons.person_rounded,
                      children: [
                        _buildInfoRow(
                          icon: Icons.account_circle_rounded,
                          title: 'Ad Soyad',
                          value: '${userData?['name']} ${userData?['surname']}',
                        ),
                        _buildDivider(),
                        _buildInfoRow(
                          icon: Icons.fingerprint_rounded,
                          title: 'T.C. Kimlik No',
                          value: userData?['tcid'] ?? '',
                        ),
                        _buildDivider(),
                        _buildInfoRow(
                          icon: Icons.cake_rounded,
                          title: 'Yaş',
                          value: '${userData?['age']}',
                        ),
                        _buildDivider(),
                        _buildInfoRow(
                          icon: Icons.wc_rounded,
                          title: 'Cinsiyet',
                          value: userData?['gender'] ?? '',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildProfileSection(
                      title: 'İletişim Bilgileri',
                      icon: Icons.contact_mail_rounded,
                      children: [
                        _buildInfoRow(
                          icon: Icons.email_rounded,
                          title: 'E-posta',
                          value: userData?['email'] ?? '',
                          isAction: true,
                        ),
                        _buildDivider(),
                        _buildInfoRow(
                          icon: Icons.phone_rounded,
                          title: 'Telefon',
                          value: userData?['phone'] ?? '',
                          isAction: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const LogoutButton(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar({required bool isDoctor}) {
    return SliverAppBar(
      expandedHeight: isDoctor ? 260 : 230,
      pinned: true,
      backgroundColor: primaryColor,
      elevation: 0,
      stretch: true,
      actions: [
        IconButton(
          onPressed: _showEditProfileDialog,
          icon: const Icon(
            Icons.edit_rounded,
            color: Colors.white,
          ),
          tooltip: 'Profili Düzenle',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor,
                primaryColor.withOpacity(0.8),
                primaryColor.withOpacity(0.6),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Decorative elements
              Positioned(
                top: -30,
                left: -30,
                child: Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                right: -20,
                child: Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Profile content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    _buildEnhancedProfileImage(),
                    const SizedBox(height: 16),
                    Text(
                      isDoctor
                          ? 'Dr. ${userData?['name']} ${userData?['surname']}'
                          : '${userData?['name']} ${userData?['surname']}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    if (isDoctor) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          userData?['expert'] ?? 'Uzman Doktor',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedProfileImage() {
    // Avatar with initials or image
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.white.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 50,
        backgroundColor: Colors.transparent,
        child: Text(
          userData?['name']?.substring(0, 1).toUpperCase() ?? 'U',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorStatusCards() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatusItem(
            title: 'Durum',
            value: userData?['status'] ?? '-',
            color: primaryColor,
            icon: Icons.verified_user_rounded,
          ),
          _buildVerticalDivider(),
          _buildStatusItem(
            title: 'Tecrübe',
            value: userData?['experience'] ?? '-',
            color: secondaryColor,
            icon: Icons.workspace_premium_rounded,
          ),
          _buildVerticalDivider(),
          _buildStatusItem(
            title: 'Uzmanlık',
            value: userData?['expert'] ?? '-',
            color: const Color(0xFFFF8800),
            icon: Icons.medical_services_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildPatientStatusCards() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatusItem(
            title: 'T.C. Kimlik No',
            value: userData?['tcid'] ?? '-',
            color: primaryColor,
            icon: Icons.fingerprint_rounded,
          ),
          _buildVerticalDivider(),
          _buildStatusItem(
            title: 'Yaş',
            value: '${userData?['age'] ?? '-'}',
            color: secondaryColor,
            icon: Icons.cake_rounded,
          ),
          _buildVerticalDivider(),
          _buildStatusItem(
            title: 'Cinsiyet',
            value: userData?['gender'] ?? '-',
            color: textColor1,
            icon: Icons.wc_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey.withOpacity(0.3),
    );
  }

  Widget _buildProfileSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: primaryColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    bool isAction = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 12.0,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: primaryColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (isAction)
            IconButton(
              onPressed: () {},
              icon: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey[400],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        color: Colors.grey.withOpacity(0.2),
        height: 1,
      ),
    );
  }
}
