import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/core/theme_provider.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/profile_summary_screen.dart';
import 'package:frontend/screens/add_meal_screen.dart';
import 'package:frontend/core/language_provider.dart';
import 'package:frontend/core/app_localizations.dart';
import 'package:frontend/services/health_service.dart';

/// Écran des réglages de l'application.
/// Permet à l'utilisateur de se déconnecter, de supprimer son compte et de changer la langue.
class SettingsScreen extends StatefulWidget {
  /// Fournisseur de thème pour gérer le mode clair/sombre.
  final ThemeProvider themeProvider;

  /// Constructeur de l'écran des réglages.
  const SettingsScreen({super.key, required this.themeProvider});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _quickAddExpanded = false;
  int? _hoveredQuickAction;
  bool _healthConnectEnabled = false;
  bool _healthConnectBusy = false;
  final GlobalKey _plusMenuKey = GlobalKey();

  Future<void> _toggleHealthConnect(bool value) async {
    if (_healthConnectBusy) return;
    setState(() => _healthConnectBusy = true);
    try {
      final health = HealthService();
      final available = await health.isAvailable();
      if (!available) {
        if (!mounted) return;
        setState(() => _healthConnectEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Health Connect non disponible sur cet appareil.')),
        );
        return;
      }

      if (value) {
        final ok = await health.authorize();
        if (!mounted) return;
        setState(() => _healthConnectEnabled = ok);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? 'Health Connect connecte.' : 'Acces Health Connect refuse.')),
        );
      } else {
        if (!mounted) return;
        setState(() => _healthConnectEnabled = false);
      }
    } finally {
      if (mounted) setState(() => _healthConnectBusy = false);
    }
  }

  /// Gère la déconnexion de l'utilisateur.
  /// Déconnecte l'utilisateur de Firebase et le redirige vers l'écran de connexion.
  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen(themeProvider: widget.themeProvider)),
      (_) => false,
    );
  }

  /// Gère la suppression du compte utilisateur.
  /// Affiche une boîte de dialogue de confirmation avant de supprimer le compte Firebase
  /// et de rediriger l'utilisateur vers l'écran de connexion.
  Future<void> _deleteAccount(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.translate('delete_account')),
        content: Text(loc.translate('delete_confirm_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(loc.translate('delete'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Si l'utilisateur confirme la suppression
      try {
        await FirebaseAuth.instance.currentUser?.delete();
        if (!context.mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen(themeProvider: widget.themeProvider)),
          (_) => false,
        );
        // Affiche une SnackBar en cas d'erreur (ex: l'utilisateur doit se reconnecter)
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e. Vous devrez peut-être vous reconnecter pour supprimer votre compte.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Récupère les localisations pour les textes traduits.
    final loc = AppLocalizations.of(context);
    // Récupère le fournisseur de langue pour changer la langue.
    final langProvider = LanguageProvider();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        // Titre de l'AppBar, traduit via AppLocalizations.
        title: Text(loc.translate('settings_title')),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          /// Option pour changer la langue de l'application.
          ListTile(
            leading: const Icon(Icons.language, color: Colors.blue),
            // Texte du titre, traduit.
            title: Text(loc.translate('language')),
            // Affiche la langue actuelle avec un drapeau.
            trailing: Text(
              langProvider.currentLocaleCode == 'fr' ? '🇫🇷 Français' : '🇬🇧 English',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () => langProvider.toggleLanguage(),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.health_and_safety, color: Color(0xFF2F80ED)),
            title: const Text('Health Connect'),
            subtitle: Text(
              _healthConnectBusy
                  ? 'Demande d\'acces en cours...'
                  : 'Synchronisation Android Health Connect',
              maxLines: 2,
              softWrap: true,
              style: const TextStyle(fontSize: 12),
            ),
            isThreeLine: true,
            trailing: Switch(
              value: _healthConnectEnabled,
              onChanged: _healthConnectBusy ? null : _toggleHealthConnect,
            ),
            onTap: _healthConnectBusy
                ? null
                : () => _toggleHealthConnect(!_healthConnectEnabled),
          ),
          const Divider(),
          /// Option pour déconnecter l'utilisateur.
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.orange),
            // Texte du titre, traduit.
            title: Text(loc.translate('logout')),
            onTap: () => _logout(context),
          ),
          const Divider(),
          /// Option pour supprimer le compte utilisateur.
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            // Texte du titre, traduit et stylisé en rouge pour attirer l'attention.
            title: Text(loc.translate('delete_account'), 
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () => _deleteAccount(context),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
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
                setState(() => _quickAddExpanded = false);
                Navigator.pushReplacementNamed(context, '/home');
              }),
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
              _buildNavItem(Icons.settings, 'SETTINGS', true, primaryColor, isDark, () {}),
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

  Widget _buildNavItem(
    IconData icon,
    String label,
    bool isActive,
    Color primaryColor,
    bool isDark,
    VoidCallback onTap,
  ) {
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