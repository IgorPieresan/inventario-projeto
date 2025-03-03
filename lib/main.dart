import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'state/app_state.dart';
import 'screens/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final List<CameraDescription> cameras = await availableCameras();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MyApp(cameras: cameras),
    ),
  );
}

/// Classe principal do aplicativo.
/// Define o MaterialApp e a tela inicial, passando a lista de câmeras.
class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Remove o banner de debug
      title: 'Inventário',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MainScreen(cameras: cameras), // Tela inicial do app
    );
  }
}

