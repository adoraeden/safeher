import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../models/chat_message.dart';

class AiAssistantService {
  /// Sends [message] to the backend with cleaned [history].
  ///
  /// Throws a descriptive [Exception] on any failure.
  Future<String> sendMessage(String message, List<ChatMessage> history) async {
    // ── Auth ──────────────────────────────────────────────────────────────
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('You need to be signed in to use the AI assistant.');
    }

    // Refresh the token in case it recently expired.
    String idToken = '';
    try {
      idToken = await user.getIdToken(false) ?? '';
      if (idToken.isEmpty) {
        idToken = await user.getIdToken(true) ?? '';
      }
    } catch (_) {
      try {
        idToken = await user.getIdToken(true) ?? '';
      } catch (_) {
        throw Exception(
          'Authentication failed. Please sign out and sign back in.',
        );
      }
    }

    if (idToken.isEmpty) {
      throw Exception(
        'Authentication failed. Please sign out and sign back in.',
      );
    }

    // ── Clean history ─────────────────────────────────────────────────────
    // Strip error bubbles and empty messages before sending to backend.
    final cleanHistory = history
        .where(
          (m) =>
              !m.isError &&
              m.text.trim().isNotEmpty &&
              !m.text.startsWith("I couldn't respond just now"),
        )
        .map((m) => {'role': m.role, 'text': m.text.trim()})
        .toList();

    // ── Network request ───────────────────────────────────────────────────
    final candidateUrls = ApiConfig.candidateBaseUrls;
    http.Response? response;
    dynamic lastNetworkError;

    for (final base in candidateUrls) {
      final url = Uri.parse('$base/api/ai/assistant');
      try {
        response = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $idToken',
              },
              body: jsonEncode({
                'message': message,
                'history': cleanHistory,
              }),
            )
            .timeout(const Duration(seconds: 15));
        // If we reached a server response, break immediately
        break;
      } on SocketException catch (e) {
        lastNetworkError = e;
        continue;
      } on http.ClientException catch (e) {
        lastNetworkError = e;
        continue;
      } on TimeoutException catch (e) {
        lastNetworkError = e;
        continue;
      } catch (e) {
        lastNetworkError = e;
        continue;
      }
    }

    if (response == null) {
      if (lastNetworkError is SocketException) {
        throw Exception(
          'Cannot reach the SafeHer server at ${ApiConfig.baseUrl}.\n'
          'Make sure the backend is running and your phone is on the same network.',
        );
      } else if (lastNetworkError is http.ClientException) {
        throw Exception('Network error: ${lastNetworkError.message}. Please try again.');
      }
      throw Exception(
        'Request timed out or server unreachable. Please try again.',
      );
    }

    // ── Parse response ────────────────────────────────────────────────────
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      final reply = data?['reply'] as String?;
      if (reply == null || reply.trim().isEmpty) {
        throw Exception('Received an empty response from AI. Please try again.');
      }
      return reply.trim();
    }

    // ── Handle error status codes ─────────────────────────────────────────
    String? serverError;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      serverError = body?['error'] as String?;
    } catch (_) {
      // Body was not valid JSON.
    }

    switch (response.statusCode) {
      case 401:
        throw Exception(
          'Authentication expired. Please sign out and sign back in.',
        );
      case 400:
        throw Exception(
          serverError ?? 'Invalid request. Please try rephrasing your message.',
        );
      case 429:
        throw Exception(
          serverError ??
              'The AI assistant is busy right now. Please wait a moment and try again.',
        );
      case 504:
        throw Exception(
          serverError ??
              'The AI assistant took too long to respond. Please try again.',
        );
      case 500:
        throw Exception(
          serverError ??
              'The server has a configuration issue. Please check backend environment.',
        );
      default:
        throw Exception(
          serverError ??
              'Server error (${response.statusCode}). Please try again.',
        );
    }
  }
}
