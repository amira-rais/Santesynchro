// Interface représentant un log de consommation d'eau
export interface WaterLog {
  id: string;
  amount: number;      // en ml (ex: 250)
  date: string;        // format YYYY-MM-DD
  createdAt: string;   // ISO timestamp
}
