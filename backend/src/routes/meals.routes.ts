import { Router } from "express";
import { requireAuth } from "../middleware/requireAuth";
import { addMeal, getMeals, getMealById, updateMeal, deleteMeal } from "../controllers/meals.controller";

const router = Router();

router.post("/", requireAuth, addMeal);
router.get("/", requireAuth, getMeals);
router.get("/:id", requireAuth, getMealById);
router.put("/:id", requireAuth, updateMeal);
router.delete("/:id", requireAuth, deleteMeal);

export default router;

