import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:frontend/core/theme_provider.dart';
import 'package:frontend/core/language_provider.dart';
import 'package:frontend/core/app_localizations.dart';
import 'package:frontend/services/api.dart';
import 'package:frontend/shared/password_validator.dart';

/// Écran d'inscription
/// Permet aux nouveaux utilisateurs de créer un compte
class SignupScreen extends StatefulWidget {
  /// Fournisseur pour gérer le thème
  final ThemeProvider themeProvider;
  
  const SignupScreen({super.key, required this.themeProvider});
  
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  /// Contrôleurs pour les champs du formulaire d'inscription
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _pwd2Ctrl = TextEditingController();
  final _pwdFocus = FocusNode();
  /// Indique si l'inscription est en cours
  bool _loading = false;
  /// Contrôle la visibilité du 1er mot de passe
  bool _showPassword = false;
  /// Contrôle la visibilité du 2e mot de passe
  bool _showPassword2 = false;
  /// Indique si le mot de passe est valide (3/4 conditions)
  bool _passwordValid = false;

  @override
  void initState() {
    super.initState();
    // Écoute les changements du mot de passe pour la validation en temps réel
    _pwdCtrl.addListener(() {
      setState(() {});
    });
    // Écoute le focus pour afficher/masquer la validation
    _pwdFocus.addListener(() {
      setState(() {});
    });
  }

  /// Inscription avec email et mot de passe
  /// Crée un compte Firebase et stocke le nom d'utilisateur
  Future<void> _signupEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final loc = AppLocalizations.of(context);
    try {
      // Vérifie que les deux mots de passe correspondent
      if (_pwdCtrl.text.trim() != _pwd2Ctrl.text.trim()) {
        throw Exception(loc.translate('passwords_dont_match'));
      }
      // Crée le compte utilisateur avec Firebase Auth
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _pwdCtrl.text.trim(),
      );
      // Met à jour le nom d'affichage
      await cred.user?.updateDisplayName(_nameCtrl.text.trim());
      // Crée le profil utilisateur dans Firestore
      await Api.me();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/verify-email');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? loc.translate('signup_failed'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signupGoogle() async {
    setState(() => _loading = true);
    try {
      final g = await GoogleSignIn().signIn();
      if (g == null) {
        setState(() => _loading = false);
        return;
      }
      final ga = await g.authentication;
      final c = GoogleAuthProvider.credential(idToken: ga.idToken, accessToken: ga.accessToken);
      await FirebaseAuth.instance.signInWithCredential(c);
      // Crée le profil utilisateur dans Firestore
      await Api.me();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/verify-email');
    } catch (e) {
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final loc = AppLocalizations.of(context);
    final langProvider = LanguageProvider();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(loc.translate('signup_title')),
          elevation: 0,
          actions: [
            IconButton(
              icon: Text(
                langProvider.currentLocaleCode == 'fr' ? '🇫🇷' : '🇬🇧',
                style: const TextStyle(fontSize: 22),
              ),
              onPressed: () => langProvider.toggleLanguage(),
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
                        const SizedBox(height: 30),
                        // Logo / Titre
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person_add,
                                  size: 48,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                loc.translate('signup_header'),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                loc.translate('signup_subtitle'),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Nom
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            labelText: loc.translate('name_label'),
                            hintText: loc.translate('name_hint'),
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? loc.translate('name_required') : null,
                        ),
                        const SizedBox(height: 16),
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
                        // Mot de passe
                        TextFormField(
                          controller: _pwdCtrl,
                          focusNode: _pwdFocus,
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
                        PasswordValidationWidget(
                          password: _pwdCtrl.text,
                          isVisible: _pwdFocus.hasFocus,
                          onValidationChanged: (isValid) {
                            if (_passwordValid != isValid) {
                              setState(() => _passwordValid = isValid);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        // Confirmer mot de passe
                        TextFormField(
                          controller: _pwd2Ctrl,
                          decoration: InputDecoration(
                            labelText: loc.translate('confirm_password_label'),
                            hintText: loc.translate('password_hint'),
                            prefixIcon: const Icon(Icons.lock_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPassword2 ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () => setState(() => _showPassword2 = !_showPassword2),
                            ),
                          ),
                          obscureText: !_showPassword2,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? loc.translate('confirm_password')
                              : null,
                        ),
                        const SizedBox(height: 24),
                        // Bouton inscription
                        ElevatedButton.icon(
                          onPressed: _signupEmail,
                          icon: const Icon(Icons.person_add),
                          label: Text(loc.translate('signup_button')),
                        ),
                        const SizedBox(height: 12),
                        // Bouton Google
                        OutlinedButton.icon(
                          onPressed: _signupGoogle,
                          icon: const Icon(FontAwesomeIcons.google),
                          label: Text(loc.translate('google_login')),
                        ),
                        const SizedBox(height: 24),
                        // Lien connexion
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(loc.translate('already_have_account')),
                            TextButton(
                              onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                loc.translate('login_link'),
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
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    _pwd2Ctrl.dispose();
    super.dispose();
  }
}