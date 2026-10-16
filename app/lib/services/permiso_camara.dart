/// Resultado de consultar o pedir el permiso de la cámara.
enum EstadoPermiso {
  concedido,
  denegado,

  /// El usuario marcó "no volver a preguntar": solo se puede cambiar desde los
  /// ajustes del sistema.
  denegadoPermanente,
}

/// Acceso al permiso de la cámara. La implementación real está en
/// `permiso_camara_sistema.dart`; así las pruebas no dependen del teléfono.
abstract class PermisoCamara {
  /// Consulta el estado actual sin mostrar ningún diálogo.
  Future<EstadoPermiso> estado();

  /// Muestra el diálogo del sistema (si todavía se puede) y devuelve el
  /// resultado.
  Future<EstadoPermiso> solicitar();

  /// Abre los ajustes de la app en el sistema.
  Future<void> abrirAjustes();
}

/// Versión para pruebas: el permiso nunca está concedido de antemano, pero
/// [solicitar] lo concede.
class PermisoCamaraNulo implements PermisoCamara {
  const PermisoCamaraNulo();

  @override
  Future<EstadoPermiso> estado() async => EstadoPermiso.denegado;

  @override
  Future<EstadoPermiso> solicitar() async => EstadoPermiso.concedido;

  @override
  Future<void> abrirAjustes() async {}
}
