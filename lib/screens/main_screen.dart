import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'multi_step_scan_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class MainScreen extends StatelessWidget {
  final List<CameraDescription> cameras;
  const MainScreen({Key? key, required this.cameras}) : super(key: key);

  static const String googleSheetsUrl =
      'https://docs.google.com/spreadsheets/d/118Q1GpMRtRc5EqWhFHA8ri5owaXfi0Jux7ANxj7vHLC8/edit';
  static const String googleDriveUrl =
      'https://drive.google.com/drive/folders/1aDSiBZIVLcVx-igBOHbeYSof9YhRfj-y';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventário'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navegar para configurações (a implementar)
            },
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 300,
              height: 100,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          MultiStepScanScreen(cameras: cameras),
                    ),
                  );
                },
                child: const Text(
                  'Iniciar Digitalização',
                  style: TextStyle(fontSize: 26),
                ),
              ),
            ),
            const SizedBox(height: 100),
            SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final Uri sheetsUri = Uri.parse(googleSheetsUrl);
                  if (!await launchUrl(sheetsUri, mode: LaunchMode.externalApplication)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Não foi possível abrir a planilha.")),
                    );
                  }
                },
                child: const Text('Abrir Planilha Sheets'),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final Uri driveUri = Uri.parse(googleDriveUrl);
                  if (!await launchUrl(driveUri, mode: LaunchMode.externalApplication)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Não foi possível abrir a pasta no Drive.")),
                    );
                  }
                },
                child: const Text('Abrir Pasta no Drive'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
