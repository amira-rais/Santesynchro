import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:frontend/core/theme_provider.dart';
import 'package:frontend/core/language_provider.dart';
import 'package:frontend/core/app_localizations.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/signup_screen.dart';
import 'package:frontend/screens/home_screen.dart';
import 'package:frontend/screens/goals_screen.dart';
import 'package:frontend/screens/meals_screen.dart';
import 'package:frontend/screens/verify_email_screen.dart';
import 'package:frontend/screens/forgot_password_screen.dart';
import 'package:frontend/screens/reset_password_screen.dart';

/// Point d'entrée de l'application
void main() async {
  // Capture toutes les exceptions Flutter (y compris les RemoteException natifs Android)
  // pour éviter que l'application crashe à cause de Health Connect
  FlutterError.onError = (FlutterErrorDetails details) {
    // Log silencieux en prod, on ne propage pas le crash
    FlutterError.dumpErrorToConsole(details);
  };

  await runZonedGuarded(() async {
    // Initialise le binding Flutter pour les services asynchrones
    WidgetsFlutterBinding.ensureInitialized();

    // Initialise Firebase (authentification, etc.)
    await Firebase.initializeApp();

    // Initialise le gestionnaire de thème
    final themeProvider = ThemeProvider();
    await themeProvider.init();

    // Initialise le gestionnaire de langue
    final languageProvider = LanguageProvider();
    await languageProvider.init();

    // Lance l'application avec le thème et la langue providers
    runApp(SanteSynchroApp(themeProvider: themeProvider, languageProvider: languageProvider));
  }, (error, stack) {
    // Toutes les exceptions non catchées (y compris RemoteException Android) sont loggées ici
    // au lieu de crasher l'application
    debugPrint('[ZonedGuard] Caught unhandled error: $error');
  });
}

/// Widget racine de l'application
/// Gère la configuration du thème et la navigation
class SanteSynchroApp extends StatefulWidget {
  final ThemeProvider themeProvider;
  final LanguageProvider languageProvider;
  
  const SanteSynchroApp({super.key, required this.themeProvider, required this.languageProvider});

  @override
  State<SanteSynchroApp> createState() => _SanteSynchroAppState();
}

class _SanteSynchroAppState extends State<SanteSynchroApp> {
  late ThemeProvider _themeProvider;
  late LanguageProvider _languageProvider;

  @override
  void initState() {
    super.initState();
    _themeProvider = widget.themeProvider;
    _languageProvider = widget.languageProvider;
    _themeProvider.addListener(_refresh);
    _languageProvider.addListener(_refresh);
  }

  @override
  void dispose() {
    _themeProvider.removeListener(_refresh);
    _languageProvider.removeListener(_refresh);
    super.dispose();
  }

  /// Callback appelé quand le thème ou la langue change
  /// Rafraîchit l'UI
  void _refresh() {
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
      locale: _languageProvider.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', ''),
        Locale('en', ''),
      ],
      initialRoute: '/login',
      routes: {
        '/login': (_) => LoginScreen(themeProvider: _themeProvider),
        '/signup': (_) => SignupScreen(themeProvider: _themeProvider),
        '/verify-email': (_) => VerifyEmailScreen(themeProvider: _themeProvider),
        '/home': (_) => HomeScreen(themeProvider: _themeProvider),
        '/meals': (_) => MealsScreen(themeProvider: _themeProvider),
        '/goals': (_) => GoalsScreen(themeProvider: _themeProvider),
        '/forgot-password': (_) => ForgotPasswordScreen(themeProvider: _themeProvider),
        '/reset-password': (_) => ResetPasswordScreen(themeProvider: _themeProvider),
      },
    );
  }
}