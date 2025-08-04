import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../provider/post_provider.dart';
import '../../service/api_service.dart';
import '../../style/color.dart';
import '../../service/community_service.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({Key? key}) : super(key: key);

  @override
  _CreatePostPageState createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController messageController = TextEditingController();
  final ApiService _apiService = ApiService();
  final FocusNode _focusNode = FocusNode();
  late final CommunityService _communityService;

  File? _selectedImage;
  bool _isSubmitting = false;
  bool _isExpanded = false;
  String _doctorName = "Dr. ...";
  String _doctorId = "1";
  AnimationController? _animationController;
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();
    _communityService = CommunityService(context);
    _loadUserInfo();

    // Token kontrolü yap
    _checkAndInitializeToken();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
        if (mounted) setState(() {});
      });

    _animation = CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    );

    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && _isExpanded) {
      setState(() => _isExpanded = false);
      _animationController!.reverse();
    }
  }

  Future<void> _loadUserInfo() async {
    try {
      final apiService = ApiService();
      final profileResult = await apiService.getUserProfile();

      if (profileResult['success']) {
        final userData = profileResult['data'];
        if (mounted) {
          setState(() {
            _doctorName = userData['role'] == 'doctor'
                ? "Dr. ${userData['name']} ${userData['surname']}"
                : "${userData['name']} ${userData['surname']}";
            _doctorId = userData['id'].toString();
          });
        }
      } else {
        // Hata durumunda SharedPreferences'tan oku (yedek)
        final prefs = await SharedPreferences.getInstance();
        final name = prefs.getString('user_name');
        final id = prefs.getString('user_id');
        if (mounted) {
          setState(() {
            _doctorName = name != null ? "Dr. $name" : "Dr. ...";
            _doctorId = id ?? "1";
          });
        }
      }
    } catch (e) {
      print('Kullanıcı bilgileri yüklenirken hata: $e');
      // Hata durumunda SharedPreferences'tan oku (yedek)
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('user_name');
      final id = prefs.getString('user_id');
      if (mounted) {
        setState(() {
          _doctorName = name != null ? "Dr. $name" : "Dr. ...";
          _doctorId = id ?? "1";
        });
      }
    }
  }

  Future<void> _checkAndInitializeToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final email = prefs.getString('user_email');
      final password = prefs.getString('user_password');

      if (token == null && email != null && password != null) {
        print('CreatePostPage - Token yok, yeniden giriş yapılıyor...');
        final apiService = ApiService();
        try {
          final loginResponse = await apiService.login(email, password);
          if (loginResponse['success']) {
            print('CreatePostPage - Yeniden giriş başarılı');
            return;
          }
        } catch (e) {
          print('CreatePostPage - Giriş hatası: $e');
          _showLoginError();
        }
      }
    } catch (e) {
      print('CreatePostPage - Token kontrolü hatası: $e');
      _showLoginError();
    }
  }

  void _showLoginError() {
    if (!mounted) return;
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

  void _toggleImageOptions() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _animationController!.forward();
    } else {
      _animationController!.reverse();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() {
        _isSubmitting = true;
        _isExpanded = false;
      });
      _animationController!.reverse();

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Resim seçilirken hata oluştu', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSnackBar(String message,
      {bool isError = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline
                  : isSuccess
                      ? Icons.check_circle
                      : Icons.info_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError
            ? Colors.red.shade700
            : isSuccess
                ? successColor
                : primaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _createPost() async {
    // Haptic feedback
    HapticFeedback.mediumImpact();

    if (_isSubmitting) return;

    if (messageController.text.trim().isEmpty && _selectedImage == null) {
      _showSnackBar('Lütfen bir içerik veya fotoğraf ekleyin', isError: true);
      return;
    }

    try {
      setState(() => _isSubmitting = true);

      // _doctorId'nin null olup olmadığını kontrol et
      String doctorId = _doctorId.isNotEmpty ? _doctorId : "1";

      // Post oluştur
      final success = await context.read<PostProvider>().addPost(
            messageController.text,
            doctorId,
            image: _selectedImage,
          );

      if (!mounted) return;

      if (success) {
        Navigator.pop(context);
      } else {
        final error = context.read<PostProvider>().error;
        _showSnackBar(error ?? 'Gönderi oluşturulurken bir hata oluştu',
            isError: true);
      }
    } catch (e) {
      print('CreatePostPage - Post oluşturma hatası: $e');
      if (!mounted) return;

      _showSnackBar('Gönderi oluşturulurken bir hata oluştu: ${e.toString()}',
          isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isSubmitting) return false;
        if (_isExpanded) {
          _toggleImageOptions();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: _buildAppBar(),
        body: _buildBody(),
        resizeToAvoidBottomInset: true,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      centerTitle: true,
      title: Text(
        'Yeni Gönderi',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: textColor1,
          fontSize: 18,
        ),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: primaryColor, size: 22),
        onPressed: _isSubmitting ? null : () => Navigator.pop(context),
        splashRadius: 24,
      ),
      actions: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isSubmitting
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: TextButton(
                    onPressed: _createPost,
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, primaryColorLight],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Paylaş',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        // Main content
        Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUserInfoSection(),
                      const SizedBox(height: 24),
                      _buildMessageField(),
                      const SizedBox(height: 20),
                      if (_selectedImage != null) _buildImagePreview(),
                      SizedBox(height: _isExpanded ? 120 : 80),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        // Bottom image options bar
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildBottomBar(),
        ),

        // Loading overlay
        if (_isSubmitting) _buildLoadingOverlay(),
      ],
    );
  }

  Widget _buildUserInfoSection() {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: secondaryColor.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 24,
            backgroundColor: backgroundColor2.withOpacity(0.3),
            child: Icon(Icons.person, color: secondaryColorLight, size: 24),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _doctorName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textColor1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: secondaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Şimdi paylaşılıyor',
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageField() {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: messageController,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: 'Ne düşünüyorsunuz?',
          border: InputBorder.none,
          hintStyle: TextStyle(
            color: textColor2.withOpacity(0.6),
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        style: TextStyle(
          fontSize: 16,
          color: textColor1,
          height: 1.5,
        ),
        maxLines: null,
        minLines: 5,
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              _selectedImage!,
              height: 300,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: InkWell(
              onTap: () => setState(() => _selectedImage = null),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: _isSubmitting ? null : _toggleImageOptions,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: secondaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              color: secondaryColor,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Fotoğraf ekle',
                              style: TextStyle(
                                color: secondaryColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizeTransition(
                  sizeFactor: _animation!,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildImageOptionButton(
                          icon: Icons.photo_library_rounded,
                          label: 'Galeri',
                          onTap: () => _pickImage(ImageSource.gallery),
                          color: galleryColor,
                        ),
                        _buildImageOptionButton(
                          icon: Icons.camera_alt_rounded,
                          label: 'Kamera',
                          onTap: () => _pickImage(ImageSource.camera),
                          color: cameraColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isSubmitting ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Gönderi paylaşılıyor...',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textColor1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    messageController.dispose();
    _animationController!.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
