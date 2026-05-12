import axios from 'axios';

export class OllamaService {
  private static OLLAMA_URL = 'http://localhost:11434/api/generate';

  static async analyzeFood(base64Image: string): Promise<any> {
    const prompt = `You are a food recognition AI. Analyze the image and identify the main food items.
Return ONLY a valid JSON object with a single key "labels" containing an array of strings representing the detected food items (maximum 5 items).
Keep the labels concise and in French if possible.
Example: {"labels": ["Pomme", "Banane"]}`;

    try {
      const response = await axios.post(
        this.OLLAMA_URL,
        {
          model: 'llava',
          prompt: prompt,
          images: [base64Image],
          stream: false,
          format: 'json',
        },
        {
          timeout: 300000, // 5 minutes timeout (LLaVA can be slow, especially on first load or without a dedicated GPU)
        }
      );

      const responseText = response.data.response;
      return JSON.parse(responseText);
    } catch (error: any) {
      if (error.code === 'ECONNREFUSED') {
        throw new Error('Ollama is not running. Please start Ollama locally on port 11434.');
      }
      if (error.code === 'ECONNABORTED') {
        throw new Error('Ollama request timed out.');
      }
      console.error('Ollama Service Error:', error.message || error);
      throw new Error('Failed to analyze image with Ollama.');
    }
  }
}
