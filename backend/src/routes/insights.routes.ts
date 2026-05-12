import { Router } from "express";
import { getProgressionData } from "../controllers/insights.controller";
import { requireAuth } from "../middleware/requireAuth";

const router = Router();

// Route protégée par token Firebase
router.get("/progression", requireAuth, getProgressionData);

export default router;
