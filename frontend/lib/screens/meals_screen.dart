import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/services/api.dart';
import 'package:frontend/screens/add_meal_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/edit_meal_screen.dart';
import 'package:frontend/core/theme_provider.dart';

/// Écran principal du journal des repas
/// Affiche la liste de tous les repas enregistrés
class MealsScreen extends StatefulWidget {
  /// Fournisseur pour gérer le thème
  final ThemeProvider themeProvider;
  
  const MealsScreen({super.key, required this.themeProvider});
  
  @override
  State<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends State<MealsScreen> {
  /// Indique si les données sont en cours de chargement
  bool loading = true;
  /// Liste de tous les repas enregistrés
  List<dynamic> meals = [];

  /// Mappe each meal type à son icône
  /// Utilisé pour afficher l'icône appropriée pour chaque type de repas
  final _mealIcons = {
    'breakfast': Icons.coffee,
    'lunch': Icons.restaurant,
    'dinner': Icons.dinner_dining,
    'snack': Icons.cake,
  };

  /// Mappe each meal type à ses labels en français
  /// Affichés dans les badges de couleur
  final _mealLabels = {
    'breakfast': 'Petit-déjeuner',
    'lunch': 'Déjeuner',
    'dinner': 'Dîner',
    'snack': 'Snack',
  };

  /// Mappe each meal type à sa couleur affichée
  /// Utilisé pour les icônes et les badges
  final _mealColors = {
    'breakfast': Color(0xFFFFB84D),
    'lunch': Color(0xFF4CAF50),
    'dinner': Color(0xFF9C27B0),
    'snack': Color(0xFFFF6B6B),
  };

  @override
  void initState() {
    super.initState();
    // Charge les repas au démarrage de l'écran
    _loadMeals();
  }

  /// Charge la liste des repas depuis l'API backend
  /// Met à jour l'état et gère les erreurs de chargement
  Future<void> _loadMeals() async {
    try {
      // Récupère les repas depuis l'API
      final data = await Api.getMeals();
      if (!mounted) return;
      // Met à jour l'UI avec les données
      setState(() { meals = data; loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur chargement: $e')),
      );
    }
  }

  /// Déconnecte l'utilisateur et retourne à l'écran de connexion
  Future<void> _logout() async {
    // Déconnecte l'utilisateur de Firebase
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    // Navigue vers la page de connexion
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen(themeProvider: widget.themeProvider)),
          (_) => false,
    );
  }

  /// Supprime un repas de la base de données
  /// Prend en paramètre l'ID du repas à supprimer
  Future<void> _delete(String id) async {
    try {
      // Appelle l'API pour supprimer le repas
      await Api.deleteMeal(id);
      // Recharge la liste
      _loadMeals();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Suppression: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal des repas'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMeals,
          ),
          IconButton(
            icon: Icon(
              widget.themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () => widget.themeProvider.toggleDarkMode(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddMealScreen(themeProvider: widget.themeProvider)),
          );
          if (added == true) _loadMeals();
        },
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : meals.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucun repas enregistré',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap le bouton + pour ajouter ton premier repas',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: meals.length,
              itemBuilder: (context, i) {
                final m = meals[i] as Map<String, dynamic>;
                final type = m['type']?.toString() ?? 'snack';
                final color = _mealColors[type] ?? Colors.grey;
                final icon = _mealIcons[type] ?? Icons.restaurant;
                final label = _mealLabels[type] ?? type;
                final createdAt = (m['createdAt'] ?? '')
                    .toString()
                    .replaceAll('T', ' ')
                    .replaceAll('Z', '')
                    .split('.')
                    .first;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Card(
                    elevation: 1,
                    child: InkWell(
                      onTap: () async {
                        final updated = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditMealScreen(meal: m),
                          ),
                        );
                        if (updated == true) {
                          await _loadMeals();
                        } else if (updated is Map<String, dynamic>) {
                          final id = updated['id']?.toString() ?? m['id'].toString();
                          final idx = meals.indexWhere((x) => (x as Map)['id'].toString() == id);
                          if (idx != -1) {
                            setState(() {
                              final prev = meals[idx] as Map<String, dynamic>;
                              meals[idx] = {...prev, ...updated};
                            });
                          }
                        }
                      },
                      onLongPress: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Supprimer'),
                            content: Text('Supprimer "${m['name']}" ?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Annuler'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Supprimer'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) _delete(m['id'].toString());
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                icon,
                                color: color,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m['name']?.toString() ?? '—',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${m['quantity']}${m['unit'] != null ? ' ${m['unit']}' : ''}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    createdAt,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey[400],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}