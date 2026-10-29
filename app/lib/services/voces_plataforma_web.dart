import 'dart:js_interop';

import 'voz_disponible.dart';

@JS('speechSynthesis')
external _Sintesis get _sintesis;

extension type _Sintesis._(JSObject _) implements JSObject {
  external JSArray<_VozJs> getVoices();
}

extension type _VozJs._(JSObject _) implements JSObject {
  external String get name;
  external String get lang;
  external bool get localService;
}

/// Voces de `speechSynthesis`. Safari las llena poco después de abrir la
/// página, así que se consulta justo antes de hablar.
List<VozDisponible> listarVoces() {
  try {
    return [
      for (final v in _sintesis.getVoices().toDart)
        VozDisponible(nombre: v.name, idioma: v.lang, local: v.localService),
    ];
  } catch (_) {
    return const [];
  }
}
