import { Request, Response } from "express";
import { db } from "../config/firebase";

/**
 * Récupère les données de progression sur les 7 derniers jours :
 * - Calories consommées par jour
 * - Nombre de pas par jour
 */
export const getProgressionData = async (req: Request, res: Response) => {
  try {
    const uid = (req as any).user?.uid;
    const history: any[] = [];
    
    // Calculer les 7 derniers jours
    const days = [];
    for (let i = 6; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      days.push(d.toISOString().split("T")[0]);
    }

    // 1. Récupérer tous les repas des 7 derniers jours
    const mealsSnapshot = await db
      .collection("users")
      .doc(uid!)
      .collection("meals")
      .where("createdAt", ">=", days[0] + "T00:00:00")
      .get();

    // 2. Récupérer les vitaux des 7 derniers jours
    const vitalsSnapshot = await db
      .collection("users")
      .doc(uid!)
      .collection("vitals")
      .where("date", ">=", days[0])
      .get();

    // Mapper les vitaux par date
    const vitalsMap: Record<string, any> = {};
    vitalsSnapshot.forEach(doc => {
      vitalsMap[doc.id] = doc.data();
    });

    // Mapper les calories par date
    const caloriesMap: Record<string, number> = {};
    mealsSnapshot.forEach(doc => {
      const meal = doc.data();
      const date = meal.createdAt.split("T")[0];
      const kcal = meal.nutrition?.calories ?? 0;
      caloriesMap[date] = (caloriesMap[date] ?? 0) + kcal;
    });

    // Construire le tableau de résultats
    const progression = days.map(day => ({
      date: day,
      calories: caloriesMap[day] ?? 0,
      steps: vitalsMap[day]?.steps ?? 0,
    }));

    return res.status(200).json(progression);
  } catch (err) {
    console.error("Error fetching progression data:", err);
    return res.status(500).json({ message: "Server error" });
  }
};
