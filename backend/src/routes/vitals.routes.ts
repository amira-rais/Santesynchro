// Routes pour la gestion des données vitales (pas, sommeil)
import { Router } from "express";
import { updateVitals, getVitalsToday } from "../controllers/vitals.controller";
import { requireAuth } from "../middleware/requireAuth";

const router = Router();

// PUT /vitals — Mettre à jour les vitaux du jour
router.put("/", requireAuth, updateVitals);

// GET /vitals/today — Récupérer les vitaux du jour
router.get("/today", requireAuth, getVitalsToday);

export default router;
