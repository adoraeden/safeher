import 'package:firebase_auth/firebase_auth.dart';

/// Returns the signed-in user's UID, waiting briefly for Firebase's auth
/// state to settle if it hasn't resolved yet (this happens sometimes,
/// especially right after a page load on web). Throws a clear error only
/// if no one is genuinely signed in after waiting.
Future<String> requireUid() async {
  final immediate = FirebaseAuth.instance.currentUser;
  if (immediate != null) return immediate.uid;

  final user = await FirebaseAuth.instance
      .authStateChanges()
      .firstWhere((u) => u != null, orElse: () => null)
      .timeout(const Duration(seconds: 5), onTimeout: () => null);

  if (user == null) {
    throw Exception('Not signed in — please log out and log back in.');
  }
  return user.uid;
}
