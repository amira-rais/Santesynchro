import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/core/theme_provider.dart';
import 'package:frontend/services/api.dart';

/// Écran de vérification d'email / Saisie OTP
class VerifyEmailScreen extends StatefulWidget {
  final ThemeProvider themeProvider;

  const VerifyEmailScreen({super.key, required this.themeProvider});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  int _secondsLeft = 60;
  bool _loading = false;
  Timer? _countdownTimer;
  Timer? _checkTimer;
  
  // Contrôleurs pour l'OTP (6 champs ou 1 champ avec style)
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final isPasswordReset = args?['isPasswordReset'] == true;

      if (!isPasswordReset) {
        // Flux Inscription standard : Vérification Firebase Native
        _sendVerificationEmail(silent: true);
        _startAutoCheck();
      }
    });
    _startCountdown();
  }

  /// Vérifie le code OTP pour la réinitialisation de mot de passe
  Future<void> _verifyOTP() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final email = args?['email'] as String?;
    
    String otp = _otpControllers.map((c) => c.text).join();
    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir le code complet à 6 chiffres.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      if (email != null) {
        await Api.verifyOTP(email, otp);
        if (mounted) {
          Navigator.pushReplacementNamed(
            context, 
            '/reset-password', 
            arguments: {'email': email, 'otp': otp}
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Vérifie si l'email Firebase est vérifié (pour l'inscription)
  Future<void> _checkFirebaseVerified({bool auto = false}) async {
    if (!auto) setState(() => _loading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      final verified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
      
      if (verified) {
        _checkTimer?.cancel();
        _countdownTimer?.cancel();
        if (mounted) Navigator.pushReplacementNamed(context, '/goals');
      } else if (!auto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email pas encore vérifié. Vérifiez votre boîte mail.')),
        );
      }
    } catch (e) {
      if (!auto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Renvoie l'email ou le code OTP
  Future<void> _resend() async {
    if (_secondsLeft > 0) return;
    
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final email = args?['email'] as String?;
    final isPasswordReset = args?['isPasswordReset'] == true;

    setState(() => _loading = true);
    try {
      if (isPasswordReset && email != null) {
        await Api.sendOTP(email);
      } else {
        await _sendVerificationEmail();
      }
      
      _startCountdown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isPasswordReset ? 'Nouveau code OTP envoyé !' : 'Lien de vérification renvoyé !')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _checkTimer?.cancel();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _sendVerificationEmail({bool silent = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified) {
      try {
        await user.sendEmailVerification();
      } catch (e) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Firebase : ${e.toString()}')),
          );
        }
      }
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _secondsLeft = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          t.cancel();
        }
      });
    });
  }

  void _startAutoCheck() {
    _checkTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _checkFirebaseVerified(auto: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final isPasswordReset = args?['isPasswordReset'] == true;
    final email = args?['email'] ?? 'votre e-mail';
    final canResend = _secondsLeft == 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(isPasswordReset ? 'Réinitialisation' : 'Vérification email'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              widget.themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () => widget.themeProvider.toggleDarkMode(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPasswordReset ? Icons.security : Icons.mark_email_unread_outlined,
                    size: 56,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isPasswordReset ? 'Saisissez le code' : 'Vérifiez votre email',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                isPasswordReset
                    ? 'Un code à 6 chiffres a été envoyé à\n$email'
                    : 'Un lien de vérification a été envoyé à\n$email',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.6),
              ),
              const SizedBox(height: 40),

              if (isPasswordReset)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 45,
                      height: 55,
                      child: TextField(
                        controller: _otpControllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        textAlignVertical: TextAlignVertical.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: TextStyle(
                          fontSize: 24, 
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                        decoration: InputDecoration(
                          counterText: "",
                          contentPadding: EdgeInsets.zero,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                          ),
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty && index < 5) {
                            _focusNodes[index + 1].requestFocus();
                          } else if (value.isEmpty && index > 0) {
                            _focusNodes[index - 1].requestFocus();
                          }
                          if (value.isNotEmpty && index == 5) {
                            _verifyOTP();
                          }
                        },
                      ),
                    );
                  }),
                ),

              const SizedBox(height: 40),

              if (_loading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: isPasswordReset ? _verifyOTP : () => _checkFirebaseVerified(),
                  child: Text(isPasswordReset ? "Vérifier le code" : "J'ai vérifié mon email"),
                ),

              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    if (_secondsLeft > 0)
                      Text(
                        'Renvoyer dans ${_secondsLeft}s',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    TextButton(
                      onPressed: canResend ? _resend : null,
                      child: Text(
                        isPasswordReset ? 'Renvoyer le code' : 'Renvoyer le lien',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: canResend ? Theme.of(context).primaryColor : Colors.grey[400],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                child: Text(
                  'Retour à la connexion',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
