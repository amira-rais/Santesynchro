import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:frontend/services/hive_service.dart';

/// Service de comptage des pas en temps réel via le podomètre matériel.
///
/// Logique delta robuste :
///  - À chaque événement capteur, on calcule delta = nouvelleValeur − dernièreValeur.
///  - Si nouvValeur < dernièreValeur → le capteur a été réinitialisé (reboot) : delta = nouvelleValeur.
///  - Le delta est ajouté aux pas du jour stockés dans Hive.
///
/// Ainsi, même après un redémarrage du téléphone, le compteur repart correctement.
class StepService {
  static final StepService _instance = StepService._internal();
  factory StepService() => _instance;
  StepService._internal();

  StreamSubscription<StepCount>? _subscription;

  /// Nombre de pas du jour, mis à jour en temps réel.
  int todaySteps = 0;

  /// Broadcast stream : émet à chaque mise à jour du compteur.
  final _controller = StreamController<int>.broadcast();
  Stream<int> get stepStream => _controller.stream;

  /// Initialise le service : charge les pas depuis Hive et démarre le flux capteur.
  Future<void> init() async {
    // Charger les pas déjà enregistrés pour aujourd'hui
    final summary = HiveService.getOrCreateToday();
    todaySteps = summary.steps;
    _controller.add(todaySteps);

    // Demander la permission si nécessaire
    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) {
      print('[StepService] Permission d\'activité physique refusée.');
      return;
    }

    // Démarrer le flux podomètre
    _subscription = Pedometer.stepCountStream.listen(
      _onStep,
      onError: _onError,
      cancelOnError: false,
    );
  }

  /// Appelé à chaque nouvel événement capteur.
  void _onStep(StepCount event) async {
    final newSensorValue = event.steps;
    final lastSensorValue = HiveService.getLastSensorValue();

    // ── Logique delta (reboot-safe) ──────────────────────────────────────────
    int delta;
    if (newSensorValue >= lastSensorValue) {
      // Cas normal : capteur qui avance
      delta = newSensorValue - lastSensorValue;
    } else {
      // Cas reboot ou reset capteur : on prend la nouvelle valeur comme delta
      delta = newSensorValue;
    }

    // Limite de sécurité : ignorer les deltas aberrants (> 5000 pas d'un coup)
    if (delta > 5000) delta = 0;

    if (delta == 0 && newSensorValue == lastSensorValue) return; // Pas de changement

    todaySteps += delta;

    // Sauvegarder la nouvelle valeur brute et les pas du jour dans Hive
    await HiveService.saveLastSensorValue(newSensorValue);
    final summary = HiveService.getOrCreateToday();
    summary.steps = todaySteps;
    summary.isSynced = false; // Les nouvelles données doivent être re-synchros
    await HiveService.saveSummary(summary);

    // Notifier les écouteurs
    _controller.add(todaySteps);
  }

  void _onError(dynamic error) {
    print('[StepService] Erreur podomètre: $error');
  }

  /// Libère les ressources (à appeler dans dispose() du widget racine).
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}
