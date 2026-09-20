import 'package:flutter/material.dart';

import '../../models/chat_message.dart';
import '../../services/ai_assistant_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _service = AiAssistantService();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isSending = false;

  static const _suggestedPrompts = [
    'I feel unsafe right now',
    'Someone is following me',
    'Help me plan a safer route home',
    'What should I do before walking alone at night?',
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _isSending) return;
    final userMessage = ChatMessage(role: 'user', text: text.trim());
    setState(() {
      _messages.add(userMessage);
      _isSending = true;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      final reply = await _service.sendMessage(userMessage.text, _messages);
      setState(
        () => _messages.add(ChatMessage(role: 'assistant', text: reply)),
      );
    } catch (e) {
      setState(
        () => _messages.add(
          ChatMessage(
            role: 'assistant',
            text:
                "I couldn't respond just now (${e.toString().replaceFirst('Exception: ', '')}). If this is urgent, please use the SOS button or call your local emergency number.",
          ),
        ),
      );
    } finally {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Safety Assistant')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            color: AppColors.warning.withValues(alpha: 0.1),
            child: const Text(
              "Not a substitute for emergency services. In immediate danger, use SOS or call your local emergency number.",
              style: TextStyle(
                fontSize: 11,
                color: AppColors.warning,
                height: 1.3,
              ),
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? _EmptyPrompts(onSelect: _send)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: _messages.length + (_isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length)
                        return const _TypingBubble();
                      return _MessageBubble(message: _messages[index]);
                    },
                  ),
          ),
          _ChatInput(
            controller: _inputController,
            onSend: _send,
            isSending: _isSending,
          ),
        ],
      ),
    );
  }
}

class _EmptyPrompts extends StatelessWidget {
  final void Function(String) onSelect;
  const _EmptyPrompts({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 40,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Ask about a safety situation, or pick one below',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _AiAssistantScreenState._suggestedPrompts
                .map(
                  (p) => ActionChip(
                    label: Text(p, style: const TextStyle(fontSize: 12)),
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.border),
                    onPressed: () => onSelect(p),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.md),
            topRight: const Radius.circular(AppRadius.md),
            bottomLeft: Radius.circular(isUser ? AppRadius.md : 2),
            bottomRight: Radius.circular(isUser ? 2 : AppRadius.md),
          ),
          border: isUser ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontSize: 14,
            color: isUser ? Colors.white : AppColors.textPrimary,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onSend;
  final bool isSending;

  const _ChatInput({
    required this.controller,
    required this.onSend,
    required this.isSending,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !isSending,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Type a message…'),
                onSubmitted: onSend,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              onPressed: isSending ? null : () => onSend(controller.text),
              icon: const Icon(Icons.send),
              style: IconButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
