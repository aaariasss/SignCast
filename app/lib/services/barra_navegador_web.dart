import 'dart:js_interop';
import 'dart:ui' show Color;

@JS('document')
external _Documento get _documento;

extension type _Documento._(JSObject _) implements JSObject {
  external _Elemento get documentElement;
  external _Elemento? get body;
  external _Elemento? querySelector(String selector);
}

extension type _Elemento._(JSObject _) implements JSObject {
  external _Estilo get style;
  external void setAttribute(String nombre, String valor);
}

extension type _Estilo._(JSObject _) implements JSObject {
  external set backgroundColor(String valor);
}

/// Safari tiñe la franja de arriba con el fondo de la página y con
/// `theme-color`. Si no se cambian, se ve una franja clara sobre la app oscura.
void pintarBarraNavegador(Color fondo) {
  try {
    final rgb = (fondo.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    final color = '#$rgb';
    _documento.documentElement.style.backgroundColor = color;
    _documento.body?.style.backgroundColor = color;
    _documento
        .querySelector('meta[name="theme-color"]')
        ?.setAttribute('content', color);
  } catch (_) {}
}
