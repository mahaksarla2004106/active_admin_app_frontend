import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:activ_admin/main.dart';

void main() {
  testWidgets('Admin app renders login screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const AdminApp());
    await tester.pump();

    expect(find.text('SIGN IN'), findsNothing);
  });
}