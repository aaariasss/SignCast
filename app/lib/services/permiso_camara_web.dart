import 'dart:js_interop';

import 'permiso_camara.dart';
import 'puntos_js.dart';

/// Permiso de cámara en el navegador. El navegador no deja consultarlo sin
/// preguntar (Safari no lo permite), así que siempre se pasa por la pantalla
/// del permiso: el botón "Permitir cámara" es el toque que Safari exige para
/// mostrar el aviso.
class PermisoCamaraWeb implements PermisoCamara {
  const PermisoCamaraWeb();

  @override
  Future<EstadoPermiso> estado() async => EstadoPermiso.denegado;

  @override
  Future<EstadoPermiso> solicitar() async {
    try {
      final js = await esperarPuntosJs();
      final concedido = (await js.pedirPermiso().toDart).toDart;
      return concedido ? EstadoPermiso.concedido : EstadoPermiso.denegado;
    } catch (_) {
      return EstadoPermiso.denegado;
    }
  }

  /// En el navegador el permiso se cambia desde el candado de la barra de
  /// direcciones o los ajustes de Safari; no se puede abrir desde la página.
  @override
  Future<void> abrirAjustes() async {}
}

PermisoCamara crearPermisoCamara() => const PermisoCamaraWeb();
