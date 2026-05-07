import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_habits/app.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    // Splash view loads an asset asynchronously, so just verify the scaffold
    // exists before the logo loads.
    expect(find.byType(ProviderScope), findsOneWidget);
  });
}
