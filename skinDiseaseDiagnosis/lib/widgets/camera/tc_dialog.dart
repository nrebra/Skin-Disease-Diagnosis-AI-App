import 'package:flutter/material.dart';
import '../../style/color.dart';

class TcDialog extends StatelessWidget {
  final TextEditingController controller;
  final bool isSaving;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const TcDialog({
    Key? key,
    required this.controller,
    required this.isSaving,
    required this.onSave,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Center(
        child: Column(
          children: [
            Icon(Icons.person_pin_circle, size: 48, color: textColor1),
            SizedBox(height: 8),
            Text(
              'Hasta Kimlik Bilgisi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ],
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Teşhisi kaydetmek için hasta TC kimlik numarasını giriniz',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          SizedBox(height: 20),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 11,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, letterSpacing: 2),
            decoration: InputDecoration(
              labelText: 'TC Kimlik No',
              floatingLabelBehavior: FloatingLabelBehavior.auto,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: primaryColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
              prefixIcon: Icon(Icons.badge_outlined, color: primaryColor),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
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
          onPressed: isSaving ? null : onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade400,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: isSaving
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text('Kaydet'),
        ),
      ],
    );
  }

  static void show(BuildContext context, TextEditingController controller,
      bool isSaving, VoidCallback onSave, VoidCallback onCancel) {
    showDialog(
      context: context,
      builder: (context) => TcDialog(
        controller: controller,
        isSaving: isSaving,
        onSave: onSave,
        onCancel: onCancel,
      ),
    );
  }
}
