// services/balance_reset_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';

class BalanceResetService {
  static final BalanceResetService _instance = BalanceResetService._internal();
  factory BalanceResetService() => _instance;
  BalanceResetService._internal();

  final DatabaseService _dbService = DatabaseService();

  /// Check and perform weekly balance reset if needed
  Future<Map<String, dynamic>> checkAndResetWeeklyBalance(
      double currentBalance, int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // Check if today is Monday (weekday = 1)
    if (now.weekday == 1) {
      // Get last reset date
      final lastResetDateString = prefs.getString('lastWeeklyResetDate');
      final lastResetDate = lastResetDateString != null
          ? DateTime.parse(lastResetDateString)
          : null;

      // Check if reset has been done this week
      final currentMondayDate = _getMondayOfCurrentWeek(now);

      if (lastResetDate == null || lastResetDate.isBefore(currentMondayDate)) {
        // Calculate remaining balance from last week
        final expenses = await _dbService.getExpensesByUser(userId);

        // Filter expenses from last week (until last Sunday)
        final lastSunday = currentMondayDate.subtract(const Duration(days: 1));
        final lastMondayStart = lastSunday.subtract(const Duration(days: 6));

        final lastWeekExpenses = expenses.where((expense) {
          return expense.expenseDate
                  .isAfter(lastMondayStart.subtract(const Duration(days: 1))) &&
              expense.expenseDate.isBefore(currentMondayDate);
        }).toList();

        final lastWeekTotalExpenses = lastWeekExpenses.fold<double>(
            0, (sum, expense) => sum + expense.amount);
        final remainingBalance = currentBalance - lastWeekTotalExpenses;
        final newBalance = remainingBalance >= 0 ? remainingBalance : 0.0;

        // Save new balance and reset date
        await prefs.setDouble('totalBalance', newBalance);
        await prefs.setString(
            'lastWeeklyResetDate', currentMondayDate.toIso8601String());

        // Save reset history
        await saveResetHistory(currentBalance, newBalance, 'weekly_reset');

        return {
          'wasReset': true,
          'previousBalance': currentBalance,
          'newBalance': newBalance,
          'lastWeekExpenses': lastWeekTotalExpenses,
        };
      }
    }

    return {
      'wasReset': false,
      'previousBalance': currentBalance,
      'newBalance': currentBalance,
    };
  }

  /// Perform manual/test reset
  Future<Map<String, dynamic>> performManualReset(
      double currentBalance, int userId) async {
    final expenses = await _dbService.getExpensesByUser(userId);
    final totalExpenses =
        expenses.fold<double>(0, (sum, expense) => sum + expense.amount);
    final remainingBalance = currentBalance - totalExpenses;
    final newBalance = remainingBalance >= 0 ? remainingBalance : 0.0;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('totalBalance', newBalance);
    await saveResetHistory(currentBalance, newBalance, 'manual_reset');

    return {
      'previousBalance': currentBalance,
      'newBalance': newBalance,
      'totalExpenses': totalExpenses,
    };
  }

  /// Save reset history
  Future<void> saveResetHistory(
      double previousBalance, double newBalance, String type) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final history = prefs.getStringList('resetHistory') ?? [];

    final historyEntry =
        '${now.toIso8601String()}|$previousBalance|$newBalance|$type';
    history.insert(0, historyEntry);

    // Keep only last 20 reset entries
    if (history.length > 20) {
      history.removeRange(20, history.length);
    }

    await prefs.setStringList('resetHistory', history);
  }

  /// Get reset history
  Future<List<Map<String, dynamic>>> getResetHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('resetHistory') ?? [];

    return history
        .map((entry) {
          final parts = entry.split('|');
          if (parts.length >= 4) {
            return {
              'date': DateTime.parse(parts[0]),
              'previousBalance': double.parse(parts[1]),
              'newBalance': double.parse(parts[2]),
              'type': parts[3],
            };
          }
          return <String, dynamic>{};
        })
        .where((item) => item.isNotEmpty)
        .toList();
  }

  /// Get Monday of current week
  DateTime _getMondayOfCurrentWeek(DateTime date) {
    final daysFromMonday = date.weekday - 1; // 0 = Monday, 1 = Tuesday, etc.
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: daysFromMonday));
  }

  /// Save balance history for adding balance
  Future<void> saveBalanceHistory(double amount, String type) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final history = prefs.getStringList('balanceHistory') ?? [];

    final historyEntry = '${now.toIso8601String()}|$amount|$type|add';
    history.insert(0, historyEntry);

    // Keep only last 50 entries
    if (history.length > 50) {
      history.removeRange(50, history.length);
    }

    await prefs.setStringList('balanceHistory', history);
  }

  /// Load current balance
  Future<double> loadBalance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('totalBalance') ?? 1000000.0;
  }

  /// Calculate remaining balance (total balance - current week expenses)
  Future<double> calculateRemainingBalance(int userId) async {
    final currentBalance = await loadBalance();
    final expenses = await _dbService.getExpensesByUser(userId);

    // Get current week range (Monday to today)
    final now = DateTime.now();
    final currentMondayDate = _getMondayOfCurrentWeek(now);

    // Filter expenses from current week (Monday until today)
    final currentWeekExpenses = expenses.where((expense) {
      return expense.expenseDate
              .isAfter(currentMondayDate.subtract(const Duration(days: 1))) &&
          expense.expenseDate.isBefore(now.add(const Duration(days: 1)));
    }).toList();

    final currentWeekTotalExpenses = currentWeekExpenses.fold<double>(
        0, (sum, expense) => sum + expense.amount);

    return currentBalance - currentWeekTotalExpenses;
  }

  /// Save current balance
  Future<void> saveBalance(double balance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('totalBalance', balance);
  }
}
