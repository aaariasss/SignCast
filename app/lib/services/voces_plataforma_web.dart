import 'dart:js_interop';

import 'voz_disponible.dart';

@JS('speechSynthesis')
external _Sintesis get _sintesis;

extension type _Sintesis._(JSObject _) implements JSObject {
  external JSArray<_VozJs> getVoices();
  external void speak(_Enunciado enunciado);
  external void resume();
}

@JS('SpeechSynthesisUtterance')
extension type _Enunciado._(JSObject _) implements JSObject {
  external _Enunciado(String texto);
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

/// Desbloquea el audio de Safari. Habla un texto vacío directo en
/// `speechSynthesis`, de forma síncrona, para que cuente como audio iniciado
/// por el toque del usuario (pasando por el plugin llega ya fuera del toque y
/// Safari lo ignora). Tiene que ser vacío: el iPhone no respeta el volumen en
/// cero y diría en voz alta cualquier letra.
void desbloquearSintesis() {
  try {
    _sintesis.speak(_Enunciado(''));
  } catch (_) {}
}

/// Safari a veces deja la síntesis en pausa después de cancelar; reanudarla
/// antes de hablar no hace daño si no lo estaba.
void reanudarSintesis() {
  try {
    _sintesis.resume();
  } catch (_) {}
}
