import 'package:flutter/material.dart';
import 'package:skincancer/style/color.dart';
import 'package:skincancer/pages/ControllerPage.dart';
import 'package:skincancer/pages/chat/PatientControllerPage.dart';
import '../../service/authService.dart';
import '../../widgets/LogTextField.dart';
import 'SignupPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../service/api_service.dart';
import 'package:animate_do/animate_do.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  bool _isObscured = true;
  bool _isLoading = false;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _initializeApiService();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {


        final apiService = ApiService();
        final result = await apiService.login(
          _emailController.text.trim(),
          _passwordController.text,
        );



        if (result['success']) {
          final token = result['token'];
          final user = result['user'];



          // Token'ı ApiService'e kaydet
          apiService.setToken(token);


          // Token ve kullanıcı bilgilerini local storage'a kaydet
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', token);
          await prefs.setString('user_id', user['id'].toString());
          await prefs.setString('user_role', user['role']);
          await prefs.setString(
              'user_name', '${user['name']} ${user['surname']}');
          await prefs.setString('user_email', user['email']);
          await prefs.setString('user_tcid', user['tcid']);

          // Kullanıcı doktor ise status bilgisini de kaydet
          if (user['role'] == 'doctor' && user['status'] != null) {
            await prefs.setString('user_status', user['status']);

          }



          if (!mounted) return;

          // Kullanıcı rolüne göre yönlendirme
          if (user['role'] == 'doctor') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ControllerPage(
                  userName: '${user['name']} ${user['surname']}',
                ),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => PatientControllerPage(
                  userName: '${user['name']} ${user['surname']}',
                ),
              ),
            );
          }
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Giriş başarısız'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bir hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _initializeApiService() async {
    try {
      await ApiService().initialize();
    } catch (e) {

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


          Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [

                      FadeInDown(
                        duration: Duration(milliseconds: 600),
                        child: Text(
                          'SMARTDERM',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),

                      const SizedBox(height: 40),


                      AnimatedCustomTextField(
                        controller: _emailController,
                        labelText: 'Email',
                        icon: Icons.email_rounded,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),


                      AnimatedCustomTextField(
                        controller: _passwordController,
                        labelText: 'Şifre',
                        icon: Icons.lock_rounded,
                        isPassword: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 30),


                      FadeInUp(
                        duration: Duration(milliseconds: 600),
                        delay: Duration(milliseconds: 400),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: backgroundColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator()
                              : Text(
                                  'Giriş Yap',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),


                      FadeInLeft(
                        duration: Duration(milliseconds: 600),
                        delay: Duration(milliseconds: 600),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Hesabın yok mu?',
                              style: TextStyle(color: Colors.white70),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SignUpScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                'Kayıt Ol',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
