import app from "./app";
import dotenv from "dotenv";

dotenv.config();

const PORT = process.env.PORT || 4000;
const HOST = "0.0.0.0";

app.listen(PORT, HOST, () => {
  console.log(`API running at http://${HOST}:${PORT}`);
});