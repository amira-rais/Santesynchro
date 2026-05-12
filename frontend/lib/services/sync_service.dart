import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/models/health_data.dart';
import 'package:frontend/services/api.dart';
import 'package:frontend/services/hive_service.dart';

/// Service de synchronisation Offline-First.
///
/// Stratégie :
///  1. Vérifier la connectivité réseau via connectivity_plus.
///  2. Confirmer l'accès internet réel via un ping au backend.
///  3. Envoyer les enregistrements non-synchros (isSynced == false) vers l'API.
///  4. Utiliser [date] comme clé unique → évite les doublons dans Firestore.
///  5. Marquer isSynced = true uniquement après un succès HTTP 200/201.
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;

  /// Démarre la surveillance de la connexion réseau.
  void start() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      (results) async {
        final hasNetwork = results.any(
          (r) => r == ConnectivityResult.mobile || r == ConnectivityResult.wifi,
        );
        if (hasNetwork) {
          await syncNow();
        }
      },
    );

    // Tenter une synchronisation initiale au démarrage
    syncNow();
  }

  /// Lance une synchronisation manuelle (peut être appelé depuis l'UI).
  Future<void> syncNow() async {
    if (_isSyncing) return; // Évite les appels concurrents
    _isSyncing = true;

    try {
      // ── 1. Vérifier la connectivité réseau ──────────────────────────────
      final results = await Connectivity().checkConnectivity();
      final hasNetwork = results.any(
        (r) => r == ConnectivityResult.mobile || r == ConnectivityResult.wifi,
      );
      if (!hasNetwork) {
        print('[SyncService] Pas de réseau. Sync annulée.');
        return;
      }

      // ── 2. Ping backend pour confirmer internet réel ────────────────────
      final isReachable = await _pingBackend();
      if (!isReachable) {
        print('[SyncService] Backend injoignable. Sync annulée.');
        return;
      }

      // ── 3. Récupérer les enregistrements en attente ─────────────────────
      final pending = HiveService.getPendingSync();
      if (pending.isEmpty) {
        print('[SyncService] Rien à synchroniser.');
        return;
      }

      print('[SyncService] ${pending.length} enregistrement(s) à synchroniser...');

      // ── 4. Synchroniser chaque jour ─────────────────────────────────────
      for (final summary in pending) {
        await _syncSummary(summary);
      }
    } catch (e) {
      print('[SyncService] Erreur inattendue: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Envoie un DailySummary vers le backend.
  Future<void> _syncSummary(DailySummary summary) async {
    try {
      await Api.updateVitals({
        'date': summary.date,            // Clé unique → évite les doublons
        'steps': summary.steps,
        'sleepDuration': summary.sleepMinutes,
        'sleepStart': summary.sleepStart?.toIso8601String(),
        'sleepEnd': summary.sleepEnd?.toIso8601String(),
        'sleepSource': summary.sleepSource,
        'sleepConfidence': summary.sleepConfidence,
      });

      // ── 5. Marquer comme synchro uniquement après succès ─────────────────
      summary.isSynced = true;
      await HiveService.saveSummary(summary);
      print('[SyncService] ✓ Synchronisé : ${summary.date} (${summary.steps} pas, ${summary.sleepMinutes} min de sommeil)');
    } catch (e) {
      // On conserve isSynced = false → sera réessayé à la prochaine sync
      print('[SyncService] ✗ Échec pour ${summary.date}: $e');
    }
  }

  /// Vérifie que le backend est joignable (test réel, pas juste le réseau).
  Future<bool> _pingBackend() async {
    try {
      final uri = Uri.parse('$BASE_URL/health'); // endpoint léger ou /auth/me simplifié
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 5));
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  void stop() {
    _connectivitySub?.cancel();
  }
}
