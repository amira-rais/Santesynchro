import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/services/api.dart';
import 'package:frontend/screens/barcode_scanner_screen.dart';
import 'package:frontend/screens/smart_scan_screen.dart';
import 'package:frontend/core/app_localizations.dart';

/// ModÃ¨le local d'un produit nutritionnel retournÃ© par l'API
class NutritionProduct {
  final String id;
  final String name;
  final String? brand;
  final String? image;
  final Map<String, dynamic> nutrition;
  final String? unit;

  const NutritionProduct({
    required this.id,
    required this.name,
    this.brand,
    this.image,
    required this.nutrition,
    this.unit,
  });

  factory NutritionProduct.fromMap(Map<String, dynamic> m) {
    return NutritionProduct(
      id: m['id']?.toString() ?? '',
      name: m['name']?.toString() ?? 'Produit inconnu',
      brand: m['brand']?.toString(),
      image: m['image']?.toString(),
      nutrition: Map<String, dynamic>.from(m['nutrition'] ?? {}),
      unit: m['unit']?.toString(),
    );
  }
}

/// Ã‰cran de recherche de produits alimentaires via Open Food Facts.
/// Permet la recherche par nom (approximatif) ou par code-barres (fiable).
/// Retourne un [NutritionProduct] sÃ©lectionnÃ© vers l'Ã©cran appelant.
class ProductSearchScreen extends StatefulWidget {
  final String? initialQuery;
  const ProductSearchScreen({super.key, this.initialQuery});

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen>
    with TickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();

  List<NutritionProduct> _results = [];
  List<NutritionProduct> _userMeals = []; // Cache for user's past meals
  bool _loading = false;
  String? _error;
  bool _showBarcodeField = false;
  String _searchMode = 'ingredients'; // 'ingredients' or 'repas'

  Timer? _debounce;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadUserMeals();
    if (widget.initialQuery != null) {
      _searchCtrl.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _search(widget.initialQuery!);
      });
    }
  }

  Future<void> _loadUserMeals() async {
    try {
      final raw = await Api.getMeals();
      setState(() {
        _userMeals = raw.map((e) {
          final m = e as Map<String, dynamic>;
          return NutritionProduct(
            id: m['id']?.toString() ?? '',
            name: m['name']?.toString() ?? 'Repas',
            brand: m['type']?.toString().toUpperCase(),
            nutrition: {
              'calories': (m['kcal'] ?? 0).toDouble(),
              'proteins': (m['protein'] ?? 0).toDouble(),
              'carbs': (m['carbs'] ?? 0).toDouble(),
              'fats': (m['fat'] ?? 0).toDouble(),
            },
            unit: m['unit']?.toString(),
          );
        }).toList();
      });
    } catch (e) {
      debugPrint('Error loading user meals: $e');
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _barcodeCtrl.dispose();
    _debounce?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _search(value.trim());
    });
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (_searchMode == 'repas') {
      // Local search in previously logged meals
      final filtered = _userMeals
          .where((m) => m.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
      setState(() {
        _results = filtered;
        _loading = false;
      });
      if (filtered.isNotEmpty) _fadeCtrl.forward(from: 0);
      return;
    }

    try {
      final raw = await Api.searchProducts(query);
      final products = raw
          .map((e) => NutritionProduct.fromMap(e as Map<String, dynamic>))
          .where((p) => p.name.isNotEmpty)
          .toList();
      setState(() {
        _results = products;
        _loading = false;
      });
      if (products.isNotEmpty) _fadeCtrl.forward(from: 0);
    } catch (e) {
      final loc = AppLocalizations.of(context);
      setState(() {
        _loading = false;
        _error = loc.translate('search_error');
      });
    }
  }

  Future<void> _searchByBarcode() async {
    final barcode = _barcodeCtrl.text.trim();
    if (barcode.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });
    try {
      final raw = await Api.getProductByBarcode(barcode);
      if (raw == null) {
        final loc = AppLocalizations.of(context);
        setState(() {
          _loading = false;
          _error = loc.translate('no_product_barcode');
        });
        return;
      }
      final product = NutritionProduct.fromMap(raw);
      // If barcode lookup is exact, return immediately
      if (mounted) Navigator.pop(context, product);
    } catch (e) {
      final loc = AppLocalizations.of(context);
      setState(() {
        _loading = false;
        _error = loc.translate('barcode_error');
      });
    }
  }

  void _select(NutritionProduct product) {
    Navigator.pop(context, product);
  }

  /// Ouvre le scanner de code-barre (appareil photo)
  Future<void> _openScanner() async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    
    if (result != null && mounted) {
      if (result == true) {
        Navigator.pop(context, true);
        return;
      }
      final product = result is Map ? result['product'] as NutritionProduct? : result as NutritionProduct?;
      if (product != null) Navigator.pop(context, product);
    }
  }

  /// Ouvre la reconnaissance photo par IA
  Future<void> _openSmartScan() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SmartScanScreen()),
    );
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Widget _buildNutritionChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildProductCard(NutritionProduct product) {
    final nut = product.nutrition;
    final cal = (nut['calories'] ?? 0).toStringAsFixed(0);
    final prot = (nut['proteins'] ?? 0).toStringAsFixed(1);
    final carbs = (nut['carbs'] ?? 0).toStringAsFixed(1);
    final fat = (nut['fats'] ?? 0).toStringAsFixed(1);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: () => _select(product),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Product image or placeholder
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: product.image != null && product.image!.isNotEmpty
                    ? Image.network(
                        product.image!,
                        width: 52,
                        errorBuilder: (context, error, stackTrace) => _imagePlaceholder(),
                      )
                    : _imagePlaceholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.brand != null && product.brand!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          product.brand!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildNutritionChip('Cal', '${cal}kcal', Theme.of(context).colorScheme.error),
                        _buildNutritionChip('P', '${prot}g', Theme.of(context).primaryColor),
                        _buildNutritionChip('G', '${carbs}g', Colors.orange),
                        _buildNutritionChip('L', '${fat}g', Colors.teal),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'per 100g',
                      style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Theme.of(context).primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.fastfood_rounded, color: Theme.of(context).primaryColor, size: 26),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _searchMode == 'repas' ? AppLocalizations.of(context).translate('my_meals') : AppLocalizations.of(context).translate('ingredients'),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _showBarcodeField ? AppLocalizations.of(context).translate('hide_barcode') : AppLocalizations.of(context).translate('enter_barcode'),
            icon: Icon(_showBarcodeField ? Icons.search_rounded : Icons.barcode_reader),
            onPressed: () => setState(() {
              _showBarcodeField = !_showBarcodeField;
              _results = [];
              _error = null;
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _buildPillToggle(isDark, theme.primaryColor),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _showBarcodeField ? _buildBarcodeInput() : _buildSearchInput(isDark),
          ),
          const SizedBox(height: 12),

          // Search Mode Warning (only for global search)
          if (!_showBarcodeField && _results.isNotEmpty && _searchMode == 'ingredients')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: Colors.orange),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context).translate('results_disclaimer'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _loading && _results.isEmpty
                ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
                : _error != null
                    ? _buildError()
                    : _results.isEmpty && _searchCtrl.text.length >= 2
                        ? _buildEmptyState(isDark)
                        : FadeTransition(
                            opacity: _fadeAnim,
                            child: ListView.builder(
                              padding: const EdgeInsets.only(top: 6, bottom: 24),
                              itemCount: _results.length,
                              itemBuilder: (ctx, i) => _buildProductCard(_results[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillToggle(bool isDark, Color primary) {
    return Center(
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200],
          borderRadius: BorderRadius.circular(50),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutBack,
              alignment: _searchMode == 'repas' ? Alignment.centerLeft : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? primary : Colors.white,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                _buildToggleItem(AppLocalizations.of(context).translate('my_meals'), _searchMode == 'repas', () {
                  setState(() {
                    _searchMode = 'repas';
                    _results = [];
                    _searchCtrl.clear();
                  });
                }, isDark, primary),
                _buildToggleItem(AppLocalizations.of(context).translate('ingredients'), _searchMode == 'ingredients', () {
                  setState(() {
                    _searchMode = 'ingredients';
                    _results = [];
                    _searchCtrl.clear();
                  });
                }, isDark, primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem(String label, bool active, VoidCallback onTap, bool isDark, Color primary) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: active 
                ? (isDark ? Colors.white : primary) 
                : (isDark ? Colors.white54 : Colors.grey[600]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchInput(bool isDark) {
    return TextField(
      controller: _searchCtrl,
      autofocus: true,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText: _searchMode == 'repas' 
          ? AppLocalizations.of(context).translate('search_my_meals') 
          : AppLocalizations.of(context).translate('search_ingredients_hint'),
        prefixIcon: Icon(Icons.search_rounded, color: Theme.of(context).primaryColor),
        suffixIcon: _searchCtrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() {
                    _results = [];
                    _error = null;
                  });
                },
              )
            : null,
        filled: true,
        fillColor: Theme.of(context).inputDecorationTheme.fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildBarcodeInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _barcodeCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Ex: 3017620422003',
              prefixIcon: Icon(Icons.barcode_reader, color: Theme.of(context).primaryColor),
              filled: true,
              fillColor: Theme.of(context).inputDecorationTheme.fillColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: _loading ? null : _searchByBarcode,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.search_rounded),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _loading ? null : _openScanner,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF166534).withValues(alpha: 0.1),
            foregroundColor: const Color(0xFF166534),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          child: const Icon(Icons.qr_code_scanner),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _loading ? null : _openSmartScan,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.withValues(alpha: 0.1),
            foregroundColor: Colors.blue,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          child: const Icon(Icons.auto_awesome),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final modeLabel = _searchMode == 'repas' 
        ? AppLocalizations.of(context).translate('meal_singular') 
        : AppLocalizations.of(context).translate('product_singular');
    final hasQuery = _searchCtrl.text.trim().isNotEmpty || _barcodeCtrl.text.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? Icons.search_off_rounded : Icons.food_bank_outlined,
              size: 64,
              color: isDark ? Colors.white24 : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery
                  ? AppLocalizations.of(context).translate('no_results_found').replaceAll('{mode}', modeLabel)
                  : AppLocalizations.of(context).translate('search_by_name').replaceAll('{mode}', modeLabel),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.grey[500],
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

