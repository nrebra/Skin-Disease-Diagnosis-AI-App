import 'package:flutter/material.dart';
import 'package:skincancer/pages/OnBoarding/on_boarding_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skincancer/pages/ControllerPage.dart';
import 'package:skincancer/pages/chat/PatientControllerPage.dart';
import 'package:skincancer/pages/auth/LoginPage.dart';

class BeginScreen extends StatefulWidget {
  @override
  _BeginScreenState createState() => _BeginScreenState();
}

class _BeginScreenState extends State<BeginScreen> {
  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
    final token = prefs.getString('token');
    final userRole = prefs.getString('user_role');
    final userName = prefs.getString('user_name');

    if (!isFirstLaunch) {
      // İlk kurulum değilse ve kullanıcı giriş yapmışsa direkt ana sayfaya yönlendir
      if (token != null && userRole != null && userName != null) {
        if (!mounted) return;

        if (userRole == 'doctor') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ControllerPage(userName: userName),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PatientControllerPage(userName: userName),
            ),
          );
        }
      } else {
        // İlk kurulum değilse ve kullanıcı giriş yapmamışsa LoginScreen sayfasına yönlendir
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LoginScreen(),
          ),
        );
      }
    } else {
      // İlk kurulumsa OnBoarding sayfasına yönlendir
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OnBoarding(),
        ),
      );
      // Flag'i false yap
      await prefs.setBool('isFirstLaunch', false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/skin_cancer_img.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            color: Colors.teal.withOpacity(0.7),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.accessibility,
                  color: Colors.white,
                  size: 100,
                ),
                const SizedBox(height: 20),
                const Text(
                  "SMARTDERM",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 35,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 70),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OnBoarding(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white70,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 80, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: const Text(
                  'Sağlıklı bir cilt için her şey..',
                  style: TextStyle(color: Color.fromARGB(255, 4, 58, 80)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
