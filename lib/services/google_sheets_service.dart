import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:googleapis/sheets/v4.dart' hide Padding;
import 'package:googleapis_auth/auth_io.dart';

/// Serviço para integração com o Google Sheets.
/// Responsável por carregar as credenciais, armazenar dados temporariamente e enviar os dados para a planilha.
class GoogleSheetsService {
  // ID da planilha no Google Sheets
  static const _spreadsheetId =
      '18Q1GpMRtRc5EqWhFHA8ri5owaXfi0Jux7ANxj7vHLC8';
  // Caminho para o arquivo de credenciais armazenado na pasta assets
  static const _credentialsPath = 'assets/credentials.json';

  // Implementação do padrão Singleton para garantir uma única instância.
  static final GoogleSheetsService _instance = GoogleSheetsService._internal();
  factory GoogleSheetsService() => _instance;
  GoogleSheetsService._internal();

  // Variáveis para armazenar os dados temporariamente
  String? _patrimonio;
  String? _modelo;

  /// Carrega as credenciais a partir do arquivo JSON.
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

  /// Armazena os dados para cada etapa.
  Future<void> cacheData(String text, String scanType) async {
    try {
      if (scanType == 'patrimonio') {
        _patrimonio = text;
      } else if (scanType == 'modelo') {
        _modelo = text;
      }
    } catch (e) {
      print('Erro no cacheData: $e');
      rethrow;
    }
  }

  /// Métódo que finaliza o processo e envia os dados para o Google Sheets.
  /// Deve ser chamado após a etapa de modelo.
  Future<void> finalizeData() async {
    if (_patrimonio != null && _modelo != null) {
      final credentials = await _getCredentials();
      final client = await clientViaServiceAccount(
          credentials, [SheetsApi.spreadsheetsScope]);
      final sheetsApi = SheetsApi(client);
      try {
        final now = DateTime.now();
        final timestamp = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        final valueRange = ValueRange.fromJson({
          'values': [[timestamp, _patrimonio, _modelo]]
        });
        await sheetsApi.spreadsheets.values.append(
          valueRange,
          _spreadsheetId,
          'A1', // Ponto inicial para a inserção
          valueInputOption: 'USER_ENTERED',
          insertDataOption: 'INSERT_ROWS',
        );
        print('Dados enviados com sucesso para o Google Sheets!');
      } catch (e) {
        print('Erro ao enviar dados para o Sheets: $e');
      } finally {
        client.close();
        _patrimonio = null;
        _modelo = null;
      }
    } else {
      print('Dados incompletos para envio.');
    }
  }
}