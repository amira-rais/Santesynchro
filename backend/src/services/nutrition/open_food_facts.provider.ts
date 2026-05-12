import axios from "axios";
import { INutritionProvider, NutritionProduct } from "./nutrition_provider";
import { Nutrition } from "../../models/nutrition.model";

export class OpenFoodFactsProvider implements INutritionProvider {
  private readonly baseUrl = "https://world.openfoodfacts.org";
  private readonly userAgent = "SanteSynchro - Android - Version 1.0";

  async search(query: string): Promise<NutritionProduct[]> {
    try {
      const response = await axios.get(`${this.baseUrl}/cgi/search.pl`, {
        params: {
          search_terms: query,
          search_simple: 1,
          action: "process",
          fields: "id,product_name,nutriments,image_front_small_url,brands",
          json: 1,
          page_size: 20,
        },
        headers: {
          "User-Agent": this.userAgent,
        },
      });

      const products = response.data.products || [];
      return products.map((p: any) => this.mapToProduct(p));
    } catch (error) {
      console.error("OFF Search Error:", error);
      return [];
    }
  }

  async getByBarcode(barcode: string): Promise<NutritionProduct | null> {
    try {
      const response = await axios.get(`${this.baseUrl}/api/v2/product/${barcode}.json`, {
        params: {
          fields: "id,product_name,nutriments,image_front_small_url,brands",
        },
        headers: {
          "User-Agent": this.userAgent,
        },
      });

      if (response.data.status === 1 || response.data.product) {
        return this.mapToProduct(response.data.product);
      }
      return null;
    } catch (error) {
      console.error("OFF Barcode Error:", error);
      return null;
    }
  }

  private mapToProduct(p: any): NutritionProduct {
    const nutriments = p.nutriments || {};
    
    // Détection auto si c'est un liquide (OFF utilise _100ml pour les boissons)
    const isLiquid = nutriments["energy-kcal_100ml"] !== undefined || 
                     nutriments["portions_unit"] === "ml" ||
                     p.product_quantity_unit === "ml";
    
    const unit = isLiquid ? 'ml' : 'g';
    const suffix = isLiquid ? '_100ml' : '_100g';
    
    // Fallback logic for energy
    let kcal = nutriments[`energy-kcal${suffix}`] ?? nutriments["energy-kcal_100g"];
    if (kcal === undefined && (nutriments[`energy${suffix}`] || nutriments["energy_100g"])) {
      const e = nutriments[`energy${suffix}`] || nutriments["energy_100g"];
      kcal = Math.round(e / 4.184);
    }

    const nutrition: Nutrition = {
      calories: Math.round(kcal || 0),
      proteins: Number((nutriments[`proteins${suffix}`] || nutriments["proteins_100g"] || 0).toFixed(1)),
      carbs: Number((nutriments[`carbohydrates${suffix}`] || nutriments["carbohydrates_100g"] || 0).toFixed(1)),
      fats: Number((nutriments[`fat${suffix}`] || nutriments["fat_100g"] || 0).toFixed(1)),
      source: "open_food_facts",
    };

    return {
      id: p.id || p._id,
      name: p.product_name || "Produit inconnu",
      brand: p.brands,
      image: p.image_front_small_url,
      nutrition,
      unit,
    };
  }
}
