import 'package:aqua_in_laba_app/features/chat/widgets/chat_message_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('message action sheet returns a selected reaction', (
    tester,
  ) async {
    late Future<ChatMessageAction?> actionResult;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                actionResult = showChatMessageActions(
                  context,
                  canEdit: false,
                  selectedReaction: null,
                );
              },
              child: const Text('Open actions'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open actions'));
    await tester.pumpAndSettle();
    expect(find.text('Edit message'), findsNothing);

    await tester.tap(find.text('👍'));
    await tester.pumpAndSettle();

    expect((await actionResult)?.reaction, '👍');
  });

  testWidgets('message action sheet offers editing only when allowed', (
    tester,
  ) async {
    late Future<ChatMessageAction?> actionResult;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                actionResult = showChatMessageActions(
                  context,
                  canEdit: true,
                  selectedReaction: null,
                );
              },
              child: const Text('Open actions'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit message'));
    await tester.pumpAndSettle();

    expect((await actionResult)?.edit, isTrue);
  });
}
