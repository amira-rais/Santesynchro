import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:frontend/core/theme_provider.dart';
import 'package:frontend/core/language_provider.dart';
import 'package:frontend/core/app_localizations.dart';
import 'package:frontend/screens/profile_summary_screen.dart';
import 'package:frontend/services/api.dart';
import 'package:frontend/utils/nutrition_calculator.dart';

/// Écran de configuration des objectifs (Onboarding).
/// Utilise un PageView pour diviser le processus en 3 étapes : Objectifs, Profil, Santé.
class GoalsScreen extends StatefulWidget {
  final ThemeProvider themeProvider;
  final bool isEditing;

  const GoalsScreen({
    super.key, 
    required this.themeProvider, 
    this.isEditing = false,
  });

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  // Contrôleur pour gérer la navigation entre les pages de configuration
  final PageController _pageController = PageController();
  // Index de l'étape actuelle (0, 1 ou 2)
  int _currentStep = 0;
  bool _loading = false;
  String? _selectedGender;
  int _birthMonth = 1;
  int _birthDay = 1;
  int _birthYear = 2000;
  late final FixedExtentScrollController _monthController;
  late final FixedExtentScrollController _dayController;
  late final FixedExtentScrollController _yearController;
  
  // État pour les objectifs (Étape 1)
  final Set<String> _selectedGoals = {};
  
  // État pour les données physiques et préférences (Étape 2)
  double _height = 175.0;
  double _currentWeight = 85.0;
  double _targetWeight = 75.0;
  final Set<String> _selectedDiets = {};
  
  // État pour les conditions de santé (Étape 3)
  final Set<String> _selectedConditions = {};
  final Set<String> _selectedAllergies = {};
  
  // Variables temporaires pour le calcul du rythme
  double _goalWeight = 0.0;
  String _unit = 'kg';
  String _pace = 'Steady';
  String _activityLevel = 'moderate'; // sedentary, light, moderate, active

  final List<Map<String, dynamic>> _goalOptions = [
    {
      'id': 'weight_loss',
      'titleKey': 'weight_loss',
      'subtitleKey': 'weight_loss_desc',
      'icon': Icons.fitness_center,
      'color': const Color(0xFFE0F2FE),
      'iconColor': const Color(0xFF0EA5E9),
    },
    {
      'id': 'muscle_gain',
      'titleKey': 'muscle_gain',
      'subtitleKey': 'muscle_gain_desc',
      'icon': Icons.fitness_center,
      'color': const Color(0xFFFFF7ED),
      'iconColor': const Color(0xFFF97316),
    },
    {
      'id': 'lifestyle',
      'titleKey': 'lifestyle',
      'subtitleKey': 'lifestyle_desc',
      'icon': Icons.spa,
      'color': const Color(0xFFF5F3FF),
      'iconColor': const Color(0xFF8B5CF6),
    },
  ];

  static const List<Map<String, dynamic>> _pathologyData = [
    {"id": "diabetes_type_1", "nameKey": "diabetes_type_1_name", "category": "Metabolic", "descKey": "diabetes_type_1_desc"},
    {"id": "diabetes_type_2", "nameKey": "diabetes_type_2_name", "category": "Metabolic", "descKey": "diabetes_type_2_desc"},
    {"id": "obesity", "nameKey": "obesity_name", "category": "Metabolic", "descKey": "obesity_desc"},
    {"id": "hypertension", "nameKey": "hypertension_name", "category": "Cardiovascular", "descKey": "hypertension_desc"},
    {"id": "high_cholesterol", "nameKey": "high_cholesterol_name", "category": "Cardiovascular", "descKey": "high_cholesterol_desc"},
    {"id": "heart_disease", "nameKey": "heart_disease_name", "category": "Cardiovascular", "descKey": "heart_disease_desc"},
    {"id": "gerd", "nameKey": "gerd_name", "category": "Digestive", "descKey": "gerd_desc"},
    {"id": "ibs", "nameKey": "ibs_name", "category": "Digestive", "descKey": "ibs_desc"},
    {"id": "anemia", "nameKey": "anemia_name", "category": "Deficiency", "descKey": "anemia_desc"},
    {"id": "thyroid", "nameKey": "thyroid_name", "category": "Hormonal", "descKey": "thyroid_desc"},
    {"id": "pcos", "nameKey": "pcos_name", "category": "Hormonal", "descKey": "pcos_desc"},
    {"id": "none", "nameKey": "none_condition_name", "category": "General", "descKey": "none_condition_desc"}
  ];

  static const List<Map<String, dynamic>> _allergyData = [
    {"id": "peanuts", "nameKey": "peanuts_name", "type": "Food Allergy"},
    {"id": "tree_nuts", "nameKey": "tree_nuts_name", "type": "Food Allergy"},
    {"id": "milk", "nameKey": "milk_name", "type": "Food Allergy"},
    {"id": "eggs", "nameKey": "eggs_name", "type": "Food Allergy"},
    {"id": "gluten", "nameKey": "gluten_name", "type": "Food Allergy"},
    {"id": "fish", "nameKey": "fish_name", "type": "Food Allergy"},
    {"id": "shellfish", "nameKey": "shellfish_name", "type": "Food Allergy"},
    {"id": "soy", "nameKey": "soy_name", "type": "Food Allergy"},
    {"id": "sesame", "nameKey": "sesame_name", "type": "Food Allergy"},
    {"id": "lactose_intolerance", "nameKey": "lactose_intolerance_name", "type": "Intolerance"},
    {"id": "gluten_sensitivity", "nameKey": "gluten_sensitivity_name", "type": "Intolerance"},
    {"id": "none", "nameKey": "no_allergies_name", "type": "General"}
  ];

  @override
  void initState() {
    super.initState();
    _monthController = FixedExtentScrollController(initialItem: _birthMonth - 1);
    _dayController = FixedExtentScrollController(initialItem: _birthDay - 1);
    _yearController = FixedExtentScrollController(initialItem: _yearToIndex(_birthYear));
    
    if (widget.isEditing) {
      _loadExistingData();
    }
  }

  Future<void> _loadExistingData() async {
    setState(() => _loading = true);
    try {
      final me = await Api.me();
      final goals = await Api.getGoals();

      setState(() {
        _selectedGender = me['gender'];
        if (me['birthDate'] != null) {
          final dt = DateTime.tryParse(me['birthDate']);
          if (dt != null) {
            _birthYear = dt.year;
            _birthMonth = dt.month;
            _birthDay = dt.day;
            
            if (_yearController.hasClients) _yearController.jumpToItem(_yearToIndex(_birthYear));
            if (_monthController.hasClients) _monthController.jumpToItem(_birthMonth - 1);
            if (_dayController.hasClients) _dayController.jumpToItem(_birthDay - 1);
          }
        }
        _height = double.tryParse(me['height']?.toString() ?? '175') ?? 175.0;
        _currentWeight = double.tryParse(me['weight']?.toString() ?? '85') ?? 85.0;
        _targetWeight = double.tryParse(me['targetWeight']?.toString() ?? '75') ?? 75.0;
        _pace = me['pace'] ?? 'Steady';
        _activityLevel = me['activityLevel'] ?? 'moderate';
        
        _selectedDiets.addAll((me['diets'] as List? ?? []).map((e) => e.toString()));
        _selectedConditions.addAll((me['conditions'] as List? ?? []).map((e) => e.toString()));
        _selectedAllergies.addAll((me['allergies'] as List? ?? []).map((e) => e.toString()));
        
        _selectedGoals.addAll(goals.map((g) => g['type'].toString()));
      });
    } catch (e) {
      debugPrint("Error loading existing goals: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  int _yearToIndex(int year) => year - 1940;
  int _indexToYear(int index) => 1940 + index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.themeProvider.isDarkMode;
    final primaryColor = theme.primaryColor;
    final loc = AppLocalizations.of(context);
    final langProvider = LanguageProvider();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black, size: 20),
          onPressed: () {
            // Retour à la page précédente ou fermeture de l'écran
            if (_currentStep > 0) {
              _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: _buildSegmentedProgress(),
        centerTitle: true,
        actions: [
          TextButton(
            // Option de passer la configuration pour les utilisateurs pressés
            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
            child: Text(loc.translate('skip'), style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) => setState(() => _currentStep = index),
              children: [
                _buildGenderSelection(primaryColor, isDark),
                _buildBirthDateSelection(primaryColor, isDark),
                _buildGoalSelection(primaryColor, isDark),
                _buildProfileSetup(primaryColor, isDark),
                _buildHealthSetup(primaryColor, isDark),
              ],
            ),
    );
  }

  /// Construit les indicateurs de progression segmentés dans l'AppBar
  Widget _buildSegmentedProgress() {
    final isDark = widget.themeProvider.isDarkMode;
    final primaryColor = Theme.of(context).primaryColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        bool isActive = index <= _currentStep;
        return Container(
          width: 34,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isActive ? primaryColor : (isDark ? Colors.grey[800] : const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  // STEP 0: Gender Selection
  Widget _buildGenderSelection(Color primaryColor, bool isDark) {
    final loc = AppLocalizations.of(context);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Text(
                  loc.translate('gender_title'),
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, height: 1.05),
                ),
                const SizedBox(height: 12),
                Text(
                  loc.translate('gender_subtitle'),
                  style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.35),
                ),
                const SizedBox(height: 32),
                _buildGenderCard(
                  label: loc.translate('female'),
                  symbol: '♀',
                  selectedBackground: const Color(0xFFFFDCF4),
                  neutralIconColor: const Color(0xFFB04E67),
                  selectedIconColor: const Color(0xFFB04E67),
                  assetPath: 'assets/images/Female.png',
                  selected: _selectedGender == 'female',
                  isDark: isDark,
                  onTap: () => setState(() => _selectedGender = 'female'),
                ),
                const SizedBox(height: 16),
                _buildGenderCard(
                  label: loc.translate('male'),
                  symbol: '♂',
                  selectedBackground: const Color(0xFFDCFCFF),
                  neutralIconColor: const Color(0xFF4B88A8),
                  selectedIconColor: const Color(0xFF1A6EA0),
                  assetPath: 'assets/images/Male.png',
                  selected: _selectedGender == 'male',
                  isDark: isDark,
                  onTap: () => setState(() => _selectedGender = 'male'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: _buildContinueButton(
            text: loc.translate('continue'),
            onPressed: _selectedGender == null
                ? null
                : () => _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderCard({
    required String label,
    required String symbol,
    required Color selectedBackground,
    required Color neutralIconColor,
    required Color selectedIconColor,
    required String assetPath,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        constraints: BoxConstraints(minHeight: selected ? 240 : 80),
        padding: EdgeInsets.symmetric(
          horizontal: 18,
          vertical: selected ? 14 : 16,
        ),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? theme.primaryColor.withOpacity(0.4) : selectedBackground)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? theme.primaryColor
                : (isDark ? theme.dividerColor : const Color(0xFFD6D6DE)),
            width: selected ? 2 : 1.1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  symbol,
                  key: ValueKey('symbol_$label'),
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w500,
                    color: neutralIconColor,
                    height: 0.95,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      fontSize: selected ? 33 : 32,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? const Color(0xFF0F0F1A) : (isDark ? Colors.white : const Color(0xFF0F0F1A)),
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: FadeTransition(opacity: animation, child: child)),
                  child: selected
                      ? Icon(Icons.check_circle, key: ValueKey('check_$label'), color: selectedIconColor, size: 24)
                      : SizedBox(key: ValueKey('empty_$label'), width: 24),
                ),
              ],
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    axisAlignment: -1,
                    child: child,
                  ),
                );
              },
              child: selected
                  ? Padding(
                      key: ValueKey('img_block_$label'),
                      padding: const EdgeInsets.only(top: 12),
                      child: Center(
                        child: SizedBox(
                          width: 150,
                          height: 120,
                          child: Image.asset(
                            assetPath,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('no_img')),
            ),
          ],
        ),
      ),
    );
  }

  // STEP 1: Birth Date Selection
  Widget _buildBirthDateSelection(Color primaryColor, bool isDark) {
    final loc = AppLocalizations.of(context);
    final monthNames = loc.locale.languageCode == 'fr'
        ? const [
            'Janvier',
            'Fevrier',
            'Mars',
            'Avril',
            'Mai',
            'Juin',
            'Juillet',
            'Aout',
            'Septembre',
            'Octobre',
            'Novembre',
            'Decembre',
          ]
        : const [
            'January',
            'February',
            'March',
            'April',
            'May',
            'June',
            'July',
            'August',
            'September',
            'October',
            'November',
            'December',
          ];
    final maxDays = _daysInMonth(_birthYear, _birthMonth);
    final yearsCount = (2026 - 1940) + 1;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Text(
                  loc.translate('birth_title'),
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, height: 1.05),
                ),
                const SizedBox(height: 12),
                Text(
                  loc.translate('birth_subtitle'),
                  style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.35),
                ),
                const SizedBox(height: 52),
                SizedBox(
                  height: 240,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: _buildPickerColumn(
                          controller: _monthController,
                          itemCount: 12,
                          itemBuilder: (index) => monthNames[index],
                          onSelectedItemChanged: (index) {
                            setState(() {
                              _birthMonth = index + 1;
                              final newMax = _daysInMonth(_birthYear, _birthMonth);
                              if (_birthDay > newMax) {
                                _birthDay = newMax;
                                _dayController.jumpToItem(newMax - 1);
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: _buildPickerColumn(
                          controller: _dayController,
                          itemCount: maxDays,
                          itemBuilder: (index) => '${index + 1}'.padLeft(2, '0'),
                          onSelectedItemChanged: (index) {
                            setState(() => _birthDay = index + 1);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: _buildPickerColumn(
                          controller: _yearController,
                          itemCount: yearsCount,
                          itemBuilder: (index) => '${_indexToYear(index)}',
                          onSelectedItemChanged: (index) {
                            setState(() {
                              _birthYear = _indexToYear(index);
                              final newMax = _daysInMonth(_birthYear, _birthMonth);
                              if (_birthDay > newMax) {
                                _birthDay = newMax;
                                _dayController.jumpToItem(newMax - 1);
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: _buildContinueButton(
            text: loc.translate('continue'),
            onPressed: () => _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPickerColumn({
    required FixedExtentScrollController controller,
    required int itemCount,
    required String Function(int index) itemBuilder,
    required ValueChanged<int> onSelectedItemChanged,
  }) {
    final isDark = widget.themeProvider.isDarkMode;
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: CupertinoPicker(
        scrollController: controller,
        itemExtent: 42,
        diameterRatio: 2.3,
        magnification: 1.08,
        useMagnifier: true,
        squeeze: 1.05,
        onSelectedItemChanged: onSelectedItemChanged,
        selectionOverlay: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            // Keep the highlight visible without hiding selected text.
            color: isDark ? Colors.white12 : const Color(0xFFE5E7EB).withOpacity(0.35),
            border: Border.all(
              color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        children: List.generate(
          itemCount,
          (index) => Center(
            child: Text(
              itemBuilder(index),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // STEP 2: Goal Selection
  Widget _buildGoalSelection(Color primaryColor, bool isDark) {
    final loc = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.translate('goals_header'),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, height: 1.2),
          ),
          const SizedBox(height: 12),
          Text(
            loc.translate('goals_subtitle'),
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          ..._goalOptions.map((option) => _buildGoalCard(option, primaryColor, isDark)).toList(),
          const SizedBox(height: 32),
          _buildContinueButton(
            text: loc.translate('continue'),
            onPressed: _selectedGoals.isEmpty ? null : () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
          ),
        ],
      ),
    );
  }

  /// ÉTAPE 2 : Configuration du profil physique (Taille, Poids, Régime)
  Widget _buildProfileSetup(Color primaryColor, bool isDark) {
    final loc = AppLocalizations.of(context);
    bool isWeightLossSelected = _selectedGoals.contains('weight_loss');
    double displayedTargetWeight = isWeightLossSelected ? (_currentWeight - _goalWeight) : _targetWeight;
    
    double diff = _currentWeight - displayedTargetWeight;
    double percent = (_currentWeight > 0) ? (diff / _currentWeight) * 100 : 0;
    
    // Calcul de l'IMC (BMI)
    double heightInMeters = _height / 100;
    double imc = _currentWeight / (heightInMeters * heightInMeters);
    String imcCategory = '';
    Color imcColor = Colors.grey;
    String imcDesc = '';

    if (imc < 18.5) {
      imcCategory = loc.translate('bmi_underweight') ?? 'Insuffisance pondérale';
      imcColor = Colors.blue;
      imcDesc = 'Votre poids est inférieur à la normale.';
    } else if (imc < 25) {
      imcCategory = loc.translate('bmi_normal') ?? 'Corpulence normale';
      imcColor = Colors.green;
      imcDesc = 'Vous avez un poids de forme.';
    } else if (imc < 30) {
      imcCategory = loc.translate('bmi_overweight') ?? 'Surpoids';
      imcColor = Colors.orange;
      imcDesc = 'Votre poids est supérieur à la normale.';
    } else {
      imcCategory = loc.translate('bmi_obese') ?? 'Obésité';
      imcColor = Colors.red;
      imcDesc = 'Des risques pour votre santé sont possibles.';
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            loc.translate('fine_tune_goal') ?? 'Affinez votre objectif',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            loc.translate('adjust_metrics') ?? 'Ajustez vos mesures pour personnaliser votre plan nutritionnel.',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),

          _buildMetricSlider(loc.translate('height') ?? 'Taille', _height, 140, 220, 'cm', (val) => setState(() => _height = val), primaryColor, isDark),
          _buildMetricSlider(loc.translate('weight_current') ?? 'Poids Actuel', _currentWeight, 40, 150, 'kg', (val) => setState(() => _currentWeight = val), primaryColor, isDark),
          _buildMetricSlider(loc.translate('weight_target') ?? 'Poids Cible', displayedTargetWeight, 40, 150, 'kg', (val) => setState(() => _targetWeight = val), primaryColor, isDark, enabled: !isWeightLossSelected),

          const SizedBox(height: 16),
          // Boîte de l'IMC
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: imcColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: imcColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: imcColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    imc.toStringAsFixed(1),
                    style: TextStyle(color: imcColor, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IMC : $imcCategory',
                        style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        imcDesc,
                        style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Sélection du niveau d'activité
          Text(
            loc.translate('activity_level') ?? 'Niveau d\'activité',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Déterminez votre dépense énergétique quotidienne',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          _buildActivityLevelSelector(primaryColor, isDark),

          const SizedBox(height: 32),
          // Boîte de résumé de l'objectif calculé dynamiquement
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryColor.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Icon(Icons.trending_down, color: primaryColor, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14),
                      children: [
                        TextSpan(text: loc.translate('goal_summary')),
                        TextSpan(
                          text: '${diff > 0 ? loc.translate('reduce_weight') : loc.translate('gain_weight')}${diff.abs().toStringAsFixed(1)}kg (${percent.abs().toInt()}%)',
                          style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 48),
          Text(
            loc.translate('health_diet_prefs'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            loc.translate('select_all_apply'),
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          
          // Liste des régimes sous forme de puces filtrables
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              'Vegan', 'Keto', 'Gluten-Free', 'Dairy-Free', 'Paleo', 'Low Carb'
            ].map((diet) {
              bool selected = _selectedDiets.contains(diet);
              return FilterChip(
                label: Text(diet),
                selected: selected,
                onSelected: (val) {
                  setState(() {
                    if (val) _selectedDiets.add(diet);
                    else _selectedDiets.remove(diet);
                  });
                },
                selectedColor: primaryColor,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
                backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                side: BorderSide(color: selected ? primaryColor : (isDark ? Colors.grey[700]! : Colors.grey[300]!)),
              );
            }).toList(),
          ),

          const SizedBox(height: 40),
          _buildContinueButton(
            text: loc.translate('continue'),
            onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Widget générique pour un curseur de sélection de mesure (Taille/Poids)
  Widget _buildMetricSlider(String label, double value, double min, double max, String unit, Function(double) onChanged, Color primaryColor, bool isDark, {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: enabled ? (isDark ? Colors.white : Colors.black) : Colors.grey)),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value.toStringAsFixed(1),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: enabled ? primaryColor : Colors.grey),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          activeColor: enabled ? primaryColor : Colors.grey[400],
          inactiveColor: isDark ? Colors.grey[800] : Colors.grey[200],
          onChanged: enabled ? onChanged : null,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildActivityLevelSelector(Color primaryColor, bool isDark) {
    return Column(
      children: [
        _buildActivityOption('sedentary', 'Sédentaire', 'Peu ou pas d\'exercice', Icons.weekend_outlined, primaryColor, isDark),
        const SizedBox(height: 8),
        _buildActivityOption('light', 'Légère', 'Exercice léger 1-3 jours/sem', Icons.directions_walk, primaryColor, isDark),
        const SizedBox(height: 8),
        _buildActivityOption('moderate', 'Modérée', 'Exercice modéré 3-5 jours/sem', Icons.directions_run, primaryColor, isDark),
        const SizedBox(height: 8),
        _buildActivityOption('active', 'Intense', 'Exercice intense 6-7 jours/sem', Icons.fitness_center, primaryColor, isDark),
      ],
    );
  }

  Widget _buildActivityOption(String value, String title, String subtitle, IconData icon, Color primaryColor, bool isDark) {
    bool selected = _activityLevel == value;
    return GestureDetector(
      onTap: () => setState(() => _activityLevel = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? primaryColor : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected ? primaryColor : (isDark ? Colors.grey[800] : Colors.grey[200]),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: selected ? Colors.white : Colors.grey, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                      color: selected ? primaryColor : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: primaryColor)
          ],
        ),
      ),
    );
  }

  /// ÉTAPE 3 : Informations de santé (Pathologies et Allergies)
  Widget _buildHealthSetup(Color primaryColor, bool isDark) {
    final loc = AppLocalizations.of(context);
    double displayedTargetWeight = _targetWeight;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            loc.translate('health_info_title') == 'health_info_title' ? 'Health Information' : loc.translate('health_info_title'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            loc.translate('health_info_subtitle') == 'health_info_subtitle' ? 'Select any conditions or allergies' : loc.translate('health_info_subtitle'),
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),

          // Section des pathologies avec logique d'exclusion mutuelle pour "Aucune"
          Text(loc.translate('pathologies_label') == 'pathologies_label' ? 'HEALTH CONDITIONS' : loc.translate('pathologies_label'), 
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          ..._pathologyData.map((patho) {
            bool selected = _selectedConditions.contains(patho['id']);
            return _buildConditionTile(
              patho['id'],
              loc.translate(patho['nameKey']),
              loc.translate(patho['descKey']),
              Icons.healing,
              onTap: () {
                setState(() {
                  if (patho['id'] == 'none') {
                    _selectedConditions.clear();
                    _selectedConditions.add('none');
                  } else {
                    _selectedConditions.remove('none');
                    if (selected) {
                      _selectedConditions.remove(patho['id']);
                    } else {
                      _selectedConditions.add(patho['id']);
                    }
                  }
                });
              },
              isDark: isDark,
              primaryColor: primaryColor,
            );
          }).toList(),

          const SizedBox(height: 32),

          // Section des allergies sous forme de FilterChips
          Text(loc.translate('allergies_label') == 'allergies_label' ? 'ALLERGIES' : loc.translate('allergies_label'), 
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _allergyData.map((allergy) {
              bool isNoneSelected = _selectedAllergies.contains('none');
              bool isThisNone = allergy['id'] == 'none';
              bool selected = _selectedAllergies.contains(allergy['id']);
              bool disabled = isNoneSelected && !isThisNone;

              return FilterChip(
                label: Text(loc.translate(allergy['nameKey'])),
                selected: selected,
                onSelected: disabled ? null : (val) {
                  setState(() {
                    if (isThisNone) {
                      if (val) {
                        _selectedAllergies.clear();
                        _selectedAllergies.add(allergy['id']);
                      } else {
                        _selectedAllergies.remove(allergy['id']);
                      }
                    } else {
                      _selectedAllergies.remove('none');
                      if (val) {
                        _selectedAllergies.add(allergy['id']);
                      } else {
                        _selectedAllergies.remove(allergy['id']);
                      }
                    }
                  });
                },
                selectedColor: primaryColor,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: disabled ? Colors.grey[600] : (selected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700])),
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
                backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                side: BorderSide(color: selected ? primaryColor : (isDark ? Colors.grey[700]! : Colors.grey[300]!)),
              );
            }).toList(),
          ),

          const SizedBox(height: 48),
          _buildContinueButton(
            text: loc.translate('finish') == 'finish' ? 'Finish' : loc.translate('finish'),
            onPressed: () async {
              // Calcul des besoins caloriques avec NutritionCalculator
              final age = NutritionCalculator.calculateAge(DateTime(_birthYear, _birthMonth, _birthDay));
              final bmr = NutritionCalculator.calculateBMR(
                gender: _selectedGender ?? 'male', 
                weight: _currentWeight, 
                height: _height, 
                age: age
              );
              final tdee = NutritionCalculator.calculateTDEE(bmr: bmr, activityLevel: _activityLevel);
              
              String primaryGoal = 'maintenance';
              if (_selectedGoals.contains('weight_loss')) primaryGoal = 'weight_loss';
              else if (_selectedGoals.contains('muscle_gain')) primaryGoal = 'muscle_gain';
              
              final dailyCalories = NutritionCalculator.calculateDailyCalories(tdee: tdee, goalType: primaryGoal);

              // Rassemblement de toutes les données collectées pour le résumé final
              final Map<String, dynamic> userData = {
                'gender': _selectedGender,
                'birthDate': '${_birthYear.toString().padLeft(4, '0')}-${_birthMonth.toString().padLeft(2, '0')}-${_birthDay.toString().padLeft(2, '0')}',
                'goals': _selectedGoals,
                'height': _height,
                'currentWeight': _currentWeight,
                'targetWeight': displayedTargetWeight,
                'pace': _pace,
                'activityLevel': _activityLevel,
                'diets': _selectedDiets,
                'conditions': _selectedConditions,
                'allergies': _selectedAllergies,
                'nutritionGoals': {
                  'calories': dailyCalories,
                  'protein': 0, // Placeholder
                  'carbs': 0,   // Placeholder
                  'fat': 0      // Placeholder
                }
              };
              
              if (widget.isEditing) {
                setState(() => _loading = true);
                try {
                  // 1. Mise à jour du profil
                  await Api.updateProfile({
                    'gender': userData['gender'],
                    'birthDate': userData['birthDate'],
                    'height': userData['height'],
                    'weight': userData['currentWeight'],
                    'targetWeight': userData['targetWeight'],
                    'pace': userData['pace'],
                    'activityLevel': userData['activityLevel'],
                    'nutritionGoals': userData['nutritionGoals'],
                    'diets': (userData['diets'] as Set<String>).toList(),
                    'conditions': (userData['conditions'] as Set<String>).toList(),
                    'allergies': (userData['allergies'] as Set<String>).toList(),
                  });

                  // 2. Mise à jour des objectifs (On rajoute les nouveaux s'ils n'existent pas)
                  final existingGoals = await Api.getGoals();
                  final Set<String> existingTypes = existingGoals.map((g) => g['type'].toString()).toSet();
                  
                  for (var goalType in _selectedGoals) {
                    if (!existingTypes.contains(goalType)) {
                      await Api.addGoal({
                        'type': goalType,
                        'target': userData['targetWeight'],
                        'unit': 'kg',
                      });
                    }
                  }

                  if (!mounted) return;
                  Navigator.pop(context);
                } catch (e) {
                  debugPrint("Error updating goals: $e");
                  if (mounted) {
                    final loc = AppLocalizations.of(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${loc.translate('save_error')} : $e')),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileSummaryScreen(
                      themeProvider: widget.themeProvider,
                      userData: userData,
                    ),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Widget utilitaire pour une tuile de sélection (utilisée pour les pathologies)
  Widget _buildSelectionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback? onTap,
    required bool isDark,
    required Color primaryColor,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? primaryColor : (isDark ? Colors.grey[800]! : Colors.grey[300]!), width: 1.5),
              color: selected ? primaryColor.withOpacity(0.02) : (isDark ? const Color(0xFF1A1A1A) : Colors.white),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: enabled ? primaryColor : Colors.grey, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: enabled ? (isDark ? Colors.white : Colors.black) : Colors.grey)),
                      Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected ? primaryColor : Colors.grey[300],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConditionTile(String id, String title, String subtitle, IconData icon, {required VoidCallback onTap, required bool isDark, required Color primaryColor}) {
    bool selected = _selectedConditions.contains(id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? primaryColor : (isDark ? Colors.grey[800]! : Colors.grey[300]!), width: 1.5),
            color: selected ? primaryColor.withOpacity(0.02) : (isDark ? const Color(0xFF1A1A1A) : Colors.white),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: primaryColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? primaryColor : Colors.grey[300],
              ),
            ],
          ),
        ),
      ),
    );
  }


  /// Affiche une prévision basée sur le rythme de perte/gain de poids choisi
  Widget _buildDailyForecast(Color primaryColor, bool isDark) {
    final loc = AppLocalizations.of(context);
    
    // Calculs de prévision
    double paceKgPerWeek = 0.8;
    int deficit = 500;
    if (_pace == 'Slow') {
      paceKgPerWeek = 0.1;
      deficit = 250;
    } else if (_pace == 'Fast') {
      paceKgPerWeek = 1.5;
      deficit = 1000;
    }

    int daysToGoal = (_goalWeight > 0 && paceKgPerWeek > 0) 
        ? ((_goalWeight / paceKgPerWeek) * 7).round() 
        : 0;
    
    DateTime goalDate = DateTime.now().add(Duration(days: daysToGoal));
    final List<String> months = [
      loc.translate('jan'), loc.translate('feb'), loc.translate('mar'),
      loc.translate('apr'), loc.translate('may'), loc.translate('jun'),
      loc.translate('jul'), loc.translate('aug'), loc.translate('sep'),
      loc.translate('oct'), loc.translate('nov'), loc.translate('dec')
    ];
    String formattedDate = daysToGoal > 0 
        ? "${months[goalDate.month - 1]} ${goalDate.day} ${goalDate.year}"
        : "--";

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Theme.of(context).dividerColor : Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: primaryColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.translate('daily_forecast'), 
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold, 
                        color: isDark ? Colors.white : const Color(0xFF065F46) // Darker variant of mint for text
                      )
                    ),
                    Text(
                      '${loc.translate('forecast_desc')} "$_pace"', 
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600])
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _buildForecastStat(loc.translate('daily_deficit'), '-$deficit kcal', isDark)),
              const SizedBox(width: 8),
              Expanded(child: _buildForecastStat(loc.translate('goal_date'), formattedDate, isDark)),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.5),
              children: [
                TextSpan(text: loc.translate('reach_goal_text_1'), style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                TextSpan(text: '${_goalWeight.toStringAsFixed(1)}kg', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                TextSpan(text: loc.translate('reach_goal_text_2'), style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                TextSpan(text: loc.translate(_pace.toLowerCase()), style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                TextSpan(text: loc.translate('reach_goal_text_3'), style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                TextSpan(text: formattedDate, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Petit widget pour afficher une statistique de prévision
  Widget _buildForecastStat(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  /// Bouton principal stylisé pour passer à l'étape suivante
  Widget _buildContinueButton({required String text, VoidCallback? onPressed}) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final isDark = widget.themeProvider.isDarkMode;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: isDark ? 0 : 4,
          shadowColor: primaryColor.withOpacity(0.4),
        ),
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  /// Affiche une boîte de dialogue modale pour configurer les détails d'un objectif spécifique
  void _showGoalDataDialog(String goalId, String goalTitle) {
    final theme = Theme.of(context);
    final isDark = widget.themeProvider.isDarkMode;
    final primaryColor = theme.primaryColor;
    final loc = AppLocalizations.of(context);

    // État local pour le dialogue
    String weightLossDuration = "1 mois";
    String muscleGainLevel = "";
    String muscleGainDiet = "Standard";
    String wellnessTracking = "Suivi Complet";
    double trainingDays = 4.0;
    List<String> selectedHabits = [];
    bool hasInteracted = false; // Track if user touched any control

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 1000),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation, 
            curve: Curves.easeOutCubic,
            reverseCurve: const Interval(0, 1.0, curve: Curves.easeIn),
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(
                parent: animation, 
                curve: Curves.easeOutCubic,
                reverseCurve: const Interval(0, 1.0, curve: Curves.easeIn),
              ),
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
        final loc = AppLocalizations.of(context);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: SingleChildScrollView(
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        // En-tête du dialogue avec icône
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                _getGoalIcon(goalId),
                                color: primaryColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    goalTitle,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  Text(
                                    _getGoalMotto(goalId),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 40), // Espace pour le bouton fermer
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Contenu spécifique selon l'ID de l'objectif
                        if (goalId == 'weight_loss')
                          _buildWeightLossDialogContent(isDark, primaryColor, setDialogState, weightLossDuration, 
                            (val) {
                              setDialogState(() {
                                weightLossDuration = val;
                                hasInteracted = true;
                              });
                            },
                            () => setDialogState(() => hasInteracted = true),
                          )
                        else if (goalId == 'muscle_gain')
                          _buildMuscleGainDialogContent(isDark, primaryColor, setDialogState, muscleGainLevel, muscleGainDiet, trainingDays, 
                            (val) => setDialogState(() { muscleGainLevel = val; hasInteracted = true; }), 
                            (val) => setDialogState(() { muscleGainDiet = val; hasInteracted = true; }), 
                            (val) => setDialogState(() { trainingDays = val; hasInteracted = true; }))
                        else if (goalId == 'lifestyle')
                          _buildWellnessDialogContent(isDark, primaryColor, setDialogState, selectedHabits, (habit) {
                            setDialogState(() {
                              if (selectedHabits.contains(habit)) {
                                selectedHabits.remove(habit);
                              } else {
                                selectedHabits.add(habit);
                              }
                              hasInteracted = true;
                            });
                          })
                        else
                          _buildDefaultDialogContent(isDark, primaryColor, goalTitle),

                        const SizedBox(height: 32),

                        // Bouton de validation
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            onPressed: (goalId == 'weight_loss' ? _goalWeight > 0 : (goalId == 'muscle_gain' ? muscleGainLevel.isNotEmpty : (goalId == 'lifestyle' ? selectedHabits.isNotEmpty : hasInteracted)))
                              ? () {
                                  setState(() {
                                    _selectedGoals.add(goalId);
                                  });
                                  Navigator.pop(context);
                                }
                              : null,
                            child: Text(
                              loc.translate('done'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.grey[400]),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

  /// Retourne l'icône appropriée pour un objectif
  IconData _getGoalIcon(String goalId) {
    switch (goalId) {
      case 'weight_loss': return Icons.analytics_outlined;
      case 'muscle_gain': return Icons.fitness_center;
      case 'general':
      case 'lifestyle': return Icons.auto_awesome;
      default: return Icons.flag_outlined;
    }
  }

  /// Retourne une petite phrase de motivation selon l'objectif
  String _getGoalMotto(String goalId) {
    final loc = AppLocalizations.of(context);
    switch (goalId) {
      case 'weight_loss': return loc.translate('motto_weight_loss');
      case 'muscle_gain': return loc.translate('motto_muscle_gain');
      case 'general':
      case 'lifestyle': return loc.translate('motto_lifestyle');
      default: return loc.translate('motto_default');
    }
  }

  /// Contenu spécifique pour l'objectif "Perte de poids"
  Widget _buildWeightLossDialogContent(bool isDark, Color primaryColor, StateSetter setDialogState, String selectedDuration, Function(String) onDurationChanged, VoidCallback onInteraction) {
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(loc.translate('how_many_kg'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.scale_outlined, size: 40, color: Colors.grey),
              const SizedBox(width: 20),
              Text(
                _goalWeight.toStringAsFixed(1),
                style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 20),
              Column(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() => _goalWeight += 0.5);
                      onInteraction();
                    },
                    icon: const Icon(Icons.keyboard_arrow_up, size: 30)
                  ),
                  IconButton(
                    onPressed: () {
                      if (_goalWeight >= 0.5) {
                        setState(() => _goalWeight -= 0.5);
                        onInteraction();
                      }
                    },
                    icon: const Icon(Icons.keyboard_arrow_down, size: 30)
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(loc.translate('choose_pace'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildPaceSelector(primaryColor, isDark, onInteraction),
        const SizedBox(height: 32),
        _buildDailyForecast(primaryColor, isDark),
      ],
    );
  }

  Widget _buildPaceSelector(Color primaryColor, bool isDark, VoidCallback onInteraction) {
    const List<String> paceOrder = ['Slow', 'Steady', 'Fast'];
    const List<double> paceValues = [0.1, 0.8, 1.5];
    const List<String> paceEmoji = ['🦥', '🐇', '🐆'];
    final int selectedIndex = paceOrder.indexOf(_pace).clamp(0, 2);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Theme.of(context).dividerColor : Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context).translate('lose_weight_speed'),
            style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : const Color(0xFF374151)),
          ),
          const SizedBox(height: 8),
          Text(
            '${paceValues[selectedIndex].toStringAsFixed(1)} kg',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (index) {
              final bool active = selectedIndex == index;
              return Expanded(
                child: Center(
                  child: Text(
                    paceEmoji[index],
                    style: TextStyle(
                      fontSize: 30,
                      color: active ? const Color(0xFFD19A67) : (isDark ? Colors.grey[500] : Colors.black54),
                    ),
                  ),
                ),
              );
            }),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: isDark ? Colors.white : const Color(0xFF17172A),
              inactiveTrackColor: const Color(0xFFE8E5F5),
              thumbColor: isDark ? Colors.white : const Color(0xFF17172A),
              overlayColor: Colors.transparent,
              trackHeight: 4,
            ),
            child: Slider(
              value: selectedIndex.toDouble(),
              min: 0,
              max: 2,
              divisions: 2,
              onChanged: (value) {
                final int newIndex = value.round();
                setState(() => _pace = paceOrder[newIndex]);
                onInteraction();
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: paceValues
                .map(
                  (v) => Text(
                    '${v.toStringAsFixed(1)} kg',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : const Color(0xFF1F2937),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2D33) : const Color(0xFFF1F2F6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _paceMessage(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF202332),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _paceMessage() {
    final loc = AppLocalizations.of(context);
    switch (_pace) {
      case 'Slow':
        return loc.translate('pace_slow_steady');
      case 'Fast':
        return loc.translate('pace_warning_fast');
      case 'Steady':
      default:
        return loc.translate('recommended');
    }
  }

  /// Contenu spécifique pour l'objectif "Prise de muscle"
  Widget _buildMuscleGainDialogContent(bool isDark, Color primaryColor, StateSetter setDialogState, String selectedLevel, String selectedDiet, double trainingDays, Function(String) onLevelChanged, Function(String) onDietChanged, Function(double) onDaysChanged) {
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(loc.translate('build_your_plan'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          loc.translate('customize_plan_desc'),
          style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(Icons.fitness_center, size: 20, color: primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                loc.translate('target_muscle_groups'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _buildGridOption(loc.translate('full_body'), Icons.accessibility_new, selectedLevel == 'Full Body', onLevelChanged, isDark, primaryColor),
            _buildGridOption(loc.translate('upper_body'), Icons.arrow_upward, selectedLevel == 'Upper Body', onLevelChanged, isDark, primaryColor),
            _buildGridOption(loc.translate('legs'), Icons.arrow_downward, selectedLevel == 'Legs', onLevelChanged, isDark, primaryColor),
            _buildGridOption('Push / Pull', Icons.compare_arrows, selectedLevel == 'Push / Pull', onLevelChanged, isDark, primaryColor),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.calendar_month, size: 20, color: primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      loc.translate('training_frequency'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Text(loc.translate('training_days_count').replaceAll('{count}', trainingDays.toInt().toString()), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor)),
          ],
        ),
        const SizedBox(height: 16),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: primaryColor,
            inactiveTrackColor: isDark ? Colors.grey[800] : Colors.grey[300],
            thumbColor: Colors.white,
            overlayColor: primaryColor.withOpacity(0.2),
          ),
          child: Slider(
            value: trainingDays,
            min: 1,
            max: 7,
            divisions: 6,
            onChanged: onDaysChanged,
          ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, primaryColor.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.restaurant_menu, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      loc.translate('growth_fuel'),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.8)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(loc.translate('estimated_protein'), style: const TextStyle(fontSize: 16, color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  /// Widget pour une option dans une grille (utilisé pour les groupes musculaires)
  Widget _buildGridOption(String title, IconData icon, bool isSelected, Function(String) onSelect, bool isDark, Color primaryColor) {
    return GestureDetector(
      onTap: () => onSelect(title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.1) : (isDark ? Colors.grey[800] : Colors.white),
          border: Border.all(color: isSelected ? primaryColor : (isDark ? Colors.grey[700]! : Colors.grey[300]!), width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 20, color: isSelected ? primaryColor : Colors.grey),
                if (isSelected) Icon(Icons.check_circle, size: 16, color: primaryColor),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          ],
        ),
      ),
    );
  }

  /// Contenu spécifique pour l'objectif "Vie Saine"
  Widget _buildWellnessDialogContent(bool isDark, Color primaryColor, StateSetter setDialogState, List<String> selectedHabits, Function(String) onHabitToggled) {
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(loc.translate('build_habits_title'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          loc.translate('build_habits_desc'),
          style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        const SizedBox(height: 24),
        _buildHabitOption(loc.translate('habit_water_title'), loc.translate('habit_water_desc'), Icons.water_drop, const Color(0xFFE0F2FE), const Color(0xFF0EA5E9), selectedHabits.contains('Drink 2L Water'), isDark, primaryColor, () => onHabitToggled('Drink 2L Water')),
        const SizedBox(height: 12),
        _buildHabitOption(loc.translate('habit_veggies_title'), loc.translate('habit_veggies_desc'), Icons.apple, const Color(0xFFDCFCE7), const Color(0xFF22C55E), selectedHabits.contains('Eat More Veggies'), isDark, primaryColor, () => onHabitToggled('Eat More Veggies')),
        const SizedBox(height: 12),
        _buildHabitOption(loc.translate('habit_processed_title'), loc.translate('habit_processed_desc'), Icons.no_food, const Color(0xFFFFEDD5), const Color(0xFFF97316), selectedHabits.contains('Reduce Processed Food'), isDark, primaryColor, () => onHabitToggled('Reduce Processed Food')),
        const SizedBox(height: 12),
        _buildHabitOption(loc.translate('habit_sleep_title'), loc.translate('habit_sleep_desc'), Icons.nightlight_round, const Color(0xFFF3E8FF), const Color(0xFFA855F7), selectedHabits.contains('7+ Hours of Sleep'), isDark, primaryColor, () => onHabitToggled('7+ Hours of Sleep')),
        const SizedBox(height: 12),
        _buildHabitOption(loc.translate('habit_walk_title'), loc.translate('habit_walk_desc'), Icons.directions_walk, const Color(0xFFE0F2FE), const Color(0xFF3B82F6), selectedHabits.contains('Daily 15min Walk'), isDark, primaryColor, () => onHabitToggled('Daily 15min Walk')),
      ],
    );
  }

  /// Widget utilitaire pour une option d'habitude
  Widget _buildHabitOption(String title, String subtitle, IconData icon, Color bgColor, Color iconColor, bool isSelected, bool isDark, Color primaryColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? (isSelected ? primaryColor.withOpacity(0.05) : Colors.grey[800]) : (isSelected ? primaryColor.withOpacity(0.05) : Colors.white),
          border: Border.all(color: isSelected ? primaryColor : (isDark ? Colors.grey[700]! : Colors.grey[200]!), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: isDark ? iconColor.withOpacity(0.2) : bgColor, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                ],
              ),
            ),
            Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? primaryColor : Colors.grey[400], size: 24),
          ],
        ),
      ),
    );
  }

  /// Vue par défaut si aucun contenu spécifique n'est défini
  Widget _buildDefaultDialogContent(bool isDark, Color primaryColor, String title) {
    final loc = AppLocalizations.of(context);
    return Column(
      children: [
        Text(
          loc.translate('prepare_for_goal').replaceAll('{title}', title),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: isDark ? Colors.grey[300] : Colors.grey[700]),
        ),
        const SizedBox(height: 24),
        const Icon(Icons.rocket_launch, size: 64, color: Colors.blueAccent),
      ],
    );
  }

  /// Carte d'objectif affichée à l'étape 1
  Widget _buildGoalCard(Map<String, dynamic> option, Color primaryColor, bool isDark) {
    final loc = AppLocalizations.of(context);
    bool selected = _selectedGoals.contains(option['id']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: () {
          if (selected) {
            setState(() => _selectedGoals.remove(option['id']));
          } else {
            // Ouvre le dialogue de détails avant de valider la sélection
            _showGoalDataDialog(option['id']!, loc.translate(option['titleKey']!));
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? primaryColor : (isDark ? Colors.grey[800]! : Colors.grey[200]!), width: 2),
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            boxShadow: [
              if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: option['color'],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(option['icon'], color: option['iconColor'], size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loc.translate(option['titleKey']!), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(loc.translate(option['subtitleKey']!), style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.3)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.add_circle_outline,
                color: selected ? primaryColor : Colors.grey[300],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
