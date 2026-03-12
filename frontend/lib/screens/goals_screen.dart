import 'package:flutter/material.dart';
import 'package:frontend/core/theme_provider.dart';

class GoalsScreen extends StatefulWidget {
  final ThemeProvider themeProvider;

  const GoalsScreen({super.key, required this.themeProvider});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  String? _selectedGoal;
  
  // Weights State
  double _goalWeight = 68.5;
  String _unit = 'kg';
  String _pace = 'Steady';

  final List<Map<String, dynamic>> _goalOptions = [
    {
      'id': 'weight_loss',
      'title': 'Weight Loss',
      'subtitle': 'Focus on burning fat and building sustainable daily habits.',
      'icon': Icons.fitness_center,
      'color': const Color(0xFFE0F2FE),
      'iconColor': const Color(0xFF0EA5E9),
    },
    {
      'id': 'muscle_gain',
      'title': 'Muscle Gain',
      'subtitle': 'Build functional strength and increase physical performance.',
      'icon': Icons.fitness_center,
      'color': const Color(0xFFFFF7ED),
      'iconColor': const Color(0xFFF97316),
    },
    {
      'id': 'diabetes',
      'title': 'Manage Diabetes',
      'subtitle': 'Optimize blood sugar levels through tailored nutrition plans.',
      'icon': Icons.touch_app,
      'color': const Color(0xFFF0FDF4),
      'iconColor': const Color(0xFF22C55E),
    },
    {
      'id': 'lifestyle',
      'title': 'Healthy Lifestyle',
      'subtitle': 'Improve energy levels and focus on overall mental well-being.',
      'icon': Icons.spa,
      'color': const Color(0xFFF5F3FF),
      'iconColor': const Color(0xFF8B5CF6),
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.themeProvider.isDarkMode;
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black, size: 20),
          onPressed: () {
            if (_currentStep > 0) {
              _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: _buildSegmentedProgress(),
        actions: [
          TextButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/meals'),
            child: Text('Skip', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentStep = index),
        children: [
          _buildStep1(primaryColor, isDark),
          _buildStep2(primaryColor, isDark),
        ],
      ),
    );
  }

  Widget _buildSegmentedProgress() {
    final theme = Theme.of(context);
    final isDark = widget.themeProvider.isDarkMode;
    final primaryColor = theme.primaryColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        bool isActive = index <= _currentStep;
        return Container(
          width: 30,
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

  // STEP 1: Goal Selection
  Widget _buildStep1(Color primaryColor, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What is your primary\ngoal?',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, height: 1.2),
          ),
          const SizedBox(height: 12),
          Text(
            'Select the focus area that best matches your health journey.',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          ..._goalOptions.map((option) => _buildGoalCard(option, primaryColor, isDark)).toList(),
          _buildGeneralWellnessCard(primaryColor, isDark),
          const SizedBox(height: 32),
          _buildContinueButton(
            text: 'Continue',
            onPressed: _selectedGoal == null ? null : () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
          ),
        ],
      ),
    );
  }

  // STEP 2: Goal Details
  Widget _buildStep2(Color primaryColor, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weight Loss Goal',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Step 1 of 5: Let\'s define your target',
            style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(height: 40),
          
          _buildWeightPicker(isDark),
          const SizedBox(height: 40),
          
          const Text(
            'Choose your preferred pace',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildPaceSelector(isDark),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'A steady pace is generally the most sustainable for long-term health.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: 32),
          
          _buildDailyForecast(primaryColor, isDark),
          const SizedBox(height: 32),
          
          _buildContinueButton(
            text: 'Set Goal & Continue',
            onPressed: () {
              // TODO: Handle completion
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeightPicker(bool isDark) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('What is your goal weight?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: ['kg', 'lbs'].map((u) {
                  bool active = _unit == u;
                  return GestureDetector(
                    onTap: () => setState(() => _unit = u),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? (isDark ? Colors.grey[700] : Colors.white) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: active ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : [],
                      ),
                      child: Text(
                        u, 
                        style: TextStyle(
                          color: active ? primaryColor : Colors.grey, 
                          fontWeight: FontWeight.bold
                        )
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.scale_outlined, size: 40, color: Colors.grey),
            const SizedBox(width: 20),
            Text(
              _goalWeight.toStringAsFixed(1),
              style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 20),
            Column(
              children: [
                IconButton(onPressed: () => setState(() => _goalWeight += 0.5), icon: const Icon(Icons.keyboard_arrow_up, size: 30)),
                IconButton(onPressed: () => setState(() => _goalWeight -= 0.5), icon: const Icon(Icons.keyboard_arrow_down, size: 30)),
              ],
            ),
          ],
        ),
        const Divider(),
      ],
    );
  }

  Widget _buildPaceSelector(bool isDark) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final paces = [
      {'label': 'Slow', 'value': '0.25kg/wk'},
      {'label': 'Steady', 'value': '0.5kg/wk'},
      {'label': 'Fast', 'value': '1.0kg/wk'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: paces.map((p) {
          bool active = _pace == p['label'];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _pace = p['label']!),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: active ? (isDark ? Colors.grey[700] : Colors.white) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: active ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : [],
                ),
                child: Column(
                  children: [
                    Text(
                      p['label']!, 
                      style: TextStyle(
                        color: active ? primaryColor : Colors.grey, 
                        fontWeight: FontWeight.bold, 
                        fontSize: 16
                      )
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p['value']!, 
                      style: TextStyle(
                        color: active ? primaryColor.withOpacity(0.7) : Colors.grey[400], 
                        fontSize: 12
                      )
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDailyForecast(Color primaryColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryColor.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: primaryColor, size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Forecast', 
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold, 
                      color: isDark ? Colors.white : const Color(0xFF065F46) // Darker variant of mint for text
                    )
                  ),
                  Text(
                    'Based on your "$_pace" pace choice', 
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600])
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildForecastStat('DAILY DEFICIT', '-500 kcal', isDark),
              _buildForecastStat('ESTIMATED GOAL DATE', 'Oct 12 2024', isDark),
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
                TextSpan(text: 'To reach ', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                TextSpan(text: '${_goalWeight}kg', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                TextSpan(text: ' by October, your daily calorie target will be approximately ', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                TextSpan(text: '1 850 kcal', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildGoalCard(Map<String, dynamic> option, Color primaryColor, bool isDark) {
    bool isSelected = _selectedGoal == option['id'];
    return GestureDetector(
      onTap: () => setState(() => _selectedGoal = option['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? primaryColor : (isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0)), width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: isDark ? option['iconColor'].withOpacity(0.2) : option['color'], borderRadius: BorderRadius.circular(12)),
              child: Icon(option['icon'], color: option['iconColor'], size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option['title'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                  const SizedBox(height: 4),
                  Text(option['subtitle'], style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : const Color(0xFF64748B))),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: primaryColor, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralWellnessCard(Color primaryColor, bool isDark) {
    bool isSelected = _selectedGoal == 'general';
    return GestureDetector(
      onTap: () => setState(() => _selectedGoal = 'general'),
      child: Container(
        height: 120,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: const DecorationImage(
            image: AssetImage('assets/images/general_wellness_bg.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black38, BlendMode.darken),
          ),
          border: isSelected ? Border.all(color: primaryColor, width: 2) : null,
        ),
        child: Stack(
          children: [
            Positioned(
              left: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('General Wellness', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('A bit of everything for a balanced life', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9))),
                ],
              ),
            ),
            if (isSelected) Positioned(top: 16, right: 16, child: Icon(Icons.check_circle, color: primaryColor, size: 24)),
          ],
        ),
      ),
    );
  }
}
