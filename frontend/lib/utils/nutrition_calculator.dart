class NutritionCalculator {
  /// Calcule l'âge à partir de la date de naissance
  static int calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  /// Calcule le métabolisme de base (BMR) selon la formule de Mifflin-St Jeor
  static double calculateBMR({
    required String gender,
    required double weight, // en kg
    required double height, // en cm
    required int age,
  }) {
    // Formule Homme : 10 x poids + 6.25 x taille - 5 x âge + 5
    // Formule Femme : 10 x poids + 6.25 x taille - 5 x âge - 161
    double baseBmr = (10 * weight) + (6.25 * height) - (5 * age);
    
    if (gender == 'male') {
      return baseBmr + 5;
    } else {
      return baseBmr - 161;
    }
  }

  /// Calcule la dépense énergétique journalière totale (TDEE)
  static double calculateTDEE({
    required double bmr,
    required String activityLevel,
  }) {
    double multiplier;
    switch (activityLevel) {
      case 'sedentary':
        multiplier = 1.2;
        break;
      case 'light':
        multiplier = 1.375;
        break;
      case 'moderate':
        multiplier = 1.55;
        break;
      case 'active':
        multiplier = 1.725;
        break;
      default:
        multiplier = 1.2;
    }
    return bmr * multiplier;
  }

  /// Calcule l'objectif calorique final en fonction de l'objectif (perte, maintien, prise)
  static int calculateDailyCalories({
    required double tdee,
    required String goalType, // 'weight_loss', 'maintenance', 'muscle_gain'
  }) {
    int targetCalories = tdee.round();

    if (goalType == 'weight_loss') {
      targetCalories -= 400; // Déficit calorique moyen
    } else if (goalType == 'muscle_gain') {
      targetCalories += 400; // Surplus calorique moyen
    }
    
    // Ne jamais descendre sous 1200 kcal (limite santé générique)
    if (targetCalories < 1200) {
      targetCalories = 1200;
    }

    return targetCalories;
  }

  /// Récupère le libellé de l'activité en français
  static String getActivityLabel(String level) {
    switch (level) {
      case 'sedentary': return 'Sédentaire';
      case 'light': return 'Légère';
      case 'moderate': return 'Modérée';
      case 'active': return 'Intense';
      default: return 'Inconnu';
    }
  }
}
