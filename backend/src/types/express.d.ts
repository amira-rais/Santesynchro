import "express";

declare global {
  namespace Express {
    interface UserDecodedToken {
      uid: string;
      email?: string | null;
      name?: string | null;
      firebase?: { sign_in_provider?: string | null };
      // ajoute les champs que ton middleware attache réellement
    }
    interface Request {
      user?: UserDecodedToken;
    }
  }
}