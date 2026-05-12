
// Type représentant les différents fournisseurs d'authentification possibles
export type AuthProvider = "password" | "google" | "facebook" | "apple" | "github" | null;

// Interface représentant un utilisateur de l'application
export interface User {
  uid: string;
  email: string | null;
  name: string | null;
  createdAt: string;
  provider: AuthProvider;
  // Extensions futures
  age?: number;
  birthDate?: string; // YYYY-MM-DD
  gender?: "male" | "female" | "other";
  height?: number; // cm
  weight?: number; // kg
  targetWeight?: number; // kg
  pace?: string;
  activityLevel?: "sedentary" | "light" | "moderate" | "active";
  diets?: string[];
  conditions?: string[];
  allergies?: string[];
  photoUrl?: string | null;
  nutritionGoals?: {
    calories: number;
    protein: number;
    carbs: number;
    fat: number;
  };
}