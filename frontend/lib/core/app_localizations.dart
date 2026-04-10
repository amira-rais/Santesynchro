import 'dart:convert';
import 'package:flutter/material.dart';

/// Centralisateur de toutes les traductions de l'application
/// Utilisation: AppLocalizations.of(context).translate('clé')
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  /// Traductions regroupées par langue (fr / en)
  static final Map<String, Map<String, String>> _localizedValues = {
    'fr': {
      // Common
      'continue': 'Continuer',
      'back': 'Retour',
      'loading': 'Chargement...',
      'error': 'Erreur',
      'success': 'Succès',
      'save': 'Enregistrer',
      'cancel': 'Annuler',
      'done': 'Terminé',
      'edit': 'Modifier',
      'delete': 'Supprimer',
      
      // Login Screen
      'login_title': 'Connexion',
      'login_subtitle': 'Gestion complète de votre santé',
      'email_label': 'Adresse e-mail',
      'email_hint': 'votre@email.com',
      'password_label': 'Mot de passe',
      'password_hint': '••••••••',
      'forgot_password': 'Mot de passe oublié ?',
      'login_button': 'Se connecter',
      'google_login': 'Continuer avec Google',
      'no_account': 'Vous n\'avez pas de compte ?',
      'signup_link': 'Inscrivez-vous',
      'email_required': 'E-mail requis',
      'email_invalid': 'E-mail invalide',
      'password_min': '7 caractères minimum',
      'login_failed': 'Échec de connexion',
      
      // Signup Screen
      'signup_title': 'Inscription',
      'signup_header': 'Créer un compte',
      'confirm_password': 'Confirmer le mot de passe',
      'confirm_password_label': 'Confirmez le mot de passe',
      'passwords_dont_match': 'Les mots de passe ne correspondent pas',
      'already_have_account': 'Déjà un compte ?',
      'login_link': 'Se connecter',
      'signup_failed': 'Inscription échouée',
      'signup_subtitle': 'Commencez votre suivi de santé',
      'name_label': 'Nom complet',
      'name_hint': 'Jean Dupont',
      'name_required': 'Nom requis',
      
      // Goals Screen
      'goals_title': 'Vos Objectifs',
      'gender_title': 'Choisissez votre\nsexe',
      'gender_subtitle': 'Cela sera utilisé pour calibrer\nvotre plan personnalisé.',
      'birth_title': 'Quand etes-vous\nne(e) ?',
      'birth_subtitle': 'Cela sera pris en compte lors du calcul\nde vos objectifs nutritionnels quotidiens.',
      'female': 'Femme',
      'male': 'Homme',
      'goals_header': 'Quel est votre\nobjectif principal ?',
      'goals_subtitle': 'Sélectionnez les domaines sur lesquels vous souhaitez vous concentrer.',
      'weight_loss': 'Perte de poids',
      'weight_loss_desc': 'Réduire la masse grasse et habitudes durables',
      'muscle_gain': 'Prise de muscle',
      'muscle_gain_desc': 'Augmenter la force et le volume physique',
      'lifestyle': 'Vie Saine',
      'lifestyle_desc': 'Énergie et bien-être mental global',
      'skip': 'Passer',
      
      // Profile Setup
      'fine_tune_goal': 'Affinez votre objectif',
      'adjust_metrics': 'Ajustez vos mesures pour personnaliser votre plan nutritionnel.',
      'height': 'Taille',
      'weight_current': 'Poids Actuel',
      'weight_target': 'Poids Cible',
      'health_diet_prefs': 'Santé & Préférences Alimentaires',
      'select_all_apply': 'Sélectionnez tout ce qui s\'applique à vous.',
      'conditions_label': 'CONDITIONS',
      'goal_summary': 'Objectif : ',
      'reduce_weight': 'Réduire le poids de ',
      'gain_weight': 'Prendre du poids de ',
      'by': ' de ',
      
      // Goal Dialogs
      'how_many_kg': 'Combien de kilos voulez-vous perdre ?',
      'choose_pace': 'Choisissez votre rythme',
      'pace_slow': 'Lent',
      'pace_steady': 'Régulier',
      'pace_fast': 'Rapide',
      'pace_desc': 'Un rythme régulier est plus durable pour la santé.',
      'daily_forecast': 'Prévisions Quotidiennes',
      'forecast_desc': 'Basé sur votre rythme ',
      'daily_deficit': 'DÉFICIT QUOTIDIEN',
      'goal_date': 'DATE ESTIMÉE L\'OBJECTIF',
      
      // Profile Summary
      'profile_summary_title': 'Résumé du Profil',
      'premium_member': 'Membre Premium SantéSynchro',
      'my_plan': 'Mon Plan',
      'daily_targets': 'Objectifs Quotidiens',
      'energy': 'ÉNERGIE',
      'hydration': 'HYDRATATION',
      'macronutrients': 'MACRONUTRIMENTS',
      'carbs': 'Glucides',
      'protein': 'Protéines',
      'fats': 'Lipides',
      'health_diet': 'Santé & Régime',

      // Settings
      'settings_title': 'Réglages',
      'language': 'Langue',
      'logout': 'Se déconnecter',
      'delete_account': 'Supprimer le compte',
      'delete_confirm_desc': 'Êtes-vous sûr ? Cette action supprimera définitivement vos données.',
      
      // Verify Email / Reset
      'verify_email_title': 'Vérification email',
      'reset_title': 'Réinitialisation',
      'enter_code': 'Saisissez le code',
      'verify_email_header': 'Vérifiez votre email',
      'code_sent_to': 'Un code à 6 chiffres a été envoyé à\n',
      'link_sent_to': 'Un lien de vérification a été envoyé à\n',
      'forgot_password_title': 'Réinitialisation',
      'forgot_password_header': 'Mot de passe oublié ?',
      'forgot_password_desc': 'Saisissez votre e-mail pour recevoir un lien de réinitialisation sécurisé.',
      'send_link': 'Envoyer le lien',
      'reset_password_title': 'Nouveau mot de passe',
      'new_password_label': 'Nouveau mot de passe',
      'signup_button': "S'inscrire",
      'verify_code_button': 'Vérifier le code',
      'i_verified': "J'ai vérifié mon email",
      'resend_in': 'Renvoyer dans ',
      'resend_code': 'Renvoyer le code',
      'resend_link': 'Renvoyer le lien',
      'back_to_login': 'Retour à la connexion',
      'otp_resent': 'Nouveau code OTP envoyé !',
      'link_resent': 'Lien de vérification renvoyé !',
      'health_info_title': 'Informations de Santé',
      'health_info_subtitle': 'Sélectionnez vos conditions ou allergies',
      'pathologies_label': 'PATHOLOGIES / CONDITIONS',
      'allergies_label': 'ALLERGIES',
      'finish': 'Terminer',

      // Dashboard / Home Screen
      'dashboard_title': 'Tableau de Bord',
      'daily_nutrition': 'Nutrition du Jour',
      'calories_left': 'Kcal Restantes',
      'consumed': 'Consommé',
      'goal': 'Objectif',
      'ai_insights': 'Conseils IA',
      'quick_actions': 'Actions Rapides',
      'log_meal': 'Repas',
      'add_water': 'Ajouter 250ml',
      'log_activity': 'Activité',
      'todays_vitals': 'Vitaux du Jour',
      'steps': 'Pas',
      'sleep': 'Sommeil',
      'water': 'Eau',
      'hours': 'h',
      'minutes': 'm',
      'water_added': 'Eau ajoutée avec succès !',
    },
    'en': {
      // Common
      'continue': 'Continue',
      'back': 'Back',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'save': 'Save',
      'cancel': 'Cancel',
      'done': 'Done',
      'edit': 'Edit',
      'delete': 'Delete',
      
      // Login Screen
      'login_title': 'Login',
      'login_subtitle': 'Complete management of your health',
      'email_label': 'Email Address',
      'email_hint': 'your@email.com',
      'password_label': 'Password',
      'password_hint': '••••••••',
      'forgot_password': 'Forgot Password?',
      'login_button': 'Log In',
      'google_login': 'Continue with Google',
      'no_account': 'Don\'t have an account?',
      'signup_link': 'Sign Up',
      'email_required': 'Email required',
      'email_invalid': 'Invalid email',
      'password_min': '7 characters minimum',
      'login_failed': 'Login failed',
      
      // Signup Screen
      'signup_title': 'Sign Up',
      'signup_header': 'Create an Account',
      'confirm_password': 'Confirm Password',
      'confirm_password_label': 'Confirm your password',
      'passwords_dont_match': 'Passwords do not match',
      'already_have_account': 'Already have an account?',
      'login_link': 'Log In',
      'signup_failed': 'Signup failed',
      'signup_subtitle': 'Start your health tracking',
      'name_label': 'Full Name',
      'name_hint': 'John Doe',
      'name_required': 'Name required',
      
      // Goals Screen
      'goals_title': 'Your Goals',
      'gender_title': 'Choose your\nGender',
      'gender_subtitle': 'This will be used to calibrate your\ncustom plan.',
      'birth_title': 'When were you\nborn?',
      'birth_subtitle': 'This will be taken into account when\ncalculating your daily nutrition goals.',
      'female': 'Female',
      'male': 'Male',
      'goals_header': 'What is your\nmain goal?',
      'goals_subtitle': 'Select the areas you want to focus on.',
      'weight_loss': 'Weight Loss',
      'weight_loss_desc': 'Reduce body fat and sustainable habits',
      'muscle_gain': 'Muscle Gain',
      'muscle_gain_desc': 'Increase physical strength and volume',
      'lifestyle': 'Healthy Lifestyle',
      'lifestyle_desc': 'Energy and overall mental well-being',
      'skip': 'Skip',
      
      // Profile Setup
      'fine_tune_goal': 'Fine-tune your goal',
      'adjust_metrics': 'Adjust your metrics to help us personalize your daily nutrition plan.',
      'height': 'Height',
      'weight_current': 'Current Weight',
      'weight_target': 'Target Weight',
      'health_diet_prefs': 'Health & Dietary Preferences',
      'select_all_apply': 'Select any that apply to you.',
      'conditions_label': 'CONDITIONS',
      'goal_summary': 'Goal: ',
      'reduce_weight': 'Reduce body weight by ',
      'gain_weight': 'Gain body weight by ',
      'by': ' by ',
      
      // Goal Dialogs
      'how_many_kg': 'How many kilograms do you want to lose?',
      'choose_pace': 'Choose your preferred pace',
      'pace_slow': 'Slow',
      'pace_steady': 'Steady',
      'pace_fast': 'Fast',
      'pace_desc': 'A steady pace is generally the most sustainable for long-term health.',
      'daily_forecast': 'Daily Forecast',
      'forecast_desc': 'Based on your pace ',
      'daily_deficit': 'DAILY DEFICIT',
      'goal_date': 'ESTIMATED GOAL DATE',
      
      // Profile Summary
      'profile_summary_title': 'Profile Summary',
      'premium_member': 'SantéSynchro Premium Member',
      'my_plan': 'My Plan',
      'daily_targets': 'Daily Targets',
      'energy': 'ENERGY',
      'hydration': 'HYDRATION',
      'macronutrients': 'MACRONUTRIENTS',
      'carbs': 'Carbs',
      'protein': 'Protein',
      'fats': 'Fats',
      'health_diet': 'Health & Diet',

      // Settings
      'settings_title': 'Settings',
      'language': 'Language',
      'logout': 'Log Out',
      'delete_account': 'Delete Account',
      'delete_confirm_desc': 'Are you sure? This action will permanently delete your data.',
      
      // Verify Email / Reset
      'verify_email_title': 'Email Verification',
      'reset_title': 'Reset Password',
      'enter_code': 'Enter the code',
      'verify_email_header': 'Verify your email',
      'code_sent_to': 'A 6-digit code has been sent to\n',
      'link_sent_to': 'A verification link has been sent to\n',
      'forgot_password_title': 'Reset Password',
      'forgot_password_header': 'Forgot Password?',
      'forgot_password_desc': 'Enter your email to receive a secure reset link.',
      'send_link': 'Send Link',
      'reset_password_title': 'New Password',
      'new_password_label': 'New Password',
      'signup_button': 'Sign Up',
      'verify_code_button': 'Verify Code',
      'i_verified': 'I have verified my email',
      'resend_in': 'Resend in ',
      'resend_code': 'Resend code',
      'resend_link': 'Resend link',
      'back_to_login': 'Back to Login',
      'otp_resent': 'New OTP code sent!',
      'link_resent': 'Verification link resent!',
      'health_info_title': 'Health Information',
      'health_info_subtitle': 'Select any conditions or allergies',
      'pathologies_label': 'HEALTH CONDITIONS',
      'allergies_label': 'ALLERGIES',
      'finish': 'Finish',

      // Dashboard / Home Screen
      'dashboard_title': 'Dashboard',
      'daily_nutrition': 'Daily Nutrition',
      'calories_left': 'Kcal Left',
      'consumed': 'Consumed',
      'goal': 'Goal',
      'ai_insights': 'AI Insights',
      'quick_actions': 'Quick Actions',
      'log_meal': 'Log Meal',
      'add_water': 'Add 250ml',
      'log_activity': 'Activity',
      'todays_vitals': 'Today\'s Vitals',
      'steps': 'Steps',
      'sleep': 'Sleep',
      'water': 'Water',
      'hours': 'h',
      'minutes': 'm',
      'water_added': 'Water added successfully!',
    },
  };

  /// Récupère la traduction pour une clé donnée
  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }

  /// Délégué pour charger les localisations
  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'fr'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
