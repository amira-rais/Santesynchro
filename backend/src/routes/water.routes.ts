// Routes pour la gestion de l'hydratation
import { Router } from "express";
import { addWater, getWaterToday } from "../controllers/water.controller";
import { requireAuth } from "../middleware/requireAuth";

const router = Router();

// POST /water — Ajouter un log d'eau
router.post("/", requireAuth, addWater);

// GET /water/today — Récupérer le total d'eau du jour
router.get("/today", requireAuth, getWaterToday);

export default router;
