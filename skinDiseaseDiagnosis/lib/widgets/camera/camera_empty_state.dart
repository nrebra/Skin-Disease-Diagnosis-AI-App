import 'package:flutter/material.dart';
import '../../style/color.dart';

class CameraEmptyState extends StatelessWidget {
  const CameraEmptyState({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.add_photo_alternate_rounded,
              size: 80,
              color: primaryColor,
            ),
          ),
          SizedBox(height: 30),
          Text(
            'Cilt Analizi Yapın',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Analizini yapmak istediğiniz cilt bölgesinin\nnet bir fotoğrafını yükleyin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          SizedBox(height: 40),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: backgroundColor2,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: primaryColorLight),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: secondaryColor),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'İyi ışık koşullarında ve yakın çekim yapmanız daha doğru sonuç almanızı sağlar.',
                    style: TextStyle(color: textColor1),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }
}
