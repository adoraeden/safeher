import 'dart:convert';
import 'dart:io' show SocketException;

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

    // Filter history to exclude empty messages and assistant error bubbles
    final cleanHistory = history
        .where((m) =>
            m.text.trim().isNotEmpty &&
            !m.text.startsWith("I couldn't respond just now"))
        .map((m) => {'role': m.role, 'text': m.text.trim()})
        .toList();

    http.Response response;
    try {
      response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/ai/assistant'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'message': message,
          'history': cleanHistory,
        }),
      ).timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw Exception(
          'Connection timed out. The server took too long to respond.',
        ),
      );
    } on SocketException catch (_) {
      throw Exception(
        'Cannot reach backend at ${ApiConfig.baseUrl}. Please verify the SafeHer server is running.',
      );
    } on http.ClientException catch (_) {
      throw Exception(
        'Cannot reach backend at ${ApiConfig.baseUrl}. Please verify the SafeHer server is running.',
      );
    }

    if (response.statusCode != 200) {
      try {
        final body = jsonDecode(response.body);
        throw Exception(
          body['error'] ??
              'Server returned error (${response.statusCode}). Please try again.',
        );
      } catch (e) {
        if (e is Exception && !e.toString().contains('FormatException')) {
          rethrow;
        }
        throw Exception(
          'Server error (${response.statusCode}): ${response.body}',
        );
      }
    }

    final data = jsonDecode(response.body);
    final reply = data['reply'] as String?;
    if (reply == null || reply.trim().isEmpty) {
      throw Exception('Received an empty response from AI.');
    }
    return reply.trim();
  }
}
