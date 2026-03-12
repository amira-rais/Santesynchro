
// Interface représentant un aliment ou un composant d'un repas
export interface MealItem {
  name: string;
  quantity: number;   // ex. 100
  unit: string;       // ex. "g"
  calories: number;   // kcal
  carbs: number;      // g
  proteins: number;   // g
  fats: number;       // g
}

// Type représentant les différents types de repas
export type MealType = "breakfast" | "lunch" | "dinner" | "snack";

// Interface représentant un repas complet
export interface Meal {
  id?: string;
  name: string;
  type: MealType;
  quantity: number;
  unit?: string | null;
  nutrition?: any | null;
  createdAt: string;
  source?: string;
}