import 'package:flutter/material.dart';
import '../../style/color.dart';

class DiagnosisResultDialog extends StatelessWidget {
  final Map<String, dynamic> result;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const DiagnosisResultDialog({
    Key? key,
    required this.result,
    required this.onSave,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final confidence =
        result['predicted_confidence']?.toStringAsFixed(1) ?? '0';
    final diagnosis = result['predicted_class'] ?? 'Bilinmiyor';

    // Define risk level based on confidence
    String riskLevel = "Düşük Risk";
    Color riskColor = Colors.green;

    if (confidence.contains('Malignant') || confidence.contains('melanoma')) {
      riskLevel = "Yüksek Risk";
      riskColor = Colors.red;
    } else if (double.parse(confidence) > 70) {
      riskLevel = "Orta Risk";
      riskColor = Colors.orange;
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Center(
        child: Text(
          'Analiz Sonucu',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: riskColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: riskColor.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Text(
                  diagnosis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: riskColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  riskLevel,
                  style: TextStyle(
                    fontSize: 16,
                    color: riskColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.analytics_outlined, color: primaryColor),
              SizedBox(width: 8),
              Text(
                'Güven Oranı:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 5),
          Container(
            width: double.infinity,
            height: 25,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade200,
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: double.parse(confidence) / 100,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor.withOpacity(0.7), primaryColor],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    '%$confidence',
                    style: TextStyle(
                      color: double.parse(confidence) > 50
                          ? Colors.white
                          : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Bu sonucu hasta kaydına eklemek istiyor musunuz?',
            style: TextStyle(fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: Text(
            'İptal',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
        ElevatedButton(
          onPressed: onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text('Kaydet'),
          ),
        ),
      ],
    );
  }

  static void show(BuildContext context, Map<String, dynamic> result,
      VoidCallback onSave, VoidCallback onCancel) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DiagnosisResultDialog(
        result: result,
        onSave: onSave,
        onCancel: onCancel,
      ),
    );
  }
}
