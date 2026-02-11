import { db } from "../config/firebase";
import { v4 as uuidv4 } from "uuid";

export const addGoalService = async (uid: string, goalData: any) => {
  const goalId = uuidv4();

  const ref = db.collection("users").doc(uid).collection("goals").doc(goalId);

  await ref.set({
    id: goalId,
    ...goalData,
  });

  return { id: goalId, ...goalData };
};

export const getGoalsService = async (uid: string) => {
  const ref = db.collection("users").doc(uid).collection("goals");
  const snapshot = await ref.orderBy("createdAt", "desc").get();

  const goals: any[] = [];
  snapshot.forEach((doc) => goals.push(doc.data()));

  return goals;
};

export const getGoalByIdService = async (uid: string, goalId: string) => {
  const ref = db.collection("users").doc(uid).collection("goals").doc(goalId);
  const snap = await ref.get();

  if (!snap.exists) return null;

  return snap.data();
};

export const updateGoalService = async (uid: string, goalId: string, updates: any) => {
  const ref = db.collection("users").doc(uid).collection("goals").doc(goalId);
  const snap = await ref.get();

  if (!snap.exists) return null;

  await ref.update(updates);

  return { id: goalId, ...snap.data(), ...updates };
};

export const deleteGoalService = async (uid: string, goalId: string) => {
  const ref = db.collection("users").doc(uid).collection("goals").doc(goalId);
  const snap = await ref.get();

  if (!snap.exists) return false;

  await ref.delete();
  return true;
};