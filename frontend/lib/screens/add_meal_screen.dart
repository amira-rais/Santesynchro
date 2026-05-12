import 'package:flutter/material.dart';
import 'package:frontend/services/api.dart';
import 'package:frontend/core/theme_provider.dart';
import 'package:frontend/screens/product_search_screen.dart';
import 'package:frontend/screens/barcode_scanner_screen.dart';
import 'package:frontend/screens/smart_scan_screen.dart';
import 'package:frontend/core/app_localizations.dart';

/// Un ingrédient local pour composer le repas
class MealIngredient {
  final NutritionProduct product;
  double quantity; // en g ou ml
  MealIngredient({required this.product, required this.quantity});
}

/// Écran d'ajout de repas premium (multi-ingrédients)
class AddMealScreen extends StatefulWidget {
  final ThemeProvider? themeProvider;
  final NutritionProduct? initialProduct;
  final double? initialQuantity;
  
  const AddMealScreen({
    super.key, 
    this.themeProvider, 
    this.initialProduct,
    this.initialQuantity,
  });
  
  @override
  State<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen> {
  final List<MealIngredient> _ingredients = [];
  final TextEditingController _mealNameCtrl = TextEditingController();
  String _selectedType = 'breakfast';
  bool _saving = false;
  double _consumedToday = 0.0;
  double _dailyGoal = 2000.0; // Par défaut

  @override
  void initState() {
    super.initState();
    // Si un produit est passé en argument (ex: de l'accueil ou du scan direct)
    if (widget.initialProduct != null) {
      _ingredients.add(MealIngredient(
        product: widget.initialProduct!,
        quantity: widget.initialQuantity ?? 100.0,
      ));
    }
    
    // Auto-détection du type de repas par l'heure si non spécifié
    _selectedType = _getTypeByTime();
    _fetchDailyStatus();
  }

  Future<void> _fetchDailyStatus() async {
    try {
      final dashboard = await Api.getDashboard();
      if (mounted) {
        setState(() {
          _consumedToday = (dashboard['nutrition']?['consumed'] ?? 0).toDouble();
          _dailyGoal = (dashboard['nutrition']?['goal'] ?? 2000).toDouble();
        });
      }
    } catch (e) {
      debugPrint("Could not fetch dashboard for AddMeal: $e");
    }
  }

  @override
  void dispose() {
    _mealNameCtrl.dispose();
    super.dispose();
  }

  String _getTypeByTime() {
    final h = DateTime.now().hour;
    if (h < 11) return 'breakfast';
    if (h < 15) return 'lunch';
    if (h < 22) return 'dinner';
    return 'snack';
  }

  // Calculs nutritionnels agrégés
  Map<String, double> get _totals {
    double calories = 0, proteins = 0, carbs = 0, fats = 0;
    for (var item in _ingredients) {
      final ratio = item.quantity / 100.0;
      calories += (item.product.nutrition['calories'] ?? 0) * ratio;
      proteins += (item.product.nutrition['proteins'] ?? 0) * ratio;
      carbs += (item.product.nutrition['carbs'] ?? 0) * ratio;
      fats += (item.product.nutrition['fats'] ?? 0) * ratio;
    }
    return {'calories': calories, 'proteins': proteins, 'carbs': carbs, 'fats': fats};
  }

  Future<void> _addIngredient() async {
    final result = await Navigator.push<NutritionProduct>(
      context,
      MaterialPageRoute(builder: (_) => ProductSearchScreen()),
    );
    if (result != null) {
      setState(() {
        _ingredients.add(MealIngredient(product: result, quantity: 100.0));
      });
    }
  }

  Future<void> _scanIngredient() async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen(isIngredientMode: true)),
    );
    if (result != null && result is Map && result['product'] != null) {
      setState(() {
        _ingredients.add(MealIngredient(
          product: result['product'],
          quantity: result['quantity'] ?? 100.0,
        ));
      });
    }
  }

  Future<void> _smartScanIngredient() async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => SmartScanScreen()),
    );
    if (result != null && result is NutritionProduct) {
      setState(() {
        _ingredients.add(MealIngredient(
          product: result,
          quantity: 100.0,
        ));
      });
    }
  }

  Future<void> _save() async {
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).translate('at_least_one_ingredient'))));
      return;
    }

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final totals = _totals;
      
      final String customName = _mealNameCtrl.text.trim();
      final mealName = customName.isNotEmpty 
          ? customName 
          : (_ingredients.length == 1 
              ? _ingredients[0].product.name 
              : '${AppLocalizations.of(context).translate('composed_meal')} (${_ingredients.length} ${AppLocalizations.of(context).translate('items_count')})');
      
      // Essayer de trouver une image d'un ingrédient
      String? imageUrl;
      for (var ing in _ingredients) {
        if (ing.product.image != null && ing.product.image!.isNotEmpty) {
          imageUrl = ing.product.image;
          break;
        }
      }
      
      final body = {
        'name': mealName,
        'type': _selectedType,
        'quantity': 1,
        'unit': 'repas',
        'time': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        'imageUrl': imageUrl,
        'nutrition': {
          'calories': totals['calories'],
          'carbs': totals['carbs'],
          'proteins': totals['proteins'],
          'fats': totals['fats'],
          'source': 'manual_multi',
        }
      };

      await Api.addMeal(body);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
         setState(() => _saving = false);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context).translate('error')} : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final secondaryPrimary = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER ---
            _buildHeader(secondaryPrimary),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    
                    // --- SEARCH BAR ---
                    _buildSearchBar(isDark, secondaryPrimary),
                    
                    const SizedBox(height: 24),
                    const Text("Nom du repas (Optionnel)", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 12),
                    _buildMealNameField(isDark, secondaryPrimary),

                    const SizedBox(height: 24),
                    Text(AppLocalizations.of(context).translate('meal_type'), style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 12),
                    _buildTypeChips(secondaryPrimary),
                    
                    const SizedBox(height: 30),
                    _buildSummaryCard(isDark, secondaryPrimary),
                    
                    const SizedBox(height: 30),
                    _buildIngredientListHeader(),
                    const SizedBox(height: 16),
                    ..._ingredients.map((item) => _buildIngredientCard(item, isDark, secondaryPrimary)),
                    
                    _buildAddIngredientPlaceholder(isDark, secondaryPrimary),
                    const SizedBox(height: 100), // Espace pour le bouton du bas
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _buildBottomButton(secondaryPrimary),
    );
  }

  Widget _buildHeader(Color primary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context).translate('add_manual'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  Widget _buildMealNameField(bool isDark, Color primary) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Theme.of(context).dividerColor : Colors.grey[300]!),
      ),
      child: TextField(
        controller: _mealNameCtrl,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: "Ex: Pizza Maison",
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: const Icon(Icons.restaurant_menu, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, Color primary) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Theme.of(context).dividerColor : Colors.grey[300]!),
      ),
      child: TextField(
        readOnly: true,
        onTap: _addIngredient,
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context).translate('search_hint'),
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.auto_awesome, color: primary),
                onPressed: _smartScanIngredient,
              ),
              IconButton(
                icon: Icon(Icons.qr_code_scanner_rounded, color: primary),
                onPressed: _scanIngredient,
              ),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildTypeChips(Color primary) {
    final types = [
      {'id': 'breakfast', 'label': AppLocalizations.of(context).translate('breakfast')},
      {'id': 'lunch', 'label': AppLocalizations.of(context).translate('lunch')},
      {'id': 'dinner', 'label': AppLocalizations.of(context).translate('dinner')},
      {'id': 'snack', 'label': AppLocalizations.of(context).translate('snack')},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: types.map((t) {
          final isSelected = _selectedType == t['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() => _selectedType = t['id']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                color: isSelected ? primary : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF132F25) : Colors.grey[200]),
                borderRadius: BorderRadius.circular(25),
                boxShadow: isSelected ? [BoxShadow(color: primary.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))] : [],
              ),
              child: Text(
                t['label']!,
                style: TextStyle(
                  color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF9FBFB3) : Colors.grey[600]),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark, Color primary) {
    final totals = _totals;
    final mealKcal = totals['calories']!;
    
    // Calcul du budget restant
    final remainingBudget = (_dailyGoal - _consumedToday).clamp(0.0, _dailyGoal);
    // Base pour le calcul du pourcentage de l'anneau (si budget épuisé, utiliser l'objectif total)
    final baseForRing = remainingBudget > 0 ? remainingBudget : _dailyGoal;
    final progress = mealKcal / baseForRing;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Theme.of(context).dividerColor : Colors.grey[200]!),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context).translate('total_energy'), style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(mealKcal.toStringAsFixed(0), style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 6),
                      const Text('KCAL', style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (remainingBudget > 0)
                    Text(
                      '${AppLocalizations.of(context).translate('remaining_budget')}: ${remainingBudget.toInt()} ${AppLocalizations.of(context).translate('kcal')}',
                      style: TextStyle(color: isDark ? const Color(0xFF1DB954) : primary, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
              // Ring progress
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: CircularProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      strokeWidth: 8,
                      backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              _buildMacroBox(AppLocalizations.of(context).translate('proteins_label'), '${totals['proteins']!.toStringAsFixed(0)}g', isDark),
              const SizedBox(width: 12),
              _buildMacroBox(AppLocalizations.of(context).translate('carbs_label'), '${totals['carbs']!.toStringAsFixed(0)}g', isDark),
              const SizedBox(width: 12),
              _buildMacroBox(AppLocalizations.of(context).translate('fats_label'), '${totals['fats']!.toStringAsFixed(0)}g', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBox(String label, String value, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0B1F17) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: isDark ? Border.all(color: const Color(0xFF2A4A3F)) : null,
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientListHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context).translate('added_ingredients'), style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
        Text('${_ingredients.length} ${AppLocalizations.of(context).translate('items_count')}', style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildIngredientCard(MealIngredient item, bool isDark, Color primary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Theme.of(context).dividerColor : Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: item.product.image != null
                ? Image.network(item.product.image!, width: 50, height: 50, fit: BoxFit.cover)
                : Container(width: 50, height: 50, color: Colors.grey[300], child: const Icon(Icons.restaurant, color: Colors.grey)),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(
                  '${(item.product.nutrition['calories'] ?? 0)} kcal • 100g',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          // Stepper
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252B28) : Colors.grey[200],
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove, size: 16),
                  onPressed: () {
                    if (item.quantity > 10) setState(() => item.quantity -= 10);
                  },
                ),
                Text(
                  '${item.quantity.toInt()}g',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add, size: 16, color: Colors.grey),
                  onPressed: () {
                    setState(() => item.quantity += 10);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
            onPressed: () => setState(() => _ingredients.remove(item)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddIngredientPlaceholder(bool isDark, Color primary) {
    return GestureDetector(
      onTap: _addIngredient,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: primary.withOpacity(0.3), style: BorderStyle.solid),
          color: primary.withOpacity(0.05),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.add_circle, color: primary, size: 28),
              const SizedBox(height: 8),
              Text(AppLocalizations.of(context).translate('add_another_ingredient'), style: const TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButton(Color primary) {
    if (_saving) return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
    
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.transparent,
      child: ElevatedButton(
        onPressed: _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          minimumSize: const Size(double.infinity, 65),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 8,
          shadowColor: primary.withOpacity(0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Text(
              AppLocalizations.of(context).translate('add_to_journal'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }
}