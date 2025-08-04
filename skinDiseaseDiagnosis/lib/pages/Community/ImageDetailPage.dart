import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:skincancer/service/api_service.dart';

class ImageDetailPage extends StatefulWidget {
  final String imageUrl;

  const ImageDetailPage({
    Key? key,
    required this.imageUrl,
  }) : super(key: key);

  @override
  State<ImageDetailPage> createState() => _ImageDetailPageState();
}

class _ImageDetailPageState extends State<ImageDetailPage> {
  late final ApiService _apiService;
  String? _processedImageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _processImage();
  }

  Future<void> _processImage() async {
    try {
      final processedUrl = await _apiService.loadImage(widget.imageUrl);
      if (mounted) {
        setState(() {
          _processedImageUrl = processedUrl;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('ImageDetailPage - Görsel işleme hatası: $e');
      if (mounted) {
        setState(() {
          _processedImageUrl = widget.imageUrl;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: _isLoading
              ? CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                )
              : InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: _processedImageUrl ?? widget.imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    errorWidget: (context, url, error) {
                      print('ImageDetailPage - Resim yükleme hatası: $error');

                      // Token hatası durumunda yenileme dene
                      if (error.toString().contains('401') ||
                          error.toString().contains('unauthorized')) {
                        _apiService.initializeToken().then((_) {
                          if (mounted) {
                            _processImage(); // Token yeniledikten sonra görsel yüklemeyi tekrar dene
                          }
                        });
                      }

                      return Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }
}
