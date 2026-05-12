// Importation des types Request et Response d'Express
import { Request, Response } from "express";
// Importation de la configuration Firebase
import { db } from "../config/firebase";
// Importation de uuid pour générer des identifiants uniques
import { v4 as uuidv4 } from "uuid";
// Importation des interfaces de modèles
import { Meal, MealType } from "../models/meal.model";


// Contrôleur pour ajouter un nouveau repas
/**
 * Ajoute un nouveau repas pour l'utilisateur connecté.
 * Les données sont stockées dans une sous-collection 'meals' propre à l'utilisateur.
 */
export const addMeal = async (req: Request, res: Response) => {
  try {
    const uid = (req as any).user?.uid;
    const { name, type, quantity, unit, nutrition, time, imageUrl } = req.body;

    // Vérification des champs obligatoires
    if (!name || !type || !quantity || !time) {
      return res.status(400).json({
        message: "name, type, quantity and time are required",
      });
    }

    // Génération d'un identifiant unique pour le repas
    const mealId = uuidv4();

    // Construction des données du repas
    const mealData: Meal = {
      id: mealId,
      name,
      type,
      quantity,
      unit: unit ?? null,
      nutrition: nutrition || null,
      time,
      createdAt: new Date().toISOString(),
      imageUrl: imageUrl || null,
    };

    // Référence au document du repas dans Firestore
    const mealRef = db
      .collection("users")
      .doc(uid!)
      .collection("meals")
      .doc(mealId);

    // Enregistrement du repas dans Firestore
    await mealRef.set(mealData);

    // Retourne le repas créé
    return res.status(201).json(mealData);

  } catch (err) {
    // Gestion des erreurs
    console.error("Error adding meal:", err);
    return res.status(500).json({ message: "Server error" });
  }
};

// Contrôleur pour récupérer tous les repas d'un utilisateur
/**
 * Récupère la liste chronologique inverse de tous les repas de l'utilisateur.
 */
export const getMeals = async (req: Request, res: Response) => {
  try {
    const uid = (req as any).user?.uid;

    // Référence à la collection des repas, triée par date décroissante
    const mealsRef = db
      .collection("users")
      .doc(uid!)
      .collection("meals")
      .orderBy("createdAt", "desc");

    // Récupération des repas depuis Firestore
    const snapshot = await mealsRef.get();

    const meals: any[] = [];
    // Parcourt chaque document et l'ajoute à la liste
    snapshot.forEach((doc) => {
      meals.push(doc.data());
    });

    // Retourne la liste des repas
    return res.status(200).json(meals);

  } catch (err) {
    // Gestion des erreurs
    console.error("Error fetching meals:", err);
    return res.status(500).json({ message: "Server error" });
  }
};

// Contrôleur pour récupérer un repas par son ID
/**
 * Récupère les détails d'un repas spécifique via son ID.
 */
export const getMealById = async (req: Request, res: Response) => {
  try {
    const uid = (req as any).user?.uid;
    const mealId = req.params.id as string;

    // Référence au document du repas dans Firestore
    const mealRef = db
      .collection("users")
      .doc(uid!)
      .collection("meals")
      .doc(mealId);

    // Récupération du document
    const snapshot = await mealRef.get();

    // Si le repas n'existe pas
    if (!snapshot.exists) {
      return res.status(404).json({ message: "Meal not found" });
    }

    // Retourne le repas trouvé
    return res.status(200).json(snapshot.data());

  } catch (err) {
    // Gestion des erreurs
    console.error("Error fetching meal:", err);
    return res.status(500).json({ message: "Server error" });
  }
};

// Contrôleur pour mettre à jour un repas existant
/**
 * Met à jour partiellement les informations d'un repas.
 */
export const updateMeal = async (req: Request, res: Response) => {
  try {
    const uid = (req as any).user?.uid;
    const mealId = req.params.id as string;
    const updates = req.body;

    // Vérifie si des champs à mettre à jour sont fournis
    if (!updates || Object.keys(updates).length === 0) {
      return res.status(400).json({ message: "No fields to update" });
    }

    // Référence au document du repas dans Firestore
    const mealRef = db
      .collection("users")
      .doc(uid!)
      .collection("meals")
      .doc(mealId);

    // Vérifie si le repas existe
    const snapshot = await mealRef.get();
    if (!snapshot.exists) {
      return res.status(404).json({ message: "Meal not found" });
    }

    // Mise à jour du repas dans Firestore
    await mealRef.update(updates);

    // Retourne le repas mis à jour
    return res.status(200).json({
      id: mealId,
      ...snapshot.data(),
      ...updates,
    });

  } catch (err) {
    // Gestion des erreurs
    console.error("Error updating meal:", err);
    return res.status(500).json({ message: "Server error" });
  }
};

// Contrôleur pour supprimer un repas
/**
 * Supprime définitivement un repas de la base de données.
 */
export const deleteMeal = async (req: Request, res: Response) => {
  try {
    const uid = (req as any).user?.uid;
    const mealId = req.params.id as string;

    // Référence au document du repas dans Firestore
    const mealRef = db
      .collection("users")
      .doc(uid!)
      .collection("meals")
      .doc(mealId);

    // Vérifie si le repas existe
    const snapshot = await mealRef.get();
    if (!snapshot.exists) {
      return res.status(404).json({ message: "Meal not found" });
    }

    // Suppression du repas dans Firestore
    await mealRef.delete();

    return res.status(200).json({ message: "Meal deleted successfully" });

  } catch (err) {
    console.error("Error deleting meal:", err);
    return res.status(500).json({ message: "Server error" });
  }
};