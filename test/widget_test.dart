// SmartRoute smoke test — verifies the app bootstraps without errors.

import 'package:flutter_test/flutter_test.dart';
import 'package:finalyr_app/main.dart';

void main() {
  testWidgets('SmartRouteApp renders login placeholder', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartRouteApp());
    await tester.pump(); // settle providers

    // The initial route '/' renders the LoginScreen placeholder.
    expect(find.text('LoginScreen'), findsOneWidget);
  });
}
