import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan_flutter/app.dart';

void main() {
  testWidgets('app renders navigation shell', (WidgetTester tester) async {
    await tester.pumpWidget(const TianxuanApp());
    expect(find.text('总览'), findsOneWidget);
    expect(find.text('面板'), findsOneWidget);
    expect(find.text('批量'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}
