import 'package:flutter/material.dart';

/// Cambio de pantalla con desvanecimiento, para que al pasar de la bienvenida
/// o del permiso a la cámara se sienta que la app avanza.
Route<T> rutaSuave<T>(Widget destino) => PageRouteBuilder<T>(
  pageBuilder: (_, _, _) => destino,
  transitionDuration: const Duration(milliseconds: 450),
  transitionsBuilder: (_, animacion, _, hijo) => FadeTransition(
    opacity: CurvedAnimation(parent: animacion, curve: Curves.easeOut),
    child: hijo,
  ),
);
