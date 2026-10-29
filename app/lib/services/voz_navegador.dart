import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'voces_plataforma.dart';
import 'voz.dart';

/// Lee las frases con la síntesis de voz del navegador (`flutter_tts` en web).
///
/// Prefiere español de México y, si el dispositivo no tiene esa voz, usa otra
/// variante del español. Funciona sin internet mientras la voz esté instalada
/// en el dispositivo. Los errores no se propagan: sin voz la app sigue
/// mostrando los subtítulos.
class VozNavegador implements Voz {
  VozNavegador({
    FlutterTts? tts,
    this.pausaTrasCortar = const Duration(milliseconds: 120),
    List<VozDisponible> Function()? voces,
  }) : _tts = tts ?? FlutterTts(),
       _voces = voces ?? listarVoces {
    _tts.setStartHandler(() => _marcar(true));
    _tts.setCompletionHandler(() => _marcar(false));
    _tts.setCancelHandler(() => _marcar(false));
    _tts.setErrorHandler((_) => _marcar(false));
  }

  /// Si el navegador nunca avisa que terminó, se da por terminada la lectura
  /// pasado este tiempo (más un poco por cada letra) para no dejar la cámara
  /// pausada.
  static const Duration _margen = Duration(seconds: 8);

  /// Idiomas en orden de preferencia.
  static const List<String> idiomas = ['es-MX', 'es-US', 'es-419', 'es-ES'];

  /// Espera entre cortar la lectura anterior y empezar la nueva.
  final Duration pausaTrasCortar;

  final FlutterTts _tts;
  final List<VozDisponible> Function() _voces;
  final ValueNotifier<bool> _hablando = ValueNotifier<bool>(false);
  Timer? _vencimiento;
  Future<void>? _configuracion;
  bool _preparada = false;

  @override
  ValueListenable<bool> get hablando => _hablando;

  void _marcar(bool valor) {
    _vencimiento?.cancel();
    _hablando.value = valor;
  }

  /// Marca que se va a hablar y programa el aviso de respaldo.
  void _empezar(String texto) {
    _hablando.value = true;
    _vencimiento?.cancel();
    _vencimiento = Timer(
      _margen + Duration(milliseconds: texto.length * 100),
      () => _hablando.value = false,
    );
  }

  /// Elige el idioma y la voz una sola vez. Si no hay ninguna voz en español
  /// disponible, deja `es-MX` y que el navegador use lo que tenga.
  Future<void> _configurar() async {
    await _elegirIdioma();
    await _elegirVoz();
  }

  Future<void> _elegirIdioma() async {
    for (final idioma in idiomas) {
      try {
        final disponible = await _tts.isLanguageAvailable(idioma);
        if (disponible == true || disponible == 1) {
          await _tts.setLanguage(idioma);
          return;
        }
      } catch (_) {}
    }
    try {
      await _tts.setLanguage(idiomas.first);
    } catch (_) {}
  }

  /// Si el navegador elige solo, puede escoger una voz que necesita internet
  /// y quedar en silencio sin conexión. Se escoge una voz en español que
  /// suene en el propio dispositivo, la de México primero.
  Future<void> _elegirVoz() async {
    try {
      final locales = _voces().where((v) => v.local).toList();
      VozDisponible? elegida;
      for (final idioma in idiomas) {
        final buscado = idioma.toLowerCase();
        for (final v in locales) {
          if (v.idiomaNormalizado == buscado) {
            elegida = v;
            break;
          }
        }
        if (elegida != null) break;
      }
      elegida ??= locales
          .where((v) => v.idiomaNormalizado.startsWith('es'))
          .firstOrNull;
      if (elegida == null) return;
      await _tts.setVoice({'name': elegida.nombre, 'locale': elegida.idioma});
    } catch (_) {}
  }

  @override
  Future<void> preparar() async {
    if (_preparada) return;
    _preparada = true;
    try {
      // Frase en blanco: no suena, pero cuenta como el primer audio iniciado
      // por un toque, que es lo que Safari exige. Va antes de cualquier
      // `await` para seguir dentro del toque.
      final silencio = _tts.speak(' ');
      _configuracion ??= _configurar();
      await silencio;
      await _configuracion;
    } catch (_) {}
  }

  @override
  Future<void> hablar(String texto, {required double velocidad}) async {
    if (texto.trim().isEmpty) return;
    _empezar(texto);
    try {
      await (_configuracion ??= _configurar());
      await _tts.stop();
      // Safari y Chrome se comen el inicio si se habla justo después de
      // cancelar: se espera un momento a que la cancelación termine.
      await Future<void>.delayed(pausaTrasCortar);
      // En web la velocidad es la del navegador: 1.0 es la normal.
      await _tts.setSpeechRate(velocidad);
      await _tts.speak(texto);
    } catch (_) {
      _marcar(false);
    }
  }

  @override
  Future<void> detener() async {
    _marcar(false);
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
