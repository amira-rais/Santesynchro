import { Request, Response, NextFunction } from "express";
import { authAdmin, db } from "../config/firebase";

/**
 * Middleware d'authentification admin.
 * Vérifie :
 *  1. La présence d'un token Firebase Bearer valide.
 *  2. Que l'utilisateur possède le rôle "admin" ou "superAdmin"
 *     (custom claim Firebase OU champ `role` dans Firestore).
 */
export async function requireAdmin(req: Request, res: Response, next: NextFunction) {
  try {
    const header = req.headers.authorization;
    if (!header?.startsWith("Bearer ")) {
      return res.status(401).json({ message: "Missing/invalid Authorization header" });
    }

    const token = header.slice("Bearer ".length).trim();
    const decoded = await authAdmin.verifyIdToken(token);

    // 1. Vérifie les custom claims Firebase
    const isAdminByClaim =
      decoded["role"] === "admin" || decoded["role"] === "superAdmin";

    // 2. Vérifie dans Firestore (fallback pour éviter d'avoir besoin de re-générer le token)
    let isAdminByFirestore = false;
    if (!isAdminByClaim) {
      const userDoc = await db.collection("users").doc(decoded.uid).get();
      const data = userDoc.data();
      isAdminByFirestore =
        data?.role === "admin" || data?.role === "superAdmin";
    }

    if (!isAdminByClaim && !isAdminByFirestore) {
      return res.status(403).json({ message: "Forbidden: admin access required" });
    }

    (req as any).user = decoded;
    next();
  } catch (err) {
    console.error("requireAdmin error:", err);
    return res.status(401).json({ message: "Invalid or expired token" });
  }
}
