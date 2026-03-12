// Importation des dépendances Express et des middlewares/contrôleurs
import { Router } from "express";
import { requireAuth } from "../middleware/requireAuth";
import {
  addGoal,
  getGoals,
  getGoalById,
  updateGoal,
  deleteGoal,
} from "../controllers/goals.controller";

// Création du routeur pour les objectifs
const router = Router();

// Route pour ajouter un objectif
router.post("/", requireAuth, addGoal);
// Route pour récupérer tous les objectifs
router.get("/", requireAuth, getGoals);
// Route pour récupérer un objectif par ID
router.get("/:id", requireAuth, getGoalById);
// Route pour mettre à jour un objectif
router.put("/:id", requireAuth, updateGoal);
// Route pour supprimer un objectif
router.delete("/:id", requireAuth, deleteGoal);

export default router;