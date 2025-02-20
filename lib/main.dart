// Importações necessárias
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:googleapis/sheets/v4.dart' hide Padding;
import 'package:googleapis_auth/auth_io.dart';

// Função principal que inicializa o aplicativo
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

// Classe principal do aplicativo
class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MainScreen(cameras: cameras),
    );
  }
}

/// Tela inicial com botão para acessar a câmera
class MainScreen extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MainScreen({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt, size: 40),
              label: const Text(
                'INICIAR DIGITALIZAÇÃO',
                style: TextStyle(fontSize: 20),
              ),
              onPressed: () => _navigateToCameraScreen(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    vertical: 20, horizontal: 30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Toque no botão para abrir a câmera',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCameraScreen(BuildContext context) {
    Navigator.push(
        context,
        MaterialPageRoute(
        builder: (context) => CameraScreen(cameras: cameras),
      )
    );
  }
}
/// Serviço para integração com Google Sheets
class GoogleSheetsService {
  // Credenciais de autenticação
  static final _credentials = ServiceAccountCredentials.fromJson({
    "type": "service_account",
    "project_id": "inventario-ti-451517",
    "private_key_id": "c5926ed9a7c3e977d9baa8e671d799b9526db5ce",
    "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQDcFvTaCE4AiPHH\ndR36erRSLlFms/GLMUMGhiuIXTZzlrrnUKySTxkOK1ZYRWURIYUpI7QbrT2ZyqRs\nJtCpE7rC3XytalHYDG7CyByQYfop48msRf5ZR9v1dS7vnpaouQMasGpPb2FOEy8g\n3Rl31XEqCNGyDKJOiwCX2+YOqebT25aXDtprUJohKsKg3Zh/jeM8HMKMOEbDWPmR\nhqA/WYtIacRl5NmfVG3bVV7XE594wBbxv17PVmDwTVE0zOYDYslo+rUKhQvUN8Uf\ngQQNbSU8Y0dK+u4qHDJL4XJxGvhzrISHoWmyUh3DfsIz+2/Pup6OsNnkQwEoOxVn\nzjn49G4NAgMBAAECggEABW8DqIZf9p9q6LO5g7+XyBegptp2citLLlQNqxYyC/SC\ntMdHG22cfr8PKKq97ghX00YwYiaKyMs59/mVWTdFex4gv99KGf1klqZ+HgptNK+N\nARXRS778bTjxabUOnyfCLdyBI2jqjBTpKvSKdmzsmE8TbkPlle7Umusw6NfE/SH4\n/T/KpRjhfIUU4QvAmgshssnBzbQ5qhf7UXF1xXdNmtVrKYjS9jVj9EM71utjE07m\nXibb+jOufNSvI26DOwMqf9cnvQM5NE8ViyM8+tFXkAylrbya9mehx9RJf+WqCTc+\nKDNMB2txgd33kZ6XBNdzicsSpYkAkOW852naIZOFeQKBgQD8+xIumpFDfts1gSEp\nPMr02GENBYGrrMSnfaVMm5Am9b1qMgl6zsVbVSxsyxRtN7oLmFAMeFiq7u3NPFju\nnS/QgitYVDn/pJv6MvZ7Kqo6iN2OlD6Ua4F+xLF8fL5uSA1s4SXSgEhw6XLUViz2\nLeTpoXXZ8G4j8dJMAPhLS4A/wwKBgQDet2TL86GALrhjVW5UZUuslS8duGPMZwLZ\n6+K3fQLQhhdPSvWObwokTLJDqgXXpGPDCN1sHrf8LIo9YtUCO7vAaoDzoJ+AtbvG\nxnHVdJbfFtnwB7MQK66bkFp4THbQmOhKDWmEaX+PiCv6luYbbEgyrEN5XocA/HPk\nv/O/71QN7wKBgG8y0SgpCucXMLXQ/8mHjlKXdflqTTgv5fUVVn5Y9sEZTVwLiH0x\nvDBMPQ3JKj5ju2RzW+RPVfI0udR3zUN9VlIZlYHq69+B9InCsvMqqs618GVGpkdJ\nBg+516Y3kuEYzMXqJVzkxHLVOoM5KeRAAhnrvcjBVTh5iA2ec4VtN39PAoGAXoHw\nEePGaoBo2i4MbV+2pvt/TNtL7hbgTN0eDcLMiPP9vDYQ0WopIZIyKyhg5krp0n9W\nhmTaqfW0i6v+u73hRBttsPQ9+v4jOoxHDc81nmEyBfsebwQ6SeUNnvLDkGzyVUov\ntnKWILAmCWYzKvvd/zK+RyhnnXGDNFSH+LB0OJ0CgYBwVOI3L4f6n6u/KWdW5PjX\n0yYuG/x8gujqBlFZA6oZsGrKYOmnBuuvmf8UUXdKzGxB0F0MIzYb556SyzLrWTZk\nZxJwq0jcMtbidEeIJP99mp0fvvVhhRWr/+H5/ju8SWLY4n492M3jUR17Ccnj2CBp\nZWxGzvjSKJbsSbJoedooZw==\n-----END PRIVATE KEY-----\n",
    "client_email": "sheets-integration@inventario-ti-451517.iam.gserviceaccount.com",
    "client_id": "100024479860052586326",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/sheets-integration%40inventario-ti-451517.iam.gserviceaccount.com",
    "universe_domain": "googleapis.com"
  }
  );

  static const _spreadsheetId = '18Q1GpMRtRc5EqWhFHA8ri5owaXfi0Jux7ANxj7vHLC8';

  /// Envia dados para a planilha
  Future<void> appendData(String text) async {
    final client = await clientViaServiceAccount(_credentials, [SheetsApi.spreadsheetsScope]);
    final sheetsApi = SheetsApi(client);

    final valueRange = ValueRange.fromJson({
      'values': [
        [DateTime.now().toIso8601String(), text]
      ],
    });

    await sheetsApi.spreadsheets.values.append(
      valueRange,
      _spreadsheetId,
      'A1',
      valueInputOption: 'USER_ENTERED',
      insertDataOption: 'INSERT_ROWS',
    );

    client.close();
  }
}

/// Tela de captura com a câmera
class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

/// Estado da tela da câmera
class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  final TextRecognizer _textRecognizer = TextRecognizer();
  final _extractedText = '';
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  /// Inicializa o controlador da câmera
  Future<void> _initializeCamera() async {
    try {
      _controller = CameraController(
        widget.cameras[0],
        ResolutionPreset.medium,
      );
      await _controller.initialize();
    } catch (e) {
      print('Erro na câmera: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Processo completo de captura e processamento
  Future<void> _captureAndProcess() async {
    if (_isProcessing || !_controller.value.isInitialized) return;

    setState(() => _isProcessing = true);

    try {
      final XFile image = await _controller.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      await GoogleSheetsService().appendData(recognizedText.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados enviados com sucesso!')),
        );
      }

      final file = File(image.path);
      if (await file.exists()) await file.delete();

    } catch (e) {
      print('Erro no processamento: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Digitalização em Andamento'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: CameraPreview(_controller),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isProcessing
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _captureAndProcess,
              child: const Text('CAPTURAR DOCUMENTO'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _extractedText,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}