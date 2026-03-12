
// Importation des dépendances Express et des middlewares/contrôleurs
import { Router } from "express";
import { requireAuth } from "../middleware/requireAuth";
import { getMe } from "../controllers/auth.controller";

// Création du routeur pour l'authentification
const router = Router();

// Route pour récupérer les informations de l'utilisateur connecté
router.get("/me", requireAuth, getMe);

export default router;
