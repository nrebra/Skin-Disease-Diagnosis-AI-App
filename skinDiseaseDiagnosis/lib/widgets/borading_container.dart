import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../style/color.dart';

class BeginContainer extends StatelessWidget {
  String title;
  String LottieTitle;
  BeginContainer(this.title, this.LottieTitle, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(20)),
                height: 250,
                width: 250,
                child: Lottie.asset(LottieTitle, fit: BoxFit.fill),
              ),
            ), 
            Text(
              textAlign: TextAlign.center,
              title,
              style:  TextStyle(
                  fontSize: 20, color: Colors.grey.shade800, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }
}