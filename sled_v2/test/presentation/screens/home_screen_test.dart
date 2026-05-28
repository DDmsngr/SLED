import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gps_photo_tracker/presentation/providers/session_provider.dart';
import 'package:gps_photo_tracker/presentation/screens/home/home_screen.dart';

void main() {
  testWidgets('HomeScreen показывает пустое состояние когда нет сессий',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionsProvider.overrideWith((_) async => []),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Пока нет треков'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
