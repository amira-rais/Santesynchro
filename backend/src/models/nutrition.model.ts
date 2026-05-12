// Interface représentant les informations nutritionnelles
export interface Nutrition {
  calories: number;   // kcal
  carbs: number;      // g
  proteins: number;   // g
  fats: number;       // g
  source?: string;    // ex. "open_food_facts" ou "manual"
}
