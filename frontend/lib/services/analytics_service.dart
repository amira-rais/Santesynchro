// lib/services/analytics_service.dart
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'api.dart';

/// Service pour tracker les sessions utilisateur.
/// Envoie la durée de chaque session au backend pour alimenter les KPIs admin.
class AnalyticsService {
  static DateTime? _sessionStart;

  /// Appelé quand l'app passe au premier plan (resumed).
  static void onAppResumed() {
    _sessionStart = DateTime.now();
  }

  /// Appelé quand l'app passe en arrière-plan (paused).
  /// Calcule la durée et l'envoie au backend.
  static Future<void> onAppPaused() async {
    if (_sessionStart == null) return;
    final end = DateTime.now();
    final duration = end.difference(_sessionStart!).inSeconds;
    _sessionStart = null;

    // On n'envoie que les sessions de plus de 5 secondes
    if (duration < 5) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await user.getIdToken();
      await http.post(
        Uri.parse('$BASE_URL/api/admin/sessions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'startedAt': _sessionStart?.toIso8601String() ??
              end.subtract(Duration(seconds: duration)).toIso8601String(),
          'endedAt': end.toIso8601String(),
          'durationSeconds': duration,
        }),
      );
    } catch (e) {
      // On ne veut pas crasher l'app pour un problème d'analytics
      print('[Analytics] Failed to record session: $e');
    }
  }
}
