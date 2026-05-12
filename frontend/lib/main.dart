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
import 'package:frontend/screens/insights_screen.dart';
import 'package:frontend/screens/verify_email_screen.dart';
import 'package:frontend/screens/forgot_password_screen.dart';
import 'package:frontend/screens/reset_password_screen.dart';
import 'package:frontend/screens/edit_profile_screen.dart';
import 'package:frontend/services/hive_service.dart';
import 'package:frontend/services/step_service.dart';
import 'package:frontend/services/sleep_service.dart';
import 'package:frontend/services/sync_service.dart';
import 'package:frontend/services/analytics_service.dart';

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

    // Initialise le stockage local Hive (doit être avant les services)
    await HiveService.init();

    // Initialise le gestionnaire de thème
    final themeProvider = ThemeProvider();
    await themeProvider.init();

    // Initialise le gestionnaire de langue
    final languageProvider = LanguageProvider();
    await languageProvider.init();

    // Démarrer le compteur de pas en temps réel
    await StepService().init();

    // Démarrer la détection de sommeil semi-automatique
    SleepService().start();

    // Démarrer la synchronisation offline→backend
    SyncService().start();

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

class _SanteSynchroAppState extends State<SanteSynchroApp> with WidgetsBindingObserver {
  late ThemeProvider _themeProvider;
  late LanguageProvider _languageProvider;

  @override
  void initState() {
    super.initState();
    _themeProvider = widget.themeProvider;
    _languageProvider = widget.languageProvider;
    _themeProvider.addListener(_refresh);
    _languageProvider.addListener(_refresh);
    // Démarre le tracking de session dès l'ouverture
    WidgetsBinding.instance.addObserver(this);
    AnalyticsService.onAppResumed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _themeProvider.removeListener(_refresh);
    _languageProvider.removeListener(_refresh);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AnalyticsService.onAppResumed();
    } else if (state == AppLifecycleState.paused) {
      AnalyticsService.onAppPaused();
    }
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
        '/insights': (_) => InsightsScreen(themeProvider: _themeProvider),
        '/goals': (_) => GoalsScreen(themeProvider: _themeProvider),
        '/forgot-password': (_) => ForgotPasswordScreen(themeProvider: _themeProvider),
        '/reset-password': (_) => ResetPasswordScreen(themeProvider: _themeProvider),
        '/edit-profile': (_) => EditProfileScreen(themeProvider: _themeProvider),
      },
    );
  }
}