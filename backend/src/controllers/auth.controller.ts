import { Request, Response } from "express";
import { db } from "../config/firebase";

export const getMe = async (req: Request, res: Response) => {
  try {
    const decoded = (req as any).user;
    const uid = decoded.uid;

    const userRef = db.collection("users").doc(uid);
    const snap = await userRef.get();

    // Crée le doc si c’est le premier login
    if (!snap.exists) {
      await userRef.set({
        email: decoded.email ?? null,
        name: decoded.name ?? null,
        createdAt: new Date().toISOString(),
        provider: decoded.firebase?.sign_in_provider ?? null,
      });
    }

    const userDoc = await userRef.get();

    return res.json({
      uid,
      ...userDoc.data(),
    });
  } catch (error) {
    console.error("Error in getMe:", error);
    return res.status(500).json({ message: "Internal server error" });
  }
};
