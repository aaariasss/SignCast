import 'package:app/main.dart';
import 'package:app/services/permiso_camara.dart';
import 'package:app/services/reconocedor_falso.dart';
import 'package:app/services/voz.dart';
import 'package:app/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la bienvenida lleva a la pantalla del permiso de cámara', (
    tester,
  ) async {
    final estado = AppState(
      reconocedor: ReconocedorFalso(),
      voz: const VozNula(),
    );
    await tester.pumpWidget(SignCastApp(estado: estado));

    expect(find.text('Comenzar'), findsOneWidget);
    expect(find.text('en palabras'), findsOneWidget);

    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();

    expect(find.text('Activa tu cámara'), findsOneWidget);
    expect(find.text('Permitir cámara'), findsOneWidget);
  });

  testWidgets('si se niega el permiso se queda en la pantalla del permiso', (
    tester,
  ) async {
    final estado = AppState(
      reconocedor: ReconocedorFalso(),
      voz: const VozNula(),
      permisoCamara: _PermisoNegado(),
    );
    await tester.pumpWidget(SignCastApp(estado: estado));
    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Permitir cámara'));
    await tester.pumpAndSettle();

    expect(find.text('Activa tu cámara'), findsOneWidget);
    expect(find.textContaining('Sin la cámara'), findsOneWidget);
  });

  testWidgets(
    'la bienvenida sale siempre, aunque la cámara ya esté permitida',
    (tester) async {
      final estado = AppState(
        reconocedor: ReconocedorFalso(),
        voz: const VozNula(),
        permisoCamara: _PermisoConcedido(),
      );
      await tester.pumpWidget(SignCastApp(estado: estado));
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('Comenzar'), findsOneWidget);
      expect(find.text('en palabras'), findsOneWidget);
    },
  );
}

class _PermisoConcedido implements PermisoCamara {
  @override
  Future<EstadoPermiso> estado() async => EstadoPermiso.concedido;

  @override
  Future<EstadoPermiso> solicitar() async => EstadoPermiso.concedido;

  @override
  Future<void> abrirAjustes() async {}
}

class _PermisoNegado implements PermisoCamara {
  @override
  Future<EstadoPermiso> estado() async => EstadoPermiso.denegado;

  @override
  Future<EstadoPermiso> solicitar() async => EstadoPermiso.denegado;

  @override
  Future<void> abrirAjustes() async {}
}
