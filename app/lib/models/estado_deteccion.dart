/// Estado que muestra la píldora de la pantalla del traductor.
enum EstadoDeteccion {
  /// No hay manos en el encuadre.
  sinManos,

  /// Se ven manos y se están reconociendo señas (se llena el búfer).
  detectando,

  /// Ya hay una frase traducida.
  traduciendo;

  String get etiqueta => switch (this) {
    EstadoDeteccion.sinManos => 'Sin manos',
    EstadoDeteccion.detectando => 'Detectando…',
    EstadoDeteccion.traduciendo => 'Traduciendo',
  };
}
