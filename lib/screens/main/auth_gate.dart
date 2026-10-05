import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../onboarding/create_emergency_phrase_screen.dart';
import 'main_shell.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!authSnapshot.hasData) {
          return const LoginScreen();
        }

        final uid = authSnapshot.data!.uid;
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final data = profileSnapshot.data?.data();
            final bool onboardingDone = (data != null) &&
                ((data['onboardingCompleted'] == true) ||
                    (data['voiceEnrollmentComplete'] == true));

            if (!onboardingDone) {
              return const CreateEmergencyPhraseScreen();
            }
            return const MainShell();
          },
        );
      },
    );
  }
}
