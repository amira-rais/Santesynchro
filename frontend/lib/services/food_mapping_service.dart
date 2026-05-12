class FoodMappingService {
  /// Liste de labels à ignorer car trop génériques ou non alimentaires
  static const List<String> _ignoredLabels = [
    'Food',
    'Dish',
    'Cuisine',
    'Ingredient',
    'Produce',
    'Recipe',
    'Tableware',
    'Plate',
    'Fruit',
    'Vegetable',
    'Table',
    'Wood',
    'Indoor',
    'Natural foods',
    'Local food',
    'Superfood',
    'Whole food',
    'Vegan nutrition',
    'Vegetarian food',
    'Plant',
    'Green',
    'Yellow',
    'Red',
  ];

  /// Dictionnaire de normalisation pour améliorer la recherche Open Food Facts
  static const Map<String, String> _normalizationMap = {
    'Apple': 'Pomme',
    'Granny smith': 'Pomme',
    'Mcintosh': 'Pomme',
    'Honeycrisp': 'Pomme',
    'Hamburger': 'Burger',
    'Cheeseburger': 'Burger',
    'French fries': 'Frites',
    'Potato wedges': 'Frites',
    'Spaghetti': 'Pâtes',
    'Pizza': 'Pizza',
    'Bread': 'Pain',
    'Cheese': 'Fromage',
    'Orange juice': 'Jus d\'orange',
    'Coffee': 'Café',
    'Sandwich': 'Sandwich',
    'Submarine sandwich': 'Sandwich',
    'Salad': 'Salade',
    'Caesar salad': 'Salade César',
    'Chocolate': 'Chocolat',
    'Cake': 'Gâteau',
    'Pastry': 'Viennoiserie',
    'Croissant': 'Croissant',
    'Cookie': 'Biscuit',
    'Ice cream': 'Glace',
    'Sushi': 'Sushi',
    'Noodle': 'Nouilles',
    'Rice': 'Riz',
    'Milk': 'Lait',
    'Egg': 'Oeuf',
    'Beef': 'Boeuf',
    'Chicken': 'Poulet',
    'Pork': 'Porc',
    'Fish': 'Poisson',
    'Tomato': 'Tomate',
    'Cucumber': 'Concombre',
    'Carrot': 'Carotte',
    'Broccoli': 'Brocoli',
    'Banana': 'Banane',
    'Strawberry': 'Fraise',
    'Grape': 'Raisin',
    'Watermelon': 'Pastèque',
  };

  /// Filtre et normalise les labels retournés par ML Kit
  static List<String> processLabels(List<String> rawLabels) {
    List<String> processed = [];

    for (String label in rawLabels) {
      // 1. Normaliser d'abord (pour transformer 'Granny smith' en 'Pomme' avant le filtre)
      String normalized = _normalizationMap[label] ?? label;

      // 2. Ignorer les labels trop génériques SEULEMENT si on a déjà des labels précis
      if (_ignoredLabels.contains(label) && rawLabels.any((l) => !_ignoredLabels.contains(l))) {
        continue;
      }
      
      // On ignore toujours les labels purement techniques/environnementaux
      if (['Table', 'Wood', 'Indoor', 'Plant', 'Green', 'Red', 'Yellow'].contains(label)) {
        continue;
      }

      // 3. Ajouter si pas déjà présent
      if (!processed.contains(normalized)) {
        processed.add(normalized);
      }
    }

    // Si vraiment rien n'est trouvé, on remet les labels bruts non techniques
    if (processed.isEmpty) {
      processed = rawLabels.where((l) => !['Table', 'Wood', 'Indoor'].contains(l)).toList();
    }

    return processed.take(5).toList();
  }
}
