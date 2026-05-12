# SantéSynchro 🍏✨

**SantéSynchro** est une application mobile intelligente et multiplateforme dédiée au suivi nutritionnel et au bien-être global. Ce projet a été réalisé dans le cadre d'un **Projet de Fin d'Études (PFE)** chez *Loomens Technologies*.

L'application permet aux utilisateurs de gérer leur alimentation, leur activité physique et leur sommeil de manière centralisée, avec une approche axée sur la confidentialité grâce à une IA locale.

## 🚀 Fonctionnalités Clés

- **Authentification Sécurisée** : Connexion par Email/Mot de passe et Google OAuth 2.0 (Firebase Auth).
- **Suivi Nutritionnel Intelligent** :
  - Ajout manuel de repas avec calcul automatique des macronutriments.
  - Scan de codes-barres via l'API **Open Food Facts**.
  - **Reconnaissance de repas par IA** : Analyse d'images locale utilisant **Ollama** et le modèle **LLaVA**.
- **Gestion des Objectifs** : Calcul personnalisé des besoins caloriques (BMR/TDEE) selon les objectifs (perte de poids, maintien, prise de masse).
- **Suivi Santé** : Intégration de **Health Connect** pour synchroniser les pas et le sommeil.
- **Tableau de Bord Admin** : Interface Web pour la supervision des KPIs et la gestion des utilisateurs.

## 🛠️ Stack Technique

### Frontend Mobile
- **Framework** : Flutter 3.x
- **Langage** : Dart
- **Base de données locale** : Hive

### Dashboard Admin
- **Framework** : React + Vite
- **Langage** : TypeScript
- **Graphiques** : Recharts

### Backend
- **Environnement** : Node.js + Express
- **Langage** : TypeScript
- **Base de données Cloud** : Firebase Firestore
- **Authentification** : Firebase Admin SDK
- **IA Locale** : Ollama (Modèle LLaVA)
- **Gestion des médias** : Cloudinary

## 📦 Installation

### Backend
```bash
cd backend
npm install
npm run dev
```

### Dashboard Admin
```bash
cd admin-dashboard
npm install
npm run dev
```

### Frontend Mobile
```bash
cd frontend
flutter pub get
flutter run
```

## 📝 Auteur
- **Amira Haj Boubaker Rais** - *Étudiante en Licence Informatique (Génie Logiciel)*

---
*Projet réalisé pour l'Institut Supérieur de l'Informatique de Médenine (ISIMED).*
