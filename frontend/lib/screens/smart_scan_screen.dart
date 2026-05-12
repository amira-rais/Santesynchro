import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend/services/api.dart';
import 'package:frontend/services/ml_kit_service.dart';
import 'package:frontend/services/food_mapping_service.dart';
import 'package:frontend/screens/product_search_screen.dart';
import 'package:frontend/core/app_localizations.dart';

class SmartScanScreen extends StatefulWidget {
  const SmartScanScreen({super.key});

  @override
  State<SmartScanScreen> createState() => _SmartScanScreenState();
}

class _SmartScanScreenState extends State<SmartScanScreen> {
  File? _pickedImage;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _imageAnalysisResult;
  String? _imageError;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
        source: source, imageQuality: 80, maxWidth: 1024);
    if (xFile == null) return;
    setState(() {
      _pickedImage = File(xFile.path);
      _imageAnalysisResult = null;
      _imageError = null;
    });
    await _analyzeImage();
  }

  Future<void> _analyzeImage() async {
    if (_pickedImage == null) return;
    setState(() {
      _isAnalyzing = true;
      _imageError = null;
    });
    try {
      // 1. Tenter l'analyse précise via Ollama (Backend)
      final result = await Api.analyzeFoodImageOllama(_pickedImage!);
      setState(() {
        _imageAnalysisResult = result;
        _isAnalyzing = false;
      });
    } catch (e) {
      print("Erreur Ollama/Backend, passage au fallback local: $e");
      try {
        // 2. Fallback local via ML Kit si internet est indisponible
        final rawLabels = await MlKitService.getLabels(_pickedImage!);
        final filteredLabels = FoodMappingService.processLabels(rawLabels);
        
        setState(() {
          _imageAnalysisResult = {
            'labels': filteredLabels,
            'isOffline': true, // Pourrait servir à afficher un petit badge "Mode Hors-ligne"
          };
          _isAnalyzing = false;
        });
      } catch (mlError) {
        setState(() {
          _isAnalyzing = false;
          _imageError = "Impossible d'analyser l'image : $mlError";
        });
      }
    }
  }

  String _getMealTypeByTime() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) return 'breakfast';
    if (hour >= 11 && hour < 16) return 'lunch';
    if (hour >= 18 && hour < 23) return 'dinner';
    return 'snack';
  }

  Future<void> _onLabelSelected(String label) async {
    // 1. Recherche nutritionnelle via notre backend (qui interroge USDA)
    setState(() => _isAnalyzing = true);
    try {
      final result = await Api.searchNutritionByLabel(label);
      setState(() => _isAnalyzing = false);

      if (mounted) {
        _showNutritionDialog(result);
      }
    } catch (e) {
      setState(() => _isAnalyzing = false);
      // Fallback vers la recherche classique si rien trouvé sur USDA
      final searchResult = await Navigator.push<NutritionProduct>(
        context,
        MaterialPageRoute(
          builder: (_) => ProductSearchScreen(initialQuery: label),
        ),
      );
      if (searchResult != null && mounted) {
        Navigator.pop(context, searchResult);
      }
    }
  }

  void _showNutritionDialog(Map<String, dynamic> nutrition) {
    final description = nutrition['description'] ?? 'Aliment';
    final brand = nutrition['brandOwner'];
    final macros = nutrition['nutrients'] ?? {};
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1F1C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (brand != null)
              Text(brand, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMacroStat("Calories", "${(macros['calories'] ?? 0).toInt()}", Colors.orange),
                _buildMacroStat("Protéines", "${macros['proteins'] ?? 0}g", Colors.green),
                _buildMacroStat("Glucides", "${macros['carbs'] ?? 0}g", Colors.blue),
                _buildMacroStat("Lipides", "${macros['fats'] ?? 0}g", Colors.red),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final product = NutritionProduct(
                    id: nutrition['fdcId']?.toString() ?? '',
                    name: description,
                    brand: brand,
                    nutrition: {
                      'calories': (macros['calories'] ?? 0).toDouble(),
                      'proteins': (macros['proteins'] ?? 0).toDouble(),
                      'carbs': (macros['carbs'] ?? 0).toDouble(),
                      'fats': (macros['fats'] ?? 0).toDouble(),
                    },
                  );
                  Navigator.pop(context); 
                  Navigator.pop(context, product);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("Ajouter au journal", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context).translate('smart_scan_title'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _pickedImage == null
                    ? _buildImagePlaceholder(primary)
                    : _buildImageWithResult(primary),
              ),
            ),
            _buildPickButtons(primary),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(Color primary) {
    return GestureDetector(
      onTap: _showImageSourceSheet,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: primary.withValues(alpha: 0.4),
              width: 2,
              style: BorderStyle.solid),
          color: Colors.white.withValues(alpha: 0.04),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withValues(alpha: 0.15),
              ),
              child: Icon(Icons.auto_awesome, color: primary, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context).translate('smart_scan_title'),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).translate('scan_photo_desc'),
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWithResult(Color primary) {
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: primary.withValues(alpha: 0.3)),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(_pickedImage!, fit: BoxFit.cover),
                if (_isAnalyzing)
                  Container(
                    color: Colors.black54,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: primary),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context).translate('ai_analyzing'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: _showImageSourceSheet,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.refresh_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_imageError != null) _buildErrorPanel(),
        if (_imageAnalysisResult != null && !_isAnalyzing)
          _buildResultPanel(primary),
      ],
    );
  }

  Widget _buildErrorPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_imageError!,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultPanel(Color primary) {
    final labels = List<String>.from(_imageAnalysisResult?['labels'] ?? []);
    final isOffline = _imageAnalysisResult?['isOffline'] == true;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(isOffline ? Icons.wifi_off_rounded : Icons.auto_awesome, color: primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOffline ? "Mode hors-ligne (ML Kit)" : AppLocalizations.of(context).translate('detected_meal'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                    ),
                    Text(
                      AppLocalizations.of(context).translate('select_label_desc'),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: labels.map((label) => ActionChip(
              label: Text(label),
              backgroundColor: primary.withValues(alpha: 0.1),
              side: BorderSide(color: primary.withValues(alpha: 0.3)),
              labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              onPressed: () => _onLabelSelected(label),
            )).toList(),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              AppLocalizations.of(context).translate('results_disclaimer'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickButtons(Color primary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _buildPickButton(
              icon: Icons.camera_alt_rounded,
              label: AppLocalizations.of(context).translate('camera'),
              onTap: () => _pickImage(ImageSource.camera),
              primary: primary,
              filled: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildPickButton(
              icon: Icons.photo_library_rounded,
              label: AppLocalizations.of(context).translate('gallery'),
              onTap: () => _pickImage(ImageSource.gallery),
              primary: primary,
              filled: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color primary,
    required bool filled,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: filled ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: filled ? primary : primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: filled ? Colors.white : primary, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                  color: filled ? Colors.white : primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Text(
                AppLocalizations.of(context).translate('image_source'),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                title: Text(AppLocalizations.of(context).translate('take_photo'), style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Colors.white),
                title: Text(AppLocalizations.of(context).translate('pick_gallery'), style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
