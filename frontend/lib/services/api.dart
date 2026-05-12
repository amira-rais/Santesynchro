// lib/services/api.dart
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// En dev USB avec `adb reverse`, BASE_URL = 127.0.0.1
/// En Wi‑Fi, lance avec: flutter run --dart-define=API_BASE=http://192.168.x.x:4000
/// En dev local: 127.0.0.1
/// En Wi-Fi: passer --dart-define=API_BASE=http://192.168.x.x:4000
const String BASE_URL = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://127.0.0.1:4000',
);

/// Service pour communiquer avec l'API backend
/// Gère les requêtes HTTP pour l'authentification, les repas et les objectifs
class Api {
  /// Génère les headers avec le token Firebase pour l'authentification
  /// Tous les appels API incluent le token Bearer pour sécuriser les requêtes
  static Future<Map<String, String>> _headers() async {
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // ============================================
  // Authentification
  // ============================================

  /// Récupère le profil de l'utilisateur actuellement connecté
  /// Vérifie que le token Firebase est valide
  static Future<Map<String, dynamic>> me() async {
    final h = await _headers();
    final r = await http.get(Uri.parse('$BASE_URL/auth/me'), headers: h);
    if (r.statusCode != 200) throw Exception('auth/me ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Met à jour le profil de l'utilisateur
  static Future<void> updateProfile(Map<String, dynamic> body) async {
    final h = await _headers();
    final r = await http.put(Uri.parse('$BASE_URL/auth/me'), headers: h, body: jsonEncode(body));
    if (r.statusCode != 200) throw Exception('PUT /auth/me ${r.statusCode}: ${r.body}');
  }

  /// Supprime le compte de l'utilisateur et ses données associées
  static Future<void> deleteAccount() async {
    final h = await _headers();
    final r = await http.delete(Uri.parse('$BASE_URL/auth/me'), headers: h);
    if (r.statusCode != 200) throw Exception('DELETE /auth/me ${r.statusCode}: ${r.body}');
  }

  // ============================================
  // Repas (Meals)
  // ============================================

  /// Récupère la liste de tous les repas de l'utilisateur
  static Future<List<dynamic>> getMeals() async {
    final h = await _headers();
    final r = await http.get(Uri.parse('$BASE_URL/meals'), headers: h);
    if (r.statusCode != 200) throw Exception('GET /meals ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body) as List<dynamic>;
  }

  /// Ajoute un nouveau repas
  /// Paramètres: name, type (breakfast/lunch/dinner/snack), quantity, unit, nutrition
  static Future<Map<String, dynamic>> addMeal(Map<String, dynamic> body) async {
    final h = await _headers();
    final r = await http.post(Uri.parse('$BASE_URL/meals'), headers: h, body: jsonEncode(body));
    if (r.statusCode != 201) throw Exception('POST /meals ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Met à jour un repas existant par son ID
  /// Peut modifier: name, type, quantity, unit
  static Future<Map<String, dynamic>> updateMeal(String id, Map<String, dynamic> updates) async {
    final h = await _headers();
    final r = await http.put(Uri.parse('$BASE_URL/meals/$id'), headers: h, body: jsonEncode(updates));
    if (r.statusCode != 200) throw Exception('PUT /meals/$id ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Supprime un repas par son ID
  static Future<void> deleteMeal(String id) async {
    final h = await _headers();
    final r = await http.delete(Uri.parse('$BASE_URL/meals/$id'), headers: h);
    if (r.statusCode != 200) throw Exception('DELETE /meals/$id ${r.statusCode}: ${r.body}');
  }

  // ============================================
  // Objectifs (Goals)
  // ============================================

  /// Récupère la liste de tous les objectifs de l'utilisateur
  static Future<List<dynamic>> getGoals() async {
    final h = await _headers();
    final r = await http.get(Uri.parse('$BASE_URL/goals'), headers: h);
    if (r.statusCode != 200) throw Exception('GET /goals ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body) as List<dynamic>;
  }

  /// Ajoute un nouvel objectif
  static Future<Map<String, dynamic>> addGoal(Map<String, dynamic> body) async {
    final h = await _headers();
    final r = await http.post(Uri.parse('$BASE_URL/goals'), headers: h, body: jsonEncode(body));
    if (r.statusCode != 201) throw Exception('POST /goals ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Met à jour un objectif existant par son ID
  static Future<Map<String, dynamic>> updateGoal(String id, Map<String, dynamic> updates) async {
    final h = await _headers();
    final r = await http.put(Uri.parse('$BASE_URL/goals/$id'), headers: h, body: jsonEncode(updates));
    if (r.statusCode != 200) throw Exception('PUT /goals/$id ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Supprime un objectif par son ID
  static Future<void> deleteGoal(String id) async {
    final h = await _headers();
    final r = await http.delete(Uri.parse('$BASE_URL/goals/$id'), headers: h);
    if (r.statusCode != 200) throw Exception('DELETE /goals/$id ${r.statusCode}: ${r.body}');
  }

  // ============================================
  // Réinitialisation de Mot de Passe (Forgot Password)
  // ============================================

  /// Demande l'envoi d'un code OTP par e-mail
  static Future<void> sendOTP(String email) async {
    final r = await http.post(
      Uri.parse('$BASE_URL/password/forgot'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (r.statusCode != 200) {
      throw Exception(jsonDecode(r.body)['message'] ?? 'Erreur lors de l\'envoi du code');
    }
  }

  /// Vérifie le code OTP saisi par l'utilisateur
  static Future<void> verifyOTP(String email, String otp) async {
    final r = await http.post(
      Uri.parse('$BASE_URL/password/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'otp': otp,
      }),
    );
    if (r.statusCode != 200) {
      throw Exception(jsonDecode(r.body)['message'] ?? 'Code invalide ou expiré');
    }
  }

  /// Réinitialise le mot de passe après vérification de l'OTP
  static Future<void> finalizePasswordReset(String email, String newPassword) async {
    final r = await http.post(
      Uri.parse('$BASE_URL/password/reset'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'newPassword': newPassword,
      }),
    );
    if (r.statusCode != 200) {
      throw Exception(jsonDecode(r.body)['message'] ?? 'Erreur lors de la réinitialisation');
    }
  }

  // ============================================
  // Hydratation (Water)
  // ============================================

  /// Ajoute une consommation d'eau (par défaut 250ml)
  static Future<Map<String, dynamic>> addWater({int amount = 250}) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$BASE_URL/water'),
      headers: h,
      body: jsonEncode({'amount': amount}),
    );
    if (r.statusCode != 201) throw Exception('POST /water ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Récupère l'hydratation d'aujourd'hui
  static Future<Map<String, dynamic>> getWaterToday() async {
    final h = await _headers();
    final r = await http.get(Uri.parse('$BASE_URL/water/today'), headers: h);
    if (r.statusCode != 200) throw Exception('GET /water/today ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ============================================
  // Données vitales (Vitals - Steps, Sleep)
  // ============================================

  /// Met à jour les vitaux d'aujourd'hui
  static Future<Map<String, dynamic>> updateVitals(Map<String, dynamic> body) async {
    final h = await _headers();
    final r = await http.put(
      Uri.parse('$BASE_URL/vitals'),
      headers: h,
      body: jsonEncode(body),
    );
    if (r.statusCode != 200) throw Exception('PUT /vitals ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Récupère les vitaux d'aujourd'hui
  static Future<Map<String, dynamic>> getVitalsToday() async {
    final h = await _headers();
    final r = await http.get(Uri.parse('$BASE_URL/vitals/today'), headers: h);
    if (r.statusCode != 200) throw Exception('GET /vitals/today ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ============================================
  // Dashboard
  // ============================================

  /// Récupère toutes les données agrégées pour le tableau de bord
  static Future<Map<String, dynamic>> getDashboard() async {
    final h = await _headers();
    final r = await http.get(Uri.parse('$BASE_URL/dashboard'), headers: h);
    if (r.statusCode != 200) throw Exception('GET /dashboard ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ============================================
  // Insights & Progression
  // ============================================

  /// Récupère les données de progression sur les 7 derniers jours
  static Future<List<dynamic>> getProgressionData() async {
    final h = await _headers();
    final r = await http.get(Uri.parse('$BASE_URL/insights/progression'), headers: h);
    if (r.statusCode != 200) throw Exception('GET /insights/progression ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body) as List<dynamic>;
  }

  // ============================================
  // Nutrition (Open Food Facts)
  // ============================================

  /// Cherche des produits alimentaires par nom.
  /// ⚠️ Résultats approximatifs, non garantis.
  static Future<List<dynamic>> searchProducts(String query) async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$BASE_URL/nutrition/search?q=${Uri.encodeQueryComponent(query)}'),
      headers: h,
    );
    if (r.statusCode != 200) throw Exception('GET /nutrition/search ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body) as List<dynamic>;
  }

  /// Récupère un produit par son code-barres.
  /// ✅ Résultat officiel et fiable.
  static Future<Map<String, dynamic>?> getProductByBarcode(String barcode) async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$BASE_URL/nutrition/barcode/$barcode'),
      headers: h,
    );
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) throw Exception('GET /nutrition/barcode/$barcode ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Recognizes a food from an image and returns a list of labels (tags).
  /// Uses the Clarifai API on the backend.
  static Future<Map<String, dynamic>> analyzeFoodImage(File imageFile) async {
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();
    final uri = Uri.parse('$BASE_URL/nutrition/analyze-image');

    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath(
      'image',
      imageFile.path,
      contentType: MediaType('image', 'jpeg'),
    ));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('POST /nutrition/analyze-image ${response.statusCode}: ${response.body}');
    }
  }

  /// Recognizes a food from an image using local Ollama (LLaVA) API.
  /// Returns a structured JSON: { food, estimated_calories, ingredients, description }
  static Future<Map<String, dynamic>> analyzeFoodImageOllama(File imageFile) async {
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();
    final uri = Uri.parse('$BASE_URL/ollama/analyze-image');

    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath(
      'image',
      imageFile.path,
      contentType: MediaType('image', 'jpeg'),
    ));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('POST /ollama/analyze-image ${response.statusCode}: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> searchNutritionByLabel(String query) async {
    final response = await http.get(
      Uri.parse('$BASE_URL/nutrition/search-nutrition?q=${Uri.encodeComponent(query)}'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('GET /nutrition/search-nutrition ${response.statusCode}: ${response.body}');
    }
  }
}

