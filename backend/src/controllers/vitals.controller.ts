// Contrôleur pour gérer les données vitales quotidiennes (pas, sommeil)
import { Request, Response } from "express";
import { db } from "../config/firebase";

/**
 * Met à jour ou crée les vitaux du jour pour l'utilisateur connecté.
 * Stocké dans users/{uid}/vitals/{date}
 */
export const updateVitals = async (req: Request, res: Response) => {
  try {
    const uid = req.user?.uid;
    const { steps, stepsGoal, sleepDuration, sleepQuality } = req.body;

    const today = new Date().toISOString().split("T")[0];

    const vitalsRef = db
      .collection("users")
      .doc(uid!)
      .collection("vitals")
      .doc(today);

    const existing = await vitalsRef.get();

    const vitalsData = {
      date: today,
      steps: steps ?? (existing.exists ? existing.data()?.steps ?? 0 : 0),
      stepsGoal: stepsGoal ?? (existing.exists ? existing.data()?.stepsGoal ?? 10000 : 10000),
      sleepDuration: sleepDuration ?? (existing.exists ? existing.data()?.sleepDuration ?? 0 : 0),
      sleepQuality: sleepQuality ?? (existing.exists ? existing.data()?.sleepQuality ?? 0 : 0),
      updatedAt: new Date().toISOString(),
    };

    await vitalsRef.set(vitalsData, { merge: true });

    return res.status(200).json(vitalsData);
  } catch (err) {
    console.error("Error updating vitals:", err);
    return res.status(500).json({ message: "Server error" });
  }
};

/**
 * Récupère les vitaux du jour pour l'utilisateur connecté.
 */
export const getVitalsToday = async (req: Request, res: Response) => {
  try {
    const uid = req.user?.uid;
    const today = new Date().toISOString().split("T")[0];

    const vitalsRef = db
      .collection("users")
      .doc(uid!)
      .collection("vitals")
      .doc(today);

    const snapshot = await vitalsRef.get();

    if (!snapshot.exists) {
      return res.status(200).json({
        date: today,
        steps: 0,
        stepsGoal: 10000,
        sleepDuration: 0,
        sleepQuality: 0,
      });
    }

    return res.status(200).json(snapshot.data());
  } catch (err) {
    console.error("Error fetching vitals:", err);
    return res.status(500).json({ message: "Server error" });
  }
};
