/// Una voz que ofrece el dispositivo.
class VozDisponible {
  const VozDisponible({
    required this.nombre,
    required this.idioma,
    required this.local,
  });

  final String nombre;

  /// Tal como lo reporta el navegador (`es-MX`, `es_MX`...).
  final String idioma;

  /// `true` si suena sin internet; `false` si el navegador la pide a un
  /// servidor.
  final bool local;

  /// El idioma en minúsculas y con guion (`es-mx`), para comparar.
  String get idiomaNormalizado => idioma.replaceAll('_', '-').toLowerCase();
}
