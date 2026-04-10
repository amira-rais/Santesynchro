import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final Health _health = Health();

  final _types = [
    HealthDataType.STEPS,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
  ];

  /// Retourne true si Health Connect est installé et disponible sur cet appareil
  Future<bool> isAvailable() async {
    try {
      final status = await Health().getHealthConnectSdkStatus();
      return status == HealthConnectSdkStatus.sdkAvailable;
    } catch (_) {
      return false;
    }
  }

  /// Demande les permissions à l'utilisateur et retourne true si accordées
  Future<bool> authorize() async {
    // Vérification préalable : Health Connect disponible sur cet appareil ?
    final available = await isAvailable();
    if (!available) {
      print("Health Connect SDK non disponible.");
      return false;
    }

    // Demande la permission d'activité physique (requis sur Android Q+)
    await Permission.activityRecognition.request();

    try {
      // API compatible avec health 13.1.4
      await _health.configure();

      // Certains devices/providers ne supportent pas tous les types (ex: SLEEP_IN_BED).
      // On tente en mode dégradé pour éviter un faux "accès requis".
      final candidates = <List<HealthDataType>>[
        _types,
        [HealthDataType.STEPS, HealthDataType.SLEEP_ASLEEP],
        [HealthDataType.STEPS],
      ];

      for (final requestedTypes in candidates) {
        try {
          final alreadyGranted = await _health.hasPermissions(requestedTypes) ?? false;
          if (alreadyGranted) return true;
          final granted = await _health.requestAuthorization(requestedTypes);
          if (granted) return true;
        } catch (_) {
          // Try next fallback set.
        }
      }
      return false;
    } catch (e) {
      // Log l'erreur exacte pour le diagnostic (Infinix binding, etc.)
      print("Erreur d'autorisation Health Connect: $e");
      return false;
    }
  }

  /// Récupère les pas d'aujourd'hui (0 si erreur ou pas de données)
  Future<int> getTodaySteps() async {
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final steps = await _health.getTotalStepsInInterval(midnight, now);
      return steps ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Récupère le sommeil de la dernière nuit en minutes (0 si erreur)
  Future<int> getLastNightSleep() async {
    try {
      final now = DateTime.now();
      final yesterdayNoon = DateTime(now.year, now.month, now.day - 1, 12, 0);

      List<HealthDataPoint> healthData = [];
      try {
        healthData = await _health.getHealthDataFromTypes(
          types: [
            HealthDataType.SLEEP_ASLEEP,
            HealthDataType.SLEEP_AWAKE,
          ],
          startTime: yesterdayNoon,
          endTime: now,
        );
      } catch (_) {
        // Fallback minimal si un type sommeil n'est pas supporté sur l'appareil.
        healthData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.SLEEP_ASLEEP],
          startTime: yesterdayNoon,
          endTime: now,
        );
      }

      if (healthData.isEmpty) return 0;

      // Elimine les doublons éventuels avant agrégation.
      final normalized = Health().removeDuplicates(healthData);
      int totalMinutes = 0;
      for (var point in normalized) {
        if (point.type == HealthDataType.SLEEP_AWAKE) continue;
        totalMinutes += point.dateTo.difference(point.dateFrom).inMinutes;
      }
      return totalMinutes;
    } catch (_) {
      return 0;
    }
  }
}
