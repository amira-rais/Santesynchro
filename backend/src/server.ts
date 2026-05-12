import dotenv from "dotenv";
dotenv.config();
console.log("GEMINI_API_KEY =", process.env.GEMINI_API_KEY);

import app from "./app";

const PORT = parseInt(process.env.PORT || "4000", 10);
const HOST = "0.0.0.0";

app.listen(PORT, HOST, () => {
  console.log(`API running at http://${HOST}:${PORT}`);
});