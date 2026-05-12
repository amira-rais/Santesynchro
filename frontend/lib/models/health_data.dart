import 'package:hive/hive.dart';

/// Modèle pour stocker les données santé journalières localement dans Hive.
/// La [date] au format "YYYY-MM-DD" sert d'identifiant unique (clé dans la Box).
class DailySummary {
  /// Date au format ISO : "2026-04-10"
  final String date;

  /// Nombre de pas pour la journée
  int steps;

  /// Durée totale du sommeil en minutes
  int sleepMinutes;

  /// Heure de début du sommeil (null si non détecté)
  DateTime? sleepStart;

  /// Heure de fin du sommeil / réveil (null si non détecté)
  DateTime? sleepEnd;

  /// true si les données ont déjà été envoyées au backend avec succès
  bool isSynced;

  /// Source : "auto" (détection) ou "manual" (saisie utilisateur)
  String sleepSource;

  /// Score de confiance (0→100) pour le sommeil auto-détecté
  int sleepConfidence;

  /// Dernière valeur brute du capteur, pour calculer le delta au prochain démarrage
  int lastSensorStepValue;

  DailySummary({
    required this.date,
    this.steps = 0,
    this.sleepMinutes = 0,
    this.sleepStart,
    this.sleepEnd,
    this.isSynced = false,
    this.sleepSource = 'auto',
    this.sleepConfidence = 0,
    this.lastSensorStepValue = 0,
  });

  /// Formate le sommeil en "7h 30m"
  String get sleepFormatted {
    final h = sleepMinutes ~/ 60;
    final m = sleepMinutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  /// Sommeil ≥ 5h = "valide"
  bool get isSleepValid => sleepMinutes >= 300;

  /// Sommeil ≥ 3h = "minimal acceptable"
  bool get isSleepMinimal => sleepMinutes >= 180;
}

// ─────────────────────────────────────────────────────────────────────────────
// Adaptateur Hive manuel (évite build_runner / code generation)
// ─────────────────────────────────────────────────────────────────────────────
class DailySummaryAdapter extends TypeAdapter<DailySummary> {
  @override
  final int typeId = 0;

  @override
  DailySummary read(BinaryReader reader) {
    return DailySummary(
      date: reader.readString(),
      steps: reader.readInt(),
      sleepMinutes: reader.readInt(),
      sleepStart: reader.readBool() ? DateTime.fromMillisecondsSinceEpoch(reader.readInt()) : null,
      sleepEnd: reader.readBool() ? DateTime.fromMillisecondsSinceEpoch(reader.readInt()) : null,
      isSynced: reader.readBool(),
      sleepSource: reader.readString(),
      sleepConfidence: reader.readInt(),
      lastSensorStepValue: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, DailySummary obj) {
    writer.writeString(obj.date);
    writer.writeInt(obj.steps);
    writer.writeInt(obj.sleepMinutes);
    // sleepStart
    writer.writeBool(obj.sleepStart != null);
    if (obj.sleepStart != null) writer.writeInt(obj.sleepStart!.millisecondsSinceEpoch);
    // sleepEnd
    writer.writeBool(obj.sleepEnd != null);
    if (obj.sleepEnd != null) writer.writeInt(obj.sleepEnd!.millisecondsSinceEpoch);
    writer.writeBool(obj.isSynced);
    writer.writeString(obj.sleepSource);
    writer.writeInt(obj.sleepConfidence);
    writer.writeInt(obj.lastSensorStepValue);
  }
}
