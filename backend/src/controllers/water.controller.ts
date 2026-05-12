// Contrôleur pour gérer les logs de consommation d'eau
import { Request, Response } from "express";
import { db } from "../config/firebase";
import { v4 as uuidv4 } from "uuid";

/**
 * Ajoute un log de consommation d'eau pour l'utilisateur connecté.
 * Stocké dans users/{uid}/water_logs/{id}
 */
export const addWater = async (req: Request, res: Response) => {
  try {
    const uid = (req as any).user?.uid;
    const { amount } = req.body;

    const waterAmount = amount ?? 250; // 250ml par défaut

    const today = new Date().toISOString().split("T")[0]; // YYYY-MM-DD
    const logId = uuidv4();

    const logData = {
      id: logId,
      amount: waterAmount,
      date: today,
      createdAt: new Date().toISOString(),
    };

    await db
      .collection("users")
      .doc(uid!)
      .collection("water_logs")
      .doc(logId)
      .set(logData);

    return res.status(201).json(logData);
  } catch (err) {
    console.error("Error adding water log:", err);
    return res.status(500).json({ message: "Server error" });
  }
};

/**
 * Récupère le total d'eau consommée aujourd'hui.
 * Retourne { total: number, goal: number, logs: [] }
 */
export const getWaterToday = async (req: Request, res: Response) => {
  try {
    const uid = (req as any).user?.uid;
    const today = new Date().toISOString().split("T")[0];

    const snapshot = await db
      .collection("users")
      .doc(uid!)
      .collection("water_logs")
      .where("date", "==", today)
      .orderBy("createdAt", "desc")
      .get();

    const logs: any[] = [];
    let total = 0;
    snapshot.forEach((doc) => {
      const data = doc.data();
      logs.push(data);
      total += data.amount ?? 0;
    });

    return res.status(200).json({
      total,
      goal: 2500, // 2.5L par défaut
      logs,
    });
  } catch (err) {
    console.error("Error fetching water today:", err);
    return res.status(500).json({ message: "Server error" });
  }
};
