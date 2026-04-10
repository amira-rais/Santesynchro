import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gestionnaire de langue pour l'application
/// Persiste la préférence de l'utilisateur (fr / en)
class LanguageProvider extends ChangeNotifier {
  static final LanguageProvider _instance = LanguageProvider._internal();

  factory LanguageProvider() {
    return _instance;
  }

  LanguageProvider._internal();

  /// Code langue actuel (par défaut 'fr')
  String _currentLocaleCode = 'fr';

  /// Getter pour le code langue actuel
  String get currentLocaleCode => _currentLocaleCode;

  /// Getter pour l'objet Locale utilisé par MaterialApp
  Locale get locale => Locale(_currentLocaleCode);

  /// Initialise la langue en lisant la préférence sauvegardée
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLocaleCode = prefs.getString('languageCode') ?? 'fr';
    notifyListeners();
  }

  /// Change la langue de l'application
  Future<void> setLocale(String code) async {
    if (_currentLocaleCode == code) return;
    
    _currentLocaleCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', code);
    notifyListeners();
  }

  /// Bascule entre fr et en
  Future<void> toggleLanguage() async {
    final nextCode = _currentLocaleCode == 'fr' ? 'en' : 'fr';
    await setLocale(nextCode);
  }
}
