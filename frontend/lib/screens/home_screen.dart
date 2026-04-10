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
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:async';

/// Écran principal du tableau de bord
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

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    // Refresh every minute to update time/vitals sync conceptually
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) _loadDashboard(silent: true);
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
        title: const Text('Saisir mes vitaux'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: stepsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nombre de pas',
                  prefixIcon: Icon(Icons.directions_walk),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: sleepHCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Sommeil (h)',
                        prefixIcon: Icon(Icons.bedtime),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: sleepMCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Min',
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
            child: const Text('Annuler'),
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
                      content: Text('✓ $steps pas · ${hours}h${mins}m de sommeil enregistrés'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    stepsCtrl.dispose();
    sleepHCtrl.dispose();
    sleepMCtrl.dispose();
  }

  /// Synchronise les vitaux depuis Health Connect en arrière-plan
  Future<void> _syncHealthConnect({bool showFeedback = false}) async {
    final healthService = HealthService();
    // Vérification de disponibilité (méthode statique, pas de binding IPC)
    final available = await healthService.isAvailable();
    if (!available) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Health Connect non disponible sur cet appareil.'),
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
          const SnackBar(
            content: Text('Accès Health Connect requis. Vérifiez les paramètres de l\'appli Santé Connect ou relancez l\'application.'),
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
              content: Text('✓ $steps pas · ${sleep ~/ 60}h${sleep % 60}m synchronisés'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (_) {}
    } else if (showFeedback && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune donnée Health Connect disponible aujourd\'hui.')),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboard({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final data = await Api.getDashboard();
      if (!mounted) return;
      setState(() {
        _dashboardData = data;
        _loading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = widget.themeProvider.isDarkMode;
    final primaryColor = Theme.of(context).primaryColor;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA);

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
                          _buildNutritionTimeline(isDark, primaryColor),
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
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dateStr = "${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}";

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: primaryColor.withOpacity(0.2),
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
                "Hi, $name!",
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
        IconButton(
          icon: const Icon(Icons.calendar_today_outlined),
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          onPressed: () {
            // Future calendar feature
          },
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

    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.translate('daily_nutrition'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Ring progress
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 8,
                      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            left.toInt().toString(),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            loc.translate('calories_left').split(' ')[0], // 'Kcal'
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Macros
              Expanded(
                child: Column(
                  children: [
                    _buildMacroBar('Protein', nutrition['protein'], const Color(0xFF4CAF50), isDark, loc),
                    const SizedBox(height: 12),
                    _buildMacroBar('Carbs', nutrition['carbs'], const Color(0xFFFFB84D), isDark, loc),
                    const SizedBox(height: 12),
                    _buildMacroBar('Fat', nutrition['fat'], const Color(0xFF9C27B0), isDark, loc),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBar(String name, Map<String, dynamic>? data, Color color, bool isDark, AppLocalizations loc) {
    if (data == null) return const SizedBox();
    final consumed = data['consumed']?.toDouble() ?? 0.0;
    final goal = data['goal']?.toDouble() ?? 100.0;
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
              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            Text(
              "${consumed.toInt()}/${goal.toInt()}g",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
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
          Color color;
          IconData icon;
          if (type == 'hydration') { color = Colors.blue; icon = Icons.water_drop; }
          else if (type == 'sleep') { color = Colors.indigo; icon = Icons.nightlight; }
          else if (type == 'positive') { color = Colors.green; icon = Icons.thumb_up; }
          else if (type == 'overeating') { color = Colors.red; icon = Icons.warning; }
          else { color = Colors.orange; icon = Icons.info; }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    insight['message'],
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
        border: Border.all(color: accentColor.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
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
  Widget _buildNutritionTimeline(bool isDark, Color primaryColor) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? Colors.grey[400]! : const Color(0xFF64748B);
    final lineColor = isDark ? Colors.white24 : const Color(0xFFDDE3EC);
    final accentBlue = primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Nutrition Timeline',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                'View All',
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
                _buildTimelineMealItem(
                  isDark: isDark,
                  cardColor: cardColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  accentBlue: accentBlue,
                  timeLabel: '08:15 AM',
                  title: 'Avocado Toast & Egg',
                  subtitle: '340 kcal • 18g Protein',
                  autoSynced: true,
                  isCurrent: false,
                ),
                const SizedBox(height: 10),
                _buildTimelineMealItem(
                  isDark: isDark,
                  cardColor: cardColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  accentBlue: accentBlue,
                  timeLabel: '11:00 AM',
                  title: 'Greek Yogurt with Berries',
                  subtitle: '120 kcal • 12g Protein',
                  autoSynced: false,
                  isCurrent: false,
                ),
                const SizedBox(height: 8),
                _buildNowSmartScan(
                  isDark: isDark,
                  accentBlue: accentBlue,
                  textSecondary: textSecondary,
                ),
              ],
            ),
          ],
        ),
      ],
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
    required bool autoSynced,
    required bool isCurrent,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isCurrent ? accentBlue : (isDark ? const Color(0xFF26324A) : accentBlue.withOpacity(0.10)),
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
                        color: accentBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'AUTO-SYNCED',
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
                      ),
                      child: Icon(Icons.fastfood, color: textSecondary, size: 34),
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
                color: accentBlue.withOpacity(0.25),
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
                'NOW',
                style: TextStyle(
                  color: accentBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF18202E) : accentBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: accentBlue.withOpacity(0.35),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Ready for Lunch?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: accentBlue,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Scan your meal for instant macro tracking',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.document_scanner, color: Colors.white, size: 20),
                      label: const Text(
                        'Start Smart Scan',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
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
    final steps = vitals['steps'] ?? 0;
    final stepsGoal = vitals['stepsGoal'] ?? 10000;
    final sleep = vitals['sleepDuration'] ?? 0;
    final sleepQuality = vitals['sleepQuality'] ?? 85;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.translate('todays_vitals'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildVitalCard(
              icon: FontAwesomeIcons.shoePrints,
              label: loc.translate('steps').toUpperCase(),
              value: _formatSteps(steps),
              subtext: 'Goal: ${_formatSteps(stepsGoal)}',
              color: const Color(0xFFFF8A34),
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _buildVitalCard(
              icon: Icons.nightlight_round,
              label: loc.translate('sleep').toUpperCase(),
              value: "${sleep ~/ 60}h ${sleep % 60}m",
              subtext: '$sleepQuality% Sleep Quality',
              color: const Color(0xFF5B5BF2),
              isDark: isDark,
            ),
          ],
        ),
        const SizedBox(height: 20), // Reduced gap before next section
      ],
    );
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
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7FAFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 22),
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
              subtext,
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
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'HOME', true, primaryColor, isDark, () {}),
              _buildNavItem(Icons.insights_outlined, 'INSIGHTS', false, primaryColor, isDark, () {
                setState(() => _quickAddExpanded = false);
                Navigator.pushReplacementNamed(context, '/meals');
              }),
              _buildPlusNavItem(primaryColor),
              _buildNavItem(Icons.person_outline, 'PROFILE', false, primaryColor, isDark, () {
                setState(() => _quickAddExpanded = false);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileSummaryScreen(themeProvider: widget.themeProvider)),
                );
              }),
              _buildNavItem(Icons.settings_outlined, 'SETTINGS', false, primaryColor, isDark, () {
                setState(() => _quickAddExpanded = false);
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
                      color: primaryColor.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
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
                color: highlighted ? color.withOpacity(0.12) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: highlighted ? color : color.withOpacity(0.35), width: highlighted ? 2 : 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.16),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera scan bientot disponible')),
      );
      return;
    }
    if (index == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barcode scan bientot disponible')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddMealScreen(themeProvider: widget.themeProvider)),
    ).then((_) => _loadDashboard(silent: true));
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, Color primaryColor, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? primaryColor : Colors.grey,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? primaryColor : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
