import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend/core/theme_provider.dart';
import 'package:frontend/services/api.dart';
import 'package:frontend/core/language_provider.dart';
import 'package:frontend/core/app_localizations.dart';
import 'package:frontend/screens/settings_screen.dart';
import 'package:frontend/screens/add_meal_screen.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

/// Écran de résumé du profil.
/// Affiche les statistiques de l'utilisateur, ses objectifs et ses préférences santé.
class ProfileSummaryScreen extends StatefulWidget {
  final ThemeProvider themeProvider;
  final Map<String, dynamic>? userData;

  /// Peut recevoir `userData` depuis l'écran Goals ou charger via l'API.
  const ProfileSummaryScreen({
    super.key, 
    required this.themeProvider,
    this.userData,
  });

  @override
  State<ProfileSummaryScreen> createState() => _ProfileSummaryScreenState();
}

class _ProfileSummaryScreenState extends State<ProfileSummaryScreen> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool _saving = false;
  bool _loading = false;
  bool _uploading = false;
  bool _quickAddExpanded = false;
  int? _hoveredQuickAction;
  final GlobalKey _plusMenuKey = GlobalKey();
  String? _photoUrl;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    // Si on vient de l'onboarding, on utilise les données passées
    if (widget.userData != null) {
      _data = Map<String, dynamic>.from(widget.userData!);
    } else {
      _fetchProfile();
    }
  }

  /// Récupère le profil actuel de l'utilisateur depuis le backend
  Future<void> _fetchProfile() async {
    setState(() => _loading = true);
    try {
      final me = await Api.me();
      setState(() {
        _photoUrl = me['photoUrl'];
        _data = {
          'goals': (me['goals'] as List? ?? []).map((g) => g['type'].toString()).toSet(),
          'height': double.tryParse(me['height']?.toString() ?? '175') ?? 175.0,
          'currentWeight': double.tryParse(me['weight']?.toString() ?? '75') ?? 75.0,
          'targetWeight': double.tryParse(me['targetWeight']?.toString() ?? '70') ?? 70.0,
          'pace': me['pace']?.toString() ?? 'Steady',
          'diets': (me['diets'] as List? ?? []).map((d) => d.toString()).toSet(),
          'conditions': (me['conditions'] as List? ?? []).map((c) => c.toString()).toSet(),
          'allergies': (me['allergies'] as List? ?? []).map((a) => a.toString()).toSet(),
        };
      });
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Sauvegarde les données collectées vers le serveur et redirige vers l'accueil
  Future<void> _saveAndContinue() async {
    setState(() => _saving = true);
    try {
      // 1. Prépare et envoie les métriques physiques
      final metrics = {
        'height': _data?['height'],
        'weight': _data?['currentWeight'],
        'targetWeight': _data?['targetWeight'],
        'pace': _data?['pace'],
        'diets': (_data?['diets'] as Set<String>?)?.toList() ?? [],
        'conditions': (_data?['conditions'] as Set<String>?)?.toList() ?? [],
        'allergies': (_data?['allergies'] as Set<String>?)?.toList() ?? [],
      };
      await Api.updateProfile(metrics);

      // 2. Synchronise les objectifs (Goals)
      final goals = _data?['goals'] as Set<String>? ?? {};
      for (var goalType in goals) {
        await Api.addGoal({
          'type': goalType,
          'target': _data?['targetWeight'],
          'unit': 'kg',
        });
      }

      if (!mounted) return;
      // Indique que l'onboarding est terminé en allant vers la page principale
      Navigator.pushNamedAndRemoveUntil(context, '/meals', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'enregistrement : $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Gère la sélection d'une image depuis l'appareil
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          _uploading = true;
        });
        
        try {
          // Configuration Cloudinary avec vos identifiants réels
          final cloudinary = CloudinaryPublic('dmyuin2sv', 'santesynchro_upload', cache: false);
          
          CloudinaryResponse response = await cloudinary.uploadFile(
            CloudinaryFile.fromFile(pickedFile.path, resourceType: CloudinaryResourceType.Image),
          );

          final newUrl = response.secureUrl;
          
          // Mise à jour sur notre backend
          await Api.updateProfile({'photoUrl': newUrl});

          if (mounted) {
            setState(() {
              _photoUrl = newUrl;
            });
          }
        } catch (e) {
          debugPrint("Error uploading to Cloudinary: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur upload : $e')),
            );
          }
        } finally {
          if (mounted) setState(() => _uploading = false);
        }
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  /// Affiche le menu de choix pour la photo de profil (Galerie/Caméra)
  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final isDark = widget.themeProvider.isDarkMode;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Wrap(
              children: <Widget>[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Text('Choisir une photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.blue),
                  title: const Text('Galerie'),
                  onTap: () {
                    _pickImage(ImageSource.gallery);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera, color: Colors.green),
                  title: const Text('Appareil photo'),
                  onTap: () {
                    _pickImage(ImageSource.camera);
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = widget.themeProvider.isDarkMode;
    final primaryColor = theme.primaryColor;
    
    // État de chargement initial
    if (_loading || _data == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    // Extraction des données pour affichage
    final goals = _data!['goals'] as Set<String>;
    final currentWeight = _data!['currentWeight'] as double;
    final targetWeight = _data!['targetWeight'] as double;
    final pace = _data!['pace'] as String;
    final diets = _data!['diets'] as Set<String>;
    final conditions = _data!['conditions'] as Set<String>;
    final allergies = _data!['allergies'] as Set<String>;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(loc.translate('profile_summary_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(
              widget.themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () => widget.themeProvider.toggleDarkMode(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Section en-tête avec Avatar éditable
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 70,
                    backgroundColor: primaryColor.withOpacity(0.1),
                    backgroundImage: _image != null 
                      ? FileImage(_image!) 
                      : (_photoUrl != null ? NetworkImage(_photoUrl!) : null) as ImageProvider?,
                    child: _uploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : (_image == null && _photoUrl == null)
                        ? Text(
                            (FirebaseAuth.instance.currentUser?.displayName?.isNotEmpty ?? false)
                                ? FirebaseAuth.instance.currentUser!.displayName![0].toUpperCase()
                                : '?',
                            style: TextStyle(color: primaryColor, fontSize: 40, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _showImageSourceActionSheet(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.edit, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              FirebaseAuth.instance.currentUser?.displayName ?? 'Nouvel Utilisateur',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              loc.translate('premium_member'),
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 32),
            
            // Section Mon Plan
            _buildSectionHeader(loc.translate('my_plan'), onEdit: () {}, isDark: isDark),
            const SizedBox(height: 16),
            _buildPlanCard(primaryColor, isDark, goals, pace, currentWeight, targetWeight),
            
            const SizedBox(height: 32),
            // Section Objectifs Quotidiens
            _buildSectionHeader(loc.translate('daily_targets'), isDark: isDark),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTargetCard(loc.translate('energy'), '2,100', 'kcal / day', Icons.local_fire_department, Colors.orange, isDark)),
                const SizedBox(width: 16),
                Expanded(child: _buildTargetCard(loc.translate('hydration'), '2.5', 'Liters / day', Icons.opacity, Colors.blue, isDark)),
              ],
            ),
            
            const SizedBox(height: 32),
            // Section Macronutriments (Graphiques horizontaux)
            _buildMacronutrientsCard(primaryColor, isDark),
            
            const SizedBox(height: 32),
            // Section Santé et Régime (Tags/Chips)
            _buildSectionHeader(loc.translate('health_diet'), isDark: isDark),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...diets.map((d) => _buildDietChip(d, isDark, primaryColor)),
                ...conditions.map((c) => _buildDietChip(c, isDark, primaryColor, isCondition: true)),
                ...allergies.map((a) => _buildDietChip(a, isDark, primaryColor, isAllergy: true)),
              ].isEmpty 
                ? [Text(loc.translate('none') ?? 'Aucune préférence', style: TextStyle(color: Colors.grey[500]))]
                : [
                    ...diets.map((d) => _buildDietChip(d, isDark, primaryColor)),
                    ...conditions.map((c) => _buildDietChip(c, isDark, primaryColor, isCondition: true)),
                    ...allergies.map((a) => _buildDietChip(a, isDark, primaryColor, isAllergy: true)),
                  ],
            ),
            
            const SizedBox(height: 40),
            const SizedBox(height: 24),
          ],
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: Container(
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
                  setState(() => _quickAddExpanded = false);
                  Navigator.pushReplacementNamed(context, '/home');
                }),
                _buildNavItem(Icons.insights_outlined, 'INSIGHTS', false, primaryColor, isDark, () {
                  setState(() => _quickAddExpanded = false);
                  Navigator.pushReplacementNamed(context, '/meals');
                }),
                _buildPlusNavItem(primaryColor),
                _buildNavItem(Icons.person, 'PROFILE', true, primaryColor, isDark, () {}),
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
                );
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
    );
  }

  /// Widget utilitaire pour les icônes de navigation basse
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

  /// Widget pour l'en-tête d'une section du profil
  Widget _buildSectionHeader(String title, {VoidCallback? onEdit, bool isDark = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        if (onEdit != null)
          TextButton(
            onPressed: onEdit,
            child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  /// Construit la carte d'affichage de la progression vers l'objectif de poids
  Widget _buildPlanCard(Color primaryColor, bool isDark, Set<String> goals, String pace, double current, double target) {
    String title = goals.contains('weight_loss') ? 'Weight Loss' : 'Healthy Lifestyle';
    IconData icon = goals.contains('weight_loss') ? Icons.trending_down : Icons.favorite_border;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: primaryColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      '$pace Pace • ${pace == "Fast" ? "1.0kg" : (pace == "Steady" ? "0.5kg" : "0.25kg")} per week',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('PROGRESS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              Text('0%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.0,
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Target weight: ${target.toInt()}kg (Current: ${current.toInt()}kg)',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Widget pour une carte d'objectif cible (Calories ou Hydratation)
  Widget _buildTargetCard(String label, String value, String unit, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(unit, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      ),
    );
  }

  /// Construit la carte regroupant les répartitions de macronutriments
  Widget _buildMacronutrientsCard(Color primaryColor, bool isDark) {
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.donut_large, color: primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(loc.translate('macronutrients').toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 20),
          _buildMacroRow(loc.translate('carbs').toUpperCase(), '40%', Colors.blue, 0.4, isDark),
          const SizedBox(height: 12),
          _buildMacroRow(loc.translate('protein').toUpperCase(), '30%', Colors.green, 0.3, isDark),
          const SizedBox(height: 12),
          _buildMacroRow(loc.translate('fats').toUpperCase(), '30%', Colors.orange, 0.3, isDark),
        ],
      ),
    );
  }

  /// Une ligne de macronutriment avec libellé, pourcentage et jauge
  Widget _buildMacroRow(String label, String value, Color color, double progress, bool isDark) {
    return Row(
      children: [
        SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ),
      ],
    );
  }

  /// Petit badge (chip) pour afficher les régimes ou pathologies
  Widget _buildDietChip(String label, bool isDark, Color primaryColor, {bool isCondition = false, bool isAllergy = false}) {
    Color chipColor = primaryColor;
    if (isCondition) chipColor = Colors.redAccent;
    if (isAllergy) chipColor = Colors.orangeAccent;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: chipColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
