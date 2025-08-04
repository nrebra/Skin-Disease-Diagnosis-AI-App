import 'package:flutter/material.dart';
import 'package:skincancer/pages/auth/LoginPage.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import 'package:skincancer/style/color.dart';
import 'package:skincancer/widgets/borading_container.dart';

class OnBoarding extends StatefulWidget {
  const OnBoarding({super.key});

  @override
  State<OnBoarding> createState() => _OnBoardingState();
}

class _OnBoardingState extends State<OnBoarding> {
  final PageController _controller = PageController();
  bool _LastPage = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        PageView(
          controller: _controller,
          onPageChanged: (value) {
            setState(() {
              _LastPage = (value == 2);
            });
          },
          children: [
            BeginContainer(
                "Tümörün İyi Huylu Veya Kötü Huylu Olup Olmadığını Elektronik Olarak Belirlemek",
                "assets/animation/animasyon1.json"),
            BeginContainer("Cilt Kanserinin Erken Tespiti Ve Beninizin Takibi.",
                "assets/animation/animasyon1.json"),
            BeginContainer(
                "O Zaman Haydi Başlıyalım", "assets/animation/animasyon1.json")
          ],
        ),
        Container(
          alignment: const Alignment(0, 0.7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GestureDetector(
                  onTap: () {
                    _controller.jumpToPage(2);
                  },
                  child: Text(
                    "Geç",
                    style: TextStyle(
                        color: secondaryColor,
                        fontSize: 20,
                        fontFamily: 'Schyler'),
                  )),
              SmoothPageIndicator(
                controller: _controller,
                count: 3,
                effect: WormEffect(activeDotColor: primaryColor),
              ),
              _LastPage
                  ? ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const LoginScreen()));
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor),
                      child: Text(
                        "Giriş Ekranı",
                        style: TextStyle(color: backgroundColor),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: () {
                        _controller.nextPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeIn);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor),
                      child: Text(
                        "Sonraki",
                        style: TextStyle(color: backgroundColor),
                      ),
                    )
            ],
          ),
        )
      ]),
    );
  }
}
