class Budget {
  final int? budgetId;
  final int userId;
  final int? categoryId;
  final String name;
  final double amount;
  final String periodType;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isRecurring;
  final double alertThreshold;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;

  Budget({
    this.budgetId,
    required this.userId,
    this.categoryId,
    required this.name,
    required this.amount,
    required this.periodType,
    required this.startDate,
    this.endDate,
    this.isRecurring = false,
    this.alertThreshold = 80.0,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'budget_id': budgetId,
      'user_id': userId,
      'category_id': categoryId,
      'name': name,
      'amount': amount,
      'period_type': periodType,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_recurring': isRecurring ? 1 : 0,
      'alert_threshold': alertThreshold,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      budgetId: map['budget_id'],
      userId: map['user_id'],
      categoryId: map['category_id'],
      name: map['name'],
      amount: map['amount'],
      periodType: map['period_type'],
      startDate: DateTime.parse(map['start_date']),
      endDate: map['end_date'] != null ? DateTime.parse(map['end_date']) : null,
      isRecurring: map['is_recurring'] == 1,
      alertThreshold: map['alert_threshold'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt:
          map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      isActive: map['is_active'] == 1,
    );
  }
}
