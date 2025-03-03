import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:untitled/screens/main_screen.dart';

void main() {
  testWidgets('MainScreen exibe os botões esperados', (WidgetTester tester) async {
    // Constrói a MainScreen dentro de um MaterialApp para fornecer contexto de tema e navegação.
    await tester.pumpWidget(
      MaterialApp(
        home: MainScreen(cameras: []),
      ),
    );

    // Verifica se o botão "Iniciar Digitalização" está presente.
    expect(find.text('Iniciar Digitalização'), findsOneWidget);

    // Verifica se os botões para abrir Sheets e Drive estão presentes.
    expect(find.text('Abrir Planilha Sheets'), findsOneWidget);
    expect(find.text('Abrir Pasta no Drive'), findsOneWidget);
  });
}
