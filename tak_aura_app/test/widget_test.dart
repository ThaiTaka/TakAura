import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tak_aura_app/splash_screen.dart';

void main() {
  testWidgets('Splash screen hiển thị đúng nội dung', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(cameras: [], autoNavigate: false),
      ),
    );

    expect(find.text('TakAura'), findsOneWidget);
    expect(find.text('Đang khởi động hệ thống...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
