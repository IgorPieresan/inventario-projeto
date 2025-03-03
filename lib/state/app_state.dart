import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  String currentStep = 'patrimonio';
  String? scannedText;

  void updateScannedText(String text) {
    scannedText = text;
    notifyListeners();
  }

  void nextStep() {
    if (currentStep == 'patrimonio') {
      currentStep = 'modelo';
    }
    notifyListeners();
  }

  void reset() {
    scannedText = null;
    currentStep = 'patrimonio';
    notifyListeners();
  }
}
