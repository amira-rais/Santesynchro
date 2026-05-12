import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:frontend/services/api.dart';
import 'package:frontend/screens/add_meal_screen.dart';
import 'package:frontend/screens/edit_meal_screen.dart';
import 'package:frontend/core/theme_provider.dart';
import 'package:frontend/screens/profile_summary_screen.dart';
import 'package:frontend/screens/settings_screen.dart';
import 'package:frontend/widgets/spotlight_clipper.dart';
import 'package:frontend/core/app_localizations.dart';

/// Weekly insights screen with activity history.
class InsightsScreen extends StatefulWidget {
  final ThemeProvider themeProvider;

  const InsightsScreen({super.key, required this.themeProvider});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  bool loading = true;
  List<dynamic> meals = [];
  List<dynamic> progressionData = [];
  String _range = 'week';

  final Map<String, IconData> _mealIcons = {
    'breakfast': Icons.coffee,
    'lunch': Icons.restaurant,
    'dinner': Icons.dinner_dining,
    'snack': Icons.cake,
  };

  final Map<String, Color> _mealColors = {
    'breakfast': const Color(0xFFFFB84D),
    'lunch': const Color(0xFF4CAF50),
    'dinner': const Color(0xFF9C27B0),
    'snack': const Color(0xFFFF6B6B),
  };

  @override
  void initState() {
    super.initState();
    _loadMeals();
  }

  Future<void> _loadMeals() async {
    try {
      final data = await Api.getMeals();
      final prog = await Api.getProgressionData();
      if (!mounted) return;
      setState(() {
        meals = data;
        progressionData = prog;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context).translate('error')}: $e')));
    }
  }

  Future<void> _delete(String id) async {
    try {
      await Api.deleteMeal(id);
      _loadMeals();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context).translate('delete')}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeProvider.isDarkMode;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('insights_title'), style: const TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: _buildBottomNav(context),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRangeTabs(isDark, primaryColor),
                  const SizedBox(height: 14),
                  _buildConsistency(primaryColor, isDark),
                  const SizedBox(height: 18),
                  _buildProgressionCharts(primaryColor, isDark),
                  const SizedBox(height: 14),
                  _buildWeekDays(primaryColor, isDark),
                  const SizedBox(height: 18),
                  _buildSmartInsights(primaryColor, isDark),
                  const SizedBox(height: 20),
                  _buildActivityHistory(primaryColor, isDark),
                  const SizedBox(height: 18),
                ],
              ),
            ),
    );
  }

  Widget _buildRangeTabs(bool isDark, Color primaryColor) {
    Widget tab(String key, String text) {
      final active = _range == key;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _range = key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: active ? (isDark ? primaryColor.withOpacity(0.25) : Colors.white) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: active ? primaryColor : (isDark ? const Color(0xFF9FBFB3) : Colors.grey[600]),
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : const Color(0xFFF0F3F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          tab('day', AppLocalizations.of(context).translate('day')),
          tab('week', AppLocalizations.of(context).translate('week')),
          tab('month', AppLocalizations.of(context).translate('month'))
        ],
      ),
    );
  }

  Widget _buildConsistency(Color primaryColor, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context).translate('nutritional_consistency'), style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text('92%', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF111827))),
                  const SizedBox(width: 8),
                  Text('+5%', style: TextStyle(color: Colors.green[600], fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
        Text('Oct 23 - Oct 29', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF9FBFB3) : Colors.grey[500])),
      ],
    );
  }

  Widget _buildWeekDays(Color primaryColor, bool isDark) {
    final labels = [
      AppLocalizations.of(context).translate('mon'),
      AppLocalizations.of(context).translate('tue'),
      AppLocalizations.of(context).translate('wed'),
      AppLocalizations.of(context).translate('thu'),
      AppLocalizations.of(context).translate('fri'),
      AppLocalizations.of(context).translate('sat'),
      AppLocalizations.of(context).translate('sun'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels
          .map((d) => Text(
                d,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: d == 'WED' ? FontWeight.w700 : FontWeight.w500,
                  color: d == 'WED' ? primaryColor : (isDark ? const Color(0xFF9FBFB3) : Colors.grey[500]),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildProgressionCharts(Color primaryColor, bool isDark) {
    if (progressionData.isEmpty) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        child: Text(AppLocalizations.of(context).translate('loading_progression'), style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
      );
    }

    final List<FlSpot> caloriesSpots = [];
    final List<FlSpot> stepsSpots = [];
    
    double maxCal = 0;
    double maxSteps = 0;
    
    for (int i = 0; i < progressionData.length; i++) {
      final cal = (progressionData[i]['calories'] as num).toDouble();
      final steps = (progressionData[i]['steps'] as num).toDouble();
      caloriesSpots.add(FlSpot(i.toDouble(), cal));
      stepsSpots.add(FlSpot(i.toDouble(), steps));
      if (cal > maxCal) maxCal = cal;
      if (steps > maxSteps) maxSteps = steps;
    }

    final double stepsNormalizationFactor = maxCal / (maxSteps == 0 ? 1 : maxSteps);

    return Container(
      height: 240,
      padding: const EdgeInsets.only(right: 16, top: 16, bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A1F18) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF166534).withOpacity(0.3) : Colors.grey[200]!),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final isCal = spot.barIndex == 0;
                        final val = isCal ? spot.y.toInt() : (spot.y / stepsNormalizationFactor).toInt();
                        return LineTooltipItem(
                          '${isCal ? AppLocalizations.of(context).translate('energy') : AppLocalizations.of(context).translate('steps')}: $val',
                          TextStyle(
                            color: isCal ? primaryColor : const Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final days = [
                          AppLocalizations.of(context).translate('mon'),
                          AppLocalizations.of(context).translate('tue'),
                          AppLocalizations.of(context).translate('wed'),
                          AppLocalizations.of(context).translate('thu'),
                          AppLocalizations.of(context).translate('fri'),
                          AppLocalizations.of(context).translate('sat'),
                          AppLocalizations.of(context).translate('sun'),
                        ];
                        int index = value.toInt();
                        if (index < 0 || index >= days.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(days[index], style: TextStyle(color: isDark ? const Color(0xFF9FBFB3) : Colors.grey[500], fontSize: 10, fontWeight: FontWeight.w600)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (maxCal / 3).clamp(100, 2000).toDouble(),
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()}', style: TextStyle(color: isDark ? const Color(0xFF9FBFB3) : Colors.grey[500], fontSize: 10));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: caloriesSpots,
                    isCurved: true,
                    color: primaryColor,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [primaryColor.withOpacity(0.2), primaryColor.withOpacity(0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: stepsSpots.map((s) => FlSpot(s.x, s.y * stepsNormalizationFactor)).toList(),
                    isCurved: true,
                    color: const Color(0xFF10B981),
                    barWidth: 3,
                    dashArray: [5, 5],
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(AppLocalizations.of(context).translate('energy'), primaryColor),
              const SizedBox(width: 24),
              _buildLegendItem(AppLocalizations.of(context).translate('steps'), const Color(0xFF10B981)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: widget.themeProvider.isDarkMode ? Colors.white70 : Colors.black87)),
      ],
    );
  }

  Widget _buildMiniTrend(Color primaryColor, bool isDark) {
    // Keep it for now if needed elsewhere, but removed from build
    return const SizedBox();
  }

  Widget _buildSmartInsights(Color primaryColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppLocalizations.of(context).translate('smart_insights'), style: TextStyle(fontSize: 26 / 1.25, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF111827))),
            TextButton(onPressed: () {}, child: Text(AppLocalizations.of(context).translate('view_all'), style: TextStyle(color: primaryColor, fontWeight: FontWeight.w700))),
          ],
        ),
        SizedBox(
          height: 180,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildInsightCard(
                isDark: isDark,
                background: isDark ? const Color(0xFF132F25) : const Color(0xFFEAF3FF),
                chip: AppLocalizations.of(context).translate('pro_tip'),
                title: AppLocalizations.of(context).translate('tip_protein_title'),
                desc: AppLocalizations.of(context).translate('tip_protein_desc'),
                icon: Icons.restaurant,
                iconColor: primaryColor,
              ),
              const SizedBox(width: 10),
              _buildInsightCard(
                isDark: isDark,
                background: isDark ? const Color(0xFF0E2A20) : const Color(0xFFE8F9F0),
                chip: AppLocalizations.of(context).translate('hydration').toUpperCase(),
                title: AppLocalizations.of(context).translate('tip_hydration_title'),
                desc: AppLocalizations.of(context).translate('tip_hydration_desc'),
                icon: Icons.opacity,
                iconColor: const Color(0xFF1DB954),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsightCard({
    required bool isDark,
    required Color background,
    required String chip,
    required String title,
    required String desc,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      width: 245,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF2A4A3F) : Theme.of(context).dividerColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: iconColor),
                const SizedBox(width: 4),
                Text(chip, style: TextStyle(fontSize: 10, color: iconColor, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19 / 1.25, color: isDark ? Colors.white : const Color(0xFF111827))),
          const SizedBox(height: 4),
          Text(desc, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : const Color(0xFF4B5563))),
        ],
      ),
    );
  }

  Widget _buildActivityHistory(Color primaryColor, bool isDark) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final meal in meals) {
      final m = meal as Map<String, dynamic>;
      final created = DateTime.tryParse((m['createdAt'] ?? '').toString()) ?? DateTime.now();
      final key = '${created.year}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(m);
    }
    final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context).translate('activity_history'), style: TextStyle(fontSize: 26 / 1.25, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF111827))),
        const SizedBox(height: 10),
        if (keys.isEmpty)
          Text(AppLocalizations.of(context).translate('no_meal_history'), style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]))
        else
          ...keys.take(5).map((k) {
            final dayMeals = grouped[k]!;
            final total = dayMeals.fold<double>(0, (sum, m) => sum + ((m['kcal'] ?? 0).toDouble()));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatSectionDate(context, k),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.grey[400] : Colors.grey[500],
                        ),
                      ),
                      Text('${total.toInt()} ${AppLocalizations.of(context).translate('kcal')}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.grey[300] : const Color(0xFF374151))),
                    ],
                  ),
                ),
                ...dayMeals.take(3).map((m) => _buildMealHistoryTile(m, isDark, primaryColor)),
                const SizedBox(height: 6),
              ],
            );
          }),
      ],
    );
  }

  Widget _buildMealHistoryTile(Map<String, dynamic> meal, bool isDark, Color primaryColor) {
    final type = meal['type']?.toString() ?? 'snack';
    final color = _mealColors[type] ?? primaryColor;
    final icon = _mealIcons[type] ?? Icons.restaurant;
    final created = DateTime.tryParse((meal['createdAt'] ?? '').toString()) ?? DateTime.now();
    final hh = created.hour.toString().padLeft(2, '0');
    final mm = created.minute.toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF2A4A3F) : Theme.of(context).dividerColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final updated = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EditMealScreen(meal: meal)),
          );
          if (updated == true) _loadMeals();
        },
        onLongPress: () => _delete(meal['id'].toString()),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal['name']?.toString() ?? AppLocalizations.of(context).translate('meal_default'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF111827)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meal['description']?.toString() ?? '${meal['quantity'] ?? ''}${meal['unit'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$hh:$mm', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[500])),
                  const SizedBox(height: 2),
                  Text(
                    '${(meal['kcal'] ?? 0).toInt()}',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20 / 1.25, color: isDark ? Colors.white : const Color(0xFF111827)),
                  ),
                  Text(AppLocalizations.of(context).translate('unit_kcal'), style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey[500])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSectionDate(BuildContext context, String ymd) {
    final dt = DateTime.tryParse(ymd);
    if (dt == null) return ymd;
    final week = [
      AppLocalizations.of(context).translate('monday'),
      AppLocalizations.of(context).translate('tuesday'),
      AppLocalizations.of(context).translate('wednesday'),
      AppLocalizations.of(context).translate('thursday'),
      AppLocalizations.of(context).translate('friday'),
      AppLocalizations.of(context).translate('saturday'),
      AppLocalizations.of(context).translate('sunday'),
    ];
    final months = [
      AppLocalizations.of(context).translate('jan'),
      AppLocalizations.of(context).translate('feb'),
      AppLocalizations.of(context).translate('mar'),
      AppLocalizations.of(context).translate('apr'),
      AppLocalizations.of(context).translate('may'),
      AppLocalizations.of(context).translate('jun'),
      AppLocalizations.of(context).translate('jul'),
      AppLocalizations.of(context).translate('aug'),
      AppLocalizations.of(context).translate('sep'),
      AppLocalizations.of(context).translate('oct'),
      AppLocalizations.of(context).translate('nov'),
      AppLocalizations.of(context).translate('dec'),
    ];
    return '${week[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}';
  }

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
              color: Colors.black.withOpacity(0.04),
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
              _buildNavItem(Icons.home_rounded, 'HOME', false, primaryColor, isDark, () {
                Navigator.pushReplacementNamed(context, '/home');
              }),
              _buildNavItem(Icons.insights_rounded, 'INSIGHTS', true, primaryColor, isDark, () {}),
              _buildPlusNavItem(primaryColor, () async {
                final added = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddMealScreen(themeProvider: widget.themeProvider)),
                );
                if (added == true) _loadMeals();
              }),
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

  Widget _buildPlusNavItem(Color primaryColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: primaryColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
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