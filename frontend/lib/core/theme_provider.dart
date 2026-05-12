import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gestionnaire de thème (mode clair/sombre) pour l'application
/// Utilise le pattern Singleton pour une seule instance dans l'app
class ThemeProvider extends ChangeNotifier {
  static final ThemeProvider _instance = ThemeProvider._internal();

  factory ThemeProvider() {
    return _instance;
  }

  ThemeProvider._internal();

  /// Stocke l'état du mode sombre (true = mode sombre, false = mode clair)
  bool _isDarkMode = false;

  /// Getter pour vérifier si le mode sombre est activé
  bool get isDarkMode => _isDarkMode;

  /// Initialise le thème en lectures la préférence sauvegardée
  /// Appelé au démarrage de l'app depuis main.dart
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    // Récupère la valeur sauvegardée, par défaut false (mode clair)
    _isDarkMode = prefs.getBool('darkMode') ?? false;
    // Notifie tous les écouteurs du changement
    notifyListeners();
  }

  /// Bascule entre le mode clair et le mode sombre
  /// Sauvegarde la préférence pour persistence entre les sessions
  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    // Persiste le choix de l'utilisateur
    await prefs.setBool('darkMode', _isDarkMode);
    // Notifie toute l'app du changement
    notifyListeners();
  }

  // ── Palette "SantéSynchro Dark" ──────────────────────────────────────────
  static const Color _darkBg = Color(0xFF04120E); // Deeper forest black
  static const Color _darkSurface = Color(0xFF0B1F17); // Darker surface
  static const Color _primaryGreen = Color(0xFF1DB954); // Vibrant Mint
  static const Color _secondaryMint = Color(0xFF6FF5B5);
  static const Color _textPrimary = Color(0xFFE8F5F0);
  static const Color _textSecondary = Color(0xFF9FBFB3);
  static const Color _borderColor = Color(0xFF2A4A3F);

  /// Définit le thème clair (mode jour)
  ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: const Color(0xFF166534),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF166534), width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: const Color(0xFF166534),
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: const BorderSide(color: Color(0xFF166534), width: 2),
          foregroundColor: const Color(0xFF166534),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      cardColor: Colors.white,
      dividerColor: const Color(0xFFE5E7EB),
      cardTheme: CardThemeData(
        elevation: 4,
        color: Colors.white,
        shadowColor: Colors.black.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE5E7EB),
        thickness: 1,
      ),
    );
  }

  /// Définit le thème sombre (mode nuit) : "SantéSynchro Dark"
  ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _darkBg,
      primaryColor: _primaryGreen,
      
      colorScheme: const ColorScheme.dark(
        primary: _primaryGreen,
        secondary: _secondaryMint,
        surface: _darkSurface,
        background: _darkBg,
        onPrimary: _darkBg,
        onSurface: _textPrimary,
        onBackground: _textPrimary,
      ),

      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: _textPrimary),
        bodyMedium: TextStyle(color: _textSecondary),
      ),

      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: _darkBg,
        foregroundColor: _textPrimary,
        centerTitle: false,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: _darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _borderColor, width: 1),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        labelStyle: const TextStyle(color: _textSecondary),
        hintStyle: const TextStyle(color: _textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _primaryGreen, width: 2),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: _primaryGreen,
          foregroundColor: const Color(0xFF0D1512),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: const BorderSide(color: _primaryGreen, width: 2),
          foregroundColor: _primaryGreen,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: _borderColor,
        thickness: 1,
      ),
    );
  }
}
