import 'package:flutter/material.dart';
import 'package:frontend/services/api.dart';

class AddMealScreen extends StatefulWidget {
  const AddMealScreen({super.key});
  @override
  State<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  String _type = 'breakfast';
  String? _unit;
  bool saving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final body = {
        'name': _nameCtrl.text.trim(),
        'type': _type,
        'quantity': int.tryParse(_qtyCtrl.text.trim()) ?? 1,
        'unit': _unit,
        'nutrition': null,
      };
      await Api.addMeal(body);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ajout échoué: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter un repas')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: saving
            ? const Center(child: CircularProgressIndicator())
            : Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nom du repas'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _type,
                items: const [
                  DropdownMenuItem(value: 'breakfast', child: Text('Petit‑déjeuner')),
                  DropdownMenuItem(value: 'lunch', child: Text('Déjeuner')),
                  DropdownMenuItem(value: 'dinner', child: Text('Dîner')),
                  DropdownMenuItem(value: 'snack', child: Text('Snack')),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'breakfast'),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantité'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Quantité requise' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _unit,
                items: const [
                  DropdownMenuItem(value: null, child: Text('—')),
                  DropdownMenuItem(value: 'g', child: Text('g')),
                  DropdownMenuItem(value: 'ml', child: Text('ml')),
                  DropdownMenuItem(value: 'pieces', child: Text('pièces')),
                  DropdownMenuItem(value: 'serving', child: Text('portion')),
                ],
                onChanged: (v) => setState(() => _unit = v),
                decoration: const InputDecoration(labelText: 'Unité (optionnel)'),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}