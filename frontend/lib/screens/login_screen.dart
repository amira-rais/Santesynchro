import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:frontend/core/theme_provider.dart';
import 'package:frontend/core/language_provider.dart';
import 'package:frontend/core/app_localizations.dart';
import 'package:frontend/services/api.dart';

/// Écran de connexion
/// Permet aux utilisateurs de se connecter avec email/mot de passe ou Google
class LoginScreen extends StatefulWidget {
  /// Fournisseur pour gérer le thème (mode clair/sombre)
  final ThemeProvider themeProvider;
  
  const LoginScreen({super.key, required this.themeProvider});
  
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// Contrôleurs pour capturer les entrées utilisateur
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  /// Indique si une opération de connexion est en cours (affiche le spinner)
  bool _loading = false;
  /// Contrôle la visibilité du mot de passe (œil toggle)
  bool _showPassword = false;

  /// Connexion avec email et mot de passe
  /// Valide le formulaire et authentifie avec Firebase
  Future<void> _loginEmail() async {
    // Vérifie que le formulaire est valide
    if (!_formKey.currentState!.validate()) return;
    // Affiche le spinner de chargement
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _pwdCtrl.text.trim(),
      );
      // Crée ou récupère le profil utilisateur dans Firestore
      final userData = await Api.me();
      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
        if (userData['hasGoals'] == true) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          Navigator.pushReplacementNamed(context, '/goals');
        }
      } else {
        Navigator.pushReplacementNamed(context, '/verify-email');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? loc.translate('login_failed'))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Connexion avec Google Sign-In
  /// Ouvre le sélecteur de compte Google et authentifie l'utilisateur
  Future<void> _loginGoogle() async {
    setState(() => _loading = true);
    try {
      // Lance le processus de connexion Google
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _loading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final cred = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken, accessToken: googleAuth.accessToken);
      await FirebaseAuth.instance.signInWithCredential(cred);
      // Crée ou récupère le profil utilisateur dans Firestore
      final userData = await Api.me();
      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
        if (userData['hasGoals'] == true) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          Navigator.pushReplacementNamed(context, '/goals');
        }
      } else {
        Navigator.pushReplacementNamed(context, '/verify-email');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final langProvider = LanguageProvider();

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('login_title')),
        elevation: 0,
        actions: [
          IconButton(
            icon: Text(
              langProvider.currentLocaleCode == 'fr' ? '🇫🇷' : '🇬🇧',
              style: const TextStyle(fontSize: 22),
            ),
            onPressed: () => langProvider.toggleLanguage(),
            tooltip: 'Change Language',
          ),
          IconButton(
            icon: Icon(
              widget.themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () => widget.themeProvider.toggleDarkMode(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    // Logo / Titre
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.health_and_safety,
                              size: 48,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'SantéSynchro',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            loc.translate('login_subtitle'),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Email
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: InputDecoration(
                        labelText: loc.translate('email_label'),
                        hintText: loc.translate('email_hint'),
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? loc.translate('email_required')
                          : (!v.contains('@') ? loc.translate('email_invalid') : null),
                    ),
                    const SizedBox(height: 16),
                    // Mot de passe avec toggle
                    TextFormField(
                      controller: _pwdCtrl,
                      decoration: InputDecoration(
                        labelText: loc.translate('password_label'),
                        hintText: loc.translate('password_hint'),
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                      obscureText: !_showPassword,
                      validator: (v) => (v == null || v.trim().length < 7)
                          ? loc.translate('password_min')
                          : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                        child: Text(loc.translate('forgot_password')),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Bouton connexion
                    ElevatedButton.icon(
                      onPressed: _loginEmail,
                      icon: const Icon(Icons.login),
                      label: Text(loc.translate('login_button')),
                    ),
                    const SizedBox(height: 12),
                    // Bouton Google
                    OutlinedButton.icon(
                      onPressed: _loginGoogle,
                      icon: const Icon(FontAwesomeIcons.google),
                      label: Text(loc.translate('google_login')),
                    ),
                    const SizedBox(height: 24),
                    // Lien inscription
                    Column(
                      children: [
                        Text(loc.translate('no_account')),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/signup'),
                          child: Text(
                            loc.translate('signup_link'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }
}