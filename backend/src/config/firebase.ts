// Importation des dépendances nécessaires
import admin from "firebase-admin";
import path from "path";
import dotenv from "dotenv";

// Chargement des variables d'environnement
dotenv.config();

// Récupération du chemin de la clé de service Firebase
const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
if (!keyPath) throw new Error("GOOGLE_APPLICATION_CREDENTIALS missing in .env");

// Initialisation de l'application Firebase Admin si ce n'est pas déjà fait
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(path.resolve(keyPath)),
  });
}

// Exportation de l'instance Firestore et Auth pour utilisation dans l'application
export const db = admin.firestore();
export const authAdmin = admin.auth();
export default admin;