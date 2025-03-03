import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:provider/provider.dart';
import '../services/google_sheets_service.dart';
import '../state/app_state.dart';
import '../services/google_drive_service.dart';

/// Tela de digitalização multietapa.
/// Gerencia duas etapas:
/// 1. "patrimonio" – Captura ou inserção manual dos dados de patrimônio.
/// 2. "modelo" – Captura ou inserção manual dos dados de modelo.
/// Em cada etapa, o usuário pode:
/// - Capturar a imagem (CAPTURAR)
/// - Inserir o texto manualmente (INSERIR MANUALMENTE)
/// - Alternar o flash da câmera (FLASH ON/OFF)
/// Após a edição, há um botão para avançar (PRÓXIMO) ou finalizar e enviar (FINALIZAR E ENVIAR).
class MultiStepScanScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const MultiStepScanScreen({super.key, required this.cameras});

  @override
  State<MultiStepScanScreen> createState() => _MultiStepScanScreenState();
}

class _MultiStepScanScreenState extends State<MultiStepScanScreen> {
  late CameraController _controller;
  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _isLoading = true;
  bool _isProcessing = false;
  // Variável para controlar o estado do flash (ligado/desligado)
  bool _isFlashOn = false;
  // Etapa atual: 'patrimonio' ou 'modelo'
  String currentStep = 'patrimonio';
  // Armazena o texto capturado ou inserido manualmente na etapa atual
  String? scannedText;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  /// Inicializa o controlador da câmera com resolução média e define o flash como desligado.
  Future<void> _initializeCamera() async {
    try {
      _controller = CameraController(widget.cameras[0], ResolutionPreset.medium);
      await _controller.initialize();
      await _controller.setFlashMode(FlashMode.off);
    } catch (e) {
      print('Erro ao inicializar a câmera: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  /// Alterna o estado do flash da câmera.
  Future<void> _toggleFlash() async {
    if (!_controller.value.isInitialized) return;
    try {
      if (_isFlashOn) {
        await _controller.setFlashMode(FlashMode.off);
      } else {
        await _controller.setFlashMode(FlashMode.always);
      }
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      print('Erro ao alternar o flash: $e');
    }
  }

  /// Captura a imagem, extrai o texto usando ML Kit, permite a edição via diálogo,
  /// e chama o upload da imagem para o Google Drive.
  Future<void> _captureAndProcess() async {
    if (_isProcessing || !_controller.value.isInitialized) return;

    XFile? image;
    setState(() => _isProcessing = true);

    try {
      image = await _controller.takePicture();

      // Gerar timestamp no formato HHmm
      final now = DateTime.now();
      final fileName = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.jpg';

      final inputImage = InputImage.fromFilePath(image.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // Exibe diálogo para edição do texto extraído.
      final editedText = await showDialog<String>(
        context: context,
        builder: (context) {
          final controller = TextEditingController(text: recognizedText.text);
          return AlertDialog(
            title: Text('Editar texto extraído ($currentStep)'),
            content: TextField(
              controller: controller,
              maxLines: null,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text('Confirmar'),
              ),
            ],
          );
        },
      );

      if (editedText != null && editedText.isNotEmpty) {
        setState(() {
          scannedText = editedText;
        });
        // Upload com nome baseado no horário
        await GoogleDriveService().uploadImage(File(image.path), fileName);
      }
    } catch (e) {
      print('Erro no processamento: $e');
    } finally {
      if (image != null) {
        final file = File(image.path);
        if (await file.exists()) await file.delete();
      }
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Permite inserir ou editar o texto manualmente sem usar a câmera.
  Future<void> _editTextManually() async {
    final manualText = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: scannedText ?? '');
        return AlertDialog(
          title: Text('Inserir texto manualmente ($currentStep)'),
          content: TextField(
            controller: controller,
            maxLines: null,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Digite o texto manualmente',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (manualText != null && manualText.isNotEmpty) {
      setState(() {
        scannedText = manualText;
      });
    }
  }

  /// Manipula o botão de avanço ou finalização:
  /// - Se estiver na etapa "patrimonio", salva o texto e avança para "modelo".
  /// - Se estiver em "modelo", salva, finaliza e envia os dados.
  Future<void> _handleNextOrFinish() async {
    if (scannedText == null || scannedText!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nenhum texto capturado.")),
      );
      return;
    }

    final sheetsService = GoogleSheetsService();

    if (currentStep == 'patrimonio') {
      await sheetsService.cacheData(scannedText!, 'patrimonio');
      setState(() {
        currentStep = 'modelo';
        scannedText = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Agora, registre o MODELO.")),
      );
    } else if (currentStep == 'modelo') {
      await sheetsService.cacheData(scannedText!, 'modelo');
      await sheetsService.finalizeData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Processo finalizado e dados enviados.")),
      );
      Navigator.pop(context);
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
        title: Text("Digitalização em Andamento ($currentStep)"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Exibe a pré-visualização da câmera com o botão de flash sobreposto.
          Expanded(
            child: Stack(
              children: [
                CameraPreview(_controller),
                Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    icon: Icon(
                      _isFlashOn ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: _toggleFlash,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Botão para capturar imagem e extrair texto.
                _isProcessing
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _captureAndProcess,
                  child: const Text("CAPTURAR"),
                ),
                const SizedBox(height: 16),
                // Botão para inserir ou editar texto manualmente.
                ElevatedButton(
                  onPressed: _editTextManually,
                  child: const Text("INSERIR MANUALMENTE"),
                ),
                const SizedBox(height: 16),
                // Botão para avançar para a próxima etapa ou finalizar e enviar, se houver texto.
                if (scannedText != null)
                  ElevatedButton(
                    onPressed: _handleNextOrFinish,
                    child: Text(
                      currentStep == 'patrimonio'
                          ? "PRÓXIMO"
                          : "FINALIZAR E ENVIAR",
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
