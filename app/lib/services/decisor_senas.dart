import 'frases.dart';

/// Convierte las predicciones del modelo en glosas y cierra la frase tras una
/// pausa. Es la misma lógica de `ml/signcast/tiempo_real.py`:
///
/// - una predicción solo cuenta si su probabilidad llega al [umbral];
/// - una glosa se acepta cuando salen [estables] predicciones iguales seguidas;
/// - la misma glosa no se repite hasta que haya otra o un reposo entre ellas;
/// - la frase se cierra cuando el reposo dura al menos [pausaFrase].
class DecisorSenas {
  DecisorSenas({
    this.umbral = 0.75,
    this.estables = 3,
    this.pausaFrase = const Duration(milliseconds: 1200),
  });

  final double umbral;
  final int estables;
  final Duration pausaFrase;

  final List<String?> _recientes = [];
  final List<String> _glosas = [];
  String? _ultima;
  int? _inicioReposoMs;

  /// Glosas aceptadas de la frase en curso.
  List<String> get glosas => List.unmodifiable(_glosas);

  void reiniciar() {
    _recientes.clear();
    _glosas.clear();
    _ultima = null;
    _inicioReposoMs = null;
  }

  /// Registra una predicción en el instante [ms]. Devuelve `true` si con ella
  /// se agregó una glosa nueva.
  bool predecir(String etiqueta, double probabilidad, int ms) {
    _recientes.add(probabilidad >= umbral ? etiqueta : null);
    if (_recientes.length > estables) _recientes.removeAt(0);

    final estable =
        _recientes.length == estables && _recientes.toSet().length == 1;
    if (!estable) return false;

    final actual = _recientes.first;
    if (actual == claseReposo) {
      _ultima = claseReposo;
      _inicioReposoMs ??= ms;
      return false;
    }
    if (actual != null && actual != _ultima) {
      _glosas.add(actual);
      _ultima = actual;
      _inicioReposoMs = null;
      return true;
    }
    return false;
  }

  /// Si la pausa ya duró lo suficiente, devuelve las glosas de la frase y
  /// empieza una nueva; si no, `null`.
  List<String>? cerrarFrase(int ms) {
    final inicio = _inicioReposoMs;
    if (_glosas.isEmpty || inicio == null) return null;
    if (ms - inicio < pausaFrase.inMilliseconds) return null;
    final cerradas = List<String>.of(_glosas);
    _glosas.clear();
    _inicioReposoMs = null;
    return cerradas;
  }
}
