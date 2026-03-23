import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// FONTOS: Ez a név pontosan az kell legyen, amit a pubspec.yaml 'name' sorába írtál!
import 'package:bee_log_pro/main.dart';

void main() {
  testWidgets('Bejelentkező oldal betöltése teszt',
      (WidgetTester tester) async {
    // Elindítjuk az appot
    await tester.pumpWidget(const MyApp());

    // Ellenőrizzük, hogy a bejelentkező felirat ott van-e
    expect(find.text('BEE-LOG LOGIN'), findsOneWidget);

    // Ellenőrizzük a beviteli mező feliratát
    expect(find.text('Felhasználónév'), findsOneWidget);
  });
}
