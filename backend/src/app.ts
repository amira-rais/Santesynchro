import express from "express";
import cors from "cors";
import authRoutes from "./routes/auth.routes";
import mealsRoutes from "./routes/meals.routes";
import goalsRoutes from "./routes/goals.routes";
import forgotPasswordRoutes from "./routes/forgot_password.routes";

const app = express();

app.use(cors());
app.use(express.json());

app.get("/health", (req, res) => {
  res.json({ status: "ok" });
});

// Register routes
app.use("/auth", authRoutes);
app.use("/meals", mealsRoutes);
app.use("/goals", goalsRoutes);
app.use("/password", forgotPasswordRoutes);

export default app;