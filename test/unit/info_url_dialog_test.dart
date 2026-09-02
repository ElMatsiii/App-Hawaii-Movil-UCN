import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hawaii_app/shared/widgets/info_url_dialog.dart';

void main() {
  testWidgets('InfoUrlDialog renderiza titulo, descripcion y boton correctamente', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InfoUrlDialog(
            titulo: 'Instructivos UCN',
            descripcion: 'Accede a los instructivos de la Escuela de Ingeniería.',
            url: 'https://losvilos.ucn.cl/InstructivosEscuelaIngenieria/',
            labelBoton: 'Abrir enlace',
          ),
        ),
      ),
    );

    expect(find.text('Instructivos UCN'), findsOneWidget);
    expect(
      find.text('Accede a los instructivos de la Escuela de Ingeniería.'),
      findsOneWidget,
    );
    expect(find.text('Abrir enlace'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });
}
