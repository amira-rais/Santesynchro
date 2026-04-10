import 'package:flutter/material.dart';
import 'package:frontend/core/theme_provider.dart';
import 'package:frontend/core/language_provider.dart';
import 'package:frontend/core/app_localizations.dart';
import 'package:frontend/services/api.dart';
import 'package:frontend/shared/password_validator.dart';

class ResetPasswordScreen extends StatefulWidget {
  final ThemeProvider themeProvider;

  const ResetPasswordScreen({super.key, required this.themeProvider});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();
  final _pwdFocus = FocusNode();

  bool _loading = false;
  bool _showPassword = false;
  bool _passwordValid = false;
  bool get _passwordsMatch => _pwdCtrl.text.isNotEmpty && _pwdCtrl.text == _confirmPwdCtrl.text;

  @override
  void initState() {
    super.initState();
    _pwdCtrl.addListener(() => setState(() {}));
    _confirmPwdCtrl.addListener(() => setState(() {}));
    _pwdFocus.addListener(() => setState(() {}));
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pwdCtrl.text != _confirmPwdCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Les mots de passe ne correspondent pas')),
      );
      return;
    }

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final email = args?['email'] as String?;

    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail manquant pour la réinitialisation')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await Api.finalizePasswordReset(email, _pwdCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot de passe mis à jour avec succès !')),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
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
        title: Text(loc.translate('reset_password_title')),
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
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      loc.translate('reset_password_title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _pwdCtrl,
                      focusNode: _pwdFocus,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        labelText: loc.translate('new_password_label'),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                      ),
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
                    TextFormField(
                      controller: _confirmPwdCtrl,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        labelText: loc.translate('confirm_password_label'),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: _confirmPwdCtrl.text.isEmpty
                            ? null
                            : Icon(
                                _passwordsMatch ? Icons.check_circle : Icons.error_outline,
                                color: _passwordsMatch ? Colors.green : Colors.red,
                              ),
                        helperText: _confirmPwdCtrl.text.isNotEmpty && !_passwordsMatch
                            ? 'Les mots de passe ne correspondent pas'
                            : null,
                        helperStyle: const TextStyle(color: Colors.red),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: (_passwordValid && _passwordsMatch) ? _resetPassword : null,
                      child: const Text('Mettre à jour'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _pwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    _pwdFocus.dispose();
    super.dispose();
  }
}
