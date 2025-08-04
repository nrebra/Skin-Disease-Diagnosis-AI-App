import 'package:flutter/material.dart';

Widget bottomNavigatorButton(
    Function()? ontap,
    int index,
    int index2,
    IconData? icon,
    String title,
    ) {
  return MaterialButton(
    minWidth: 40,
    padding: EdgeInsets.zero,
    onPressed: ontap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (index == index2)
          Container(
            height: 35,
            width: 40,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.blue
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          )
        else
          Icon(
            icon,
            color: Colors.grey,
            size: 20,
          ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            title,
            style: TextStyle(
              color: index == index2 ? Colors.blue : Colors.grey,
              fontWeight: index == index2 ? FontWeight.bold : FontWeight.normal,
              fontSize: 10,
            ),
          ),
        ),
      ],
    ),
  );
}