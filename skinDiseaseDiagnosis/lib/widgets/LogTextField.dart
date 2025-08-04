import 'package:flutter/material.dart';
import 'package:skincancer/style/color.dart';
import 'package:animate_do/animate_do.dart';

class AnimatedCustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData icon;
  final bool isPassword;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  const AnimatedCustomTextField({
    Key? key,
    required this.controller,
    required this.labelText,
    required this.icon,
    this.isPassword = false,
    this.keyboardType,
    this.validator,
  }) : super(key: key);

  @override
  _AnimatedCustomTextFieldState createState() =>
      _AnimatedCustomTextFieldState();
}

class _AnimatedCustomTextFieldState extends State<AnimatedCustomTextField> {
  bool _isObscured = true;

  @override
  Widget build(BuildContext context) {
    return FadeIn(
      duration: const Duration(milliseconds: 600),
      delay: const Duration(milliseconds: 200),
      child: TextFormField(
        controller: widget.controller,
        obscureText: widget.isPassword && _isObscured,
        keyboardType: widget.keyboardType,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withOpacity(0.9),
          labelText: widget.labelText,
          prefixIcon: Icon(widget.icon, color: primaryColor),
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(
                    _isObscured ? Icons.visibility_off : Icons.visibility,
                    color: primaryColor,
                  ),
                  onPressed: () {
                    setState(() {
                      _isObscured = !_isObscured;
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          errorStyle: const TextStyle(color: Colors.white),
        ),
        style: const TextStyle(color: Colors.black87),
        validator: widget.validator,
      ),
    );
  }
}
