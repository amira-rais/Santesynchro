
// Type représentant la période d'un objectif (quotidien, hebdomadaire, mensuel)
export type GoalPeriod = "daily" | "weekly" | "monthly";

// Interface représentant un objectif utilisateur
export interface Goal {
  id?: string;
  type: string;
  target: number;
  unit: string;
  createdAt?: string;
  startDate?: string;
  endDate?: string | null;
}