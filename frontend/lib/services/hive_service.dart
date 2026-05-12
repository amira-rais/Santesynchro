import 'package:hive_flutter/hive_flutter.dart';
import 'package:frontend/models/health_data.dart';

/// Service d'initialisation et d'accès au stockage local Hive.
/// Doit être initialisé une seule fois dans main() avant runApp().
class HiveService {
  static const String _boxName = 'health_box';
  static const String _metaBoxName = 'meta_box';

  static Box<DailySummary>? _healthBox;
  static Box<dynamic>? _metaBox;

  /// Initialise Hive et ouvre les boxes nécessaires.
  /// Appeler dans main() : await HiveService.init();
  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(DailySummaryAdapter());
    }
    _healthBox = await Hive.openBox<DailySummary>(_boxName);
    _metaBox = await Hive.openBox(_metaBoxName);
  }

  static Box<DailySummary> get healthBox {
    if (_healthBox == null || !_healthBox!.isOpen) {
      throw StateError('HiveService non initialisé. Appelez HiveService.init() dans main().');
    }
    return _healthBox!;
  }

  static Box<dynamic> get metaBox {
    if (_metaBox == null || !_metaBox!.isOpen) {
      throw StateError('HiveService non initialisé. Appelez HiveService.init() dans main().');
    }
    return _metaBox!;
  }

  // ─────────────────────────────────────
  // Helpers DailySummary
  // ─────────────────────────────────────

  /// Retourne le résumé du jour ou crée un nouveau si absent.
  static DailySummary getOrCreateToday() {
    final key = _todayKey();
    if (!healthBox.containsKey(key)) {
      final summary = DailySummary(date: key);
      healthBox.put(key, summary);
      return summary;
    }
    return healthBox.get(key)!;
  }

  /// Sauvegarde (met à jour) un résumé journalier.
  static Future<void> saveSummary(DailySummary summary) async {
    await healthBox.put(summary.date, summary);
  }

  /// Retourne tous les résumés non encore synchronisés avec le backend.
  static List<DailySummary> getPendingSync() {
    return healthBox.values.where((s) => !s.isSynced).toList();
  }

  // ─────────────────────────────────────
  // Helpers Meta (valeurs scalaires)
  // ─────────────────────────────────────

  /// Lit la dernière valeur brute du capteur podomètre.
  static int getLastSensorValue() => metaBox.get('lastSensorValue', defaultValue: 0) as int;

  /// Sauvegarde la dernière valeur brute du capteur.
  static Future<void> saveLastSensorValue(int value) => metaBox.put('lastSensorValue', value);

  /// Clé de la journée en cours (ex: "2026-04-10")
  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
