
// Importation des dépendances Express et des middlewares/contrôleurs
import { Router } from "express";
import { requireAuth } from "../middleware/requireAuth";
import { addMeal, getMeals, getMealById, updateMeal, deleteMeal } from "../controllers/meals.controller";

// Création du routeur pour les repas
const router = Router();


// Route pour ajouter un repas
router.post("/", requireAuth, addMeal);
// Route pour récupérer tous les repas
router.get("/", requireAuth, getMeals);
// Route pour récupérer un repas par ID
router.get("/:id", requireAuth, getMealById);
// Route pour mettre à jour un repas
router.put("/:id", requireAuth, updateMeal);
// Route pour supprimer un repas
router.delete("/:id", requireAuth, deleteMeal);

export default router;

