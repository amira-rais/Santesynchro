// Importation des types Express et de la configuration Firebase
import { Request, Response, NextFunction } from "express";
import { authAdmin } from "../config/firebase";

// Middleware pour vérifier l'authentification de l'utilisateur via un token Firebase
export async function requireAuth(req: Request, res: Response, next: NextFunction) {
  try {
    // Récupère l'en-tête Authorization
    const header = req.headers.authorization;

    // Vérifie la présence et le format du token Bearer
    if (!header?.startsWith("Bearer ")) {
      return res.status(401).json({ message: "Missing/invalid Authorization header" });
    }

    // Extrait le token et le vérifie auprès de Firebase
    const token = header.slice("Bearer ".length).trim();
    const decoded = await authAdmin.verifyIdToken(token);

    // Ajoute l'utilisateur décodé à la requête
    (req as any).user = decoded; // on typera proprement après
    next();
  } catch {
    // Gestion des erreurs d'authentification
    return res.status(401).json({ message: "Invalid or expired token" });
  }
}