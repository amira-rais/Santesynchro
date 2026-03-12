## 📱 SantéSynchro Frontend - Documentation du code

### Vue d'ensemble
Cette application Flutter gère un journal personnel de santé avec :
- 👤 Authentification Firebase (email/password + Google Sign-In)
- 🍽️ Suivi des repas (petit-déjeuner, déjeuner, dîner, snacks)
- 🌙 Mode clair/sombre avec persistance

---

## 📂 Structure du projet

```
lib/
├── main.dart                    # Point d'entrée, configuration de l'app
├── core/
│   └── theme_provider.dart     # Gestion du thème (clair/sombre)
├── screens/
│   ├── login_screen.dart       # Écran de connexion
│   ├── signup_screen.dart      # Écran d'inscription
│   ├── meals_screen.dart       # Écran principal (liste des repas)
│   ├── add_meal_screen.dart    # Formulaire pour ajouter un repas
│   └── edit_meal_screen.dart   # Formulaire pour modifier un repas
└── services/
    ├── api.dart                # Client HTTP pour l'API backend
    └── user_repo.dart          # Gestion du profil utilisateur
```

---

## 🎯 Fichiers clés expliqués

### `lib/main.dart`
- Lance l'application et initialise Firebase
- Charge les préférences de thème (mode clair/sombre)
- Configure les routes de navigation :
  - `/login` → Connexion
  - `/signup` → Inscription
  - `/meals` → Écran principal

### `lib/core/theme_provider.dart`
**Singleton pattern** - Une seule instance pour toute l'app
- `isDarkMode` : État du mode sombre
- `init()` : Charge la préférence sauvegardée au démarrage
- `toggleDarkMode()` : Bascule et persiste le choix
- `lightTheme` / `darkTheme` : Définissent les styles visuels

### `lib/screens/login_screen.dart`
- Email + mot de passe OU Google Sign-In
- **Œil toggle** pour afficher/masquer le mot de passe
- **Bouton mode sombre** en haut à droite
- Validation email et mot de passe

### `lib/screens/signup_screen.dart`
- Création de compte avec email, nom, mot de passe
- Confirmation du mot de passe
- **Œil toggle** sur les deux champs mot de passe
- Lien pour retourner à la connexion

### `lib/screens/meals_screen.dart`
- **Liste principale** de tous les repas
- **Cartes colorées** avec icônes par type de repas
- Appui simple → Modifier le repas
- Appui long → Supprimer le repas
- **FAB (+)** en bas à droite → Ajouter un repas
- **Bouton mode sombre** dans l'AppBar

### `lib/screens/add_meal_screen.dart`
- **Sélection visuelle** du type (icônes + boutons colorés)
- Nom du repas
- Quantité + Unité
- Enregistre dans la base de données

### `lib/screens/edit_meal_screen.dart`
- Même interface que l'ajout
- Pré-remplissage avec les données existantes
- Affiche la date de création
- Mise à jour des données

### `lib/services/api.dart`
- **Base URL** : `http://127.0.0.1:4000`
- `_headers()` : Ajoute le token Firebase à chaque requête
- Méthodes disponibles :
  - `me()` : Récupère le profil utilisateur
  - `getMeals()` : Liste tous les repas
  - `addMeal()` : Crée un repas
  - `updateMeal()` : Modifie un repas
  - `deleteMeal()` : Supprime un repas

---

## 🔀 Flux de l'application

```
Login/Signup
    ↓
Authentification Firebase
    ↓
Meals Screen (Liste des repas)
    ├→ Appui simple : Edit Meal Screen
    ├→ Appui long : Supprimer
    └→ FAB : Add Meal Screen
```

---

## 🎨 Système de couleurs

- **Couleur primaire** : Vert menthe (#10B981)
- **Types de repas** :
  - 🌅 Petit-déjeuner (breakfast) : Orange
  - 🍽️ Déjeuner (lunch) : Vert
  - 🌙 Dîner (dinner) : Violet
  - 🍰 Snack : Rouge

---

## 🌙 Mode sombre

**Persistance** : Utilise `shared_preferences`
- Sauvegardé dans les préférences locales
- Restauré au redémarrage de l'app
- **Toggle** disponible dans tous les écrans (AppBar)

---

## ⚡ Points d'amélioration possibles

- [ ] Ajouter des statistiques nutritionnelles (calories, protéines...)
- [ ] Intégrer la base de données Open Food Facts (OFF)
- [ ] Notifications/reminders pour les repas
- [ ] Graphiques de progression
- [ ] Synchronisation cloud

---

## 🚀 Installation et utilisation

```bash
# Installer les dépendances
flutter pub get

# Lancer l'app
flutter run

# Lancer avec un serveur backend spécifique
flutter run --dart-define=API_BASE=http://192.168.x.x:4000
```

---

## 📝 Notes importantes

- **Aucune modification du backend** 🔒
- **Tous les commentaires expliquent le code** sans changer les fonctionnalités
- **Firebase Auth** gère l'authentification
- **API REST** communique avec le backend Node.js

---

**Version** : 1.0.0  
**Framework** : Flutter 3.10.7+  
**Dernière mise à jour** : 19 Février 2026
