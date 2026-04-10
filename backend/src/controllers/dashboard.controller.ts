// Contrôleur pour l'endpoint dashboard — agrège toutes les données du jour
import { Request, Response } from "express";
import { db } from "../config/firebase";

/**
 * Endpoint unique qui renvoie toutes les données nécessaires au tableau de bord :
 * - Informations utilisateur
 * - Nutrition du jour (calories, macros) calculée depuis les repas
 * - Hydratation du jour
 * - Vitaux du jour (pas, sommeil)
 * - Insights IA (règles simples)
 */
export const getDashboard = async (req: Request, res: Response) => {
  try {
    const uid = req.user?.uid;
    const today = new Date().toISOString().split("T")[0];

    // 1. Récupérer les infos utilisateur
    const userDoc = await db.collection("users").doc(uid!).get();
    const userData = userDoc.data() ?? {};

    // 2. Récupérer les repas du jour et calculer la nutrition
    const mealsSnapshot = await db
      .collection("users")
      .doc(uid!)
      .collection("meals")
      .where("createdAt", ">=", today + "T00:00:00")
      .where("createdAt", "<=", today + "T23:59:59")
      .get();

    let consumedCalories = 0;
    let consumedProtein = 0;
    let consumedCarbs = 0;
    let consumedFat = 0;

    mealsSnapshot.forEach((doc) => {
      const meal = doc.data();
      const nutrition = meal.nutrition ?? {};
      consumedCalories += nutrition.calories ?? 0;
      consumedProtein += nutrition.protein ?? nutrition.proteins ?? 0;
      consumedCarbs += nutrition.carbs ?? 0;
      consumedFat += nutrition.fat ?? nutrition.fats ?? 0;
    });

    // Objectifs nutritionnels par défaut ou depuis le profil
    const nutritionGoals = userData.nutritionGoals ?? {
      calories: 2100,
      protein: 160,
      carbs: 250,
      fat: 70,
    };

    // 3. Récupérer l'hydratation du jour
    const waterSnapshot = await db
      .collection("users")
      .doc(uid!)
      .collection("water_logs")
      .where("date", "==", today)
      .get();

    let waterTotal = 0;
    waterSnapshot.forEach((doc) => {
      waterTotal += doc.data().amount ?? 0;
    });

    // 4. Récupérer les vitaux du jour
    const vitalsDoc = await db
      .collection("users")
      .doc(uid!)
      .collection("vitals")
      .doc(today)
      .get();

    const vitals = vitalsDoc.exists
      ? vitalsDoc.data()
      : { steps: 0, stepsGoal: 10000, sleepDuration: 0, sleepQuality: 0 };

    // 5. Générer les insights (rules-based)
    const insights: { type: string; message: string; icon: string }[] = [];

    if (waterTotal < 1000) {
      insights.push({
        type: "hydration",
        message: "You're behind on water intake. Drink some water to maintain metabolic efficiency.",
        icon: "water_drop",
      });
    }

    if ((vitals?.sleepDuration ?? 0) > 0 && (vitals?.sleepDuration ?? 0) < 360) {
      insights.push({
        type: "sleep",
        message: "You slept less than 6 hours. Rest is crucial for recovery and focus.",
        icon: "nightlight",
      });
    }

    if (consumedCalories > nutritionGoals.calories) {
      insights.push({
        type: "overeating",
        message: `You've exceeded your daily calorie goal by ${consumedCalories - nutritionGoals.calories} kcal.`,
        icon: "warning",
      });
    }

    if (consumedCalories > 0 && consumedProtein < nutritionGoals.protein * 0.5) {
      insights.push({
        type: "protein",
        message: "Your protein intake is low today. Consider adding a high-protein meal.",
        icon: "fitness_center",
      });
    }

    // Si aucun insight, en ajouter un positif
    if (insights.length === 0) {
      insights.push({
        type: "positive",
        message: "Great job! You're on track with your health goals today.",
        icon: "thumb_up",
      });
    }

    // 6. Construire la réponse
    return res.status(200).json({
      user: {
        name: userData.name ?? "User",
        email: userData.email ?? "",
        photoUrl: userData.photoUrl ?? null,
      },
      nutrition: {
        consumed: consumedCalories,
        goal: nutritionGoals.calories,
        protein: { consumed: consumedProtein, goal: nutritionGoals.protein },
        carbs: { consumed: consumedCarbs, goal: nutritionGoals.carbs },
        fat: { consumed: consumedFat, goal: nutritionGoals.fat },
        mealsCount: mealsSnapshot.size,
      },
      water: {
        total: waterTotal,
        goal: 2500,
      },
      vitals: {
        steps: vitals?.steps ?? 0,
        stepsGoal: vitals?.stepsGoal ?? 10000,
        sleepDuration: vitals?.sleepDuration ?? 0,
        sleepQuality: vitals?.sleepQuality ?? 0,
      },
      insights,
    });
  } catch (err) {
    console.error("Error fetching dashboard:", err);
    return res.status(500).json({ message: "Server error" });
  }
};
