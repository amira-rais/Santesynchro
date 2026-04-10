import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/core/theme_provider.dart';
import 'package:frontend/core/language_provider.dart';
import 'package:frontend/core/app_localizations.dart';
import 'package:frontend/services/api.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final ThemeProvider themeProvider;

  const ForgotPasswordScreen({super.key, required this.themeProvider});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;

  /// Envoyer l'email de réinitialisation via le BACKEND (OTP)
  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final email = _emailCtrl.text.trim();
      
      // Appel au backend pour envoyer l'OTP
      await Api.sendOTP(email);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Code de vérification envoyé à votre adresse email.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        // On redirige vers VerifyEmailScreen pour saisir l'OTP
        Navigator.pushReplacementNamed(
          context, 
          '/verify-email', 
          arguments: {
            'email': email, 
            'isPasswordReset': true,
          }
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')), 
            backgroundColor: Colors.red
          ),
        );
      }
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
        title: Text(loc.translate('forgot_password_title')),
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
          : Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    loc.translate('forgot_password_header'),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    loc.translate('forgot_password_desc'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 48),
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
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _sendResetLink,
                    child: Text(loc.translate('send_link')),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Retour à la connexion'),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }
}
