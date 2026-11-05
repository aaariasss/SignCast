import 'package:app/services/voz_disponible.dart';
import 'package:app/services/voz_navegador.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// El plugin manda unos argumentos sueltos y otros en un mapa.
Object? valor(MethodCall llamada) {
  final a = llamada.arguments;
  return a is Map ? a.values.first : a;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const canal = MethodChannel('flutter_tts');
  late List<MethodCall> llamadas;
  late Set<String> idiomasDisponibles;

  setUp(() {
    llamadas = [];
    idiomasDisponibles = {'es-MX', 'es-ES'};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (llamada) async {
          llamadas.add(llamada);
          if (llamada.method == 'isLanguageAvailable') {
            return idiomasDisponibles.contains(valor(llamada));
          }
          return 1;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null);
  });

  Iterable<MethodCall> de(String metodo) =>
      llamadas.where((l) => l.method == metodo);

  test('lee la frase en español de México a la velocidad pedida', () async {
    final voz = VozNavegador(tts: FlutterTts());

    await voz.hablar('Hola, buenos días.', velocidad: 0.8);

    expect(valor(de('setLanguage').single), 'es-MX');
    expect(valor(de('setSpeechRate').single), 0.8);
    expect(valor(de('speak').single), 'Hola, buenos días.');
    // Corta lo anterior antes de hablar.
    final orden = llamadas.map((l) => l.method).toList();
    expect(orden.indexOf('stop'), lessThan(orden.indexOf('speak')));
  });

  test('sin voz de México usa otra variante del español', () async {
    idiomasDisponibles = {'es-US'};
    final voz = VozNavegador(tts: FlutterTts());

    await voz.hablar('Gracias.', velocidad: 1.0);

    expect(valor(de('setLanguage').single), 'es-US');
  });

  test('sin ninguna voz en español deja es-MX', () async {
    idiomasDisponibles = {};
    final voz = VozNavegador(tts: FlutterTts());

    await voz.hablar('Gracias.', velocidad: 1.0);

    expect(valor(de('setLanguage').single), 'es-MX');
  });

  test('el idioma se elige una sola vez', () async {
    final voz = VozNavegador(tts: FlutterTts());

    await voz.hablar('Uno.', velocidad: 1.0);
    await voz.hablar('Dos.', velocidad: 1.0);

    expect(de('setLanguage'), hasLength(1));
    expect(de('speak'), hasLength(2));
  });

  test('un texto vacío no suena', () async {
    final voz = VozNavegador(tts: FlutterTts());

    await voz.hablar('   ', velocidad: 1.0);

    expect(de('speak'), isEmpty);
  });

  Future<void> aviso(String metodo) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'flutter_tts',
          const StandardMethodCodec().encodeMethodCall(MethodCall(metodo)),
          (_) {},
        );
  }

  test('preparar desbloquea el audio sin pasar por el plugin', () async {
    var desbloqueos = 0;
    final voz = VozNavegador(
      tts: FlutterTts(),
      desbloquear: () => desbloqueos++,
    );

    await voz.preparar();

    expect(desbloqueos, 1);
    expect(de('speak'), isEmpty);
  });

  test('preparar se repite hasta que el navegador empieza a hablar', () async {
    var desbloqueos = 0;
    final voz = VozNavegador(
      tts: FlutterTts(),
      desbloquear: () => desbloqueos++,
    );

    await voz.preparar();
    await voz.preparar();
    expect(desbloqueos, 2);

    await voz.hablar('Hola.', velocidad: 1.0);
    await aviso('speak.onStart');
    await voz.preparar();

    expect(desbloqueos, 2);
  });

  test('si no había voces, las elige en la siguiente frase', () async {
    var lista = <VozDisponible>[];
    final voz = VozNavegador(tts: FlutterTts(), voces: () => lista);

    await voz.hablar('Uno.', velocidad: 1.0);
    expect(de('setVoice'), isEmpty);

    lista = const [
      VozDisponible(nombre: 'Siri Voz 2', idioma: 'es_MX', local: true),
    ];
    await voz.hablar('Dos.', velocidad: 1.0);

    expect(de('setVoice'), hasLength(1));
  });

  test('un fallo de la síntesis no rompe la app', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (_) async {
          throw PlatformException(code: 'sin_voz');
        });
    final voz = VozNavegador(tts: FlutterTts());

    await voz.hablar('Hola.', velocidad: 1.0);
    await voz.preparar();
    await voz.detener();
  });

  test('hablando es verdadero mientras suena la frase', () async {
    final voz = VozNavegador(tts: FlutterTts());
    expect(voz.hablando.value, isFalse);

    await voz.hablar('Hola.', velocidad: 1.0);
    expect(voz.hablando.value, isTrue);

    await aviso('speak.onComplete');
    expect(voz.hablando.value, isFalse);
  });

  test('detener deja de marcar que está hablando', () async {
    final voz = VozNavegador(tts: FlutterTts());

    await voz.hablar('Hola.', velocidad: 1.0);
    await voz.detener();

    expect(voz.hablando.value, isFalse);
  });

  test('si el navegador falla, hablando vuelve a falso', () async {
    final voz = VozNavegador(tts: FlutterTts());

    await voz.hablar('Hola.', velocidad: 1.0);
    await aviso('speak.onError');

    expect(voz.hablando.value, isFalse);
  });

  test('elige una voz en español que suene sin internet', () async {
    final voz = VozNavegador(
      tts: FlutterTts(),
      voces: () => const [
        VozDisponible(nombre: 'Paulina', idioma: 'es-MX', local: false),
        VozDisponible(nombre: 'Siri Voz 2', idioma: 'es_MX', local: true),
        VozDisponible(nombre: 'Monica', idioma: 'es-ES', local: true),
        VozDisponible(nombre: 'Samantha', idioma: 'en-US', local: true),
      ],
    );

    await voz.hablar('Hola.', velocidad: 1.0);

    expect(de('setVoice').single.arguments, {
      'name': 'Siri Voz 2',
      'locale': 'es_MX',
    });
  });

  test('sin voz de México local usa otra voz local en español', () async {
    final voz = VozNavegador(
      tts: FlutterTts(),
      voces: () => const [
        VozDisponible(nombre: 'Paulina', idioma: 'es-MX', local: false),
        VozDisponible(nombre: 'Monica', idioma: 'es-ES', local: true),
      ],
    );

    await voz.hablar('Hola.', velocidad: 1.0);

    expect(valor(de('setVoice').single), 'Monica');
  });

  test('sin voces locales deja que el navegador elija', () async {
    final voz = VozNavegador(
      tts: FlutterTts(),
      voces: () => const [
        VozDisponible(nombre: 'Paulina', idioma: 'es-MX', local: false),
      ],
    );

    await voz.hablar('Hola.', velocidad: 1.0);

    expect(de('setVoice'), isEmpty);
  });

  test('detener corta la lectura', () async {
    final voz = VozNavegador(tts: FlutterTts());

    await voz.detener();

    expect(de('stop'), hasLength(1));
  });
}
