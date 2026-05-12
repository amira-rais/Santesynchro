
// Importation des dépendances Express et des middlewares/contrôleurs
import { Router } from "express";
import { requireAuth } from "../middleware/requireAuth";
import { getMe, updateMe, deleteMe } from "../controllers/auth.controller";
// import { upload } from "../middleware/upload"; // Supprimé au profit de Cloudinary

// Création du routeur pour l'authentification
const router = Router();

// Route pour récupérer les informations de l'utilisateur connecté
router.get("/me", requireAuth, getMe);
// Route pour mettre à jour les informations de l'utilisateur connecté
router.put("/me", requireAuth, updateMe);
// Route pour supprimer l'utilisateur et ses données
router.delete("/me", requireAuth, deleteMe);

export default router;
