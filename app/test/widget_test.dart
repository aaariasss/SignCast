import 'package:app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra carga mientras abre la camara', (tester) async {
    await tester.pumpWidget(const SignCastApp());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}