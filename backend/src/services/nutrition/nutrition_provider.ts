import { Nutrition } from "../../models/nutrition.model";

export interface NutritionProduct {
  id: string;
  name: string;
  nutrition: Nutrition;
  image?: string;
  brand?: string;
  unit?: string; // "g" ou "ml"
}

export interface INutritionProvider {
  search(query: string): Promise<NutritionProduct[]>;
  getByBarcode(barcode: string): Promise<NutritionProduct | null>;
}
