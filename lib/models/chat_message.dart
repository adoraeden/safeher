class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String text;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.role,
    required this.text,
    DateTime? timestamp,
    this.isError = false,
  }) : timestamp = timestamp ?? DateTime.now();
}
