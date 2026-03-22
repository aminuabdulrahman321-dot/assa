import 'package:flutter/material.dart';
import 'package:assa/core/constants/app_colors.dart';
import 'package:assa/screens/auth/register_user_screen.dart';
import 'package:assa/screens/auth/register_driver_screen.dart';

class RegisterRoleScreen extends StatelessWidget {
  final String role;

  const RegisterRoleScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    if (role == 'driver') {
      return const RegisterDriverScreen();
    }
    return const RegisterUserScreen();
  }
}