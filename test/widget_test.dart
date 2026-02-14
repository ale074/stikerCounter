import 'package:flutter_test/flutter_test.dart';
import 'package:sticker_counter/main.dart';

void main() {
  testWidgets('App starts correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const StickerCounterApp());
    expect(find.text('Sticker Counter'), findsOneWidget);
  });
}
