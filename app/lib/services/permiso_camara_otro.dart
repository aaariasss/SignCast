import 'permiso_camara.dart';

/// Fuera del navegador (por ejemplo en `flutter test`) no hay permiso real:
/// se usa la versión nula, que concede al pedirlo.
PermisoCamara crearPermisoCamara() => const PermisoCamaraNulo();
