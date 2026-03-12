// lib/models/meal.dart
class Meal {
  final String id;
  final String name;
  final int quantity;
  final int? calories;
  final DateTime? date;

  Meal({
    required this.id,
    required this.name,
    required this.quantity,
    this.calories,
    this.date,
  });

  Meal copyWith({
    String? id,
    String? name,
    int? quantity,
    int? calories,
    DateTime? date,
  }) {
    return Meal(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      calories: calories ?? this.calories,
      date: date ?? this.date,
    );
  }

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      id: json['id'].toString(),
      name: json['name'],
      quantity: json['quantity'],
      calories: json['calories'],
      date: json['date'] != null ? DateTime.tryParse(json['date']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'calories': calories,
    'date': date?.toIso8601String(),
  };
}