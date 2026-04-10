import express from "express";
import cors from "cors";
import authRoutes from "./routes/auth.routes";
import mealsRoutes from "./routes/meals.routes";
import goalsRoutes from "./routes/goals.routes";
import forgotPasswordRoutes from "./routes/forgot_password.routes";
import waterRoutes from "./routes/water.routes";
import vitalsRoutes from "./routes/vitals.routes";
import dashboardRoutes from "./routes/dashboard.routes";

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
app.use("/water", waterRoutes);
app.use("/vitals", vitalsRoutes);
app.use("/dashboard", dashboardRoutes);

export default app;