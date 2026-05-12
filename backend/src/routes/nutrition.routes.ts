import { Router } from "express";
import multer from "multer";
import { searchProducts, getByBarcode, analyzeImage, searchNutrition } from "../controllers/nutrition.controller";
import { requireAuth } from "../middleware/requireAuth";

const router = Router();
const upload = multer({ storage: multer.memoryStorage() });

// Toutes les routes de nutrition nécessitent une authentification
router.use(requireAuth);

router.get("/search", searchProducts);
router.get("/barcode/:barcode", getByBarcode);
router.get("/search-nutrition", searchNutrition);
router.post("/analyze-image", upload.single("image"), analyzeImage);

export default router;
