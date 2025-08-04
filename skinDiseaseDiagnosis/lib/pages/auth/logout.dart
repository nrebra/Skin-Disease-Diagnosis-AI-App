import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../service/api_service.dart';

class LogoutPage extends StatefulWidget {
  @override
  _LogoutPageState createState() => _LogoutPageState();
}

class _LogoutPageState extends State<LogoutPage> {
  @override
  void initState() {
    super.initState();
    logout();
  }

  Future<void> logout() async {
    try {
      final apiService = ApiService();
      apiService.setToken(null);

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Çıkış yapılırken hata oluştu: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
