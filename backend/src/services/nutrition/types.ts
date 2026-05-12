export interface ImageRecognitionResult {
  labels: string[];
}

export interface IImageRecognitionProvider {
  recognize(imageBuffer: Buffer): Promise<ImageRecognitionResult>;
}
