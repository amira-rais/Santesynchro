// lib/services/api.dart
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// En dev USB avec `adb reverse`, BASE_URL = 127.0.0.1
/// En Wi‑Fi, lance avec: flutter run --dart-define=API_BASE=http://192.168.x.x:4000
const String BASE_URL = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://127.0.0.1:4000',
);

class Api {
  static Future<Map<String, String>> _headers() async {
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // Auth (test /auth/me)
  static Future<Map<String, dynamic>> me() async {
    final h = await _headers();
    final r = await http.get(Uri.parse('$BASE_URL/auth/me'), headers: h);
    if (r.statusCode != 200) throw Exception('auth/me ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // Meals
  static Future<List<dynamic>> getMeals() async {
    final h = await _headers();
    final r = await http.get(Uri.parse('$BASE_URL/meals'), headers: h);
    if (r.statusCode != 200) throw Exception('GET /meals ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> addMeal(Map<String, dynamic> body) async {
    final h = await _headers();
    final r = await http.post(Uri.parse('$BASE_URL/meals'), headers: h, body: jsonEncode(body));
    if (r.statusCode != 201) throw Exception('POST /meals ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateMeal(String id, Map<String, dynamic> updates) async {
    final h = await _headers();
    final r = await http.put(Uri.parse('$BASE_URL/meals/$id'), headers: h, body: jsonEncode(updates));
    if (r.statusCode != 200) throw Exception('PUT /meals/$id ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<void> deleteMeal(String id) async {
    final h = await _headers();
    final r = await http.delete(Uri.parse('$BASE_URL/meals/$id'), headers: h);
    if (r.statusCode != 200) throw Exception('DELETE /meals/$id ${r.statusCode}: ${r.body}');
  }
}