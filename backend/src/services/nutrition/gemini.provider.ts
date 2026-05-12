import axios from "axios";
import { IImageRecognitionProvider, ImageRecognitionResult } from "./types";
import dotenv from "dotenv";

dotenv.config();

export class GeminiProvider implements IImageRecognitionProvider {
  private readonly apiKey = process.env.GOOGLE_API_KEY;
  // Using v1beta for better compatibility with 1.5 models
  private readonly baseUrl = "https://generativelanguage.googleapis.com/v1beta/models";

  async recognize(imageBuffer: Buffer): Promise<ImageRecognitionResult> {
    if (!this.apiKey) {
      throw new Error("GOOGLE_API_KEY missing in .env");
    }

    // Try these models in order
    const models = ["gemini-1.5-flash", "gemini-1.5-pro"];
    let lastError: any;

    for (const modelName of models) {
      try {
        const url = `${this.baseUrl}/${modelName}:generateContent?key=${this.apiKey}`;
        
        const response = await axios.post(url, {
          contents: [
            {
              parts: [
                { text: "Identifie les aliments sur cette image. Retourne uniquement une liste séparée par des virgules des 3 noms d'aliments les plus probables en français (ex: 'Pomme Granny Smith, Pizza Margherita'). Aucun texte superflu." },
                {
                  inline_data: {
                    mime_type: "image/jpeg",
                    data: imageBuffer.toString("base64")
                  }
                }
              ]
            }
          ]
        }, {
          headers: { "Content-Type": "application/json" },
          timeout: 10000 // 10 seconds timeout
        });

        const text = response.data?.candidates?.[0]?.content?.parts?.[0]?.text;
        if (text) {
          const labels = text.split(",")
            .map((s: string) => s.trim())
            .filter((s: string) => s.length > 0);
          
          if (labels.length > 0) {
            return { labels };
          }
        }
      } catch (error: any) {
        lastError = error;
        const status = error.response?.status;
        const errorData = error.response?.data;
        console.warn(`Model ${modelName} failed (Status ${status}):`, JSON.stringify(errorData));
        
        // If 404, we try the next model
        if (status === 404) continue;
        
        // If other error (e.g. 403, 429), we stop here as it's likely a key/quota issue
        throw new Error(`IA Error (${status}): ${errorData?.error?.message || error.message}`);
      }
    }

    throw new Error("Aucun modèle Gemini n'a pu traiter l'image : " + (lastError?.message || "Erreur inconnue"));
  }
}
