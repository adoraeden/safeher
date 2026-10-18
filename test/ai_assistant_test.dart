import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety/models/chat_message.dart';
import 'package:women_safety/screens/assistant/ai_assistant_screen.dart';
import 'package:women_safety/services/ai_assistant_service.dart';

class FakeAiAssistantService extends AiAssistantService {
  String replyToReturn = 'Stay calm. Move toward a well-lit public area.';
  bool shouldThrow = false;
  String throwMessage = 'The AI assistant is temporarily unavailable. Please try again.';
  List<ChatMessage>? lastHistoryReceived;
  String? lastMessageReceived;

  @override
  Future<String> sendMessage(String message, List<ChatMessage> history) async {
    lastMessageReceived = message;
    lastHistoryReceived = List.from(history);
    if (shouldThrow) {
      throw Exception(throwMessage);
    }
    return replyToReturn;
  }
}

void main() {
  group('ChatMessage Model', () {
    test('defaults isError to false', () {
      final msg = ChatMessage(role: 'user', text: 'Hello');
      expect(msg.isError, isFalse);
      expect(msg.role, 'user');
      expect(msg.text, 'Hello');
    });

    test('supports isError flag when set to true', () {
      final msg = ChatMessage(role: 'assistant', text: 'Error occurred', isError: true);
      expect(msg.isError, isTrue);
    });
  });

  group('AiAssistantScreen Widget Tests', () {
    testWidgets('renders header, notice banner, and 4 required prompt suggestions', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeService = FakeAiAssistantService();

      await tester.pumpWidget(
        MaterialApp(
          home: AiAssistantScreen(service: fakeService),
        ),
      );

      await tester.pump();

      // 1. Header & Notice
      expect(find.text('AI Safety Assistant'), findsOneWidget);
      expect(find.text('Powered by Gemini'), findsAtLeastNWidgets(1));
      expect(
        find.textContaining('Notice: If you are in immediate physical danger'),
        findsOneWidget,
      );

      // 2. The 4 required safety prompt suggestions
      expect(
        find.text('Someone is following me on foot, what should I do?'),
        findsOneWidget,
      );
      expect(
        find.text('My rideshare driver is taking an unfamiliar route'),
        findsOneWidget,
      );
      expect(
        find.text('Safety checklist for traveling alone at night'),
        findsOneWidget,
      );
      expect(
        find.text('How do I set up a discreet distress word with my family?'),
        findsOneWidget,
      );
    });

    testWidgets('tapping a suggestion sends it and displays successful assistant reply', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeService = FakeAiAssistantService()
        ..replyToReturn = 'Head directly into a store or populated building.';

      await tester.pumpWidget(
        MaterialApp(
          home: AiAssistantScreen(service: fakeService),
        ),
      );

      await tester.pump();

      // Tap suggestion
      await tester.tap(find.text('Someone is following me on foot, what should I do?'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify user message appears
      expect(
        find.text('Someone is following me on foot, what should I do?'),
        findsOneWidget,
      );
      // Verify assistant reply appears
      expect(
        find.text('Head directly into a store or populated building.'),
        findsOneWidget,
      );
      expect(fakeService.lastMessageReceived, 'Someone is following me on foot, what should I do?');
    });

    testWidgets('displays error bubble with Retry button on failure and strips error from history', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeService = FakeAiAssistantService()
        ..shouldThrow = true
        ..throwMessage = 'The AI assistant took too long to respond. Please try again.';

      await tester.pumpWidget(
        MaterialApp(
          home: AiAssistantScreen(service: fakeService),
        ),
      );

      await tester.pump();

      // Type and send a message
      final inputFinder = find.byType(TextField);
      await tester.enterText(inputFinder, 'I feel unsafe');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify error bubble rendered
      expect(
        find.textContaining("I couldn't respond just now"),
        findsOneWidget,
      );
      // Verify retry button rendered
      expect(find.text('Retry question'), findsOneWidget);

      // Now set service to succeed and tap Retry
      fakeService.shouldThrow = false;
      fakeService.replyToReturn = 'Call a trusted contact or enter a safe open store.';

      await tester.tap(find.text('Retry question'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify success reply displayed and error bubble removed
      expect(
        find.text('Call a trusted contact or enter a safe open store.'),
        findsOneWidget,
      );
      expect(
        find.textContaining("I couldn't respond just now"),
        findsNothing,
      );

      // Verify history sent to Gemini NEVER included any error bubble
      for (final turn in fakeService.lastHistoryReceived ?? <ChatMessage>[]) {
        expect(turn.isError, isFalse);
        expect(turn.text.contains("I couldn't respond just now"), isFalse);
      }
    });
  });
}
