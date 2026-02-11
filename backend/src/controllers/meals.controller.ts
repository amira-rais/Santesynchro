import { Request, Response } from "express";
import { addMealService, getMealsService, getMealByIdService, updateMealService, deleteMealService } from "../services/meals.service";


export const addMeal = async (req: Request, res: Response) => {
  try {
    const uid = req.user?.uid;
    const { name, type, quantity, unit, nutrition } = req.body;

    if (!name || !type || !quantity) {
      return res.status(400).json({
        message: "name, type and quantity are required",
      });
    }

    const meal = await addMealService(uid!, {
      name,
      type,
      quantity,
      unit: unit ?? null,
      nutrition: nutrition ?? null,
      createdAt: new Date().toISOString(),
      source: "manual",
    });

    return res.status(201).json(meal);

  } catch (err) {
    console.error("Error adding meal:", err);
    return res.status(500).json({ message: "Server error" });
  }
};

export const getMeals = async (req: Request, res: Response) => {
  try {
    const uid = req.user?.uid;

    const meals = await getMealsService(uid!);

    return res.status(200).json(meals);

  } catch (err) {
    console.error("Error fetching meals:", err);
    return res.status(500).json({ message: "Server error" });
  }
};

export const getMealById = async (req: Request, res: Response) => {
  try {
    const uid = req.user?.uid;
    const mealId = req.params.id;

    const meal = await getMealByIdService(uid!, mealId);

    if (!meal) {
      return res.status(404).json({ message: "Meal not found" });
    }

    return res.status(200).json(meal);

  } catch (err) {
    console.error("Error fetching meal:", err);
    return res.status(500).json({ message: "Server error" });
  }
};

export const updateMeal = async (req: Request, res: Response) => {
  try {
    const uid = req.user?.uid;
    const mealId = req.params.id;
    const updates = req.body;

    if (!updates || Object.keys(updates).length === 0) {
      return res.status(400).json({ message: "No fields to update" });
    }

    const updatedMeal = await updateMealService(uid!, mealId, updates);

    if (!updatedMeal) {
      return res.status(404).json({ message: "Meal not found" });
    }

    return res.status(200).json(updatedMeal);

  } catch (err) {
    console.error("Error updating meal:", err);
    return res.status(500).json({ message: "Server error" });
  }
};

export const deleteMeal = async (req: Request, res: Response) => {
  try {
    const uid = req.user?.uid;
    const mealId = req.params.id;

    const success = await deleteMealService(uid!, mealId);

    if (!success) {
      return res.status(404).json({ message: "Meal not found" });
    }

    return res.status(200).json({ message: "Meal deleted successfully" });

  } catch (err) {
    console.error("Error deleting meal:", err);
    return res.status(500).json({ message: "Server error" });
  }
};