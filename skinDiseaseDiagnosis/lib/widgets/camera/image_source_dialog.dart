import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../style/color.dart';

class ImageSourceDialog extends StatelessWidget {
  final Function(ImageSource) onSourceSelected;

  const ImageSourceDialog({
    Key? key,
    required this.onSourceSelected,
  }) : super(key: key);

  static void show(
      BuildContext context, Function(ImageSource) onSourceSelected) {
    showDialog(
      context: context,
      builder: (context) => ImageSourceDialog(
        onSourceSelected: onSourceSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      title: Text(
        'Fotoğraf Kaynağı',
        style: TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.camera_alt, color: primaryColor),
            title: Text('Kamera'),
            onTap: () {
              Navigator.pop(context);
              onSourceSelected(ImageSource.camera);
            },
          ),
          ListTile(
            leading: Icon(Icons.photo_library, color: primaryColor),
            title: Text('Galeri'),
            onTap: () {
              Navigator.pop(context);
              onSourceSelected(ImageSource.gallery);
            },
          ),
        ],
      ),
    );
  }
}
