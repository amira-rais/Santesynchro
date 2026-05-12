// Importation des types Request et Response d'Express
import { Request, Response } from "express";
// Importation de la configuration Firebase
import { db } from "../config/firebase";
// Importation de uuid pour générer des identifiants uniques
import { v4 as uuidv4 } from "uuid";
// Importation des interfaces de modèles
import { Goal, GoalPeriod } from "../models/goal.model";


// Contrôleur pour ajouter un nouvel objectif
export const addGoal = async (req: Request, res: Response) => {
  try {
    const uid = (req as any).user?.uid;
    const { type, target, unit } = req.body;

    // Vérification des champs obligatoires
    if (!type || !target || !unit) {
      return res.status(400).json({ message: "type, target and unit are required" });
    }

    // Génération d'un identifiant unique pour l'objectif
    const goalId = uuidv4();

    // Construction des données de l'objectif
    const goalData = {
      id: goalId,
      type,
      target,
      unit,
      createdAt: new Date().toISOString(),
      startDate: new Date().toISOString(),
      endDate: null,
    };

    // Référence au document de l'objectif dans Firestore
    const goalRef = db
      .collection("users")
      .doc(uid!)
      .collection("goals")
      .doc(goalId);

    // Enregistrement de l'objectif dans Firestore
    await goalRef.set(goalData);

    // Retourne l'objectif créé
    return res.status(201).json(goalData);

  } catch (err) {
    // Gestion des erreurs
    console.error("Error adding goal:", err);
    return res.status(500).json({ message: "Server error" });
  }
};

// Contrôleur pour récupérer tous les objectifs d'un utilisateur
export const getGoals = async (req: Request, res: Response) => {
  try {
    const uid = (req as any).user?.uid;

    // Référence à la collection des objectifs, triée par date décroissante
    const goalsRef = db
      .collection("users")
      .doc(uid!)
      .collection("goals")
      .orderBy("createdAt", "desc");

    // Récupération des objectifs depuis Firestore
    const snapshot = await goalsRef.get();

    const goals: any[] = [];
    // Parcourt chaque document et l'ajoute à la liste
    snapshot.forEach((doc) => goals.push(doc.data()));

    // Retourne la liste des objectifs
    return res.status(200).json(goals);

  } catch (err) {
    // Gestion des erreurs
    console.error("Error fetching goals:", err);
    return res.status(500).json({ message: "Server error" });
  }
};

// Contrôleur pour récupérer un objectif par son ID
export const getGoalById = async (req: Request, res: Response) => {
  try {
    const uid = (req as any).user?.uid;
    const goalId = req.params.id as string;

    // Référence au document de l'objectif dans Firestore
    const goalRef = db
      .collection("users")
      .doc(uid!)
      .collection("goals")
      .doc(goalId);

    // Récupération du document
    const snap = await goalRef.get();

    // Si l'objectif n'existe pas
    if (!snap.exists) {
      return res.status(404).json({ message: "Goal not found" });
    }

    // Retourne l'objectif trouvé
    return res.status(200).json(snap.data());

  } catch (err) {
    // Gestion des erreurs
    console.error("Error fetching goal:", err);
    return res.status(500).json({ message: "Server error" });
  }
};

// Contrôleur pour mettre à jour un objectif existant
export const updateGoal = async (req: Request, res: Response) => {
  try {
    const uid = (req as any).user?.uid;
    const goalId = req.params.id as string;
    const updates = req.body;

    // Référence au document de l'objectif dans Firestore
    const goalRef = db
      .collection("users")
      .doc(uid!)
      .collection("goals")
      .doc(goalId);

    // Vérifie si l'objectif existe
    const snap = await goalRef.get();
    if (!snap.exists) {
      return res.status(404).json({ message: "Goal not found" });
    }

    // Mise à jour de l'objectif dans Firestore
    await goalRef.update(updates);

    // Retourne l'objectif mis à jour
    return res.status(200).json({
      id: goalId,
      ...snap.data(),
      ...updates,
    });

  } catch (err) {
    console.error("Error updating goal:", err);
    return res.status(500).json({ message: "Server error" });
  }
};

// Contrôleur pour supprimer un objectif
export const deleteGoal = async (req: Request, res: Response) => {
  try {
    const uid = (req as any).user?.uid;
    const goalId = req.params.id as string;

    // Référence au document de l'objectif dans Firestore
    const goalRef = db
      .collection("users")
      .doc(uid!)
      .collection("goals")
      .doc(goalId);

    // Vérifie si l'objectif existe
    const snap = await goalRef.get();
    if (!snap.exists) {
      return res.status(404).json({ message: "Goal not found" });
    }

    // Suppression de l'objectif dans Firestore
    await goalRef.delete();

    return res.status(200).json({ message: "Goal deleted successfully" });

  } catch (err) {
    console.error("Error deleting goal:", err);
    return res.status(500).json({ message: "Server error" });
  }
};