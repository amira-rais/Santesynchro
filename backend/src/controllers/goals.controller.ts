import { Request, Response } from "express";
import {
  addGoalService,
  getGoalsService,
  getGoalByIdService,
  updateGoalService,
  deleteGoalService,
} from "../services/goals.service";

export const addGoal = async (req: Request, res: Response) => {
  try {
    const uid = req.user?.uid;
    const { type, target, unit } = req.body;

    if (!type || !target || !unit) {
      return res.status(400).json({ message: "type, target and unit are required" });
    }

    const goal = await addGoalService(uid!, {
      type,
      target,
      unit,
      createdAt: new Date().toISOString(),
      startDate: new Date().toISOString(),
      endDate: null
    });

    return res.status(201).json(goal);

  } catch (err) {
    console.error("Error adding goal:", err);
    return res.status(500).json({ message: "Server error" });
  }
};

export const getGoals = async (req: Request, res: Response) => {
  try {
    const uid = req.user?.uid;
    const goals = await getGoalsService(uid!);
    return res.status(200).json(goals);
  } catch (err) {
    console.error("Error fetching goals:", err);
    return res.status(500).json({ message: "Server error" });
  }
};

export const getGoalById = async (req: Request, res: Response) => {
  try {
    const uid = req.user?.uid;
    const goalId = req.params.id;

    const goal = await getGoalByIdService(uid!, goalId);

    if (!goal) return res.status(404).json({ message: "Goal not found" });

    return res.status(200).json(goal);
  } catch (err) {
    console.error("Error fetching goal:", err);
    return res.status(500).json({ message: "Server error" });
  }
};

export const updateGoal = async (req: Request, res: Response) => {
  try {
    const uid = req.user?.uid;
    const goalId = req.params.id;
    const updates = req.body;

    const updatedGoal = await updateGoalService(uid!, goalId, updates);

    if (!updatedGoal) return res.status(404).json({ message: "Goal not found" });

    return res.status(200).json(updatedGoal);
  } catch (err) {
    console.error("Error updating goal:", err);
    return res.status(500).json({ message: "Server error" });
  }
};

export const deleteGoal = async (req: Request, res: Response) => {
  try {
    const uid = req.user?.uid;
    const goalId = req.params.id;

    const deleted = await deleteGoalService(uid!, goalId);

    if (!deleted) return res.status(404).json({ message: "Goal not found" });

    return res.status(200).json({ message: "Goal deleted successfully" });
  } catch (err) {
    console.error("Error deleting goal:", err);
    return res.status(500).json({ message: "Server error" });
  }
};