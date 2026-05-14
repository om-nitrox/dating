import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reverse_match/shared/widgets/empty_state_widget.dart';

void main() {
  group('EmptyStateWidget', () {
    testWidgets('renders icon and title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.search_off,
              title: 'No results',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.search_off), findsOneWidget);
      expect(find.text('No results'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.error_outline,
              title: 'Oops',
              subtitle: 'Try again later.',
            ),
          ),
        ),
      );

      expect(find.text('Oops'), findsOneWidget);
      expect(find.text('Try again later.'), findsOneWidget);
    });

    testWidgets('omits subtitle text when null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(icon: Icons.info, title: 'Hi'),
          ),
        ),
      );

      expect(find.text('Hi'), findsOneWidget);
      // No stray subtitle text rendered.
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('action button invokes callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.refresh,
              title: 'Empty',
              actionLabel: 'Retry',
              onAction: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}
