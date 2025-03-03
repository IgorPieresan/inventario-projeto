import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/drive/v3.dart' as drive;

/// Serviço para integração com o Google Drive.
/// Responsável por carregar as credenciais e enviar a imagem capturada para uma pasta no Drive.
class GoogleDriveService {
  // Caminho para o arquivo de credenciais nos assets (pode ser o mesmo do Sheets)
  static const _credentialsPath = 'assets/credentials.json';
  // ID da pasta no Google Drive onde as imagens serão salvas.
  // Substitua pelo ID real da pasta no Drive que você deseja utilizar.
  static const String _folderId = '1aDSiBZIVLcVx-igBOHbeYSof9YhRfj-y';

  /// Carrega as credenciais a partir do arquivo JSON.
  Future<ServiceAccountCredentials> _getCredentials() async {
    final jsonString = await rootBundle.loadString(_credentialsPath);
    final jsonData = json.decode(jsonString) as Map<String, dynamic>;
    return ServiceAccountCredentials.fromJson(jsonData);
  }

  /// Faz o upload da imagem para a pasta especificada no Google Drive.
  Future<void> uploadImage(File imageFile, String fileName) async {
    // Verifica se o arquivo existe e possui conteúdo
    if (!await imageFile.exists()) {
      print("Arquivo não existe: ${imageFile.path}");
      return;
    }
    int fileSize = await imageFile.length();
    if (fileSize == 0) {
      print("Arquivo vazio: ${imageFile.path}");
      return;
    }
    print("Arquivo encontrado. Tamanho: $fileSize bytes");

    final credentials = await _getCredentials();
    print("Credenciais carregadas com sucesso.");
    final client = await clientViaServiceAccount(credentials, [drive.DriveApi.driveScope]);
    print("Cliente autenticado com sucesso.");
    final driveApi = drive.DriveApi(client);


    var driveFile = drive.File();
    driveFile.name = fileName; // Alterado para usar o nome personalizado
    driveFile.parents = [_folderId];

    print("Arquivo para upload: ${driveFile.name}");
    print("Pasta de destino: $_folderId");

    final media = drive.Media(imageFile.openRead(), fileSize);

    try {
      final result = await driveApi.files.create(
        driveFile,
        uploadMedia: media,
        supportsAllDrives: true,
      );
      print('Upload concluído com sucesso. ID do arquivo: ${result.id}');
    } catch (e) {
      print('Erro ao enviar imagem para o Google Drive: $e');
    } finally {
      client.close();
      print("Cliente encerrado.");
    }
  }
}
