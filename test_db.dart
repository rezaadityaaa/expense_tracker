import 'lib/services/database_service.dart';
import 'lib/models/expense.dart';

void main() async {
  print('Testing SQLite Database Connection...');

  final dbService = DatabaseService();

  try {
    // Test 1: Get Categories
    print('\n1. Testing Categories...');
    final categories = await dbService.getCategories();
    print('Found ${categories.length} categories:');
    for (var category in categories) {
      print('- ${category.name} (${category.icon})');
    }

    // Test 2: Insert Expense
    print('\n2. Testing Insert Expense...');
    final testExpense = Expense(
      userId: 1,
      categoryId: categories.first.categoryId!,
      amount: 50000.0,
      description: 'Test pengeluaran SQLite',
      expenseDate: DateTime.now(),
      createdAt: DateTime.now(),
    );

    final expenseId = await dbService.insertExpense(testExpense);
    print('Expense inserted with ID: $expenseId');

    // Test 3: Get Expenses
    print('\n3. Testing Get Expenses...');
    final expenses = await dbService.getExpensesByUser(1);
    print('Found ${expenses.length} expenses for user 1:');
    for (var expense in expenses) {
      print('- ${expense.description}: Rp ${expense.amount}');
    }

    // Test 4: Create New Expense for Update Test
    print('\n4. Testing Create New Expense for Update...');
    final updateExpense = Expense(
      expenseId: expenses.isNotEmpty ? expenses.first.expenseId : null,
      userId: 1,
      categoryId: categories.first.categoryId!,
      amount: 75000.0,
      description: 'Updated test expense',
      expenseDate: DateTime.now(),
      createdAt: DateTime.now(),
    );

    if (expenses.isNotEmpty) {
      await dbService.updateExpense(updateExpense);
      print('Expense updated successfully');
    }

    // Test 5: Delete Expense (soft delete)
    print('\n5. Testing Delete Expense...');
    if (expenses.isNotEmpty) {
      await dbService.deleteExpense(expenses.first.expenseId!);
      print('Expense deleted successfully');

      final remainingExpenses = await dbService.getExpensesByUser(1);
      print('Remaining expenses: ${remainingExpenses.length}');
    }

    print(
        '\n✅ All database tests passed! SQLite connection is working properly.');
  } catch (e) {
    print('\n❌ Database test failed: $e');
  }
}
