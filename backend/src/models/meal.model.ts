import { Nutrition } from "./nutrition.model";

// Type représentant les différents types de repas
export type MealType = "breakfast" | "lunch" | "dinner" | "snack";

// Interface représentant un repas complet
export interface Meal {
  id?: string;
  name: string;
  type: MealType;
  quantity: number;
  unit?: string | null;
  nutrition?: Nutrition | null;
  time: string;       // HH:mm
  createdAt: string;  // ISO string
  imageUrl?: string | null;
}