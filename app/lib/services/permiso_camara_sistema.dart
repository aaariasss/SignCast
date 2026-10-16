import 'package:permission_handler/permission_handler.dart';

import 'permiso_camara.dart';

/// Permiso de cámara real, con el paquete `permission_handler`.
class PermisoCamaraSistema implements PermisoCamara {
  const PermisoCamaraSistema();

  EstadoPermiso _traducir(PermissionStatus estado) {
    if (estado.isGranted) return EstadoPermiso.concedido;
    if (estado.isPermanentlyDenied) return EstadoPermiso.denegadoPermanente;
    return EstadoPermiso.denegado;
  }

  @override
  Future<EstadoPermiso> estado() async =>
      _traducir(await Permission.camera.status);

  @override
  Future<EstadoPermiso> solicitar() async =>
      _traducir(await Permission.camera.request());

  @override
  Future<void> abrirAjustes() async {
    await openAppSettings();
  }
}
