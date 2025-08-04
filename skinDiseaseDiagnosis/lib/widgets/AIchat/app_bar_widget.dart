import 'package:flutter/material.dart';
import 'package:skincancer/style/color.dart';

class AppBarWidget extends StatelessWidget {
  final VoidCallback onMenuPressed;
  final VoidCallback onMorePressed;

  const AppBarWidget({
    Key? key,
    required this.onMenuPressed,
    required this.onMorePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: Offset(0, 2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.menu),
            color: primaryColor,
            onPressed: onMenuPressed,
          ),
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.health_and_safety_outlined,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'AI Asistan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.more_vert),
            color: Colors.grey[700],
            onPressed: onMorePressed,
          ),
        ],
      ),
    );
  }
}
