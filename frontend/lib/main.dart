import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/meals_screen.dart';
import 'package:frontend/screens/goals_screen.dart';
import 'package:frontend/screens/signup_screen.dart';
import 'package:frontend/screens/verify_email_screen.dart';
import 'package:frontend/screens/forgot_password_screen.dart';
import 'package:frontend/screens/reset_password_screen.dart';
import 'package:frontend/core/theme_provider.dart';

/// Point d'entrée de l'application
void main() async {
  // Initialise le binding Flutter pour les services asynchrones
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialise Firebase (authentification, etc.)
  await Firebase.initializeApp();
  
  // Initialise le gestionnaire de thème
  final themeProvider = ThemeProvider();
  // Charge la préférence de thème sauvegardée
  await themeProvider.init();
  
  // Lance l'application avec le thème provider
  runApp(SanteSynchroApp(themeProvider: themeProvider));
}

/// Widget racine de l'application
/// Gère la configuration du thème et la navigation
class SanteSynchroApp extends StatefulWidget {
  /// Fournisseur du thème (contrôle le mode clair/sombre)
  final ThemeProvider themeProvider;
  
  const SanteSynchroApp({super.key, required this.themeProvider});

  @override
  State<SanteSynchroApp> createState() => _SanteSynchroAppState();
}

class _SanteSynchroAppState extends State<SanteSynchroApp> {
  late ThemeProvider _themeProvider;

  @override
  void initState() {
    super.initState();
    _themeProvider = widget.themeProvider;
    _themeProvider.addListener(_onThemeChange);
  }

  @override
  void dispose() {
    _themeProvider.removeListener(_onThemeChange);
    super.dispose();
  }

  /// Callback appelé quand le thème change
  /// Rafraîchit l'UI pour appliquer le nouveau thème
  void _onThemeChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SantéSynchro',
      debugShowCheckedModeBanner: false,
      theme: _themeProvider.lightTheme,
      darkTheme: _themeProvider.darkTheme,
      themeMode: _themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      initialRoute: '/login',
      routes: {
        '/login': (_) => LoginScreen(themeProvider: _themeProvider),
        '/signup': (_) => SignupScreen(themeProvider: _themeProvider),
        '/verify-email': (_) => VerifyEmailScreen(themeProvider: _themeProvider),
        '/meals': (_) => MealsScreen(themeProvider: _themeProvider),
        '/goals': (_) => GoalsScreen(themeProvider: _themeProvider),
        '/forgot-password': (_) => ForgotPasswordScreen(themeProvider: _themeProvider),
        '/reset-password': (_) => ResetPasswordScreen(themeProvider: _themeProvider),
      },
    );
  }
}