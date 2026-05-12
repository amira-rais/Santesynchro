import 'dart:async';
import 'package:frontend/models/health_data.dart';
import 'package:frontend/services/hive_service.dart';

/// Service de détection semi-automatique du sommeil.
///
/// Algorithme :
///  1. Fenêtre de nuit : 21h00 → 08h00.
///  2. Si aucun pas depuis 30 min et on est dans la fenêtre → début potentiel du sommeil.
///  3. Vérification anti-faux-positif : si des pas sont détectés entre 23h et 02h → annulation.
///  4. Premier mouvement après 05h → fin du sommeil.
///  5. Durée minimale : 3h (180 min). Seuil "valide" : 5h (300 min).
///  6. Score de confiance calculé (0–100) en fin de cycle.
class SleepService {
  static final SleepService _instance = SleepService._internal();
  factory SleepService() => _instance;
  SleepService._internal();

  // ── Fenêtres horaires ────────────────────────────────────────────────────
  static const int _windowStartHour = 21; // 21h00
  static const int _windowEndHour = 8;    // 08h00
  static const int _inactivityThresholdMin = 30; // inactivité → début sommeil
  static const int _falsePositiveStartHour = 23; // 23h00
  static const int _falsePositiveEndHour = 2;    // 02h00
  static const int _wakeUpAfterHour = 5;          // réveil attendu après 05h
  static const int _minSleepMinutes = 180;         // 3 heures minimum
  static const int _validSleepMinutes = 300;       // 5 heures = sommeil valide

  // ── État interne ──────────────────────────────────────────────────────────
  DateTime? _potentialSleepStart;
  bool _falsePositiveDetected = false;
  int _stepsAtWindowEntry = 0;
  int _lastCheckedSteps = 0;

  Timer? _checkTimer;

  /// Broadcast stream : émet chaque mise à jour de l'objet DailySummary.
  final _controller = StreamController<DailySummary>.broadcast();
  Stream<DailySummary> get sleepStream => _controller.stream;

  /// Démarre le service : vérifie toutes les 5 minutes.
  void start() {
    _reset();
    _checkTimer = Timer.periodic(const Duration(minutes: 5), (_) => _check());
    // Vérifier immédiatement au démarrage
    _check();
  }

  /// Appelé par StepService à chaque nouveau comptage (pour détecter la fin du sommeil).
  void onNewSteps(int totalSteps) {
    final now = DateTime.now();

    // ── Détection faux positif (23h–02h) ─────────────────────────────────
    if (_isInFalsePositiveWindow(now) && _potentialSleepStart != null) {
      final stepsDelta = totalSteps - _lastCheckedSteps;
      if (stepsDelta > 10) {
        // Mouvement significatif dans la fenêtre critique → annuler
        _falsePositiveDetected = true;
        _potentialSleepStart = null;
        print('[SleepService] Faux positif détecté : mouvement entre 23h-2h.');
      }
    }
    _lastCheckedSteps = totalSteps;

    // ── Détection réveil (premier mouvement après 05h) ────────────────────
    if (_potentialSleepStart != null && !_falsePositiveDetected) {
      if (now.hour >= _wakeUpAfterHour && totalSteps > _stepsAtWindowEntry + 20) {
        _confirmSleep(totalSteps);
      }
    }
  }

  /// Vérification périodique (toutes les 5 minutes).
  void _check() {
    final now = DateTime.now();
    if (!_isInWindow(now)) {
      // Hors de la fenêtre de nuit : reset si nécessaire
      if (now.hour == _windowEndHour + 1) _reset(); // Reset à 09h
      return;
    }

    // Dans la fenêtre de nuit (21h → 08h)
    final summary = HiveService.getOrCreateToday();
    final currentSteps = summary.steps;

    if (_potentialSleepStart == null && !_falsePositiveDetected) {
      // Première entrée dans la fenêtre
      _stepsAtWindowEntry = currentSteps;
      _lastCheckedSteps = currentSteps;
    }

    // Vérifier l'inactivité (pas de pas depuis _inactivityThresholdMin)
    if (_potentialSleepStart == null && !_falsePositiveDetected) {
      final stepsDelta = currentSteps - _stepsAtWindowEntry;
      if (stepsDelta == 0) {
        // Inactivité depuis l'entrée dans la fenêtre
        final inactiveSince = now.difference(_getWindowStartTime(now));
        if (inactiveSince.inMinutes >= _inactivityThresholdMin) {
          _potentialSleepStart = now.subtract(inactiveSince);
          print('[SleepService] Début de sommeil potentiel : $_potentialSleepStart');
        }
      } else {
        // Mouvement détecté → repousser l'entrée dans la fenêtre
        _stepsAtWindowEntry = currentSteps;
      }
    }
  }

  /// Confirme et enregistre le sommeil dans Hive.
  void _confirmSleep(int currentSteps) {
    final sleepEnd = DateTime.now();
    final start = _potentialSleepStart!;
    final duration = sleepEnd.difference(start).inMinutes;

    if (duration < _minSleepMinutes) {
      print('[SleepService] Sommeil trop court ($duration min < 3h). Ignoré.');
      _reset();
      return;
    }

    final confidence = _calculateConfidence(duration, sleepEnd);

    final summary = HiveService.getOrCreateToday();
    summary.sleepMinutes = duration;
    summary.sleepStart = start;
    summary.sleepEnd = sleepEnd;
    summary.sleepSource = 'auto';
    summary.sleepConfidence = confidence;
    summary.isSynced = false;
    HiveService.saveSummary(summary);

    _controller.add(summary);
    print('[SleepService] Sommeil enregistré : $duration min, confiance : $confidence%');
    _reset();
  }

  // ── Calcul du score de confiance (0–100) ─────────────────────────────────
  /// Basé sur : durée, respect de la fenêtre horaire, absence de faux positifs.
  int _calculateConfidence(int durationMin, DateTime sleepEnd) {
    int score = 0;

    // Durée (max 50 pts)
    if (durationMin >= _validSleepMinutes) {
      score += 50;
    } else if (durationMin >= _minSleepMinutes) {
      score += (durationMin - _minSleepMinutes) * 50 ~/ (_validSleepMinutes - _minSleepMinutes);
    }

    // Réveil dans la bonne plage (05h–10h) : +20 pts
    if (sleepEnd.hour >= 5 && sleepEnd.hour <= 10) score += 20;

    // Pas de faux positif détecté : +20 pts
    if (!_falsePositiveDetected) score += 20;

    // Durée valide (>= 5h) : +10 pts bonus
    if (durationMin >= _validSleepMinutes) score += 10;

    return score.clamp(0, 100);
  }

  /// Permet à l'utilisateur de corriger manuellement le sommeil.
  Future<void> setManual(DateTime start, DateTime end) async {
    final duration = end.difference(start).inMinutes;
    final summary = HiveService.getOrCreateToday();
    summary.sleepStart = start;
    summary.sleepEnd = end;
    summary.sleepMinutes = duration;
    summary.sleepSource = 'manual';
    summary.sleepConfidence = 100; // Saisie manuelle = confiance max
    summary.isSynced = false;
    await HiveService.saveSummary(summary);
    _controller.add(summary);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  bool _isInWindow(DateTime t) {
    return t.hour >= _windowStartHour || t.hour < _windowEndHour;
  }

  bool _isInFalsePositiveWindow(DateTime t) {
    return t.hour >= _falsePositiveStartHour || t.hour < _falsePositiveEndHour;
  }

  DateTime _getWindowStartTime(DateTime now) {
    if (now.hour < _windowEndHour) {
      // On est après minuit
      return DateTime(now.year, now.month, now.day - 1, _windowStartHour);
    }
    return DateTime(now.year, now.month, now.day, _windowStartHour);
  }

  void _reset() {
    _potentialSleepStart = null;
    _falsePositiveDetected = false;
    _stepsAtWindowEntry = 0;
    _lastCheckedSteps = 0;
  }

  void stop() {
    _checkTimer?.cancel();
    _controller.close();
  }
}
