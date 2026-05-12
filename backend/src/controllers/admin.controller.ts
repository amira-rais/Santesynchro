import { Request, Response } from "express";
import { db, authAdmin } from "../config/firebase";
import admin from "../config/firebase";

// ─────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────

/** Enregistre une action admin dans la collection admin_logs */
async function logAdminAction(
  adminUid: string,
  action: string,
  targetUid: string,
  details?: Record<string, unknown>
) {
  await db.collection("admin_logs").add({
    adminUid,
    action,
    targetUid,
    details: details ?? {},
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// ─────────────────────────────────────────────
// KPIs & Statistiques
// ─────────────────────────────────────────────

/** GET /api/admin/stats
 * Retourne les KPIs globaux + données quotidiennes pour graphiques.
 */
export const getStats = async (req: Request, res: Response) => {
  try {
    const usersSnap = await db.collection("users").get();
    const totalUsers = usersSnap.size;

    // Compter les utilisateurs actifs (au moins 1 session dans les 30 derniers jours)
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const sessionsRef = db.collection("sessions");
    const [mauSnap, dauSnap, totalSessionsSnap] = await Promise.all([
      sessionsRef.where("startedAt", ">=", thirtyDaysAgo.toISOString()).get(),
      sessionsRef.where("startedAt", ">=", today.toISOString()).get(),
      sessionsRef.get(),
    ]);

    // Utilisateurs uniques actifs
    const mauSet = new Set(mauSnap.docs.map((d) => d.data().uid));
    const dauSet = new Set(dauSnap.docs.map((d) => d.data().uid));

    // Temps moyen de session
    let totalDuration = 0;
    let sessionCount = 0;
    totalSessionsSnap.forEach((doc) => {
      const d = doc.data();
      if (d.durationSeconds) {
        totalDuration += d.durationSeconds;
        sessionCount++;
      }
    });
    const avgSessionMinutes =
      sessionCount > 0 ? Math.round(totalDuration / sessionCount / 60) : 0;

    // Croissance des utilisateurs (30 derniers jours)
    const dailyGrowth: Record<string, number> = {};
    usersSnap.forEach((doc) => {
      const data = doc.data();
      if (data.createdAt) {
        const day = data.createdAt.substring(0, 10); // YYYY-MM-DD
        const date = new Date(day);
        if (date >= thirtyDaysAgo) {
          dailyGrowth[day] = (dailyGrowth[day] ?? 0) + 1;
        }
      }
    });

    // Répartition par statut
    let active = 0, banned = 0, suspended = 0;
    usersSnap.forEach((doc) => {
      const status = doc.data().status ?? "active";
      if (status === "banned") banned++;
      else if (status === "suspended") suspended++;
      else active++;
    });

    // Sessions par jour (7 derniers jours)
    const dailySessions: Record<string, number> = {};
    const sessionsDailySnap = await sessionsRef
      .where("startedAt", ">=", sevenDaysAgo.toISOString())
      .get();
    sessionsDailySnap.forEach((doc) => {
      const day = doc.data().startedAt?.substring(0, 10);
      if (day) dailySessions[day] = (dailySessions[day] ?? 0) + 1;
    });

    return res.json({
      totalUsers,
      activeUsersMonthly: mauSet.size,
      activeUsersDaily: dauSet.size,
      totalSessions: sessionCount,
      avgSessionMinutes,
      userStatusDistribution: { active, banned, suspended },
      dailyUserGrowth: dailyGrowth,
      dailySessions,
    });
  } catch (err) {
    console.error("getStats error:", err);
    return res.status(500).json({ message: "Internal server error" });
  }
};

// ─────────────────────────────────────────────
// Gestion des utilisateurs
// ─────────────────────────────────────────────

/** GET /api/admin/users?page=1&limit=20&search=xxx&status=active */
export const getUsers = async (req: Request, res: Response) => {
  try {
    const limit = parseInt((req.query.limit as string) ?? "20", 10);
    const search = ((req.query.search as string) ?? "").toLowerCase();
    const statusFilter = (req.query.status as string) ?? "";
    const pageToken = req.query.pageToken as string | undefined;

    let query: admin.firestore.Query = db.collection("users").orderBy("createdAt", "desc");

    if (statusFilter) {
      query = query.where("status", "==", statusFilter);
    }

    if (pageToken) {
      const lastDoc = await db.collection("users").doc(pageToken).get();
      if (lastDoc.exists) query = query.startAfter(lastDoc);
    }

    const snap = await query.limit(limit + 1).get();
    let users = snap.docs.map((doc) => ({ uid: doc.id, ...doc.data() }));

    // Filtrage par recherche texte côté serveur (Firestore ne supporte pas LIKE)
    if (search) {
      users = users.filter((u: any) => {
        const name = (u.name ?? "").toLowerCase();
        const email = (u.email ?? "").toLowerCase();
        return name.includes(search) || email.includes(search);
      });
    }

    const hasNextPage = users.length > limit;
    if (hasNextPage) users.pop();

    const nextPageToken = hasNextPage ? snap.docs[snap.docs.length - 2]?.id : null;

    return res.json({ users, nextPageToken });
  } catch (err) {
    console.error("getUsers error:", err);
    return res.status(500).json({ message: "Internal server error" });
  }
};

/** GET /api/admin/users/:uid — Profil détaillé */
export const getUserDetail = async (req: Request, res: Response) => {
  try {
    const uid = req.params.uid as string;
    const [userDoc, goalsSnap, mealsSnap] = await Promise.all([
      db.collection("users").doc(uid).get(),
      db.collection("users").doc(uid).collection("goals").get(),
      db.collection("users").doc(uid).collection("meals").orderBy("date", "desc").limit(10).get(),
    ]);

    if (!userDoc.exists) {
      return res.status(404).json({ message: "User not found" });
    }

    return res.json({
      uid,
      ...userDoc.data(),
      goals: goalsSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
      recentMeals: mealsSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
    });
  } catch (err) {
    console.error("getUserDetail error:", err);
    return res.status(500).json({ message: "Internal server error" });
  }
};

/** PATCH /api/admin/users/:uid/status — Bannir / suspendre / réactiver */
export const updateUserStatus = async (req: Request, res: Response) => {
  try {
    const uid = req.params.uid as string;
    const { status } = req.body as { status: "active" | "banned" | "suspended" };
    const adminUid = (req as any).user?.uid;

    if (!["active", "banned", "suspended"].includes(status)) {
      return res.status(400).json({ message: "Invalid status value" });
    }

    await db.collection("users").doc(uid).update({ status });

    // Désactiver le compte Firebase Auth si banni ou suspendu
    if (status === "banned" || status === "suspended") {
      await authAdmin.updateUser(uid, { disabled: true });
    } else {
      await authAdmin.updateUser(uid, { disabled: false });
    }

    await logAdminAction(adminUid, `user_status_changed_to_${status}`, uid);

    return res.json({ message: `User status updated to ${status}` });
  } catch (err) {
    console.error("updateUserStatus error:", err);
    return res.status(500).json({ message: "Internal server error" });
  }
};

/** DELETE /api/admin/users/:uid — Supprime un utilisateur */
export const deleteUser = async (req: Request, res: Response) => {
  try {
    const uid = req.params.uid as string;
    const adminUid = (req as any).user?.uid;

    const userRef = db.collection("users").doc(uid);

    // Supprimer sous-collections
    const subCollections = ["goals", "meals", "water", "vitals", "sessions"];
    for (const col of subCollections) {
      const snap = await userRef.collection(col).get();
      if (!snap.empty) {
        const batch = db.batch();
        snap.forEach((d) => batch.delete(d.ref));
        await batch.commit();
      }
    }

    await userRef.delete();
    await authAdmin.deleteUser(uid);
    await logAdminAction(adminUid, "user_deleted", uid);

    return res.json({ message: "User deleted successfully" });
  } catch (err) {
    console.error("deleteUser error:", err);
    return res.status(500).json({ message: "Internal server error" });
  }
};

// ─────────────────────────────────────────────
// Logs d'actions admin
// ─────────────────────────────────────────────

/** GET /api/admin/logs */
export const getAdminLogs = async (req: Request, res: Response) => {
  try {
    const limit = parseInt((req.query.limit as string) ?? "50", 10);
    const snap = await db
      .collection("admin_logs")
      .orderBy("timestamp", "desc")
      .limit(limit)
      .get();

    const logs = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    return res.json(logs);
  } catch (err) {
    console.error("getAdminLogs error:", err);
    return res.status(500).json({ message: "Internal server error" });
  }
};

// ─────────────────────────────────────────────
// Analytics : enregistrement des sessions (mobile → backend)
// ─────────────────────────────────────────────

/** POST /api/admin/sessions — Envoyé par l'app Flutter */
export const recordSession = async (req: Request, res: Response) => {
  try {
    const uid = (req as any).user?.uid;
    if (!uid) return res.status(401).json({ message: "Unauthorized" });

    const { startedAt, endedAt, durationSeconds } = req.body;
    if (!startedAt || !endedAt || durationSeconds === undefined) {
      return res.status(400).json({ message: "startedAt, endedAt, durationSeconds are required" });
    }

    await db.collection("sessions").add({
      uid,
      startedAt,
      endedAt,
      durationSeconds,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.status(201).json({ message: "Session recorded" });
  } catch (err) {
    console.error("recordSession error:", err);
    return res.status(500).json({ message: "Internal server error" });
  }
};
