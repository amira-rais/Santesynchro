// lib/screens/edit_meal_screen.dart
import 'package:flutter/material.dart';
import 'package:frontend/services/api.dart';

/// Écran pour modifier un repas existant
/// Permet à l'utilisateur de changer les détails d'un repas
class EditMealScreen extends StatefulWidget {
  /// Le repas à modifier (reçu de MealsScreen)
  final Map<String, dynamic> meal;
  
  const EditMealScreen({super.key, required this.meal});

  @override
  State<EditMealScreen> createState() => _EditMealScreenState();
}

class _EditMealScreenState extends State<EditMealScreen> {
  /// Clé du formulaire pour la validation
  final _formKey = GlobalKey<FormState>();
  /// Contrôle le nom du repas
  late TextEditingController _nameCtrl;
  /// Contrôle la quantité
  late TextEditingController _qtyCtrl;
  /// Type de repas actuellement sélectionné
  late String _type;
  /// Unité de mesure
  String? _unit;
  /// Indique si la mise à jour est en cours
  bool _saving = false;

  /// Mappe each meal type à son icône
  final _mealIcons = {
    'breakfast': Icons.coffee,
    'lunch': Icons.restaurant,
    'dinner': Icons.dinner_dining,
    'snack': Icons.cake,
  };

  /// Mappe each meal type à son label en français
  final _mealLabels = {
    'breakfast': 'Petit-déjeuner',
    'lunch': 'Déjeuner',
    'dinner': 'Dîner',
    'snack': 'Snack',
  };

  @override
  void initState() {
    super.initState();
    // Initialise les contrôleurs avec les données du repas
    final m = widget.meal;
    _nameCtrl = TextEditingController(text: (m['name'] ?? '').toString());
    _qtyCtrl = TextEditingController(text: (m['quantity'] ?? 1).toString());
    _type = (m['type'] ?? 'breakfast').toString();
    _unit = m['unit'] == null ? null : m['unit'].toString();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  /// Enregistre les modifications du repas
  /// Valide le formulaire et met à jour l'API backend
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      // Prépare les données mises à jour
      final updates = {
        'name': _nameCtrl.text.trim(),
        'type': _type,
        'quantity': int.tryParse(_qtyCtrl.text.trim()) ?? 1,
        'unit': _unit,
      };

      await Api.updateMeal(widget.meal['id'].toString(), updates);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mise à jour échouée: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final created = (widget.meal['createdAt'] ?? '')
        .toString()
        .replaceAll('T', ' ')
        .replaceAll('Z', '')
        .split('.')
        .first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le repas'),
        elevation: 0,
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    // Info création
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Enregistré le',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            created,
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Nom
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nom du repas',
                        prefixIcon: const Icon(Icons.restaurant_menu),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                    ),
                    const SizedBox(height: 24),
                    // Type de repas
                    Text(
                      'Type de repas',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.2,
                      children: ['breakfast', 'lunch', 'dinner', 'snack'].map((type) {
                        final isSelected = _type == type;
                        return Material(
                          child: InkWell(
                            onTap: () => setState(() => _type = type),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF10B981)
                                      : Colors.grey[300]!,
                                  width: isSelected ? 2 : 1,
                                ),
                                color: isSelected
                                    ? const Color(0xFF10B981).withOpacity(0.1)
                                    : Colors.transparent,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _mealIcons[type],
                                    size: 32,
                                    color: isSelected
                                        ? const Color(0xFF10B981)
                                        : Colors.grey,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _mealLabels[type] ?? '',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? const Color(0xFF10B981)
                                          : Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    // Quantité et unité
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _qtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Quantité',
                              prefixIcon: const Icon(Icons.scale),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Requise'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            value: _unit,
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Unité')),
                              const DropdownMenuItem(value: 'g', child: Text('g')),
                              const DropdownMenuItem(value: 'ml', child: Text('ml')),
                              const DropdownMenuItem(value: 'pieces', child: Text('pcs')),
                              const DropdownMenuItem(value: 'serving', child: Text('port')),
                            ],
                            onChanged: (v) => setState(() => _unit = v),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.inventory_2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Bouton enregistrer
                    ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: const Text('Enregistrer les modifications'),
                    ),
                    const SizedBox(height: 12),
                    // Bouton annuler
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Annuler'),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}