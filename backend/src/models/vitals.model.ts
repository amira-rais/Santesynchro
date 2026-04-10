// Interface représentant les données vitales quotidiennes
export interface Vitals {
  date: string;            // format YYYY-MM-DD
  steps: number;           // nombre de pas
  stepsGoal: number;       // objectif de pas (défaut: 10000)
  sleepDuration: number;   // durée en minutes (ex: 440 = 7h20)
  sleepQuality: number;    // pourcentage (0-100)
  updatedAt: string;       // ISO timestamp
}
