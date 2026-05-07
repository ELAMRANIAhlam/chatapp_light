import 'package:flutter/material.dart';

class AuthTheme {
  static const primaryGradient = LinearGradient(
    colors: [Color(0xFF5AB6B9), Color(0xFF88D8C0)],
  );

  static InputDecoration inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
    );
  }
}
