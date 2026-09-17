import 'package:flutter/material.dart';

import 'login_screen.dart';

/// Kept so existing navigation to register still works.
/// The portal UI (Sign In / Create Account) lives on [LoginScreen].
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoginScreen(startOnRegister: true);
  }
}
