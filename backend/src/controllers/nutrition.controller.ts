import { Request, Response } from "express";
import { OpenFoodFactsProvider } from "../services/nutrition/open_food_facts.provider";
import { GeminiProvider } from "../services/nutrition/gemini.provider";
import { UsdaProvider } from "../services/nutrition/usda.provider";

const offProvider = new OpenFoodFactsProvider();
const visionProvider = new GeminiProvider();
const usdaProvider = new UsdaProvider();

export const searchProducts = async (req: Request, res: Response) => {
  try {
    const query = req.query.q as string;
    if (!query) {
      return res.status(400).json({ message: "Search query 'q' is required" });
    }

    // Utiliser USDA pour la recherche textuelle (idéal pour les ingrédients génériques)
    const usdaResults = await usdaProvider.searchFood(query);
    
    // Mapper les résultats USDA au format NutritionProduct attendu par le frontend
    const products = usdaResults.map(u => ({
      id: u.fdcId.toString(),
      name: u.description,
      brand: u.brandOwner || "USDA",
      image: null,
      unit: "g",
      nutrition: {
        calories: u.nutrients.calories,
        proteins: u.nutrients.proteins,
        carbs: u.nutrients.carbs,
        fats: u.nutrients.fats,
        source: "usda"
      }
    }));

    return res.status(200).json(products);
  } catch (error) {
    console.error("Error searching products:", error);
    return res.status(500).json({ message: "Server error" });
  }
};

export const getByBarcode = async (req: Request, res: Response) => {
  try {
    const { barcode } = req.params;
    if (!barcode) {
      return res.status(400).json({ message: "Barcode is required" });
    }

    const product = await offProvider.getByBarcode(barcode as string);
    if (!product) {
      return res.status(404).json({ message: "Product not found" });
    }

    return res.status(200).json(product);
  } catch (error) {
    console.error("Error fetching product by barcode:", error);
    return res.status(500).json({ message: "Server error" });
  }
};

export const analyzeImage = async (req: Request, res: Response) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: "No image file provided" });
    }

    const result = await visionProvider.recognize(req.file.buffer);
    if (!result || !result.labels || result.labels.length === 0) {
      return res.status(404).json({ message: "Aucun aliment détecté dans l'image." });
    }

    return res.status(200).json(result);
  } catch (error: any) {
    console.error("Error analyzing image:", error);
    return res.status(500).json({ 
      message: "Erreur lors de l'analyse de l'image. Veuillez réessayer.",
      error: error.message 
    });
  }
};

export const searchNutrition = async (req: Request, res: Response) => {
  try {
    const query = req.query.q as string;
    if (!query) {
      return res.status(400).json({ message: "Query parameter 'q' is required" });
    }

    const results = await usdaProvider.searchFood(query);
    const bestMatch = usdaProvider.findBestMatch(results, query);

    if (!bestMatch) {
      return res.status(404).json({ message: "No nutritional data found for this label" });
    }

    return res.status(200).json(bestMatch);
  } catch (error) {
    console.error("Error searching nutrition:", error);
    return res.status(500).json({ message: "Server error" });
  }
};
