import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/meals_screen.dart';
import 'package:frontend/screens/signup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const SanteSynchroApp());
}

class SanteSynchroApp extends StatelessWidget {
  const SanteSynchroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SantéSynchro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignupScreen(),
        '/meals': (_) => const MealsScreen(),
      },
    );
  }
}