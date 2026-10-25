import 'package:bepay_transaction_history/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app opens the transaction history screen', (tester) async {
    await tester.pumpWidget(const BePayApp());
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Everyday activity'), findsOneWidget);
    expect(find.text('YOUR MONEY, IN MOTION'), findsOneWidget);
  });
}
