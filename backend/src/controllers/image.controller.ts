import { Request, Response } from 'express';
import { OllamaService } from '../services/ollama.service';

export const analyzeImageLocal = async (req: Request, res: Response): Promise<void> => {
  try {
    if (!req.file) {
      console.warn('No file uploaded');
      res.status(400).json({ error: 'No image file provided. Please upload an image.' });
      return;
    }

    console.log(`File received: ${req.file.originalname}, size: ${req.file.size} bytes`);

    // Convert the image buffer to a base64 string
    const base64Image = req.file.buffer.toString('base64');
    console.log(`Base64 string length: ${base64Image.length}`);

    // Call the Ollama Service
    const aiResult = await OllamaService.analyzeFood(base64Image);

    res.status(200).json(aiResult);
  } catch (error: any) {
    console.error('analyzeImageLocal Error:', error.message);
    console.error('Full error:', error);
    res.status(500).json({ error: error.message || 'Internal Server Error' });
  }
};
