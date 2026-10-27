import 'permiso_camara.dart';
import 'permiso_camara_sistema.dart';

/// Android y demás plataformas: el permiso del sistema (`permission_handler`).
PermisoCamara crearPermisoCamara() => const PermisoCamaraSistema();
