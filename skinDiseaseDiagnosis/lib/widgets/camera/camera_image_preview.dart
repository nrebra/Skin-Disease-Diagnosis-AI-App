import 'package:flutter/material.dart';
import 'dart:io';
import '../../style/color.dart';

class CameraImagePreview extends StatelessWidget {
  final File imageFile;
  final bool isAnalyzing;
  final VoidCallback onAnalyzePressed;

  const CameraImagePreview({
    Key? key,
    required this.imageFile,
    required this.isAnalyzing,
    required this.onAnalyzePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            child: Container(
              width: double.infinity,
              child: Image.file(
                imageFile,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        SizedBox(height: 10),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 0),
          child: isAnalyzing
              ? _buildLoadingIndicator()
              : _buildAnalyzeButton(onAnalyzePressed),
        ),
        SizedBox(height: 60),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return Column(
      children: [
        CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor)),
        SizedBox(height: 16),
        Text(
          'Fotoğraf analiz ediliyor...',
          style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
        ),
        SizedBox(height: 8),
        Text(
          'Bu işlem birkaç saniye sürebilir',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildAnalyzeButton(VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        minimumSize: Size(double.infinity, 55),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, color: Colors.white, size: 25),
          SizedBox(width: 15),
          Text(
            'Tanı Analizi Yap',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
