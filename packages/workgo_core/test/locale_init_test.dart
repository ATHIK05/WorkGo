import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workgo_core/workgo_core.dart';

void main() {
  testWidgets('Verify MaterialApp renders Locale("sa") with WorkGoLocale delegates', (tester) async {
    await WorkGoLocale.ensureInitialized();

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('sa'),
        supportedLocales: [Locale('en'), Locale('sa')],
        localizationsDelegates: [
          WorkGoMaterialLocalizationsDelegate(),
          WorkGoCupertinoLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: Center(child: Text('नमस्ते', textDirection: TextDirection.ltr))),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('नमस्ते'), findsOneWidget);
  });
}
