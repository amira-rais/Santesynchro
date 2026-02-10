import admin from "firebase-admin";
import path from "path";
import dotenv from "dotenv";

dotenv.config();

const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
if (!keyPath) throw new Error("GOOGLE_APPLICATION_CREDENTIALS missing in .env");

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(path.resolve(keyPath)),
  });
}

export const db = admin.firestore();
export const authAdmin = admin.auth();
export default admin;