import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _pwd2Ctrl = TextEditingController();
  bool _loading = false;

  Future<void> _signupEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_pwdCtrl.text.trim() != _pwd2Ctrl.text.trim()) {
        throw Exception('Les mots de passe ne correspondent pas');
      }
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _pwdCtrl.text.trim(),
      );
      await cred.user?.updateDisplayName(_nameCtrl.text.trim());
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/meals');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Inscription échouée')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signupGoogle() async {
    setState(() => _loading = true);
    try {
      final g = await GoogleSignIn().signIn();
      if (g == null) { setState(() => _loading = false); return; }
      final ga = await g.authentication;
      final c = GoogleAuthProvider.credential(idToken: ga.idToken, accessToken: ga.accessToken);
      await FirebaseAuth.instance.signInWithCredential(c);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/meals');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Inscription"),
        leading: const BackButton(), // bouton retour
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nom'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Adresse e‑mail'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'E‑mail requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pwdCtrl,
                decoration: const InputDecoration(labelText: 'Mot de passe'),
                obscureText: true,
                validator: (v) => (v == null || v.trim().length < 6) ? '6 caractères min.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pwd2Ctrl,
                decoration: const InputDecoration(labelText: 'Confirmer le mot de passe'),
                obscureText: true,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Confirmez le mot de passe' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _signupEmail,
                icon: const Icon(Icons.person_add),
                label: const Text("S'inscrire"),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _signupGoogle,
                icon: const Icon(Icons.login),
                label: const Text('Continuer avec Google'),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Déjà un compte ? "),
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                    child: const Text('Connectez‑vous'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}