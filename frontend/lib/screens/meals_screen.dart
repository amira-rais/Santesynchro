import 'package:flutter/material.dart';
import 'package:frontend/services/api.dart';
import 'package:frontend/screens/add_meal_screen.dart';
import 'package:frontend/screens/edit_meal_screen.dart';
import 'package:frontend/core/theme_provider.dart';
import 'package:frontend/screens/profile_summary_screen.dart';
import 'package:frontend/screens/settings_screen.dart';

/// Weekly insights screen with activity history.
class MealsScreen extends StatefulWidget {
  final ThemeProvider themeProvider;

  const MealsScreen({super.key, required this.themeProvider});

  @override
  State<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends State<MealsScreen> {
  bool loading = true;
  List<dynamic> meals = [];
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
      if (!mounted) return;
      setState(() {
        meals = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur chargement: $e')));
    }
  }

  Future<void> _delete(String id) async {
    try {
      await Api.deleteMeal(id);
      _loadMeals();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Suppression: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeProvider.isDarkMode;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Insights', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined, size: 20),
            onPressed: () {},
          ),
        ],
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
                  _buildMiniTrend(primaryColor, isDark),
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
                color: active ? primaryColor : (isDark ? Colors.grey[400] : Colors.grey[600]),
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F3F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [tab('day', 'Day'), tab('week', 'Week'), tab('month', 'Month')],
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
              Text('Nutritional Consistency', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12)),
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
        Text('Oct 23 - Oct 29', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[500])),
      ],
    );
  }

  Widget _buildWeekDays(Color primaryColor, bool isDark) {
    const labels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels
          .map((d) => Text(
                d,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: d == 'WED' ? FontWeight.w700 : FontWeight.w500,
                  color: d == 'WED' ? primaryColor : (isDark ? Colors.grey[500] : Colors.grey[500]),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildMiniTrend(Color primaryColor, bool isDark) {
    final points = <double>[0.35, 0.40, 0.52, 0.48, 0.58, 0.62, 0.66];
    return SizedBox(
      height: 48,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(points.length, (i) {
          final active = i == 2;
          return Container(
            width: 30,
            height: 36 * points[i],
            decoration: BoxDecoration(
              color: active ? primaryColor : (isDark ? Colors.white24 : const Color(0xFFDDE3EC)),
              borderRadius: BorderRadius.circular(6),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSmartInsights(Color primaryColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Smart Insights', style: TextStyle(fontSize: 26 / 1.25, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF111827))),
            TextButton(onPressed: () {}, child: Text('View All', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w700))),
          ],
        ),
        SizedBox(
          height: 132,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildInsightCard(
                isDark: isDark,
                background: isDark ? const Color(0xFF1D2A3D) : const Color(0xFFEAF3FF),
                chip: 'PRO TIP',
                title: 'Protein Power-Up!',
                desc: 'You ate 20% more protein this week compared to last! Great for muscle recovery.',
                icon: Icons.restaurant,
                iconColor: primaryColor,
              ),
              const SizedBox(width: 10),
              _buildInsightCard(
                isDark: isDark,
                background: isDark ? const Color(0xFF193229) : const Color(0xFFE8F9F0),
                chip: 'HYDRATION',
                title: 'Consistency Win',
                desc: 'You hit your hydration goal 5 days in a row.',
                icon: Icons.opacity,
                iconColor: Colors.green,
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
        border: Border.all(color: iconColor.withOpacity(0.25)),
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
        Text('Activity History', style: TextStyle(fontSize: 26 / 1.25, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF111827))),
        const SizedBox(height: 10),
        if (keys.isEmpty)
          Text('No meal history yet.', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]))
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
                        _formatSectionDate(k),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.grey[400] : Colors.grey[500],
                        ),
                      ),
                      Text('${total.toInt()} kcal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.grey[300] : const Color(0xFF374151))),
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
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
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
                      meal['name']?.toString() ?? 'Meal',
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
                  Text('KCAL', style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey[500])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSectionDate(String ymd) {
    final dt = DateTime.tryParse(ymd);
    if (dt == null) return ymd;
    const week = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return '${week[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}';
  }

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
              _buildNavItem(Icons.home_outlined, 'HOME', false, primaryColor, isDark, () {
                Navigator.pushReplacementNamed(context, '/home');
              }),
              _buildNavItem(Icons.insights, 'INSIGHTS', true, primaryColor, isDark, () {}),
              _buildPlusNavItem(primaryColor, () async {
                final added = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddMealScreen(themeProvider: widget.themeProvider)),
                );
                if (added == true) _loadMeals();
              }),
              _buildNavItem(Icons.person_outline, 'PROFILE', false, primaryColor, isDark, () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileSummaryScreen(themeProvider: widget.themeProvider)),
                );
              }),
              _buildNavItem(Icons.settings_outlined, 'SETTINGS', false, primaryColor, isDark, () {
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