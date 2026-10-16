import 'package:flutter/material.dart';
import 'screens/camara_screen.dart';

void main() => runApp(const SignCastApp());

class SignCastApp extends StatelessWidget {
  const SignCastApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: CamaraScreen(),
      );
}