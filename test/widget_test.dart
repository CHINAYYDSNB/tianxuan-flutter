import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan_flutter/main.dart';

void main() {
  testWidgets('app renders navigation shell via theme loader', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ThemeLoader()));
    await tester.pumpAndSettle();
    expect(find.text('总览'), findsOneWidget);
    expect(find.text('面板'), findsOneWidget);
    expect(find.text('批量'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}
