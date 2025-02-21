// Importações necessárias
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Tela inicial com botões para diferentes tipos de digitalização
class MainScreen extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MainScreen({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventário'), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTypeButton(context, label: 'PATRIMÔNIO', scanType: 'patrimonio'),
            const SizedBox(height: 20),
            _buildTypeButton(context, label: 'MODELO', scanType: 'modelo'),
            const SizedBox(height: 30),
            const Text(
              'Selecione o tipo de digitalização',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton(BuildContext context, {required String label, required String scanType}) {
    return SizedBox(
      width: 250,
      child: ElevatedButton(
        onPressed: () => _navigateToCameraScreen(context, scanType),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _navigateToCameraScreen(BuildContext context, String scanType) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CameraScreen(cameras: cameras, scanType: scanType)),
    );
  }
}

/// Serviço para integração com Google Sheets
class GoogleSheetsService {
  static const _spreadsheetId = '18Q1GpMRtRc5EqWhFHA8ri5owaXfi0Jux7ANxj7vHLC8';
  static const _credentialsPath = 'assets/credentials.json';

  static final GoogleSheetsService _instance = GoogleSheetsService._internal();
  factory GoogleSheetsService() => _instance;
  GoogleSheetsService._internal();

  String? _patrimonio;
  String? _modelo;

  Future<ServiceAccountCredentials> _getCredentials() async {
    try {
      final jsonString = await rootBundle.loadString(_credentialsPath);
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      return ServiceAccountCredentials.fromJson(jsonData);
    } catch (e) {
      print('Erro ao carregar credenciais: $e');
      rethrow;
    }
  }

  Future<void> cacheData(String text, String scanType) async {
    try {
      if (scanType == 'patrimonio') {
        _patrimonio = text;
      } else if (scanType == 'modelo') {
        _modelo = text;
      }

      if (_patrimonio != null && _modelo != null) {
        await _appendData(_patrimonio!, _modelo!);
        _patrimonio = null;
        _modelo = null;
      }
    } catch (e) {
      print('Erro no cacheData: $e');
      rethrow;
    }
  }

  Future<void> _appendData(String patrimonio, String modelo) async {
    final credentials = await _getCredentials();
    final client = await clientViaServiceAccount(credentials, [SheetsApi.spreadsheetsScope]);
    final sheetsApi = SheetsApi(client);

    try {
      final timestamp = DateTime.now().toIso8601String();
      final valueRange = ValueRange.fromJson({
        'values': [[timestamp, patrimonio, modelo]]
      });

      await sheetsApi.spreadsheets.values.append(
        valueRange,
        _spreadsheetId,
        'A1',
        valueInputOption: 'USER_ENTERED',
        insertDataOption: 'INSERT_ROWS',
      );

      print('Dados enviados com sucesso!');
    } catch (e) {
      print('Erro no appendData: $e');
      throw Exception('Erro ao enviar para a planilha: ${e.toString()}');
    } finally {
      client.close();
    }
  }
}

  List<dynamic> _getFormattedValues(String text, String scanType) {
    final timestamp = DateTime.now().toIso8601String();
    return scanType == 'patrimonio' ? [timestamp, text] : [timestamp, '', text];
  }

/// Tela de captura com a câmera
class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String scanType;

  const CameraScreen({super.key, required this.cameras, required this.scanType});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _controller = CameraController(widget.cameras[0], ResolutionPreset.medium);
      await _controller.initialize();
    } catch (e) {
      print('Erro ao inicializar a câmera: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }
  // CAPTURA E PROCESSA A IMAGEM
  Future<void> _captureAndProcess() async {
    if (_isProcessing || !_controller.value.isInitialized) return;

    XFile? image; // Declare a variável fora do try
    setState(() => _isProcessing = true);

    try {
      image = await _controller.takePicture(); // Atribua o valor aqui
      final inputImage = InputImage.fromFilePath(image.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      await GoogleSheetsService().cacheData(recognizedText.text, widget.scanType);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.scanType.toUpperCase()} capturado!')),
        );
      }

    } catch (e) {
      print('Erro no processamento: $e');
    } finally {
      // Mova a exclusão do arquivo para dentro deste bloco
      if (image != null) {
        final file = File(image.path);
        if (await file.exists()) await file.delete();
      }

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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Digitalização em Andamento'), centerTitle: true),
      body: Column(
        children: [
          Expanded(child: CameraPreview(_controller)),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isProcessing
                ? const CircularProgressIndicator()
                : ElevatedButton(onPressed: _captureAndProcess, child: const Text('CAPTURAR')),
          ),
        ],
      ),
    );
  }
}
