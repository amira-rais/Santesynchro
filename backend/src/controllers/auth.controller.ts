// Importation des types Request et Response d'Express
import { Request, Response } from "express";
// Importation de la configuration Firebase
import { db, authAdmin } from "../config/firebase";
import admin from "../config/firebase";
// Importation de l'interface User
import { User } from "../models/user.model";


// Contrôleur pour récupérer les informations de l'utilisateur connecté
export const getMe = async (req: Request, res: Response) => {
  try {
    // Récupère les informations de l'utilisateur depuis le token
    const decoded = (req as any).user;
    if (!decoded?.uid) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    const uid = decoded.uid;

    // Référence au document utilisateur dans Firestore
    const userRef = db.collection("users").doc(uid);
    const snap = await userRef.get();

    // Crée le document utilisateur si c'est le premier login
    if (!snap.exists) {
      let name = decoded.name ?? null;

      // Si le nom est null dans le token (souvent le cas juste après l'inscription),
      // on essaie de le récupérer directement via l'Admin SDK pour avoir l'info la plus à jour.
      if (!name) {
        try {
          const userRecord = await authAdmin.getUser(uid);
          name = userRecord.displayName ?? null;
        } catch (err) {
          console.error("Error fetching user record from admin:", err);
        }
      }

      const userData: Omit<User, "uid"> = {
        email: decoded.email ?? null,
        name: name,
        createdAt: new Date().toISOString(),
        provider: (decoded.firebase?.sign_in_provider ?? null) as import("../models/user.model").AuthProvider,
      };
      await userRef.set(userData);
    }

    // Vérifie si l'utilisateur a déjà des objectifs
    const goalsSnap = await userRef.collection("goals").limit(1).get();
    const hasGoals = !goalsSnap.empty;

    // Récupère les données utilisateur mises à jour
    const userDoc = await userRef.get();

    // Retourne les informations utilisateur
    return res.json({
      uid,
      ...userDoc.data(),
      hasGoals,
    });

  } catch (error) {
    // Gestion des erreurs
    console.error("Error in getMe:", error);
    return res.status(500).json({ message: "Internal server error" });
  }
};


// Contrôleur pour mettre à jour les informations de l'utilisateur
export const updateMe = async (req: Request, res: Response) => {
  try {
    const uid = (req as any).user?.uid;
    if (!uid) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    const updates = req.body;
    const userRef = db.collection("users").doc(uid);
    
    await userRef.update(updates);

    return res.json({ message: "Profile updated successfully" });
  } catch (error) {
    console.error("Error in updateMe:", error);
    return res.status(500).json({ message: "Internal server error" });
  }
};

// Contrôleur pour supprimer les informations de l'utilisateur
export const deleteMe = async (req: Request, res: Response) => {
  try {
    const uid = (req as any).user?.uid;
    if (!uid) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    const userRef = db.collection("users").doc(uid);

    // Supprimer les sous-collections
    const collections = ["goals", "meals", "water", "vitals"];
    for (const collectionName of collections) {
      const snap = await userRef.collection(collectionName).get();
      if (!snap.empty) {
        const batch = db.batch();
        snap.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
      }
    }

    // Supprimer le document utilisateur
    await userRef.delete();

    return res.json({ message: "User data deleted successfully from database" });
  } catch (error) {
    console.error("Error in deleteMe:", error);
    return res.status(500).json({ message: "Internal server error" });
  }
};