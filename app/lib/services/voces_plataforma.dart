// Lista las voces del dispositivo: la síntesis de voz del navegador en web y,
// fuera de él, ninguna. Ofrece `List<VozDisponible> listarVoces()`.
export 'voces_plataforma_otro.dart'
    if (dart.library.js_interop) 'voces_plataforma_web.dart';
export 'voz_disponible.dart';
