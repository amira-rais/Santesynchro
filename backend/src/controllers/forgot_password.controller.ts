import { Request, Response } from "express";
import { db, authAdmin } from "../config/firebase";
import { sendOTPEmail } from "../config/email.config";

/**
 * Génère un code OTP à 6 chiffres.
 */
const generateOTP = () => {
    return Math.floor(100000 + Math.random() * 900000).toString();
};

/**
 * Envoie un code OTP par email et le stocke dans Firestore.
 */
export const sendOTP = async (req: Request, res: Response) => {
    try {
        const { email } = req.body;

        if (!email) {
            return res.status(400).json({ message: "Email is required" });
        }

        // Vérifier si l'utilisateur existe
        try {
            await authAdmin.getUserByEmail(email);
        } catch (err) {
            return res.status(404).json({ message: "User not found" });
        }

        // Générer un OTP et une expiration
        const otp = generateOTP();
        const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes

        // Stocker dans Firestore (utilisons l'email comme ID pour écraser les anciennes demandes)
        await db.collection("password_resets").doc(email).set({
            email,
            otp,
            verified: false,
            expiresAt: expiresAt.toISOString(),
            createdAt: new Date().toISOString()
        });

        // Envoi de l'e-mail via Nodemailer
        try {
            await sendOTPEmail(email, otp);
        } catch (mailError) {
            console.error("Mail sending failed:", mailError);
            // On continue pour le dev, mais on informe dans la console
            console.log(`DEBUG: OTP pour ${email} est ${otp}`);
        }

        return res.status(200).json({
            message: "OTP sent successfully",
            email
        });
    } catch (error) {
        console.error("Error in sendOTP:", error);
        return res.status(500).json({ message: "Internal server error" });
    }
};

/**
 * Vérifie le code OTP saisi par l'utilisateur.
 */
export const verifyOTP = async (req: Request, res: Response) => {
    try {
        const { email, otp } = req.body;

        if (!email || !otp) {
            return res.status(400).json({ message: "Email and OTP are required" });
        }

        const resetDoc = await db.collection("password_resets").doc(email).get();

        if (!resetDoc.exists) {
            return res.status(404).json({ message: "No reset request found for this email" });
        }

        const data = resetDoc.data();
        const now = new Date();
        const expiresAt = new Date(data?.expiresAt);

        if (now > expiresAt) {
            return res.status(400).json({ message: "OTP has expired" });
        }

        if (data?.otp !== otp) {
            return res.status(400).json({ message: "Invalid OTP" });
        }

        // Marquer comme vérifié
        await db.collection("password_resets").doc(email).update({
            verified: true
        });

        return res.status(200).json({
            message: "OTP verified successfully",
            email
        });
    } catch (error) {
        console.error("Error in verifyOTP:", error);
        return res.status(500).json({ message: "Internal server error" });
    }
};

/**
 * Mise à jour finale du mot de passe.
 */
export const finalizePasswordReset = async (req: Request, res: Response) => {
    try {
        const { email, newPassword } = req.body;

        if (!email || !newPassword) {
            return res.status(400).json({ message: "Email and new password are required" });
        }

        const resetDoc = await db.collection("password_resets").doc(email).get();

        if (!resetDoc.exists || !resetDoc.data()?.verified) {
            return res.status(400).json({ message: "Request not verified or not found" });
        }

        // Vérifier encore l'expiration par sécurité
        const data = resetDoc.data();
        const now = new Date();
        const expiresAt = new Date(data?.expiresAt);

        if (now > expiresAt) {
            return res.status(400).json({ message: "Session expired" });
        }

        // Mettre à jour dans Firebase Auth
        const userRecord = await authAdmin.getUserByEmail(email);
        await authAdmin.updateUser(userRecord.uid, {
            password: newPassword,
        });

        // Supprimer la demande de réinitialisation
        await db.collection("password_resets").doc(email).delete();

        return res.json({ message: "Password updated successfully" });
    } catch (error) {
        console.error("Error in finalizePasswordReset:", error);
        return res.status(500).json({ message: "Internal server error" });
    }
};
