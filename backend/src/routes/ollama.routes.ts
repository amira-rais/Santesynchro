import { Router } from 'express';
import multer from 'multer';
import { analyzeImageLocal } from '../controllers/image.controller';
import { requireAuth } from '../middleware/requireAuth';

const router = Router();
const upload = multer({ 
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 50 * 1024 * 1024 // 50MB limit for images
  }
});

// All ollama routes require authentication
router.use(requireAuth);

router.post('/analyze-image', (req, res, next) => {
  upload.single('image')(req, res, (err) => {
    if (err instanceof multer.MulterError) {
      return res.status(400).json({ error: `Multer error: ${err.message}` });
    } else if (err) {
      return res.status(400).json({ error: `Upload error: ${err.message}` });
    }
    next();
  });
}, analyzeImageLocal);

export default router;
