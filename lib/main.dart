// Importações necessárias para funcionamento do app, acesso à câmera, ML Kit, Google Sheets e Google Drive.
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:googleapis/sheets/v4.dart' hide Padding;
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/drive/v3.dart' as drive;

/// Função principal que inicializa o aplicativo.
/// Garante a inicialização dos Widgets do Flutter, obtém as câmeras disponíveis e inicia o app.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras(); // Lista de câmeras disponíveis
  runApp(MyApp(cameras: cameras));
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
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MainScreen(cameras: cameras), // Tela inicial do app
    );
  }
}

/// Tela inicial com botões para seleção do tipo de digitalização.
/// Permite escolher entre "PATRIMÔNIO" e "MODELO".
class MainScreen extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MainScreen({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventário'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Botão para digitalização de Patrimônio
            _buildTypeButton(context, label: 'PATRIMÔNIO', scanType: 'patrimonio'),
            const SizedBox(height: 20),
            // Botão para digitalização de Modelo
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

  /// Método auxiliar para construir os botões de seleção.
  Widget _buildTypeButton(BuildContext context, {required String label, required String scanType}) {
    return SizedBox(
      width: 250,
      child: ElevatedButton(
        // Ao pressionar, navega para a tela de captura, passando o tipo de digitalização
        onPressed: () => _navigateToCameraScreen(context, scanType),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// Método que navega para a tela de câmera, passando as câmeras e o tipo de scan.
  void _navigateToCameraScreen(BuildContext context, String scanType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(cameras: cameras, scanType: scanType),
      ),
    );
  }
}

/// Serviço para integração com o Google Sheets.
/// Responsável por carregar as credenciais, armazenar dados temporariamente e enviar os dados para a planilha.
class GoogleSheetsService {
  // ID da planilha no Google Sheets
  static const _spreadsheetId = '18Q1GpMRtRc5EqWhFHA8ri5owaXfi0Jux7ANxj7vHLC8';
  // Caminho para o arquivo de credenciais armazenado na pasta assets
  static const _credentialsPath = 'assets/credentials.json';

  // Implementação do padrão Singleton para garantir uma única instância do serviço.
  static final GoogleSheetsService _instance = GoogleSheetsService._internal();
  factory GoogleSheetsService() => _instance;
  GoogleSheetsService._internal();

  // Variáveis para armazenar temporariamente os dados
  String? _patrimonio;
  String? _modelo;

  /// Carrega as credenciais a partir do arquivo JSON contido em assets.
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

  /// Armazena temporariamente os dados extraídos.
  /// Quando ambos os valores (patrimônio e modelo) estiverem preenchidos, envia os dados para a planilha.
  Future<void> cacheData(String text, String scanType) async {
    try {
      if (scanType == 'patrimonio') {
        _patrimonio = text;
      } else if (scanType == 'modelo') {
        _modelo = text;
      }

      // Envia os dados para o Google Sheets quando ambos os campos estiverem preenchidos.
      if (_patrimonio != null && _modelo != null) {
        await _appendData(_patrimonio!, _modelo!);
        // Limpa o cache após o envio.
        _patrimonio = null;
        _modelo = null;
      }
    } catch (e) {
      print('Erro no cacheData: $e');
      rethrow;
    }
  }

  /// Método privado que envia os dados para a planilha do Google Sheets.
  /// Os dados são enviados como uma nova linha contendo o timestamp, patrimônio e modelo.
  Future<void> _appendData(String patrimonio, String modelo) async {
    final credentials = await _getCredentials();
    final client = await clientViaServiceAccount(credentials, [SheetsApi.spreadsheetsScope]);
    final sheetsApi = SheetsApi(client);

    try {
      final timestamp = DateTime.now().toIso8601String();
      // Monta os valores na linha a ser adicionada.
      final valueRange = ValueRange.fromJson({
        'values': [[timestamp, patrimonio, modelo]]
      });

      // Envia os dados para a planilha, inserindo uma nova linha.
      await sheetsApi.spreadsheets.values.append(
        valueRange,
        _spreadsheetId,
        'A1', // Ponto inicial para a inserção
        valueInputOption: 'USER_ENTERED',
        insertDataOption: 'INSERT_ROWS',
      );

      print('Dados enviados com sucesso para o Google Sheets!');
    } catch (e) {
      print('Erro no appendData: $e');
      throw Exception('Erro ao enviar para a planilha: ${e.toString()}');
    } finally {
      client.close(); // Fecha o cliente para liberar recursos.
    }
  }
}

/// Serviço para integração com o Google Drive.
/// Responsável por carregar as credenciais e enviar a imagem capturada para uma pasta no Drive.
class GoogleDriveService {
  // Caminho para o arquivo de credenciais nos assets (pode ser o mesmo do Sheets)
  static const _credentialsPath = 'assets/credentials.json';
  // ID da pasta no Google Drive onde as imagens serão salvas.
  // Substitua 'YOUR_FOLDER_ID_HERE' pelo ID real da pasta no Google Drive.
  static const String _folderId = '1aDSiBZIVLcVx-igBOHbeYSof9YhRfj-y';

  /// Carrega as credenciais a partir do arquivo JSON.
  Future<ServiceAccountCredentials> _getCredentials() async {
    final jsonString = await rootBundle.loadString(_credentialsPath);
    final jsonData = json.decode(jsonString) as Map<String, dynamic>;
    return ServiceAccountCredentials.fromJson(jsonData);
  }

  /// Faz o upload da imagem para a pasta especificada no Google Drive.
  Future<void> uploadImage(File imageFile) async {
    final credentials = await _getCredentials();
    // Cria um cliente autenticado com o escopo de arquivos do Drive.
    final client = await clientViaServiceAccount(credentials, [drive.DriveApi.driveFileScope]);
    final driveApi = drive.DriveApi(client);

    // Cria o objeto que representa o arquivo a ser enviado.
    var driveFile = drive.File();
    // Define o nome do arquivo com base no nome do arquivo local.
    driveFile.name = imageFile.path.split('/').last;
    // Define a pasta de destino no Google Drive.
    driveFile.parents = [_folderId];

    // Cria o objeto Media para o upload, informando o stream e o tamanho do arquivo.
    final media = drive.Media(imageFile.openRead(), await imageFile.length());

    try {
      // Realiza o upload do arquivo para o Google Drive.
      final result = await driveApi.files.create(driveFile, uploadMedia: media);
      print('Imagem enviada para o Google Drive com ID: ${result.id}');
    } catch (e) {
      print('Erro ao enviar imagem para o Google Drive: $e');
    } finally {
      client.close(); // Fecha o cliente para liberar recursos.
    }
  }
}

/// Tela de captura com a câmera.
/// Exibe a pré-visualização da câmera, captura a imagem, extrai o texto e permite que o usuário edite o conteúdo
/// antes de enviar os dados para o Google Sheets. Além disso, envia a imagem para o Google Drive.
class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String scanType; // Pode ser 'patrimonio' ou 'modelo'

  const CameraScreen({super.key, required this.cameras, required this.scanType});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller; // Controlador da câmera
  final TextRecognizer _textRecognizer = TextRecognizer(); // Instância do ML Kit para reconhecimento de texto
  bool _isLoading = true; // Indica se a câmera está carregando
  bool _isProcessing = false; // Indica se a imagem está sendo processada

  @override
  void initState() {
    super.initState();
    _initializeCamera(); // Inicializa a câmera ao criar a tela
  }

  /// Inicializa o controlador da câmera com resolução média.
  Future<void> _initializeCamera() async {
    try {
      _controller = CameraController(widget.cameras[0], ResolutionPreset.medium);
      await _controller.initialize();
    } catch (e) {
      print('Erro ao inicializar a câmera: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  /// Método que captura uma imagem, processa o texto extraído e permite que o usuário edite o conteúdo.
  /// Em seguida, envia os dados para o Google Sheets e a imagem para o Google Drive.
  Future<void> _captureAndProcess() async {
    // Verifica se a câmera já está processando ou não está inicializada.
    if (_isProcessing || !_controller.value.isInitialized) return;

    XFile? image; // Variável para armazenar a imagem capturada
    setState(() => _isProcessing = true);

    try {
      // Captura a imagem com a câmera.
      image = await _controller.takePicture();
      // Cria um objeto InputImage para o ML Kit a partir do caminho da imagem.
      final inputImage = InputImage.fromFilePath(image.path);
      // Processa a imagem para extrair o texto.
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // Exibe um diálogo com um campo de texto editável para que o usuário revise o texto extraído.
      final editedText = await showDialog<String>(
        context: context,
        builder: (context) {
          final controller = TextEditingController(text: recognizedText.text);
          return AlertDialog(
            title: const Text('Editar texto extraído'),
            content: TextField(
              controller: controller,
              maxLines: null,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              // Botão para cancelar a edição.
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              // Botão para confirmar a edição e retornar o texto atualizado.
              ElevatedButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text('Confirmar'),
              ),
            ],
          );
        },
      );

      // Se o usuário confirmou a edição (texto não nulo e não vazio), envia os dados para o Google Sheets.
      if (editedText != null && editedText.isNotEmpty) {
        await GoogleSheetsService().cacheData(editedText, widget.scanType);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.scanType.toUpperCase()} capturado!')),
          );
        }
      }

      // Faz o upload da imagem para o Google Drive.
      await GoogleDriveService().uploadImage(File(image.path));

    } catch (e) {
      print('Erro no processamento: $e');
    } finally {
      // Após o processamento, remove a imagem salva temporariamente.
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
    // Libera os recursos da câmera e do reconhecedor de texto.
    _controller.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Enquanto a câmera estiver carregando, exibe um indicador de progresso.
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // Exibe a pré-visualização da câmera e um botão para capturar a imagem.
    return Scaffold(
      appBar: AppBar(title: const Text('Digitalização em Andamento'), centerTitle: true),
      body: Column(
        children: [
          Expanded(child: CameraPreview(_controller)),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isProcessing
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _captureAndProcess, // Inicia a captura, edição e envio
              child: const Text('CAPTURAR'),
            ),
          ),
        ],
      ),
    );
  }
}
