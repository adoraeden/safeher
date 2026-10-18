import 'package:flutter/material.dart';

import '../../models/chat_message.dart';
import '../../services/ai_assistant_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/voice_input_button.dart';

class AiAssistantScreen extends StatefulWidget {
  final AiAssistantService? service;

  const AiAssistantScreen({super.key, this.service});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  late final AiAssistantService _service = widget.service ?? AiAssistantService();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isSending = false;
  String? _lastFailedUserMessage;

  static const List<_PromptSuggestion> _suggestedPrompts = [
    _PromptSuggestion(
      title: 'Someone is following me on foot, what should I do?',
      category: 'Immediate Situational Guidance',
      icon: Icons.directions_walk_rounded,
    ),
    _PromptSuggestion(
      title: 'My rideshare driver is taking an unfamiliar route',
      category: 'Travel & De-escalation Tips',
      icon: Icons.local_taxi_rounded,
    ),
    _PromptSuggestion(
      title: 'Safety checklist for traveling alone at night',
      category: 'Night Travel Preparedness',
      icon: Icons.nights_stay_rounded,
    ),
    _PromptSuggestion(
      title: 'How do I set up a discreet distress word with my family?',
      category: 'Discreet Emergency Planning',
      icon: Icons.lock_person_rounded,
    ),
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
    final trimmedText = text.trim();
    if (trimmedText.isEmpty || _isSending) return;

    // Capture clean history snapshot BEFORE adding the current message (excluding error bubbles)
    final historySnapshot = _messages
        .where((m) => !m.isError && m.text.trim().isNotEmpty)
        .toList();

    final userMessage = ChatMessage(
      role: 'user',
      text: trimmedText,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isSending = true;
      _lastFailedUserMessage = null;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      final reply = await _service.sendMessage(trimmedText, historySnapshot);
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              role: 'assistant',
              text: reply,
              timestamp: DateTime.now(),
              isError: false,
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceFirst('Exception: ', '');
        setState(() {
          _lastFailedUserMessage = trimmedText;
          _messages.add(
            ChatMessage(
              role: 'assistant',
              text:
                  "I couldn't respond just now ($errorMsg).\n\nIf this is urgent, please use the SOS button or call your local emergency number (911/112).",
              timestamp: DateTime.now(),
              isError: true,
            ),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  void _retryLastFailedMessage() {
    if (_lastFailedUserMessage == null || _isSending) return;
    final messageToRetry = _lastFailedUserMessage!;

    // Remove the trailing error bubble if present
    setState(() {
      if (_messages.isNotEmpty && _messages.last.isError) {
        _messages.removeLast();
      }
      // Also remove the user message if it's already there to avoid duplicate user bubbles
      if (_messages.isNotEmpty && _messages.last.role == 'user' && _messages.last.text == messageToRetry) {
        _messages.removeLast();
      }
    });

    _send(messageToRetry);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: AppColors.primaryLight,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'AI Safety Assistant',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Powered by Gemini',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Emergency Disclaimer Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            color: AppColors.warning.withValues(alpha: 0.12),
            child: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: AppColors.warning,
                ),
                SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    "Notice: If you are in immediate physical danger, please trigger Emergency SOS or call 911/112 right away.",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.warning,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? _EmptyPromptsView(
                    suggestions: _suggestedPrompts,
                    onSelect: _send,
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: _messages.length + (_isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return const _TypingBubble();
                      }
                      final msg = _messages[index];
                      return _MessageBubble(
                        message: msg,
                        onRetry: msg.isError ? _retryLastFailedMessage : null,
                      );
                    },
                  ),
          ),
          // Suggested prompts chips bar when messages are active
          if (_messages.isNotEmpty && !_isSending)
            _ActiveSuggestionsBar(
              suggestions: _suggestedPrompts,
              onSelect: _send,
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

class _PromptSuggestion {
  final String title;
  final String category;
  final IconData icon;

  const _PromptSuggestion({
    required this.title,
    required this.category,
    required this.icon,
  });
}

class _EmptyPromptsView extends StatelessWidget {
  final List<_PromptSuggestion> suggestions;
  final void Function(String) onSelect;

  const _EmptyPromptsView({required this.suggestions, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: AppColors.primaryLight,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SafeHer AI Assistant',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Powered by Gemini',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'I am your SafeHer AI Safety Assistant, powered by Gemini. I can provide real-time situational guidance, travel de-escalation tips, safe route recommendations, and emergency preparedness advice.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Text(
            'Suggested Situations & Questions',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Tap any scenario below to get immediate guidance:',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          ...suggestions.map(
            (suggestion) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onSelect(suggestion.title),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Icon(
                            suggestion.icon,
                            size: 20,
                            color: AppColors.primaryLight,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                suggestion.category,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                suggestion.title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveSuggestionsBar extends StatelessWidget {
  final List<_PromptSuggestion> suggestions;
  final void Function(String) onSelect;

  const _ActiveSuggestionsBar({
    required this.suggestions,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final s = suggestions[index];
          return ActionChip(
            avatar: Icon(s.icon, size: 14, color: AppColors.primaryLight),
            label: Text(
              s.title.length > 32 ? '${s.title.substring(0, 32)}…' : s.title,
              style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
            ),
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            onPressed: () => onSelect(s.title),
          );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;

  const _MessageBubble({
    required this.message,
    this.onRetry,
  });

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final isError = message.isError;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Icon(
                  isError ? Icons.error_outline_rounded : Icons.shield_rounded,
                  size: 14,
                  color: isError ? AppColors.danger : AppColors.primaryLight,
                ),
                const SizedBox(width: 4),
                Text(
                  isError ? 'Notice' : 'SafeHer Assistant',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isError ? AppColors.danger : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                _formatTime(message.timestamp),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 6),
                const Text(
                  'You',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.84,
            ),
            decoration: BoxDecoration(
              color: isUser
                  ? AppColors.primary
                  : isError
                      ? AppColors.danger.withValues(alpha: 0.08)
                      : AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(AppRadius.md),
                topRight: const Radius.circular(AppRadius.md),
                bottomLeft: Radius.circular(isUser ? AppRadius.md : 2),
                bottomRight: Radius.circular(isUser ? 2 : AppRadius.md),
              ),
              border: isUser
                  ? null
                  : Border.all(
                      color: isError
                          ? AppColors.danger.withValues(alpha: 0.3)
                          : AppColors.border,
                    ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  message.text,
                  style: TextStyle(
                    fontSize: 14,
                    color: isUser
                        ? Colors.white
                        : isError
                            ? AppColors.dangerLight
                            : AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                if (isError && onRetry != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      minimumSize: const Size(0, 30),
                      backgroundColor: AppColors.surface,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 14, color: AppColors.primaryLight),
                    label: const Text('Retry question', style: TextStyle(fontSize: 12, color: AppColors.primaryLight)),
                    onPressed: onRetry,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shield_rounded,
                size: 14,
                color: AppColors.primaryLight,
              ),
              SizedBox(width: 4),
              Text(
                'SafeHer Assistant',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryLight,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Analyzing situation...',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !isSending,
                  minLines: 1,
                  maxLines: 4,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Ask for safety advice or guidance...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  onSubmitted: isSending ? null : onSend,
                ),
              ),
              Opacity(
                opacity: isSending ? 0.4 : 1.0,
                child: IgnorePointer(
                  ignoring: isSending,
                  child: VoiceInputButton(controller: controller),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton.filled(
                onPressed: isSending ? null : () => onSend(controller.text),
                icon: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.border,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
