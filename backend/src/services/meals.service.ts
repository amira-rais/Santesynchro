import { db } from "../config/firebase";
import { v4 as uuidv4 } from "uuid";

export const addMealService = async (uid: string, mealData: any) => {
  const mealId = uuidv4();

  const mealRef = db
    .collection("users")
    .doc(uid)
    .collection("meals")
    .doc(mealId);

  await mealRef.set({
    id: mealId,
    ...mealData,
  });

  return {
    id: mealId,
    ...mealData,
  };
};

export const getMealsService = async (uid: string) => {
  const mealsRef = db
    .collection("users")
    .doc(uid)
    .collection("meals")
    .orderBy("createdAt", "desc");

  const snapshot = await mealsRef.get();

  const meals: any[] = [];

  snapshot.forEach((doc) => {
    meals.push(doc.data());
  });

  return meals;
};

export const getMealByIdService = async (uid: string, mealId: string) => {
  const mealRef = db
    .collection("users")
    .doc(uid)
    .collection("meals")
    .doc(mealId);

  const snapshot = await mealRef.get();

  if (!snapshot.exists) {
    return null;
  }

  return snapshot.data();
};

export const updateMealService = async (uid: string, mealId: string, updates: any) => {
  const mealRef = db
    .collection("users")
    .doc(uid)
    .collection("meals")
    .doc(mealId);

  const snapshot = await mealRef.get();

  if (!snapshot.exists) return null;

  await mealRef.update(updates);

  return {
    id: mealId,
    ...snapshot.data(),
    ...updates
  };
};

export const deleteMealService = async (uid: string, mealId: string) => {
  const mealRef = db
    .collection("users")
    .doc(uid)
    .collection("meals")
    .doc(mealId);

  const snapshot = await mealRef.get();

  if (!snapshot.exists) return false;

  await mealRef.delete();
  return true;
};