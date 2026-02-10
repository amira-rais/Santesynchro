import { Request, Response, NextFunction } from "express";
import { authAdmin } from "../config/firebase";

export async function requireAuth(req: Request, res: Response, next: NextFunction) {
  try {
    const header = req.headers.authorization;

    if (!header?.startsWith("Bearer ")) {
      return res.status(401).json({ message: "Missing/invalid Authorization header" });
    }

    const token = header.slice("Bearer ".length).trim();
    const decoded = await authAdmin.verifyIdToken(token);

    (req as any).user = decoded; // on typera proprement après
    next();
  } catch {
    return res.status(401).json({ message: "Invalid or expired token" });
  }
}