class Expense {
  final int? expenseId;
  final int userId;
  final int categoryId;
  final double amount;
  final String description;
  final DateTime expenseDate;
  final String paymentMethod;
  final String? location;
  final String? receiptUrl;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;

  Expense({
    this.expenseId,
    required this.userId,
    required this.categoryId,
    required this.amount,
    required this.description,
    required this.expenseDate,
    this.paymentMethod = 'cash',
    this.location,
    this.receiptUrl,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'expense_id': expenseId,
      'user_id': userId,
      'category_id': categoryId,
      'amount': amount,
      'description': description,
      'expense_date': expenseDate.toIso8601String(),
      'payment_method': paymentMethod,
      'location': location,
      'receipt_url': receiptUrl,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      expenseId: map['expense_id'],
      userId: map['user_id'],
      categoryId: map['category_id'],
      amount: map['amount'],
      description: map['description'],
      expenseDate: DateTime.parse(map['expense_date']),
      paymentMethod: map['payment_method'],
      location: map['location'],
      receiptUrl: map['receipt_url'],
      notes: map['notes'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt:
          map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      isDeleted: map['is_deleted'] == 1,
    );
  }
}
