// services/export_service.dart
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/expense.dart';
import '../models/category.dart';

class ExportService {
  static Future<String> exportExpensesToCSV(
    List<Expense> expenses,
    List<Category> categories,
  ) async {
    try {
      // Buat header CSV
      List<List<dynamic>> csvData = [
        [
          'ID',
          'Tanggal',
          'Waktu',
          'Kategori',
          'Deskripsi',
          'Jumlah (Rp)',
          'Metode Pembayaran',
          'Lokasi',
          'Catatan',
        ]
      ];

      // Create category map for lookup
      final categoryMap = {for (var cat in categories) cat.categoryId: cat};

      // Tambahkan data expenses
      for (var expense in expenses) {
        final category = categoryMap[expense.categoryId];
        csvData.add([
          expense.expenseId ?? '',
          DateFormat('dd/MM/yyyy').format(expense.expenseDate),
          DateFormat('HH:mm').format(expense.createdAt),
          category?.name ?? 'Unknown',
          expense.description,
          expense.amount,
          expense.paymentMethod,
          expense.location ?? '',
          expense.notes ?? '',
        ]);
      }

      // Convert to CSV string
      String csvString = const ListToCsvConverter().convert(csvData);

      // Get directory untuk menyimpan file
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'pengeluaran_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${directory.path}/$fileName');

      // Write file
      await file.writeAsString(csvString);

      return file.path;
    } catch (e) {
      throw Exception('Gagal mengexport data: $e');
    }
  }

  static Future<Map<String, dynamic>> getExpenseSummary(
    List<Expense> expenses,
    List<Category> categories,
  ) async {
    if (expenses.isEmpty) {
      return {
        'totalExpenses': 0.0,
        'totalTransactions': 0,
        'averagePerDay': 0.0,
        'categoryBreakdown': <Map<String, dynamic>>[],
        'dateRange': 'Tidak ada data',
      };
    }

    final totalExpenses =
        expenses.fold<double>(0, (sum, expense) => sum + expense.amount);
    final totalTransactions = expenses.length;

    // Calculate date range
    final sortedDates = expenses.map((e) => e.expenseDate).toList()..sort();
    final dateRange =
        '${DateFormat('dd/MM/yyyy').format(sortedDates.first)} - ${DateFormat('dd/MM/yyyy').format(sortedDates.last)}';

    // Calculate average per day
    final daysDifference =
        sortedDates.last.difference(sortedDates.first).inDays + 1;
    final averagePerDay = totalExpenses / daysDifference;

    // Category breakdown
    final categoryMap = {for (var cat in categories) cat.categoryId: cat};
    final Map<int, double> categoryTotals = {};

    for (var expense in expenses) {
      categoryTotals[expense.categoryId] =
          (categoryTotals[expense.categoryId] ?? 0) + expense.amount;
    }

    final categoryBreakdown = categoryTotals.entries.map((entry) {
      final category = categoryMap[entry.key];
      return {
        'name': category?.name ?? 'Unknown',
        'icon': category?.icon ?? '❓',
        'amount': entry.value,
        'percentage': (entry.value / totalExpenses) * 100,
      };
    }).toList();

    // Sort by amount descending
    categoryBreakdown.sort(
        (a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

    return {
      'totalExpenses': totalExpenses,
      'totalTransactions': totalTransactions,
      'averagePerDay': averagePerDay,
      'categoryBreakdown': categoryBreakdown,
      'dateRange': dateRange,
    };
  }
}
