import 'expense.dart';
import 'money_type.dart';

class ExpenseWithCategory extends Expense {
  final String categoryName;

  ExpenseWithCategory({
    super.expenseId,
    required super.userId,
    required super.categoryId,
    required super.amount,
    required super.description,
    required super.expenseDate,
    super.paymentMethod = 'cash',
    super.moneyType = MoneyType.cash,
    super.location,
    super.receiptUrl,
    super.notes,
    required super.createdAt,
    super.updatedAt,
    super.isDeleted = false,
    required this.categoryName,
  });

  factory ExpenseWithCategory.fromMap(Map<String, dynamic> map) {
    return ExpenseWithCategory(
      expenseId: map['expense_id'],
      userId: map['user_id'],
      categoryId: map['category_id'],
      amount: map['amount'],
      description: map['description'],
      expenseDate: DateTime.parse(map['expense_date']),
      paymentMethod: map['payment_method'],
      moneyType: MoneyType.fromString(map['money_type'] ?? 'cash'),
      location: map['location'],
      receiptUrl: map['receipt_url'],
      notes: map['notes'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt:
          map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      isDeleted: map['is_deleted'] == 1,
      categoryName: map['category_name'] ?? 'Unknown',
    );
  }
}
