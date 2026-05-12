import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/core/theme_provider.dart';
import 'package:frontend/core/app_localizations.dart';
import 'package:frontend/services/api.dart';
import 'package:intl/intl.dart';

class EditProfileScreen extends StatefulWidget {
  final ThemeProvider themeProvider;

  const EditProfileScreen({super.key, required this.themeProvider});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  String? _gender;
  DateTime? _birthDate;
  double _height = 175.0;
  double _weight = 75.0;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: FirebaseAuth.instance.currentUser?.displayName ?? '');
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final me = await Api.me();
      setState(() {
        _gender = me['gender'];
        if (me['birthDate'] != null) {
          _birthDate = DateTime.tryParse(me['birthDate']);
        }
        _height = double.tryParse(me['height']?.toString() ?? '175') ?? 175.0;
        _weight = double.tryParse(me['weight']?.toString() ?? '75') ?? 75.0;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      setState(() => _loading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: widget.themeProvider.isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _birthDate) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final loc = AppLocalizations.of(context);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _nameCtrl.text.trim() != user.displayName) {
        await user.updateDisplayName(_nameCtrl.text.trim());
      }

      await Api.updateProfile({
        'name': _nameCtrl.text.trim(),
        'gender': _gender,
        'birthDate': _birthDate != null ? DateFormat('yyyy-MM-dd').format(_birthDate!) : null,
        'height': _height,
        'weight': _weight,
      });

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.translate('profile_updated'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${loc.translate('save_error')} : $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = widget.themeProvider.isDarkMode;
    final primaryColor = theme.primaryColor;

    if (_loading) {
      return Scaffold(body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('edit_profile'), style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: Text(loc.translate('save'), style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loc.translate('personal_info'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: loc.translate('full_name'),
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v == null || v.isEmpty ? loc.translate('name_required') : null,
              ),
              const SizedBox(height: 24),
              
              Text(loc.translate('gender'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildGenderOption('male', Icons.male, Colors.blue),
                  const SizedBox(width: 12),
                  _buildGenderOption('female', Icons.female, Colors.pink),
                ],
              ),
              const SizedBox(height: 24),

              Text(loc.translate('birth_date'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _selectDate(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 20, color: Colors.grey),
                      const SizedBox(width: 12),
                      Text(
                        _birthDate == null ? loc.translate('select') : DateFormat('dd/MM/yyyy').format(_birthDate!),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Text(loc.translate('physical_measures'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
              const SizedBox(height: 16),
              _buildMetricSlider(loc.translate('height_label_full'), _height, 140, 220, 'cm', (v) => setState(() => _height = v), primaryColor, isDark),
              _buildMetricSlider(loc.translate('weight_label_full'), _weight, 40, 150, 'kg', (v) => setState(() => _weight = v), primaryColor, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderOption(String value, IconData icon, Color color) {
    final loc = AppLocalizations.of(context);
    bool selected = _gender == value;
    final primaryColor = Theme.of(context).primaryColor;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gender = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? primaryColor.withOpacity(0.1) : Colors.transparent,
            border: Border.all(color: selected ? primaryColor : Colors.grey[400]!, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? primaryColor : Colors.grey),
              const SizedBox(width: 8),
              Text(
                value == 'male' ? loc.translate('male') : loc.translate('female'),
                style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricSlider(String label, double value, double min, double max, String unit, Function(double) onChanged, Color primaryColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            Text('${value.toStringAsFixed(1)} $unit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: primaryColor,
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }
}
