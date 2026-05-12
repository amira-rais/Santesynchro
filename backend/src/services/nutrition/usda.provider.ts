import axios from "axios";
import dotenv from "dotenv";

dotenv.config();

export interface UsdaFoodResult {
  fdcId: number;
  description: string;
  brandOwner?: string;
  nutrients: {
    calories: number;
    proteins: number;
    carbs: number;
    fats: number;
  };
}

export class UsdaProvider {
  private readonly apiKey = process.env.USDA_API_KEY;
  private readonly baseUrl = "https://api.nal.usda.gov/fdc/v1";

  async searchFood(query: string): Promise<UsdaFoodResult[]> {
    if (!this.apiKey) {
      throw new Error("USDA_API_KEY missing in .env");
    }

    try {
      const response = await axios.get(
        `${this.baseUrl}/foods/search?query=${encodeURIComponent(query)}&api_key=${this.apiKey}&pageSize=5`
      );

      const foods = response.data.foods || [];
      return foods.map((f: any) => {
        const nutrients = f.foodNutrients || [];
        
        const getNutrient = (ids: number[]) => {
          const n = nutrients.find((element: any) => 
            ids.includes(element.nutrientId) || ids.includes(parseInt(element.nutrientNumber))
          );
          return n ? n.value : 0;
        };

        return {
          fdcId: f.fdcId,
          description: f.description,
          brandOwner: f.brandOwner,
          nutrients: {
            calories: getNutrient([1008, 2047, 2048]),
            proteins: getNutrient([1003]),
            carbs: getNutrient([1005, 1050]),
            fats: getNutrient([1004]),
          },
        };
      });
    } catch (error: any) {
      console.error("USDA Search Error:", error.response?.data || error.message);
      return [];
    }
  }

  findBestMatch(results: UsdaFoodResult[], query: string): UsdaFoodResult | null {
    if (results.length === 0) return null;
    const lowerQuery = query.toLowerCase();
    const match = results.find(f => f.description.toLowerCase().startsWith(lowerQuery));
    return match || results[0];
  }
}
