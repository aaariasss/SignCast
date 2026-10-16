/// Una frase traducida durante la sesión.
class FraseHistorial {
  const FraseHistorial({required this.hora, required this.texto});

  final DateTime hora;
  final String texto;

  /// Hora en formato 24 h, por ejemplo `10:42`.
  String get horaTexto {
    final h = hora.hour.toString().padLeft(2, '0');
    final m = hora.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
