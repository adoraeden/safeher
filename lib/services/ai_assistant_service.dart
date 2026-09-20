import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../models/chat_message.dart';

class AiAssistantService {
  Future<String> sendMessage(String message, List<ChatMessage> history) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('You need to be signed in to use the AI assistant.');
    }
    final idToken = await user.getIdToken();

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/ai/assistant'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'message': message,
        'history': history
            .map((m) => {'role': m.role, 'text': m.text})
            .toList(),
      }),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(
        body['error'] ?? 'Something went wrong. Please try again.',
      );
    }

    final data = jsonDecode(response.body);
    return data['reply'] as String;
  }
}
