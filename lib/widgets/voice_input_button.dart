import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

import '../services/voice_guard_service.dart';
import '../theme/app_colors.dart';

/// A mic button for dictating into a text field.
///
/// Tap once to start listening: your words appear in [controller] live as
/// you speak, appended after anything already typed. Tap again (or just
/// stop talking) to finish. The user can then edit the text and send it
/// normally.
///
/// Usage, next to the send button in the chat input row:
///
///   VoiceInputButton(controller: _messageController)
class VoiceInputButton extends StatefulWidget {
  final TextEditingController controller;

  /// Optional locale, e.g. 'en_IN'. Defaults to the device language.
  final String? localeId;

  /// Optional: called once when listening ends.
  final VoidCallback? onFinished;

  const VoiceInputButton({
    super.key,
    required this.controller,
    this.localeId,
    this.onFinished,
  });

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _available = false;
  bool _isListening = false;
  String _baseText = '';
  String _lastWritten = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _speech.cancel();
    VoiceGuardService().resume();
    super.dispose();
  }

  // If the box gets cleared while we're listening (e.g. the user tapped
  // Send), stop listening so we don't keep typing into an empty box.
  void _onControllerChanged() {
    if (_isListening &&
        widget.controller.text.isEmpty &&
        _lastWritten.isNotEmpty) {
      _speech.cancel();
      VoiceGuardService().resume();
      if (mounted) setState(() => _isListening = false);
    }
  }

  Future<void> _toggle() async {
    if (_isListening) {
      await _speech.stop();
      VoiceGuardService().resume();
      return;
    }
    await _start();
  }

  Future<void> _start() async {
    VoiceGuardService().pause();

    if (!_available) {
      try {
        _available = await _speech.initialize(
          onStatus: _onStatus,
          onError: _onError,
        );
      } catch (e) {
        _available = false;
      }
      if (!_available) {
        VoiceGuardService().resume();
        _showMessage(
          'Microphone permission denied or speech recognition is unavailable.',
        );
        return;
      }
    }

    final existing = widget.controller.text.trim();
    _baseText = existing.isEmpty ? '' : '$existing ';
    _lastWritten = widget.controller.text;

    setState(() => _isListening = true);

    try {
      await _speech.listen(
        onResult: _onResult,
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
          pauseFor: const Duration(seconds: 4),
          listenFor: const Duration(seconds: 60),
          localeId: widget.localeId,
        ),
      );
    } catch (e) {
      VoiceGuardService().resume();
      if (mounted) setState(() => _isListening = false);
      _showMessage('Could not start dictation: $e');
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    final text = _baseText + result.recognizedWords;
    _lastWritten = text;
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    if (result.finalResult) _finish();
  }

  void _onStatus(String status) {
    if (status == 'done' || status == 'notListening') _finish();
  }

  void _onError(SpeechRecognitionError error) {
    if (mounted) setState(() => _isListening = false);

    final msg = error.errorMsg.toLowerCase();
    if (msg.contains('busy') || msg.contains('client')) {
      _showMessage(
        'Microphone is busy. If Voice Guard is on, turn it off and try again.',
      );
    } else if (msg.contains('no_match') || msg.contains('timeout')) {
      _showMessage("Didn't catch that. Tap the mic and try again.");
    } else if (msg.contains('permission')) {
      _showMessage('Microphone permission is needed for voice input.');
    } else if (msg.contains('network')) {
      _showMessage('Speech recognition needs a network connection.');
    } else {
      _showMessage('Voice input error: ${error.errorMsg}');
    }
  }

  void _finish() {
    if (!_isListening) return;
    if (mounted) setState(() => _isListening = false);
    widget.onFinished?.call();
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _isListening ? 'Stop dictation' : 'Dictate your message',
      onPressed: _toggle,
      icon: Icon(
        _isListening ? Icons.stop_circle_outlined : Icons.mic_none_outlined,
      ),
      color: _isListening ? AppColors.dangerLight : AppColors.textSecondary,
    );
  }
}
