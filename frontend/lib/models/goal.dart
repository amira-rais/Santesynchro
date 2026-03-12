// lib/models/goal.dart

class Goal {
  final String? id;
  final String type;
  final double target;
  final String unit;
  final String? createdAt;
  final String? startDate;
  final String? endDate;

  Goal({
    this.id,
    required this.type,
    required this.target,
    required this.unit,
    this.createdAt,
    this.startDate,
    this.endDate,
  });

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'],
      type: json['type'],
      target: (json['target'] as num).toDouble(),
      unit: json['unit'],
      createdAt: json['createdAt'],
      startDate: json['startDate'],
      endDate: json['endDate'],
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'type': type,
    'target': target,
    'unit': unit,
    if (createdAt != null) 'createdAt': createdAt,
    if (startDate != null) 'startDate': startDate,
    if (endDate != null) 'endDate': endDate,
  };
}
