import nodemailer from 'nodemailer';
import dotenv from 'dotenv';

dotenv.config();

/**
 * Configuration du transporteur Nodemailer.
 * Charge les informations SMTP depuis le fichier .env.
 */
export const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || 'smtp.gmail.com',
  port: parseInt(process.env.SMTP_PORT || '587'),
  secure: process.env.SMTP_SECURE === 'true', // true pour le port 465, false pour les autres ports
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

/**
 * Fonction utilitaire pour envoyer un e-mail avec un code OTP.
 */
export const sendOTPEmail = async (to: string, otp: string) => {
  const mailOptions = {
    from: `"SantéSynchro" <${process.env.SMTP_USER}>`,
    to,
    subject: 'Votre code de vérification SantéSynchro',
    html: `
      <div style="font-family: sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 8px;">
        <h2 style="color: #10B981; text-align: center;">Réinitialisation du mot de passe</h2>
        <p>Bonjour,</p>
        <p>Vous avez demandé la réinitialisation de votre mot de passe pour votre compte SantéSynchro.</p>
        <p>Veuillez utiliser le code de vérification suivant :</p>
        <div style="text-align: center; margin: 30px 0;">
          <span style="display: inline-block; padding: 15px 25px; font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #10B981; background-color: #f0fdf4; border: 2px dashed #10B981; border-radius: 8px;">
            ${otp}
          </span>
        </div>
        <p>Ce code est valable pendant <b>15 minutes</b>. S'il expire, vous devrez refaire une demande.</p>
        <p>Si vous n'êtes pas à l'origine de cette demande, vous pouvez ignorer cet e-mail en toute sécurité.</p>
        <hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 30px 0;">
        <p style="font-size: 12px; color: #64748b; text-align: center;">
          &copy; ${new Date().getFullYear()} SantéSynchro. Tous droits réservés.
        </p>
      </div>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log(`Email envoyé avec succès à ${to}`);
  } catch (error) {
    console.error('Erreur lors de l\'envoi de l\'email :', error);
    throw new Error('Could not send OTP email');
  }
};
