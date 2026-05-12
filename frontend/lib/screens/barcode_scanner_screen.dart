import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:frontend/services/api.dart';
import 'package:frontend/screens/product_search_screen.dart';
import 'package:frontend/core/app_localizations.dart';

/// Écran de scan de code-barres dédié.
/// Retourne un [NutritionProduct] via Navigator.pop ou enregistre le repas directement.
class BarcodeScannerScreen extends StatefulWidget {
  final bool isIngredientMode;
  const BarcodeScannerScreen({super.key, this.isIngredientMode = false});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController();
  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnimation;

  NutritionProduct? _detectedProduct;
  bool _isSearching = false;
  String? _lastBarcode;
  double _selectedQuantity = 100.0;
  bool _isLogging = false;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _scanLineAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(String code) async {
    if (code == _lastBarcode || _isSearching) return;
    
    setState(() {
      _lastBarcode = code;
      _isSearching = true;
      _detectedProduct = null;
    });

    try {
      final raw = await Api.getProductByBarcode(code);
      if (raw != null) {
        setState(() {
          _detectedProduct = NutritionProduct.fromMap(raw);
          _isSearching = false;
        });
      } else {
        setState(() {
          _isSearching = false;
          _lastBarcode = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).translate('product_not_recognized'))),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
        _lastBarcode = null;
      });
    }
  }

  Future<void> _showQuantityDialog() async {
    final ctrl = TextEditingController(
      text: _selectedQuantity % 1 == 0 
          ? _selectedQuantity.toInt().toString() 
          : _selectedQuantity.toStringAsFixed(1)
    );
    final unit = _detectedProduct?.unit ?? 'g';

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('quantity_with_unit').replaceAll('{unit}', unit)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(suffixText: unit),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context).translate('cancel'))),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text);
              if (val != null && val > 0) Navigator.pop(ctx, val);
            },
            child: Text(AppLocalizations.of(context).translate('confirm')),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => _selectedQuantity = result);
    }
  }

  String _getMealType() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) return 'breakfast';
    if (hour >= 11 && hour < 16) return 'lunch';
    if (hour >= 18 && hour < 23) return 'dinner';
    return 'snack';
  }

  Future<void> _saveMeal() async {
    if (_detectedProduct == null || _isLogging) return;
    setState(() => _isLogging = true);

    try {
      await Api.addMeal({
        'name': _detectedProduct!.name,
        'type': _getMealType(),
        'quantity': _selectedQuantity,
        'unit': _detectedProduct!.unit ?? 'g',
        'nutrition': _detectedProduct!.nutrition,
        'time': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('meal_saved')),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.translate('error')} : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  void _handleSuccess() {
    if (widget.isIngredientMode) {
      Navigator.pop(context, {
        'product': _detectedProduct,
        'quantity': _selectedQuantity,
      });
    } else {
      _saveMeal();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // SCANNER
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _handleBarcode(barcode.rawValue!);
                }
              }
            },
          ),

          // OVERLAY
          _buildOverlay(primary),

          // TOP BAR
          _buildTopBar(),

          // BOTTOM PANEL
          _buildBottomPanel(primary),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildCircleButton(
              icon: Icons.close,
              onPressed: () => Navigator.pop(context),
            ),
            Text(
              AppLocalizations.of(context).translate('barcode_scanner_title'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontSize: 12,
              ),
            ),
            ValueListenableBuilder(
              valueListenable: _scannerController,
              builder: (context, state, child) {
                final isTorchOn = state.torchState == TorchState.on;
                return _buildCircleButton(
                  icon: isTorchOn ? Icons.flash_on : Icons.flash_off,
                  color: isTorchOn ? Colors.yellow : Colors.white,
                  onPressed: () => _scannerController.toggleTorch(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay(Color primary) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _ScannerOverlayPainter(
              windowWidth: 280,
              windowHeight: 180,
              borderRadius: 24,
            ),
          ),
        ),
        Center(
          child: Container(
            width: 280,
            height: 180,
            decoration: BoxDecoration(
              border: Border.all(color: primary.withValues(alpha: 0.5), width: 2),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    AppLocalizations.of(context).translate('align_barcode'),
                    style: const TextStyle(
                      color: Colors.white70,
                      letterSpacing: 2,
                      fontSize: 10,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _scanLineAnimation,
                  builder: (context, child) {
                    return Positioned(
                      top: _scanLineAnimation.value * 180,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.8),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                          gradient: LinearGradient(
                            colors: [
                              primary.withValues(alpha: 0),
                              primary,
                              primary.withValues(alpha: 0),
                            ]
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPanel(Color primary) {
    final hasResult = _detectedProduct != null || _isSearching;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutQuart,
      bottom: hasResult ? 0 : -350,
      left: 0,
      right: 0,
      child: Container(
        height: 380,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 20, offset: const Offset(0, -5))
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            if (_isSearching)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_detectedProduct != null)
              _buildProductInfo(primary),
          ],
        ),
      ),
    );
  }

  Widget _buildProductInfo(Color primary) {
    final p = _detectedProduct!;
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${p.brand ?? AppLocalizations.of(context).translate('product_singular')} (${_selectedQuantity.toInt()}${p.unit ?? "g"})',
                      style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _showQuantityDialog,
                icon: const Icon(Icons.edit, size: 16),
                label: Text(AppLocalizations.of(context).translate('edit'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMacroCard(p.nutrition['calories'], AppLocalizations.of(context).translate('kcal_label'), Colors.white, Colors.black),
              _buildMacroCard(p.nutrition['proteins'], AppLocalizations.of(context).translate('prot_label'), const Color(0xFFDCFCE7), const Color(0xFF166534)),
              _buildMacroCard(p.nutrition['carbs'], AppLocalizations.of(context).translate('carb_label'), const Color(0xFFDBEAFE), const Color(0xFF1E40AF)),
              _buildMacroCard(p.nutrition['fats'], AppLocalizations.of(context).translate('fat_label'), const Color(0xFFFEF3C7), const Color(0xFF92400E)),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLogging ? null : _handleSuccess,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                _isLogging ? AppLocalizations.of(context).translate('saving') : (widget.isIngredientMode ? AppLocalizations.of(context).translate('add_ingredient') : AppLocalizations.of(context).translate('add_to_journal')),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCard(dynamic raw, String label, Color bg, Color text) {
    final double base = double.tryParse(raw?.toString() ?? '0') ?? 0.0;
    final double scaled = (base * _selectedQuantity) / 100.0;
    final String val = scaled % 1 == 0 ? scaled.toInt().toString() : scaled.toStringAsFixed(1);
    
    return Container(
      width: 70,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(val, style: TextStyle(color: text, fontWeight: FontWeight.w900, fontSize: 18)),
          Text(label, style: TextStyle(color: text.withValues(alpha: 0.6), fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCircleButton({required IconData icon, required VoidCallback onPressed, Color color = Colors.white}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
      child: IconButton(icon: Icon(icon, color: color, size: 20), onPressed: onPressed),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final double windowWidth;
  final double windowHeight;
  final double borderRadius;

  _ScannerOverlayPainter({required this.windowWidth, required this.windowHeight, required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.6);
    final fullScreenPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final windowPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: windowWidth, height: windowHeight),
        Radius.circular(borderRadius),
      ));
    canvas.drawPath(Path.combine(PathOperation.difference, fullScreenPath, windowPath), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
