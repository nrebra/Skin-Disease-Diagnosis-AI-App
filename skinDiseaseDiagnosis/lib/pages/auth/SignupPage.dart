import 'package:flutter/material.dart';

import 'package:skincancer/pages/auth/information.dart';
import 'package:skincancer/style/color.dart';
import '../../widgets/LogTextField.dart';
import '../../service/authService.dart';
import 'package:animate_do/animate_do.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  final _authService = AuthService();
  String _userType = 'patient';

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
                          'Kayıt Ol',
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
                      const SizedBox(height: 30),
                      Container(
                        margin: EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'patient',
                              label: Text('Hasta'),
                              icon: Icon(Icons.person),
                            ),
                            ButtonSegment(
                              value: 'doctor',
                              label: Text('Doktor'),
                              icon: Icon(Icons.medical_services),
                            ),
                          ],
                          selected: {_userType},
                          onSelectionChanged: (Set<String> newSelection) {
                            setState(() {
                              _userType = newSelection.first;
                            });
                          },
                          style: ButtonStyle(
                            backgroundColor:
                                MaterialStateProperty.resolveWith<Color>(
                              (Set<MaterialState> states) {
                                if (states.contains(MaterialState.selected)) {
                                  return primaryColor;
                                }
                                return Colors.transparent;
                              },
                            ),
                          ),
                        ),
                      ),
                      AnimatedCustomTextField(
                        controller: _nameController,
                        labelText: 'Ad',
                        icon: Icons.person_rounded,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ad gerekli';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      AnimatedCustomTextField(
                        controller: _surnameController,
                        labelText: 'Soyad',
                        icon: Icons.person_rounded,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Soyad gerekli';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      AnimatedCustomTextField(
                        controller: _emailController,
                        labelText: 'Email',
                        icon: Icons.email_rounded,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Email gerekli';
                          }
                          if (!value.endsWith('@gmail.com')) {
                            return '@gmail.com ile bitmelidir';
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
                            return 'Şifre gerekli';
                          }
                          if (value.length < 6) {
                            return 'Şifre en az 6 karakter olmalı';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      AnimatedCustomTextField(
                        controller: _confirmPasswordController,
                        labelText: 'Şifre Onayla',
                        icon: Icons.lock_rounded,
                        isPassword: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Şifre onayı gerekli';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 30),
                      FadeInUp(
                        duration: Duration(milliseconds: 600),
                        delay: Duration(milliseconds: 400),
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  if (_formKey.currentState!.validate()) {
                                    if (_passwordController.text !=
                                        _confirmPasswordController.text) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text('Şifreler eşleşmiyor')),
                                      );
                                      return;
                                    }

                                    setState(() => _isLoading = true);

                                    try {
                                      final result =
                                          await _authService.initializeSignUp(
                                        email: _emailController.text,
                                        password: _passwordController.text,
                                        name: _nameController.text,
                                        surname: _surnameController.text,
                                        userType: _userType,
                                      );

                                      setState(() => _isLoading = false);

                                      if (result['success']) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => Information(
                                              email: _emailController.text,
                                              password:
                                                  _passwordController.text,
                                              name: _nameController.text,
                                              surname: _surnameController.text,
                                              userType: _userType,
                                            ),
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(result['message'])),
                                        );
                                      }
                                    } catch (e) {
                                      setState(() => _isLoading = false);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('Bir hata oluştu: $e')),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text(
                                  'Devam Et',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
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
                              'Zaten bir hesabın var mı?',
                              style: TextStyle(color: Colors.white70),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Giriş Yap',
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    super.dispose();
  }
}
