import * as admin from "firebase-admin";
import * as path from "path";
import * as dotenv from "dotenv";

dotenv.config();

const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
if (!keyPath) throw new Error("GOOGLE_APPLICATION_CREDENTIALS missing in .env");

// Initialisation de Firebase
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(path.resolve(__dirname, "../../", keyPath)),
  });
}

const auth = admin.auth();
const db = admin.firestore();

async function createAdmin() {
  const email = process.argv[2];
  const password = process.argv[3];

  if (!email || !password) {
    console.error("Usage: npx ts-node src/scripts/create_admin.ts <email> <password>");
    process.exit(1);
  }

  try {
    let userRecord;
    try {
      // Vérifie si l'utilisateur existe déjà
      userRecord = await auth.getUserByEmail(email);
      console.log("Utilisateur trouvé dans Firebase Auth. Mise à jour de son rôle et mot de passe...");
      // Met à jour le mot de passe même si l'utilisateur existe
      await auth.updateUser(userRecord.uid, {
        password: password,
      });
    } catch (e: any) {
      if (e.code === "auth/user-not-found") {
        // Crée un nouvel utilisateur
        console.log("Création de l'utilisateur dans Firebase Auth...");
        userRecord = await auth.createUser({
          email: email,
          password: password,
          displayName: "Super Admin",
        });
      } else {
        throw e;
      }
    }

    const uid = userRecord.uid;

    // Ajoute le rôle 'admin' dans Firestore (utilisé par notre middleware)
    console.log("Mise à jour du document utilisateur dans Firestore...");
    await db.collection("users").doc(uid).set(
      {
        email: email,
        name: "Super Admin",
        role: "admin",
        status: "active",
        createdAt: new Date().toISOString(),
      },
      { merge: true }
    );

    // Optionnel : Ajouter un "Custom Claim" Firebase pour plus de sécurité
    await auth.setCustomUserClaims(uid, { role: "admin" });

    console.log("✅ Compte administrateur créé avec succès !");
    console.log(`Email : ${email}`);
    console.log(`Mot de passe : ${password}`);
    process.exit(0);
  } catch (error) {
    console.error("❌ Erreur lors de la création de l'admin:", error);
    process.exit(1);
  }
}

createAdmin();
