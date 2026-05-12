import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/services/api.dart';
import 'package:frontend/screens/add_meal_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/core/theme_provider.dart';
import 'package:frontend/screens/profile_summary_screen.dart';
import 'package:frontend/screens/settings_screen.dart';
import 'package:frontend/core/app_localizations.dart';
import 'package:frontend/services/health_service.dart';
import 'package:frontend/services/step_service.dart';
import 'package:frontend/services/sleep_service.dart';
import 'package:frontend/services/sync_service.dart';
import 'package:frontend/models/health_data.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:frontend/screens/barcode_scanner_screen.dart';
import 'package:frontend/screens/product_search_screen.dart';
import 'package:frontend/screens/smart_scan_screen.dart';
import 'dart:async';
import 'package:frontend/widgets/spotlight_clipper.dart';

/// Ã‰cran principal du tableau de bord
class HomeScreen extends StatefulWidget {
  final ThemeProvider themeProvider;
  
  const HomeScreen({super.key, required this.themeProvider});
  
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  Map<String, dynamic>? _dashboardData;
  Timer? _timer;
  bool _quickAddExpanded = false;
  int? _hoveredQuickAction;
  final GlobalKey _plusMenuKey = GlobalKey();
  List<dynamic> _todayMeals = [];
  final GlobalKey<AnimatedListState> _timelineKey = GlobalKey<AnimatedListState>();

  // â”€â”€ DonnÃ©es temps rÃ©el (capteurs locaux) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  int _liveSteps = 0;
  DailySummary? _liveSleep;
  StreamSubscription<int>? _stepSub;
  StreamSubscription<DailySummary>? _sleepSub;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    // Refresh every minute to update time/vitals sync conceptually
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) _loadDashboard(silent: true);
    });

    // Ã‰couter les pas en temps rÃ©el
    _liveSteps = StepService().todaySteps;
    _stepSub = StepService().stepStream.listen((steps) {
      if (mounted) setState(() => _liveSteps = steps);
      // Notifier le SleepService de l'activitÃ©
      SleepService().onNewSteps(steps);
    });

    // Ã‰couter les mises Ã  jour du sommeil
    _sleepSub = SleepService().sleepStream.listen((summary) {
      if (mounted) setState(() => _liveSleep = summary);
    });
  }

  /// Affiche un dialogue de saisie manuelle des vitaux (Pas + Sommeil)
  Future<void> _showVitalsInputDialog() async {
    final stepsCtrl = TextEditingController();
    final sleepHCtrl = TextEditingController();
    final sleepMCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('input_vitals')),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: stepsCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).translate('steps_label'),
                  prefixIcon: const Icon(Icons.directions_walk),
                ),
                validator: (v) => (v == null || v.isEmpty) ? AppLocalizations.of(context).translate('required') : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: sleepHCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '${AppLocalizations.of(context).translate('sleep')} (${AppLocalizations.of(context).translate('hours')})',
                        prefixIcon: const Icon(Icons.bedtime),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: sleepMCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).translate('sleep_minutes'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              try {
                final steps = int.tryParse(stepsCtrl.text) ?? 0;
                final hours = int.tryParse(sleepHCtrl.text) ?? 0;
                final mins = int.tryParse(sleepMCtrl.text) ?? 0;
                final sleepMinutes = hours * 60 + mins;
                await Api.updateVitals({'steps': steps, 'sleepDuration': sleepMinutes});
                _loadDashboard(silent: true);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✓ $steps ${AppLocalizations.of(context).translate('steps_unit')} · ${hours}h${mins}m ${AppLocalizations.of(context).translate('sleep_recorded')}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  final loc = AppLocalizations.of(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${loc.translate('error')}: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text(AppLocalizations.of(context).translate('save')),
          ),
        ],
      ),
    );

    stepsCtrl.dispose();
    sleepHCtrl.dispose();
    sleepMCtrl.dispose();
  }

  /// Synchronise les vitaux depuis Health Connect en arriÃ¨re-plan
  Future<void> _syncHealthConnect({bool showFeedback = false}) async {
    final healthService = HealthService();
    // VÃ©rification de disponibilitÃ© (mÃ©thode statique, pas de binding IPC)
    final available = await healthService.isAvailable();
    if (!available) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('health_connect_unavailable')),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    bool authorized = false;
    try {
      authorized = await healthService.authorize();
    } catch (_) {
      authorized = false;
    }

    if (!authorized) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('health_connect_required')),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    int steps = 0;
    int sleep = 0;
    try { steps = await healthService.getTodaySteps(); } catch (_) {}
    try { sleep = await healthService.getLastNightSleep(); } catch (_) {}

    if (steps > 0 || sleep > 0) {
      try {
        await Api.updateVitals({'steps': steps, 'sleepDuration': sleep});
        if (mounted) _loadDashboard(silent: true);
        if (showFeedback && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('âœ“ $steps pas Â· ${sleep ~/ 60}h${sleep % 60}m synchronisÃ©s'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (_) {}
    } else if (showFeedback && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune donnÃ©e Health Connect disponible aujourd\'hui.')),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stepSub?.cancel();
    _sleepSub?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboard({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final data = await Api.getDashboard();
      if (!mounted) return;
      final newMeals = data['todayMeals'] ?? [];
      
      // Animation logic for AnimatedList
      if (_todayMeals.isEmpty && newMeals.isNotEmpty) {
        // Initial load
        setState(() {
          _dashboardData = data;
          _todayMeals = List.from(newMeals);
          _loading = false;
        });
      } else if (newMeals.length > _todayMeals.length) {
        // Items added (added at the end for oldest-to-newest order)
        final addedCount = newMeals.length - _todayMeals.length;
        final startIndex = _todayMeals.length;
        setState(() {
          _dashboardData = data;
          _loading = false;
        });
        for (int i = 0; i < addedCount; i++) {
          final newIdx = startIndex + i;
          _todayMeals.add(newMeals[newIdx]);
          _timelineKey.currentState?.insertItem(newIdx);
        }
      } else {
        // No new items or deletion (simpler refresh)
        setState(() {
          _dashboardData = data;
          _todayMeals = List.from(newMeals);
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _addWater() async {
    try {
      await Api.addWater(amount: 250);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).translate('water_added'))),
      );
      _loadDashboard(silent: true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen(themeProvider: widget.themeProvider)),
      (_) => false,
    );
  }

  /// Ouvre le scanner et redirige vers l'ajout de repas si un produit est trouvÃ©
  Future<void> _openScanner() async {
    setState(() => _quickAddExpanded = false);
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    
    if (result != null && mounted) {
      if (result == true) {
        // Le repas a Ã©tÃ© enregistrÃ© DIRECTEMENT depuis le scanner
        _loadDashboard(silent: true);
        return;
      }

      final product = result is Map ? result['product'] as NutritionProduct? : result as NutritionProduct?;
      final quantity = result is Map ? result['quantity'] as double? : null;

      if (product != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddMealScreen(
              themeProvider: widget.themeProvider,
              initialProduct: product,
              initialQuantity: quantity,
            ),
          ),
        ).then((_) => _loadDashboard(silent: true));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = widget.themeProvider.isDarkMode;
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final bgColor = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _dashboardData == null
              ? Center(child: Text(loc.translate('error')))
              : RefreshIndicator(
                  onRefresh: _loadDashboard,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 25.0, left: 20.0, right: 20.0, bottom: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(isDark, primaryColor, loc),
                          const SizedBox(height: 24),
                          _buildDailyNutrition(isDark, primaryColor, loc),
                          const SizedBox(height: 18),
                          _buildInsights(isDark, loc),
                          const SizedBox(height: 18),
                          _buildVitals(isDark, primaryColor, loc),
                          const SizedBox(height: 14),
                          _buildQuickActions(isDark, primaryColor, loc),
                          const SizedBox(height: 18),
                          _buildNutritionTimeline(isDark, primaryColor, loc),
                        ],
                      ),
                    ),
                  ),
                ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // ==========================================
  // 1. Header
  // ==========================================
  Widget _buildHeader(bool isDark, Color primaryColor, AppLocalizations loc) {
    final user = _dashboardData?['user'] ?? {};
    final name = user['name'] ?? 'User';
    
    // Full date format (e.g. "Tuesday, 7 April")
    final now = DateTime.now();
    final months = [
      loc.translate('january'), loc.translate('february'), loc.translate('march'),
      loc.translate('april'), loc.translate('may'), loc.translate('june'),
      loc.translate('july'), loc.translate('august'), loc.translate('september'),
      loc.translate('october'), loc.translate('november'), loc.translate('december')
    ];
    final days = [
      loc.translate('monday'), loc.translate('tuesday'), loc.translate('wednesday'),
      loc.translate('thursday'), loc.translate('friday'), loc.translate('saturday'),
      loc.translate('sunday')
    ];
    final dateStr = "${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}";

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: primaryColor.withValues(alpha: 0.2),
            backgroundImage: (user['photoUrl'] != null) ? NetworkImage(user['photoUrl']) : null,
            child: (user['photoUrl'] == null) 
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(color: primaryColor, fontSize: 20, fontWeight: FontWeight.bold),
                )
              : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.translate('hi_name').replaceAll('{name}', name),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(dateStr, style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600])),
            ],
          ),
        ),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none),
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              onPressed: () {
                // Notifications feature
              },
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // 2. Daily Nutrition
  // ==========================================
  Widget _buildDailyNutrition(bool isDark, Color primaryColor, AppLocalizations loc) {
    final nutrition = _dashboardData?['nutrition'] ?? {};
    final consumed = nutrition['consumed']?.toDouble() ?? 0.0;
    final goal = nutrition['goal']?.toDouble() ?? 2100.0;
    final left = (goal - consumed).clamp(0, goal);
    final progress = (consumed / goal).clamp(0.0, 1.0);

    final theme = Theme.of(context);
    final cardColor = theme.cardColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? theme.dividerColor : Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.translate('daily_nutrition'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF6FF5B5).withValues(alpha: 0.1) : const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  loc.translate('in_progress'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF6FF5B5) : const Color(0xFF0EA5E9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Ring progress
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 10,
                      strokeCap: StrokeCap.round,
                      backgroundColor: isDark ? theme.dividerColor : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            left.toInt().toString(),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: isDark ? const Color(0xFFE8F5F0) : Colors.black87,
                              letterSpacing: -1,
                            ),
                          ),
                          Text(
                            loc.translate('calories_left'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isDark ? theme.colorScheme.secondary : (Colors.grey[600] ?? Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Macros Mini-Cards
              Expanded(
                child: Column(
                  children: [
                    _buildMacroProgressBar('protein', nutrition['protein'], const Color(0xFF7DA37C), isDark, loc),
                    const SizedBox(height: 12),
                    _buildMacroProgressBar('carbs', nutrition['carbs'], const Color(0xFF5BA4FA), isDark, loc),
                    const SizedBox(height: 12),
                    _buildMacroProgressBar('fats', nutrition['fats'] ?? nutrition['fat'], const Color(0xFFFFBB33), isDark, loc),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroProgressBar(String name, Map<String, dynamic>? data, Color color, bool isDark, AppLocalizations loc) {
    if (data == null) return const SizedBox();
    final consumed = (data['consumed']?.toDouble() ?? 0.0).toInt();
    int goal = (data['goal']?.toDouble() ?? 100.0).toInt();
    if (goal <= 0) goal = 100; // Fallback pour éviter la division par zéro ou "0/0g"
    final progress = (consumed / goal).clamp(0.0, 1.0);
    final localizedName = loc.translate(name.toLowerCase());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              localizedName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF9FBFB3) : Colors.grey[700],
              ),
            ),
            Text(
              "${consumed}/${goal}g",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDark ? const Color(0xFFE8F5F0) : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  if (isDark)
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 3. AI Insights
  // ==========================================
  Widget _buildInsights(bool isDark, AppLocalizations loc) {
    final insights = _dashboardData?['insights'] as List<dynamic>? ?? [];
    if (insights.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.translate('ai_insights'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ...insights.map((insight) {
          final type = insight['type'] as String;
          String message = insight['message'] as String;
          
          // Localize backend messages (supports both IDs and legacy strings)
          if (message == 'insight_hydration' || message.contains('water intake')) {
            message = loc.translate('insight_hydration');
          } else if (message == 'insight_sleep' || message.contains('less than 6 hours')) {
            message = loc.translate('insight_sleep');
          } else if (message == 'insight_protein' || message.contains('protein intake is low')) {
            message = loc.translate('insight_protein');
          } else if (message == 'insight_positive' || message.contains('Great job')) {
            message = loc.translate('insight_positive');
          } else if (message == 'insight_overeating' || message.contains('exceeded your daily calorie goal')) {
            if (message == 'insight_overeating') {
               final diff = insight['data']?['diff']?.toString() ?? '0';
               message = loc.translate('insight_overeating').replaceAll('{diff}', diff);
            } else {
              final parts = message.split('by ');
              if (parts.length > 1) {
                final diff = parts[1].split(' ').first;
                message = loc.translate('insight_overeating').replaceAll('{diff}', diff);
              }
            }
          } else {
            // Try to translate as key anyway
            message = loc.translate(message);
          }

          Color color;
          IconData icon;
          if (type == 'hydration') { color = Colors.blue; icon = Icons.water_drop; }
          else if (type == 'sleep') { color = Colors.indigo; icon = Icons.nightlight; }
          else if (type == 'positive') { color = Colors.green; icon = Icons.thumb_up; }
          else if (type == 'overeating') { color = Colors.red; icon = Icons.warning; }
          else if (type == 'protein') { color = Colors.orange; icon = Icons.fitness_center; }
          else { color = Colors.orange; icon = Icons.info; }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ==========================================
  // 4. Quick Actions
  // ==========================================
  Widget _buildQuickActions(bool isDark, Color primaryColor, AppLocalizations loc) {
    final waterTotal = (_dashboardData?['water']?['total'] ?? 0).toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.translate('quick_actions'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        _buildWaterQuickCard(
          isDark: isDark,
          accentColor: const Color(0xFF2F80ED),
          amountText: '${waterTotal}ml',
          label: loc.translate('water'),
          onAdd: _addWater,
        ),
      ],
    );
  }

  Widget _buildWaterQuickCard({
    required bool isDark,
    required Color accentColor,
    required String amountText,
    required String label,
    required VoidCallback onAdd,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFDDEBFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.local_drink, color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(amountText, style: TextStyle(fontSize: 30 / 1.35, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1F2937))),
                Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF5C6B7F))),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('+250ml', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. Nutrition Timeline
  // ==========================================
  Widget _buildNutritionTimeline(bool isDark, Color primaryColor, AppLocalizations loc) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? Colors.grey[400]! : const Color(0xFF64748B);
    final lineColor = isDark ? Colors.white24 : const Color(0xFFDDE3EC);
    final accentBlue = isDark ? primaryColor : const Color(0xFF166534);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                loc.translate('nutrition_timeline'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                loc.translate('view_all'),
                style: TextStyle(
                  color: accentBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Positioned(
              left: 17,
              top: 0,
              bottom: 0,
              child: Container(width: 3, color: lineColor),
            ),
            Column(
              children: [
                AnimatedList(
                  key: _timelineKey,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  initialItemCount: _todayMeals.length,
                  itemBuilder: (context, index, animation) {
                    final meal = _todayMeals[index];
                    return _buildAnimatedTimelineItem(meal, animation, isDark, cardColor, textPrimary, textSecondary, accentBlue, loc);
                  },
                ),
                _buildNowSmartScan(
                  isDark: isDark,
                  accentBlue: accentBlue,
                  textSecondary: textSecondary,
                  loc: loc,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnimatedTimelineItem(dynamic meal, Animation<double> animation, bool isDark, Color cardColor, Color textPrimary, Color textSecondary, Color accentBlue, AppLocalizations loc) {
    final created = (DateTime.tryParse(meal['createdAt'] ?? '') ?? DateTime.now()).toLocal();
    final hh = created.hour.toString().padLeft(2, '0');
    final mm = created.minute.toString().padLeft(2, '0');
    final nutrition = meal['nutrition'] ?? {};
    final kcal = (nutrition['calories'] ?? 0).toInt();
    final protein = (nutrition['protein'] ?? nutrition['proteins'] ?? 0).toInt();

    return FadeTransition(
      opacity: animation,
      child: SizeTransition(
        sizeFactor: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildTimelineMealItem(
              isDark: isDark,
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              accentBlue: accentBlue,
              timeLabel: '$hh:$mm',
              title: meal['name'] ?? loc.translate('meal_default'),
              subtitle: '$kcal kcal • ${protein}g Protein',
              imageUrl: meal['imageUrl'],
              autoSynced: meal['source'] == 'health_connect',
              isCurrent: false,
              loc: loc,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineMealItem({
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color accentBlue,
    required String timeLabel,
    required String title,
    required String subtitle,
    String? imageUrl,
    required bool autoSynced,
    required bool isCurrent,
    required AppLocalizations loc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isCurrent ? accentBlue : (isDark ? const Color(0xFF26324A) : accentBlue.withValues(alpha: 0.10)),
            shape: BoxShape.circle,
            border: Border.all(color: accentBlue, width: 2),
          ),
          child: Icon(
            autoSynced ? Icons.wb_sunny_outlined : Icons.restaurant_menu,
            color: isCurrent ? Colors.white : accentBlue,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    timeLabel,
                    style: TextStyle(
                      color: accentBlue,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (autoSynced) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: accentBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        loc.translate('auto_synced'),
                        style: TextStyle(
                          color: accentBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE4E9F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isDark ? Colors.grey[800] : const Color(0xFFF2F4F7),
                        image: (imageUrl != null && imageUrl.isNotEmpty)
                            ? DecorationImage(
                                image: NetworkImage(imageUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: (imageUrl == null || imageUrl.isEmpty)
                          ? Icon(Icons.fastfood, color: textSecondary, size: 34)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!autoSynced) Icon(Icons.edit, color: textSecondary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNowSmartScan({
    required bool isDark,
    required Color accentBlue,
    required Color textSecondary,
    required AppLocalizations loc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accentBlue,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: accentBlue.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.translate('now'),
                style: TextStyle(
                  color: accentBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final theme = Theme.of(context);
                  final isDark = theme.brightness == Brightness.dark;
                  final accentColor = isDark ? theme.primaryColor : const Color(0xFF166534);
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                    decoration: BoxDecoration(
                      color: isDark ? theme.cardColor : accentColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark ? theme.dividerColor : accentColor.withValues(alpha: 0.35),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          loc.translate('ready_for_meal'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          loc.translate('scan_meal_desc'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? const Color(0xFF9FBFB3) : Colors.grey[600],
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _openScanner,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            minimumSize: const Size(double.infinity, 50),
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                          label: const Text(
                            'Start Smart Scan',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 6. Today's Vitals
  // ==========================================
  Widget _buildVitals(bool isDark, Color primaryColor, AppLocalizations loc) {
    final vitals = _dashboardData?['vitals'] ?? {};
    final stepsGoal = vitals['stepsGoal'] ?? 10000;

    // Priorité : données temps réel (capteur) > données backend
    final steps = _liveSteps > 0 ? _liveSteps : (vitals['steps'] ?? 0);
    final sleep = _liveSleep?.sleepMinutes ?? (vitals['sleepDuration'] ?? 0);
    final sleepQuality = vitals['sleepQuality'] ?? 85;
    final sleepSource = _liveSleep?.sleepSource ?? 'manual';
    final sleepConfidence = _liveSleep?.sleepConfidence ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              loc.translate('todays_vitals'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            // Bouton synchronisation manuelle
            TextButton.icon(
              onPressed: () => SyncService().syncNow(),
              icon: Icon(Icons.sync, size: 16, color: primaryColor),
              label: Text('Sync', style: TextStyle(color: primaryColor, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // ── Carte Pas (temps réel) ──────────────────────────────────────────
            _buildVitalCard(
              icon: FontAwesomeIcons.shoePrints,
              label: loc.translate('steps').toUpperCase(),
              value: _formatSteps(steps),
              subtext: 'Objectif : ${_formatSteps(stepsGoal)}',
              color: const Color(0xFFFF8A34),
              isDark: isDark,
              badge: _liveSteps > 0 ? 'LIVE' : null,
              badgeColor: Colors.green,
            ),
            const SizedBox(width: 8),
            // ── Carte Sommeil (semi-auto) ──────────────────────────────────────
            _buildSleepCard(
              isDark: isDark,
              sleepMinutes: sleep,
              sleepSource: sleepSource,
              sleepConfidence: sleepConfidence,
              sleepQuality: sleepQuality,
              primaryColor: primaryColor,
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  /// Carte Sommeil dédiée avec badge source et bouton correction manuelle.
  Widget _buildSleepCard({
    required bool isDark,
    required int sleepMinutes,
    required String sleepSource,
    required int sleepConfidence,
    required int sleepQuality,
    required Color primaryColor,
  }) {
    const sleepColor = Color(0xFF5B5BF2);
    final h = sleepMinutes ~/ 60;
    final m = sleepMinutes % 60;
    final sleepText = sleepMinutes == 0 ? '--' : '${h}h ${m}m';
    final isAuto = sleepSource == 'auto';
    final confidenceColor = sleepConfidence >= 70
        ? Colors.green
        : sleepConfidence >= 40
            ? Colors.orange
            : Colors.red;

    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? theme.dividerColor : sleepColor.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.nightlight_round, color: Color(0xFF5B5BF2), size: 22),
                // Badge source : AUTO ou MANUEL
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isAuto
                        ? Colors.indigo.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isAuto ? 'AUTO' : 'MANUEL',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: isAuto ? Colors.indigo : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              sleepText,
              style: TextStyle(
                fontSize: 36 / 1.35,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 2),
            // Score de confiance (seulement si auto et > 0)
            if (isAuto && sleepConfidence > 0)
              Row(
                children: [
                  Icon(Icons.verified, size: 12, color: confidenceColor),
                  const SizedBox(width: 3),
                  Text(
                    'Confiance $sleepConfidence%',
                    style: TextStyle(fontSize: 11, color: confidenceColor),
                  ),
                ],
              )
            else
              Text(
                '$sleepQuality% Sleep Quality',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : const Color(0xFF6B7280),
                ),
              ),
            const SizedBox(height: 8),
            // Bouton de correction manuelle
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showSleepEditDialog(),
                icon: const Icon(Icons.edit, size: 12),
                label: const Text('Corriger', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  foregroundColor: sleepColor,
                  side: BorderSide(color: sleepColor.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialogue de correction manuelle du sommeil.
  Future<void> _showSleepEditDialog() async {
    TimeOfDay startTime = const TimeOfDay(hour: 23, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 7, minute: 0);

    final pickedStart = await showTimePicker(
      context: context,
      initialTime: startTime,
      helpText: 'Heure de coucher',
    );
    if (pickedStart == null || !mounted) return;
    startTime = pickedStart;

    final pickedEnd = await showTimePicker(
      context: context,
      initialTime: endTime,
      helpText: 'Heure de rÃ©veil',
    );
    if (pickedEnd == null || !mounted) return;
    endTime = pickedEnd;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - 1, startTime.hour, startTime.minute);
    var end = DateTime(now.year, now.month, now.day, endTime.hour, endTime.minute);
    if (end.isBefore(start)) end = end.add(const Duration(days: 1));

    await SleepService().setManual(start, end);
    final durationMin = end.difference(start).inMinutes;
    await Api.updateVitals({
      'sleepDuration': durationMin,
      'sleepStart': start.toIso8601String(),
      'sleepEnd': end.toIso8601String(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('âœ“ Sommeil corrigÃ© : ${durationMin ~/ 60}h ${durationMin % 60}m'),
          backgroundColor: Colors.indigo,
        ),
      );
    }
  }

  String _formatSteps(dynamic value) {
    final n = (value is num) ? value.toInt() : int.tryParse(value.toString()) ?? 0;
    final s = n.toString();
    final r = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      r.write(s[i]);
      final rem = s.length - i - 1;
      if (rem > 0 && rem % 3 == 0) r.write(',');
    }
    return r.toString();
  }

  Widget _buildVitalCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtext,
    required Color color,
    required bool isDark,
    String? badge,
    Color? badgeColor,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? theme.dividerColor : color.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 22),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (badgeColor ?? color).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: badgeColor ?? color,
                      ),
                    ),
                  )
                else
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.grey[400] : const Color(0xFF95A4B8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 36 / 1.35,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              badge != null ? label : subtext,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // Bottom Nav
  // ==========================================
  Widget _buildBottomNav(BuildContext context) {
    final isDark = widget.themeProvider.isDarkMode;
    final primaryColor = Theme.of(context).primaryColor;
    
    final navBg = isDark ? const Color(0xFF04120E) : Colors.white;
    final topBorder = isDark ? const Color(0xFF2A4A3F) : Colors.grey[200]!;
    
    return Container(
      decoration: BoxDecoration(
        color: navBg,
        border: Border(top: BorderSide(color: topBorder, width: 1)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_filled, 'HOME', true, primaryColor, isDark, () {}),
              _buildNavItem(Icons.insights_rounded, 'INSIGHTS', false, primaryColor, isDark, () {
                  setState(() => _quickAddExpanded = false);
                  Navigator.pushReplacementNamed(context, '/insights');
                }),
              _buildPlusNavItem(primaryColor),
              _buildNavItem(Icons.person_rounded, 'PROFILE', false, primaryColor, isDark, () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileSummaryScreen(themeProvider: widget.themeProvider)),
                );
              }),
              _buildNavItem(Icons.settings_rounded, 'SETTINGS', false, primaryColor, isDark, () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => SettingsScreen(themeProvider: widget.themeProvider)),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlusNavItem(Color primaryColor) {
    return SizedBox(
      key: _plusMenuKey,
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          _buildMiniActionButton(
            icon: Icons.photo_camera_outlined,
            color: primaryColor,
            expandedBottom: 74,
            expandedLeft: -58,
            highlighted: _hoveredQuickAction == 0,
            onTap: () => _executeQuickAction(0),
          ),
          _buildMiniActionButton(
            icon: Icons.qr_code_scanner,
            color: primaryColor,
            expandedBottom: 104,
            expandedLeft: 7,
            highlighted: _hoveredQuickAction == 1,
            onTap: () => _executeQuickAction(1),
          ),
          _buildMiniActionButton(
            icon: Icons.keyboard_outlined,
            color: primaryColor,
            expandedBottom: 74,
            expandedRight: -58,
            highlighted: _hoveredQuickAction == 2,
            onTap: () => _executeQuickAction(2),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutCubic,
            bottom: _quickAddExpanded ? -2 : 18,
            child: GestureDetector(
              onTap: () {
                if (_quickAddExpanded) {
                  setState(() {
                    _quickAddExpanded = false;
                    _hoveredQuickAction = null;
                  });
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddMealScreen(themeProvider: widget.themeProvider)),
                ).then((_) => _loadDashboard(silent: true));
              },
              onLongPressStart: (details) {
                setState(() {
                  _quickAddExpanded = true;
                  _hoveredQuickAction = null;
                });
                _updateQuickActionFromGlobal(details.globalPosition);
              },
              onLongPressMoveUpdate: (details) {
                _updateQuickActionFromGlobal(details.globalPosition);
              },
              onLongPressEnd: (_) {
                final selected = _hoveredQuickAction;
                if (selected != null) {
                  _executeQuickAction(selected);
                } else {
                  setState(() {
                    _quickAddExpanded = false;
                    _hoveredQuickAction = null;
                  });
                }
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
                child: Center(
                  child: AnimatedRotation(
                    turns: _quickAddExpanded ? 0.125 : 0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOutCubic,
                    child: const Icon(Icons.add, color: Colors.white, size: 34),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniActionButton({
    required IconData icon,
    required Color color,
    required double expandedBottom,
    double? expandedLeft,
    double? expandedRight,
    required bool highlighted,
    required VoidCallback onTap,
  }) {
    final bool usingLeft = expandedLeft != null;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      bottom: _quickAddExpanded ? expandedBottom : 8,
      left: usingLeft ? (_quickAddExpanded ? expandedLeft : 1) : null,
      right: !usingLeft ? (_quickAddExpanded ? expandedRight : 1) : null,
      child: AnimatedScale(
        scale: _quickAddExpanded ? 1 : 0.55,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
        child: AnimatedOpacity(
          opacity: _quickAddExpanded ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: highlighted ? color.withValues(alpha: 0.12) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: highlighted ? color : color.withValues(alpha: 0.35), width: highlighted ? 2 : 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 26),
            ),
          ),
        ),
      ),
    );
  }

  void _updateQuickActionFromGlobal(Offset globalPosition) {
    final ctx = _plusMenuKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPosition);
    const center = Offset(26, 26);
    const actionPoints = <Offset>[
      Offset(-56, -70),
      Offset(0, -102),
      Offset(56, -70),
    ];
    int? candidate;
    double minDistance = 9999;
    for (int i = 0; i < actionPoints.length; i++) {
      final p = center + actionPoints[i];
      final d = (local - p).distance;
      if (d < minDistance) {
        minDistance = d;
        candidate = i;
      }
    }
    final centerDistance = (local - center).distance;
    final next = centerDistance <= 34
        ? null
        : (minDistance <= 48 ? candidate : _hoveredQuickAction);
    if (_hoveredQuickAction != next) {
      setState(() => _hoveredQuickAction = next);
    }
  }

  void _executeQuickAction(int index) {
    setState(() {
      _quickAddExpanded = false;
      _hoveredQuickAction = null;
    });
    if (index == 0) {
      Navigator.push<dynamic>(
        context,
        MaterialPageRoute(builder: (_) => SmartScanScreen()),
      ).then((result) async {
        if (result != null && result is NutritionProduct) {
          try {
            final now = DateTime.now();
            final hour = now.hour;
            String type = 'snack';
            if (hour >= 5 && hour < 11) type = 'breakfast';
            else if (hour >= 11 && hour < 16) type = 'lunch';
            else if (hour >= 18 && hour < 23) type = 'dinner';

            await Api.addMeal({
              'name': result.name,
              'type': type,
              'quantity': 1,
              'unit': 'portion',
              'time': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
              'imageUrl': result.image,
              'nutrition': {
                'calories': result.nutrition['calories'] ?? 0,
                'carbs': result.nutrition['carbs'] ?? 0,
                'proteins': result.nutrition['proteins'] ?? 0,
                'fats': result.nutrition['fats'] ?? 0,
                'source': 'smart_scan',
              }
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Repas ajouté avec succès')));
            }
          } catch (e) {
            print("Erreur lors de l'ajout du repas scanné : $e");
          }
        }
        _loadDashboard(silent: true);
      });
      return;
    }
    if (index == 1) {
      _openScanner();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddMealScreen(themeProvider: widget.themeProvider)),
    ).then((_) => _loadDashboard(silent: true));
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, Color primaryColor, bool isDark, VoidCallback onTap) {
    final Color spotlightColor = isDark ? Colors.white : primaryColor;
    
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        height: 50,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (isActive)
              Positioned(
                top: -12,
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: spotlightColor,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
                        boxShadow: [
                          BoxShadow(
                            color: spotlightColor.withOpacity(0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    ClipPath(
                      clipper: SpotlightClipper(),
                      child: Container(
                        width: 56,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              spotlightColor.withOpacity(0.25),
                              spotlightColor.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Icon(
              icon,
              color: isActive ? spotlightColor : (isDark ? Colors.grey[600] : const Color(0xFF1E1E1E).withOpacity(0.5)),
              size: 30,
            ),
          ],
        ),
      ),
    );
  }
}

