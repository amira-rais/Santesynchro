import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/services/api.dart';
import 'package:frontend/screens/add_meal_screen.dart';
import 'package:frontend/screens/login_screen.dart';

class MealsScreen extends StatefulWidget {
  const MealsScreen({super.key});
  @override
  State<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends State<MealsScreen> {
  bool loading = true;
  List<dynamic> meals = [];

  @override
  void initState() {
    super.initState();
    _loadMeals();
  }

  Future<void> _loadMeals() async {
    try {
      final data = await Api.getMeals();
      if (!mounted) return;
      setState(() { meals = data; loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur chargement: $e')),
      );
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
    );
  }

  Future<void> _delete(String id) async {
    try {
      await Api.deleteMeal(id);
      _loadMeals();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Suppression: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal des repas'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMeals),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddMealScreen()),
          );
          if (added == true) _loadMeals();
        },
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : meals.isEmpty
          ? const Center(child: Text('Aucun repas. Ajoute ton premier repas ✨'))
          : ListView.separated(
        itemCount: meals.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final m = meals[i] as Map<String, dynamic>;
          final createdAt = (m['createdAt'] ?? '')
              .toString().replaceAll('T', ' ').replaceAll('Z', '');
          return ListTile(
            title: Text(m['name']?.toString() ?? '—'),
            subtitle: Text('${m['type']} • ${m['quantity']}${m['unit'] != null ? ' ${m['unit']}' : ''}'),
            trailing: Text(createdAt, style: const TextStyle(fontSize: 12)),
            onLongPress: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Supprimer'),
                  content: Text('Supprimer "${m['name']}" ?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                    ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
                  ],
                ),
              );
              if (ok == true) _delete(m['id'].toString());
            },
          );
        },
      ),
    );
  }
}