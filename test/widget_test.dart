import 'package:flutter_test/flutter_test.dart';
import 'package:watt_buddy/main.dart';

void main() {
  testWidgets('Login/Register screen loads correctly', (
    WidgetTester tester,
  ) async {
    // Load the app
    await tester.pumpWidget(WattBuddyApp());
    await tester.pumpAndSettle();

    // Confirm that the login/register UI is visible
    expect(find.text("Watt Buddy ⚡"), findsOneWidget);

    // Tabs exist
    expect(find.text("Login"), findsWidgets); // (button + tab)
    expect(find.text("Register"), findsOneWidget);
  });
}
