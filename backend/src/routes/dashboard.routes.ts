// Route pour le tableau de bord — agrège toutes les données du jour
import { Router } from "express";
import { getDashboard } from "../controllers/dashboard.controller";
import { requireAuth } from "../middleware/requireAuth";

const router = Router();

// GET /dashboard — Récupérer toutes les données du tableau de bord
router.get("/", requireAuth, getDashboard);

export default router;
