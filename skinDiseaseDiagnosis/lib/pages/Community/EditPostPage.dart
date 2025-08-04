import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../provider/post_provider.dart';
import '../../style/color.dart';
import '../../service/api_service.dart';
import '../../service/community_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditPostPage extends StatefulWidget {
  final String postId;
  final String currentContent;
  final String? currentImageUrl;

  const EditPostPage({
    Key? key,
    required this.postId,
    required this.currentContent,
    this.currentImageUrl,
  }) : super(key: key);

  @override
  _EditPostPageState createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage>
    with SingleTickerProviderStateMixin {
  late TextEditingController _contentController;
  late final CommunityService _communityService;
  File? _selectedImage;
  bool _isSubmitting = false;
  bool _keepCurrentImage = true;
  bool _isExpanded = false;
  final FocusNode _focusNode = FocusNode();
  String _doctorName = "Dr. ...";
  String? _currentDoctorId;

  // Animation for the bottom menu
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.currentContent);
    _communityService = CommunityService(context);

    // Token kontrolü yap
    _checkAndInitializeToken();

    // Doktor bilgilerini yükle
    _loadDoctorInfo();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    // Start animation
    _animationController.forward();

    _focusNode.addListener(_onFocusChange);

    // Log initial state
    print('EditPostPage initialized with postId: ${widget.postId}');
    print('Current image URL: ${widget.currentImageUrl}');
  }

  Future<void> _checkAndInitializeToken() async {
    try {
      final apiService = ApiService();
      await apiService.initialize();
      String? token = await apiService.getToken();

      if (token == null) {
        final prefs = await SharedPreferences.getInstance();
        final email = prefs.getString('user_email');
        final password = prefs.getString('user_password');

        if (email != null && password != null) {
          print('EditPostPage - Token yok, yeniden giriş yapılıyor...');
          final loginResponse = await apiService.login(email, password);
          if (!loginResponse['success']) {
            throw Exception('Yeniden giriş başarısız');
          }
          print('EditPostPage - Yeniden giriş başarılı');
        } else {
          throw Exception('Oturum bilgileri bulunamadı');
        }
      }
    } catch (e) {
      print('EditPostPage - Token kontrolü hatası: $e');
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

  // Doktor bilgilerini yükle
  Future<void> _loadDoctorInfo() async {
    try {
      _currentDoctorId = await _communityService.getCurrentDoctorId();
      if (_currentDoctorId != null) {
        final doctorInfo =
            await _communityService.getDoctorInfo(_currentDoctorId);

        if (mounted) {
          setState(() {
            if (doctorInfo.containsKey('name') && doctorInfo['name'] != null) {
              _doctorName = "Dr. ${doctorInfo['name']}";
            } else {
              _doctorName = "Dr. ${_currentDoctorId!}";
            }
          });
        }
      }
    } catch (e) {
      print('Doktor bilgisi yüklenirken hata: $e');
      if (mounted && _currentDoctorId != null) {
        setState(() {
          _doctorName = "Dr. ${_currentDoctorId!}";
        });
      }
    }
  }

  void _toggleImageOptions() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    File? selectedImage = await _communityService.pickImage(
      source,
      setLoading: (loading) {
        setState(() {
          _isSubmitting = loading;
        });
      },
    );

    if (selectedImage != null) {
      setState(() {
        _selectedImage = selectedImage;
        _keepCurrentImage = false;
        _isExpanded = false;
      });
    }
  }

  Future<void> _updatePost() async {
    // Haptic feedback
    HapticFeedback.mediumImpact();

    if (_isSubmitting) return;

    // İçerik ve resim kontrolü
    if (_contentController.text.trim().isEmpty &&
        !_keepCurrentImage &&
        _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lütfen bir içerik girin veya resim seçin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() => _isSubmitting = true);

      // Token kontrolü ve yenileme
      await _checkAndInitializeToken();

      print('Güncelleme başlatılıyor...');
      print('Seçili resim: ${_selectedImage?.path ?? 'Yok'}');
      print('Mevcut resmi koru: $_keepCurrentImage');

      // Post güncelleme işlemi
      bool success = await _communityService.updatePost(
        widget.postId,
        _contentController.text,
        image: _selectedImage,
        keepCurrentImage: _keepCurrentImage,
        setLoading: (loading) {
          if (mounted) {
            setState(() => _isSubmitting = loading);
          }
        },
      );

      if (success && mounted) {
        // Provider'ı güncelle
        await Provider.of<PostProvider>(context, listen: false).fetchPosts();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gönderi başarıyla güncellendi'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      print('EditPostPage - Post güncelleme hatası: $e');
      if (!mounted) return;

      if (e.toString().contains('Token') ||
          e.toString().contains('oturum') ||
          e.toString().contains('giriş')) {
        _showLoginError();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Gönderi güncellenirken bir hata oluştu: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
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
        _showDiscardDialog(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: Colors.black87),
            onPressed: _isSubmitting ? null : () => _showDiscardDialog(context),
          ),
          centerTitle: true,
          title: Text(
            'Yeni Gönderi',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              fontSize: 18,
            ),
          ),
          actions: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _updatePost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF3C8589),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Text(
                  'Paylaş',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUserInfoSection(),

                  // Metin girişi
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _contentController,
                      focusNode: _focusNode,
                      decoration: InputDecoration.collapsed(
                        hintText: 'Ne düşünüyorsunuz?',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 16,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                      maxLines: null,
                      minLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),

                  // Görsel önizleme
                  if (_selectedImage != null ||
                      (_keepCurrentImage && widget.currentImageUrl != null))
                    _buildImagePreview(),

                  SizedBox(height: 350),
                ],
              ),
            ),

            // Fotoğraf ekleme butonu
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                                color: Color(0xFFF5E1E5),
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
                          padding:
                              const EdgeInsets.only(top: 16.0, bottom: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _communityService.buildImageOptionButton(
                                icon: Icons.photo_library_rounded,
                                label: 'Galeri',
                                onTap: () => _pickImage(ImageSource.gallery),
                                color: galleryColor,
                                isSubmitting: _isSubmitting,
                              ),
                              _communityService.buildImageOptionButton(
                                icon: Icons.camera_alt_rounded,
                                label: 'Kamera',
                                onTap: () => _pickImage(ImageSource.camera),
                                color: cameraColor,
                                isSubmitting: _isSubmitting,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Yükleniyor göstergesi
            if (_isSubmitting)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF3C8589)),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Gönderi güncelleniyor...',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
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
          SizedBox(width: 12),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
      ),
    );
  }

  Widget _buildImagePreview() {
    if (widget.currentImageUrl != null && _keepCurrentImage) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade200,
              ),
              clipBehavior: Clip.antiAlias,
              child: FutureBuilder<Map<String, String>>(
                future: _communityService.getAuthHeaders(),
                builder: (context, snapshot) {
                  final headers = snapshot.data ?? {};

                  // URL formatı
                  String imageUrl;
                  if (widget.currentImageUrl == null ||
                      widget.currentImageUrl!.isEmpty) {
                    imageUrl = '${ApiService.baseUrl}/uploads/placeholder.jpg';
                  } else if (widget.currentImageUrl!.startsWith('http')) {
                    imageUrl = widget.currentImageUrl!;
                  } else if (widget.currentImageUrl!.startsWith('/')) {
                    imageUrl = ApiService.baseUrl + widget.currentImageUrl!;
                  } else if (widget.currentImageUrl!.startsWith('uploads/')) {
                    imageUrl =
                        '${ApiService.baseUrl}/${widget.currentImageUrl!}';
                  } else {
                    imageUrl =
                        '${ApiService.baseUrl}/uploads/${widget.currentImageUrl!}';
                  }

                  return Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    headers: headers,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF3C8589)),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.grey.shade400,
                              size: 32,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Resim yüklenemedi',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: InkWell(
                onTap: () => setState(() => _keepCurrentImage = false),
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (_selectedImage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade200,
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.file(
                _selectedImage!,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: InkWell(
                onTap: () => setState(() => _selectedImage = null),
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return SizedBox.shrink();
    }
  }

  void _showDiscardDialog(BuildContext context) {
    _communityService.showDiscardPostDialog(context);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && _isExpanded) {
      setState(() => _isExpanded = false);
      _animationController.reverse();
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}
