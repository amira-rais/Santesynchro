
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
  gender?: "male" | "female";
  height?: number; // cm
  weight?: number; // kg
  photoUrl?: string | null;
  nutritionGoals?: {
    calories: number;
    protein: number;
    carbs: number;
    fat: number;
  };
}