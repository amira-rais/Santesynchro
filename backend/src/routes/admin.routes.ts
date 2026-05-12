import { Router } from "express";
import { requireAdmin } from "../middleware/requireAdmin";
import { requireAuth } from "../middleware/requireAuth";
import {
  getStats,
  getUsers,
  getUserDetail,
  updateUserStatus,
  deleteUser,
  getAdminLogs,
  recordSession,
} from "../controllers/admin.controller";

const router = Router();

// ─── Routes admin (protégées par requireAdmin) ───────────────────────────────
router.get("/stats", requireAdmin, getStats);
router.get("/users", requireAdmin, getUsers);
router.get("/users/:uid", requireAdmin, getUserDetail);
router.patch("/users/:uid/status", requireAdmin, updateUserStatus);
router.delete("/users/:uid", requireAdmin, deleteUser);
router.get("/logs", requireAdmin, getAdminLogs);

// ─── Route de tracking sessions (protégée par requireAuth, appelée par l'app mobile) ─
router.post("/sessions", requireAuth, recordSession);

export default router;
