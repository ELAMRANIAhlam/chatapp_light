import 'dart:convert';
import 'dart:io';

class StorageService {
  // Conversion fichier en Base64
  Future<String> fileToBase64(File file) async {
    return base64Encode(await file.readAsBytes());
  }
}