import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recontent_ai/core/widgets.dart';

void main() {
  test('formats content labels for display', () {
    expect(titleCase('short_post'), 'Short Post');
  });

  testWidgets('status pill shows a readable status', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StatusPill(status: 'scheduled')),
      ),
    );
    expect(find.text('Scheduled'), findsOneWidget);
  });
}
