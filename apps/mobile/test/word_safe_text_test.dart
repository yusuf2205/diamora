import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diamoraa_mobile/core/ui/widgets.dart';

void main() {
  testWidgets('a word wider than its box is scaled down, never split', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 50, child: WordSafeText('Подготовить работу', style: TextStyle(fontSize: 14)))))));
    final text = tester.widget<Text>(find.byType(Text));
    // ignore: avoid_print
    print('font=${text.style?.fontSize}');
    expect(text.style!.fontSize!, lessThan(14));
  });
}
