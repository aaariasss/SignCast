import '../models/cuadro_puntos.dart';
import 'caracteristicas.dart';

/// Últimos cuadros con su hora, para armar la secuencia que recibe el modelo.
///
/// El entrenamiento usa 30 cuadros a 30 por segundo (≈ 1 s). La cámara web va
/// más lento y a ritmo variable (hasta ~20 por segundo), así que en vez de
/// tomar los últimos 30 cuadros se toman los que hubo en el último segundo y
/// se reparten en 30 posiciones. Si un cuadro falta, se repite el anterior.
class VentanaTemporal {
  VentanaTemporal({
    this.fps = 30,
    this.memoriaMs = 1500,
    this.toleranciaMs = 100,
  });

  /// Ritmo con el que se grabó el entrenamiento.
  final int fps;

  /// Cuánta historia se conserva.
  final int memoriaMs;

  /// Cuánto puede faltar al principio de la ventana para darla por llena.
  final int toleranciaMs;

  final List<(int, CuadroPuntos)> _cuadros = [];

  int get cantidad => _cuadros.length;

  void agregar(int ms, CuadroPuntos cuadro) {
    _cuadros.add((ms, cuadro));
    while (_cuadros.first.$1 < ms - memoriaMs) {
      _cuadros.removeAt(0);
    }
  }

  void limpiar() => _cuadros.clear();

  /// Los [longitudSecuencia] cuadros de la ventana, o `null` si todavía no hay
  /// historia suficiente (menos de ~1 s desde el primer cuadro).
  List<CuadroPuntos>? muestrear() {
    if (_cuadros.isEmpty) return null;
    final fin = _cuadros.last.$1;
    final paso = 1000 / fps;
    final inicio = fin - paso * (longitudSecuencia - 1);
    if (_cuadros.first.$1 > inicio + toleranciaMs) return null;

    final salida = <CuadroPuntos>[];
    var j = 0;
    for (var i = 0; i < longitudSecuencia; i++) {
      final objetivo = inicio + paso * i;
      while (j + 1 < _cuadros.length && _cuadros[j + 1].$1 <= objetivo) {
        j++;
      }
      salida.add(_cuadros[j].$2);
    }
    return salida;
  }
}
