/// Constructor de frases de SignCast.
///
/// Traducción directa de `ml/signcast/frases.py`: convierte la lista de glosas
/// que predice el modelo en una oración en español.
library;

/// Glosa que marca "manos quietas o abajo"; separa palabras y frases.
/// Debe coincidir con `CLASE_REPOSO` de `ml/signcast/config.py`.
const String claseReposo = '_REPOSO';

final Set<String> _letras = 'ABCDEFGHIJKLMNOPQRSTUVWXYZÑ'.split('').toSet();

const Map<String, String> _saludos = {
  'HOLA': 'hola',
  'ADIOS': 'adiós',
  'GRACIAS': 'gracias',
};
const Map<String, String> _respuestas = {'SI': 'sí', 'NO': 'no'};
const Map<String, String> _interrogativos = {
  'QUE': 'qué',
  'DONDE': 'dónde',
  'CUANDO': 'cuándo',
  'COMO': 'cómo',
};
const Map<String, String> _tiempo = {'HOY': 'hoy', 'MANANA': 'mañana'};
const Map<String, int> _sujetos = {
  'YO': 1,
  'TU': 2,
  'MAESTRO': 3,
  'COMPANERO': 3,
};
const Map<String, String> _cliticos = {'YO': 'me', 'TU': 'te'};

/// Infinitivo, 1.ª, 2.ª y 3.ª persona (el índice 0 es el infinitivo).
const Map<String, List<String>> _verbos = {
  'ENTENDER': ['entender', 'entiendo', 'entiendes', 'entiende'],
  'REPETIR': ['repetir', 'repito', 'repites', 'repite'],
  'AYUDAR': ['ayudar', 'ayudo', 'ayudas', 'ayuda'],
  'PODER': ['poder', 'puedo', 'puedes', 'puede'],
  'IR': ['ir', 'voy', 'vas', 'va'],
  'TENER': ['tener', 'tengo', 'tienes', 'tiene'],
};
const Set<String> _peticiones = {'REPETIR', 'AYUDAR'};

/// Palabra y género ('m' o 'f').
const Map<String, (String, String)> _sustantivos = {
  'MAESTRO': ('maestro', 'm'),
  'COMPANERO': ('compañero', 'm'),
  'CLASE': ('clase', 'f'),
  'TAREA': ('tarea', 'f'),
  'EXAMEN': ('examen', 'm'),
  'PREGUNTA': ('pregunta', 'f'),
  'BANO': ('baño', 'm'),
};

final RegExp _letra = RegExp(r'\p{L}', unicode: true);

/// Quita glosas repetidas seguidas (`HOLA HOLA` -> `HOLA`). `_REPOSO` se conserva.
List<String> limpiar(List<String> glosas) {
  final salida = <String>[];
  for (final g in glosas) {
    if (g == claseReposo) {
      salida.add(g);
      continue;
    }
    if (salida.isNotEmpty && salida.last == g) continue;
    salida.add(g);
  }
  return salida;
}

/// Junta letras seguidas en un nombre propio (`A N A` -> `#Ana`).
/// `_REPOSO` o cualquier otra glosa corta el deletreo.
List<String> unirDeletreo(List<String> glosas) {
  final salida = <String>[];
  var palabra = '';
  for (final g in [...glosas, claseReposo]) {
    if (_letras.contains(g)) {
      palabra += g;
      continue;
    }
    if (palabra.isNotEmpty) {
      salida.add('#${_capitalize(palabra)}');
      palabra = '';
    }
    if (g != claseReposo) salida.add(g);
  }
  return salida;
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

String _articulo(String glosa, {bool indefinido = false}) {
  final (palabra, genero) = _sustantivos[glosa]!;
  if (indefinido) return '${genero == 'm' ? 'un' : 'una'} $palabra';
  return '${genero == 'm' ? 'el' : 'la'} $palabra';
}

/// Pone en mayúscula la primera letra (ignora signos como `¿`).
String _capitalizar(String texto) {
  final m = _letra.firstMatch(texto);
  if (m == null) return texto;
  return texto.substring(0, m.start) +
      m.group(0)!.toUpperCase() +
      texto.substring(m.end);
}

/// Construye la oración en español a partir de las glosas reconocidas.
String construirFrase(List<String> glosas) {
  var tokens = unirDeletreo(limpiar(glosas));
  if (tokens.isEmpty) return '';

  final inicio = <String>[];
  while (tokens.isNotEmpty && _saludos.containsKey(tokens.first)) {
    inicio.add(_saludos[tokens.removeAt(0)]!);
  }
  final porFavor = tokens.contains('POR-FAVOR');
  tokens = tokens.where((t) => t != 'POR-FAVOR').toList();
  final cierre = <String>[];
  while (tokens.isNotEmpty && _saludos.containsKey(tokens.last)) {
    cierre.insert(0, _saludos[tokens.removeLast()]!);
  }

  if (tokens.length == 1 && _respuestas.containsKey(tokens.first)) {
    return _unir(
      inicio,
      _cerrar([_respuestas[tokens.first]!], porFavor: porFavor),
      cierre,
    );
  }
  if (tokens.isEmpty) {
    return _unir([], _cerrar([...inicio, ...cierre], porFavor: porFavor), []);
  }

  final interrogativo = tokens.where(_interrogativos.containsKey).firstOrNull;
  final negacion = tokens.contains('NO');
  final tiempo = [
    for (final t in tokens)
      if (_tiempo.containsKey(t)) _tiempo[t]!,
  ];
  final verbos = tokens.where(_verbos.containsKey).toList();
  final nombres = [
    for (final t in tokens)
      if (t.startsWith('#')) t.substring(1),
  ];

  String? sujeto;
  final cliticos = <String>[];
  final sustantivos = <String>[];
  final idxVerbo = verbos.isNotEmpty ? tokens.indexOf(verbos.first) : -1;
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if (_sujetos.containsKey(t) &&
        sujeto == null &&
        (verbos.isEmpty || i < idxVerbo)) {
      sujeto = t;
    } else if (_cliticos.containsKey(t) && verbos.isNotEmpty && i > idxVerbo) {
      cliticos.add(_cliticos[t]!);
    } else if (_sustantivos.containsKey(t)) {
      sustantivos.add(t);
    }
  }

  final persona = _sujetos[sujeto] ?? 0;
  final personaVerbo = persona == 0 ? 1 : persona; // sin sujeto: 1.ª persona
  var esPregunta = interrogativo != null;
  final partes = <String>[];

  // Sujeto que es un sustantivo (MAESTRO, COMPANERO): "el maestro".
  if (sujeto != null && _sustantivos.containsKey(sujeto)) {
    partes.add(_articulo(sujeto));
  }

  if (verbos.isNotEmpty) {
    final principal = verbos.first;
    final resto = verbos.sublist(1);
    final List<String> nucleo;
    if (_peticiones.contains(principal) && persona == 0) {
      esPregunta = true;
      nucleo = ['puede', _verbos[principal]![0]];
    } else if (principal == 'PODER' && resto.isNotEmpty) {
      nucleo = [_verbos['PODER']![personaVerbo], _verbos[resto.first]![0]];
      esPregunta = esPregunta || persona == 0 || persona == 1; // pedir permiso
    } else {
      nucleo = [_verbos[principal]![personaVerbo]];
    }
    if (negacion) partes.add('no');
    partes
      ..addAll(cliticos)
      ..addAll(nucleo);
    final indefinido = principal == 'TENER';
    for (final s in sustantivos) {
      var fraseNominal = _articulo(s, indefinido: indefinido);
      if (verbos.contains('IR')) {
        fraseNominal = fraseNominal.startsWith('el ')
            ? 'al${fraseNominal.substring(2)}'
            : 'a $fraseNominal';
      }
      partes.add(fraseNominal);
    }
  } else {
    if (sujeto == 'YO' && nombres.isNotEmpty) {
      partes.add('soy');
    } else if (interrogativo != null) {
      partes.add(interrogativo == 'DONDE' ? 'está' : 'es');
    } else if (tiempo.isNotEmpty && sustantivos.isNotEmpty) {
      partes.add('hay');
    }
    if (negacion) partes.insert(0, 'no');
    for (final s in sustantivos) {
      partes.add(
        (tiempo.isNotEmpty && interrogativo == null)
            ? _sustantivos[s]!.$1
            : _articulo(s),
      );
    }
  }

  partes.addAll(nombres);
  if (interrogativo != null) partes.insert(0, _interrogativos[interrogativo]!);
  final conTiempo = tiempo.isNotEmpty ? [...tiempo, ...partes] : partes;

  return _unir(
    inicio,
    _cerrar([conTiempo.join(' ')], pregunta: esPregunta, porFavor: porFavor),
    cierre,
  );
}

/// 'Hola.' + cuerpo + 'Gracias.'
String _unir(List<String> inicio, String cuerpo, List<String> cierre) {
  final piezas = <String>[
    if (inicio.isNotEmpty) _cerrar(inicio),
    cuerpo,
    if (cierre.isNotEmpty) _cerrar(cierre),
  ];
  return piezas.join(' ');
}

String _cerrar(
  List<String> partes, {
  bool pregunta = false,
  bool porFavor = false,
}) {
  var texto = partes.where((p) => p.isNotEmpty).join(', ');
  if (porFavor) texto = texto.isNotEmpty ? '$texto, por favor' : 'por favor';
  texto = _capitalizar(texto);
  return pregunta ? '¿$texto?' : '$texto.';
}
