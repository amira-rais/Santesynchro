import { Router } from "express";
import { requireAuth } from "../middleware/requireAuth";
import {
  addGoal,
  getGoals,
  getGoalById,
  updateGoal,
  deleteGoal,
} from "../controllers/goals.controller";

const router = Router();

router.post("/", requireAuth, addGoal);
router.get("/", requireAuth, getGoals);
router.get("/:id", requireAuth, getGoalById);
router.put("/:id", requireAuth, updateGoal);
router.delete("/:id", requireAuth, deleteGoal);

export default router;