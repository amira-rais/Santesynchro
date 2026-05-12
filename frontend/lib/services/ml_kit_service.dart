import 'dart:io';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

class MlKitService {
  static final ImageLabelerOptions _options = ImageLabelerOptions(confidenceThreshold: 0.4);
  static final ImageLabeler _imageLabeler = ImageLabeler(options: _options);

  /// Analyse une image locale et retourne une liste de labels (chaînes de caractères)
  static Future<List<String>> getLabels(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final List<ImageLabel> labels = await _imageLabeler.processImage(inputImage);
      
      // On extrait uniquement le texte des labels
      return labels.map((label) => label.label).toList();
    } catch (e) {
      print('ML Kit Error: $e');
      return [];
    }
  }

  /// Libère les ressources
  static void dispose() {
    _imageLabeler.close();
  }
}
