// pages/summary_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../models/money_type.dart';
import '../services/database_service.dart';
import 'add_expense_page.dart';
import 'balance_history_page.dart';

class BreakdownItem {
  final String type;
  final double amount;
  final double percentage;
  final String icon;
  final Color color;

  BreakdownItem({
    required this.type,
    required this.amount,
    required this.percentage,
    required this.icon,
    required this.color,
  });
}

class SummaryPage extends StatefulWidget {
  const SummaryPage({super.key});

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  final _dbService = DatabaseService();
  late Future<List<Expense>> _allExpenses;
  late Future<List<Category>> _categories;

  double _totalBalance = 0; // Saldo total default
  double _cashBalance = 0; // Cash balance default
  double _digitalBalance = 0; // Digital/Saldo balance default
  String _selectedPeriod = 'Bulanan';

  final int _currentUserId = 1;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _loadBalance();
    _checkAndResetWeeklyBalance(); // Cek reset mingguan
  }

  void _fetchData() {
    setState(() {
      _allExpenses = _dbService.getExpensesByUser(_currentUserId);
      _categories = _dbService.getCategories();
    });
  }

  Future<void> _loadBalance() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _totalBalance = prefs.getDouble('totalBalance') ?? 0;
      _cashBalance = prefs.getDouble('cashBalance') ?? 0;
      _digitalBalance = prefs.getDouble('digitalBalance') ?? 0;
    });
  }

  Future<void> _saveBalance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('totalBalance', _totalBalance);
    await prefs.setDouble('cashBalance', _cashBalance);
    await prefs.setDouble('digitalBalance', _digitalBalance);
  }

  void _showBalanceDialog() {
    final cashController = TextEditingController(text: _cashBalance.toString());
    final digitalController =
        TextEditingController(text: _digitalBalance.toString());
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.white,
        title: Text(
          'Edit Saldo Mingguan',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cash Balance Field
            TextField(
              controller: cashController,
              keyboardType: TextInputType.number,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                labelText: 'Cash Balance',
                labelStyle: TextStyle(
                  color:
                      isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                prefixText: '💵 Rp ',
                prefixStyle: TextStyle(
                  color: isDarkMode
                      ? Colors.green.shade300
                      : Colors.green.shade600,
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isDarkMode
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isDarkMode
                        ? Colors.green.shade300
                        : Colors.green.shade600,
                  ),
                ),
                filled: true,
                fillColor:
                    isDarkMode ? Colors.grey.shade700 : Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 16),
            // Digital Balance Field
            TextField(
              controller: digitalController,
              keyboardType: TextInputType.number,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                labelText: 'Saldo Digital',
                labelStyle: TextStyle(
                  color:
                      isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                prefixText: '💳 Rp ',
                prefixStyle: TextStyle(
                  color:
                      isDarkMode ? Colors.blue.shade300 : Colors.blue.shade600,
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isDarkMode
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isDarkMode
                        ? Colors.blue.shade300
                        : Colors.blue.shade600,
                  ),
                ),
                filled: true,
                fillColor:
                    isDarkMode ? Colors.grey.shade700 : Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.blue.shade800.withOpacity(0.3)
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      isDarkMode ? Colors.blue.shade600 : Colors.blue.shade200,
                ),
              ),
              child: Text(
                'Saldo ini akan menjadi saldo awal untuk minggu ini. Perubahan akan disimpan secara otomatis.',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      isDarkMode ? Colors.blue.shade200 : Colors.blue.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Batal',
              style: TextStyle(
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() {
                _cashBalance =
                    double.tryParse(cashController.text) ?? _cashBalance;
                _digitalBalance =
                    double.tryParse(digitalController.text) ?? _digitalBalance;
                _totalBalance =
                    _cashBalance + _digitalBalance; // Update total balance
              });
              await _saveBalance();
              if (mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Saldo berhasil diperbarui'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDarkMode ? Colors.blue.shade600 : Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showAddBalanceDialog() {
    final addAmountController = TextEditingController();
    String selectedType = 'Gaji'; // Default type
    MoneyType selectedMoneyType = MoneyType.cash; // Default money type
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final balanceTypes = [
      'Gaji',
      'Bonus',
      'Transfer',
      'Tabungan',
      'Investasi',
      'Lainnya'
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.white,
          title: Row(
            children: [
              Icon(Icons.add_circle, color: Colors.green, size: 28),
              const SizedBox(width: 8),
              Text(
                'Tambah Saldo',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: addAmountController,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  labelText: 'Jumlah Saldo',
                  labelStyle: TextStyle(
                    color: isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                  prefixText: 'Rp ',
                  prefixStyle: TextStyle(
                    color: isDarkMode
                        ? Colors.green.shade300
                        : Colors.green.shade600,
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: isDarkMode
                          ? Colors.grey.shade600
                          : Colors.grey.shade400,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: isDarkMode
                          ? Colors.green.shade300
                          : Colors.green.shade600,
                    ),
                  ),
                  hintText: 'Masukkan jumlah saldo',
                  hintStyle: TextStyle(
                    color: isDarkMode
                        ? Colors.grey.shade500
                        : Colors.grey.shade500,
                  ),
                  filled: true,
                  fillColor:
                      isDarkMode ? Colors.grey.shade700 : Colors.grey.shade50,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),

              // Money Type Selection
              Text(
                'Jenis Dana:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  color: isDarkMode ? Colors.grey.shade700 : Colors.white,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<MoneyType>(
                    value: selectedMoneyType,
                    isExpanded: true,
                    dropdownColor:
                        isDarkMode ? Colors.grey.shade800 : Colors.white,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    items: MoneyType.values.map((MoneyType type) {
                      return DropdownMenuItem<MoneyType>(
                        value: type,
                        child: Row(
                          children: [
                            Text(
                              type.icon,
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              type.displayName,
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (MoneyType? newValue) {
                      setDialogState(() {
                        selectedMoneyType = newValue!;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Jenis Pemasukan:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  color: isDarkMode ? Colors.grey.shade700 : Colors.white,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedType,
                    isExpanded: true,
                    dropdownColor:
                        isDarkMode ? Colors.grey.shade800 : Colors.white,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    items: balanceTypes.map((String type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(
                          type,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setDialogState(() {
                        selectedType = newValue!;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Quick amount buttons
              Text(
                'Jumlah Cepat:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [50000, 100000, 300000].map((amount) {
                  return OutlinedButton(
                    onPressed: () {
                      addAmountController.text = amount.toString();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      side: BorderSide(
                        color: isDarkMode
                            ? Colors.grey.shade600
                            : Colors.grey.shade400,
                      ),
                      foregroundColor: isDarkMode ? Colors.white : Colors.black,
                    ),
                    child: Text('${NumberFormat('#,###').format(amount)}'),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Batal',
                style: TextStyle(
                  color:
                      isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final amount = double.tryParse(addAmountController.text);
                if (amount != null && amount > 0) {
                  _addBalance(amount, selectedType, selectedMoneyType);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Masukkan jumlah yang valid'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Tambah Saldo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addBalance(double amount, String type, MoneyType moneyType) {
    setState(() {
      if (moneyType == MoneyType.cash) {
        _cashBalance += amount;
      } else {
        _digitalBalance += amount;
      }
      _totalBalance = _cashBalance + _digitalBalance;
    });
    _saveBalance();
    _saveBalanceHistory(amount, type);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${moneyType.displayName} berhasil ditambah Rp ${NumberFormat('#,###').format(amount)}'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {
            _undoAddBalance(amount, moneyType);
          },
        ),
      ),
    );
  }

  void _undoAddBalance(double amount, MoneyType moneyType) {
    setState(() {
      if (moneyType == MoneyType.cash) {
        _cashBalance -= amount;
      } else {
        _digitalBalance -= amount;
      }
      _totalBalance = _cashBalance + _digitalBalance;
    });
    _saveBalance();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Penambahan saldo dibatalkan'),
        backgroundColor: Colors.grey,
      ),
    );
  }

  Future<void> _saveBalanceHistory(double amount, String type) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final history = prefs.getStringList('balanceHistory') ?? [];

    final historyEntry = '${now.toIso8601String()}|$amount|$type|add';
    history.insert(0, historyEntry); // Add to beginning

    // Keep only last 50 entries
    if (history.length > 50) {
      history.removeRange(50, history.length);
    }

    await prefs.setStringList('balanceHistory', history);
  }

  Future<void> _checkAndResetWeeklyBalance() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // Cek apakah hari ini adalah hari Senin (weekday = 1)
    if (now.weekday == 1) {
      // Get tanggal reset terakhir
      final lastResetDateString = prefs.getString('lastWeeklyResetDate');
      final lastResetDate = lastResetDateString != null
          ? DateTime.parse(lastResetDateString)
          : null;

      // Cek apakah reset sudah dilakukan minggu ini
      final currentMondayDate = _getMondayOfCurrentWeek(now);

      if (lastResetDate == null || lastResetDate.isBefore(currentMondayDate)) {
        // Hitung saldo tersisa minggu sebelumnya
        final expenses = await _dbService.getExpensesByUser(_currentUserId);

        // Filter expenses dari minggu sebelumnya (Senin sampai Minggu)
        final lastSunday = currentMondayDate.subtract(const Duration(days: 1));
        final lastMondayStart = lastSunday.subtract(const Duration(days: 6));

        final lastWeekExpenses = expenses.where((expense) {
          return expense.expenseDate
                  .isAfter(lastMondayStart.subtract(const Duration(days: 1))) &&
              expense.expenseDate.isBefore(currentMondayDate);
        }).toList();

        final lastWeekTotalExpenses = lastWeekExpenses.fold<double>(
            0, (sum, expense) => sum + expense.amount);

        // Saldo tersisa minggu lalu = saldo awal minggu lalu - pengeluaran minggu lalu
        final remainingBalance = _totalBalance - lastWeekTotalExpenses;

        // Simpan saldo sebelumnya untuk history
        final previousBalance = _totalBalance;

        // Reset saldo total dengan saldo tersisa minggu sebelumnya (minimal 0)
        final newBalance = remainingBalance >= 0 ? remainingBalance : 0.0;
        setState(() {
          _totalBalance = newBalance;
        });

        // Simpan saldo baru dan tanggal reset
        await _saveBalance();
        await prefs.setString(
            'lastWeeklyResetDate', currentMondayDate.toIso8601String());

        // Simpan log reset
        await _saveResetHistory(previousBalance);

        // Tampilkan notifikasi jika aplikasi aktif
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Saldo direset untuk minggu baru!\nSaldo sebelumnya: Rp ${NumberFormat('#,###').format(previousBalance)}\nPengeluaran minggu lalu: Rp ${NumberFormat('#,###').format(lastWeekTotalExpenses)}\nSaldo awal minggu ini: Rp ${NumberFormat('#,###').format(_totalBalance)}',
              ),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 8),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }

        print(
            'Weekly reset completed: Previous balance: $previousBalance, Last week expenses: $lastWeekTotalExpenses, New balance: $_totalBalance');
        print(
            'Last week period: ${DateFormat('dd/MM/yyyy').format(lastMondayStart)} - ${DateFormat('dd/MM/yyyy').format(lastSunday)}');
      }
    }
  }

  DateTime _getMondayOfCurrentWeek(DateTime date) {
    final daysFromMonday = date.weekday - 1; // 0 = Monday, 1 = Tuesday, etc.
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: daysFromMonday));
  }

  Future<void> _saveResetHistory(double previousBalance) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final history = prefs.getStringList('resetHistory') ?? [];

    final historyEntry =
        '${now.toIso8601String()}|$previousBalance|${_totalBalance}|weekly_reset';
    history.insert(0, historyEntry);

    // Keep only last 20 reset entries
    if (history.length > 20) {
      history.removeRange(20, history.length);
    }

    await prefs.setStringList('resetHistory', history);
    print('Reset history saved: $historyEntry');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          _fetchData();
          _loadBalance();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBalanceCards(),
              const SizedBox(height: 24),
              _buildQuickActions(),
              const SizedBox(height: 24),
              _buildWeeklySummary(),
              const SizedBox(height: 24),
              _buildPeriodSelector(),
              const SizedBox(height: 16),
              _buildExpenseAnalysis(),
              const SizedBox(height: 24),
              _buildCategoryBreakdown(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCards() {
    return FutureBuilder<List<Expense>>(
      future: _allExpenses,
      builder: (context, snapshot) {
        double totalCashExpenses = 0;
        double totalDigitalExpenses = 0;

        if (snapshot.hasData) {
          // Hitung total pengeluaran dari awal minggu ini sampai sekarang
          final now = DateTime.now();
          final startOfThisWeek = _getMondayOfCurrentWeek(now);

          final thisWeekExpenses = snapshot.data!.where((expense) {
            return expense.expenseDate.isAfter(
                    startOfThisWeek.subtract(const Duration(days: 1))) &&
                expense.expenseDate.isBefore(now.add(const Duration(days: 1)));
          }).toList();

          // Pisahkan berdasarkan money type
          totalCashExpenses = thisWeekExpenses
              .where((expense) => expense.moneyType == MoneyType.cash)
              .fold(0, (sum, expense) => sum + expense.amount);

          totalDigitalExpenses = thisWeekExpenses
              .where((expense) => expense.moneyType == MoneyType.balance)
              .fold(0, (sum, expense) => sum + expense.amount);

          print('This week Cash expenses: $totalCashExpenses');
          print('This week Digital expenses: $totalDigitalExpenses');
        }

        // Hitung total dana dan sisa
        final totalWeeklyBalance = _cashBalance + _digitalBalance;
        final totalExpenses = totalCashExpenses + totalDigitalExpenses;
        final remainingBalance = totalWeeklyBalance - totalExpenses;
        final remainingCash = _cashBalance - totalCashExpenses;
        final remainingDigital = _digitalBalance - totalDigitalExpenses;

        // Hitung persentase
        final cashPercentage = remainingBalance > 0
            ? (remainingCash / remainingBalance * 100)
            : 0.0;
        final digitalPercentage = remainingBalance > 0
            ? (remainingDigital / remainingBalance * 100)
            : 0.0;

        return Column(
          children: [
            Row(
              children: [
                Text(
                  'Manajemen Saldo',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: _showBalanceDialog,
                  tooltip: 'Edit Saldo',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Dana Mingguan & Dana Tersisa (Main Cards)
            Row(
              children: [
                Expanded(
                  child: _buildBalanceCard(
                    'Dana Mingguan',
                    totalWeeklyBalance,
                    Colors.blue,
                    Icons.account_balance_wallet,
                    subtitle: 'Total dana awal minggu',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBalanceCard(
                    'Dana Tersisa',
                    remainingBalance,
                    remainingBalance >= 0 ? Colors.green : Colors.red,
                    remainingBalance >= 0 ? Icons.wallet : Icons.warning,
                    subtitle: 'Sisa setelah pengeluaran',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Breakdown Cash & Digital
            _buildBreakdownCard(
              'Breakdown Dana Tersisa',
              [
                BreakdownItem(
                  type: 'Cash',
                  amount: remainingCash,
                  percentage: cashPercentage,
                  icon: '💵',
                  color: Colors.green,
                ),
                BreakdownItem(
                  type: 'Saldo Digital',
                  amount: remainingDigital,
                  percentage: digitalPercentage,
                  icon: '💳',
                  color: Colors.blue,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildBreakdownCard(String title, List<BreakdownItem> items) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? Theme.of(context).cardColor : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pie_chart,
                  color: isDarkMode
                      ? Colors.orange.shade300
                      : Colors.orange.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...items.map((item) => _buildBreakdownItem(item, textColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownItem(BreakdownItem item, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            item.icon,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.type,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                Text(
                  'Rp ${NumberFormat('#,###').format(item.amount)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: item.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: item.color.withOpacity(0.3)),
            ),
            child: Text(
              '${item.percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: item.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(
      String title, double amount, Color color, IconData icon,
      {String? subtitle}) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Rp ${NumberFormat('#,###').format(amount)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Periode Analisis',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 350,
              height: 48,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'Harian',
                    label: Text('Harian'),
                    // No icon
                  ),
                  ButtonSegment(
                    value: 'Mingguan',
                    label: Text('Mingguan'),
                  ),
                  ButtonSegment(
                    value: 'Bulanan',
                    label: Text('Bulanan'),
                  ),
                ],
                selected: {_selectedPeriod},
                showSelectedIcon: false, // <-- Hilangkan logo centang
                onSelectionChanged: (selection) {
                  setState(() {
                    _selectedPeriod = selection.first;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseAnalysis() {
    return FutureBuilder<List<Expense>>(
      future: _allExpenses,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          print('Error in expense analysis: ${snapshot.error}');
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Belum ada data pengeluaran'),
            ),
          );
        }

        try {
          final expenses = _getFilteredExpenses(snapshot.data!);
          print(
              'Filtered expenses count: ${expenses.length} for period: $_selectedPeriod');

          final totalExpenses =
              expenses.fold<double>(0, (sum, expense) => sum + expense.amount);
          final averagePerDay = _calculateAveragePerDay(expenses);

          // Enhanced debug logging
          final now = DateTime.now();
          String debugInfo;
          double divider = 1;

          switch (_selectedPeriod) {
            case 'Mingguan':
              divider = now.weekday.toDouble();
              debugInfo =
                  'Weekday: ${now.weekday} (${_getWeekdayName(now.weekday)})';
              break;
            case 'Bulanan':
              divider = now.day.toDouble();
              debugInfo = 'Day of month: ${now.day}';
              break;
            default:
              debugInfo = 'Daily';
              divider = 1;
          }
          print(
              'Total expenses: $totalExpenses, Average per day: $averagePerDay ($debugInfo, divider: $divider)');
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analisis Pengeluaran $_selectedPeriod',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child:
                            _buildStatCard('Total', totalExpenses, Colors.red),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                            'Rata-rata/Hari', averagePerDay, Colors.orange),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard('Transaksi',
                            expenses.length.toDouble(), Colors.blue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  LinearProgressIndicator(
                    value: totalExpenses > 0
                        ? (averagePerDay / totalExpenses).clamp(0.0, 1.0)
                        : 0.0,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rata-rata/Hari',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      Text(
                        totalExpenses > 0
                            ? '${((averagePerDay / totalExpenses) * 100).toStringAsFixed(1)}%'
                            : '0%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        } catch (e) {
          print('Error in analysis calculation: $e');
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error dalam perhitungan analisis: $e'),
            ),
          );
        }
      },
    );
  }

  Widget _buildStatCard(String title, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title == 'Transaksi'
                ? '${value.toInt()}'
                : 'Rp ${NumberFormat('#,###').format(value)}',
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    return FutureBuilder<List<Expense>>(
      future: _allExpenses,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          print('Error in category breakdown: ${snapshot.error}');
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox();
        }

        return FutureBuilder<List<Category>>(
          future: _categories,
          builder: (context, categorySnapshot) {
            if (categorySnapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (categorySnapshot.hasError) {
              print('Error loading categories: ${categorySnapshot.error}');
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                      'Error loading categories: ${categorySnapshot.error}'),
                ),
              );
            }

            if (!categorySnapshot.hasData) {
              return const CircularProgressIndicator();
            }

            try {
              final expenses = _getFilteredExpenses(snapshot.data!);
              final totalExpenses = expenses.fold<double>(
                  0, (sum, expense) => sum + expense.amount);

              // Use monthly filter specifically for category breakdown
              final monthlyExpensesForCategories =
                  _getMonthlyExpensesForCategories(snapshot.data!);
              final categoryBreakdown = _calculateCategoryBreakdown(
                  monthlyExpensesForCategories, categorySnapshot.data!);

              print(
                  'Category breakdown calculated: ${categoryBreakdown.length} categories (monthly only)');

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.pie_chart,
                              color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Breakdown per Kategori',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Bulan Ini',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Total monthly expenses for categories
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month,
                                color: Colors.grey.shade600, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Total Bulan Ini: ',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Text(
                              'Rp ${NumberFormat('#,###').format(monthlyExpensesForCategories.fold<double>(0, (sum, expense) => sum + expense.amount))}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...categoryBreakdown
                          .map(
                              (item) => _buildCategoryItem(item, totalExpenses))
                          .toList(),
                    ],
                  ),
                ),
              );
            } catch (e) {
              print('Error in category breakdown calculation: $e');
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error dalam perhitungan kategori: $e'),
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildCategoryItem(Map<String, dynamic> item, double totalExpenses) {
    final percentage =
        totalExpenses > 0 ? (item['amount'] / totalExpenses) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${item['icon']} ${item['name']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                'Rp ${NumberFormat('#,###').format(item['amount'])}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(int.parse(item['color'].replaceAll('#', '0xff'))),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(percentage * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklySummary() {
    return FutureBuilder<List<Expense>>(
      future: _allExpenses,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox();
        }

        final now = DateTime.now();
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final thisWeekExpenses = snapshot.data!.where((expense) {
          return expense.expenseDate
                  .isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
              expense.expenseDate.isBefore(now.add(const Duration(days: 1)));
        }).toList();

        final lastWeekStart = startOfWeek.subtract(const Duration(days: 7));
        final lastWeekExpenses = snapshot.data!.where((expense) {
          return expense.expenseDate
                  .isAfter(lastWeekStart.subtract(const Duration(days: 1))) &&
              expense.expenseDate.isBefore(startOfWeek);
        }).toList();

        final thisWeekTotal = thisWeekExpenses.fold<double>(
            0, (sum, expense) => sum + expense.amount);
        final lastWeekTotal = lastWeekExpenses.fold<double>(
            0, (sum, expense) => sum + expense.amount);
        final weeklyChange = lastWeekTotal > 0
            ? ((thisWeekTotal - lastWeekTotal) / lastWeekTotal) * 100
            : 0.0;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Perbandingan Mingguan',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildWeeklyCard(
                        'Minggu Ini',
                        thisWeekTotal,
                        thisWeekExpenses.length,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildWeeklyCard(
                        'Minggu Lalu',
                        lastWeekTotal,
                        lastWeekExpenses.length,
                        Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: weeklyChange >= 0
                        ? Colors.red.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        weeklyChange >= 0
                            ? Icons.trending_up
                            : Icons.trending_down,
                        color: weeklyChange >= 0 ? Colors.red : Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        weeklyChange >= 0
                            ? 'Naik ${weeklyChange.toStringAsFixed(1)}% dari minggu lalu'
                            : 'Turun ${(-weeklyChange).toStringAsFixed(1)}% dari minggu lalu',
                        style: TextStyle(
                          color: weeklyChange >= 0 ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeeklyCard(
      String title, double amount, int transactions, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Rp ${NumberFormat('#,###').format(amount)}',
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$transactions transaksi',
            style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flash_on, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  'Aksi Cepat',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddExpensePage(),
                        ),
                      );
                      if (result == true) _fetchData();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.add, size: 24),
                        SizedBox(height: 6),
                        Text('Tambah\nPengeluaran',
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showAddBalanceDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.account_balance_wallet, size: 24),
                        SizedBox(height: 6),
                        Text('Tambah\nSaldo', textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BalanceHistoryPage(),
                        ),
                      );
                    },
                    icon: Icon(Icons.history, color: Colors.orange.shade700),
                    label: const Text('Histori Saldo'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                        color: isDarkMode
                            ? Colors.orange.shade700
                            : Colors.orange.shade200,
                        width: 1.5,
                      ),
                      foregroundColor: Colors.orange.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Expense> _getFilteredExpenses(List<Expense> allExpenses) {
    final now = DateTime.now();

    try {
      return allExpenses.where((expense) {
        switch (_selectedPeriod) {
          case 'Harian':
            // Check if expense date is today
            return DateUtils.isSameDay(expense.expenseDate, now);
          case 'Mingguan':
            // Check if expense is within current week
            final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
            final endOfWeek = startOfWeek.add(const Duration(days: 6));
            return expense.expenseDate
                    .isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
                expense.expenseDate
                    .isBefore(endOfWeek.add(const Duration(days: 1)));
          case 'Bulanan':
            // Check if expense is within current month
            return expense.expenseDate.year == now.year &&
                expense.expenseDate.month == now.month;
          default:
            return true;
        }
      }).toList();
    } catch (e) {
      print('Error filtering expenses: $e');
      return [];
    }
  }

  List<Expense> _getMonthlyExpensesForCategories(List<Expense> allExpenses) {
    final now = DateTime.now();

    try {
      return allExpenses.where((expense) {
        // Always filter by current month only for category breakdown
        return expense.expenseDate.year == now.year &&
            expense.expenseDate.month == now.month;
      }).toList();
    } catch (e) {
      print('Error filtering monthly expenses for categories: $e');
      return [];
    }
  }

  double _calculateAveragePerDay(List<Expense> expenses) {
    if (expenses.isEmpty) return 0;

    try {
      final totalAmount =
          expenses.fold<double>(0, (sum, expense) => sum + expense.amount);

      switch (_selectedPeriod) {
        case 'Harian':
          return totalAmount;
        case 'Mingguan':
          final now = DateTime.now();
          final currentWeekday = now.weekday; // 1 = Monday, 7 = Sunday
          // Calculate average based on days passed in current week
          return totalAmount / currentWeekday;
        case 'Bulanan':
          final now = DateTime.now();
          final currentDay = now.day;
          // Calculate average based on days passed in current month
          return totalAmount / currentDay;
        default:
          return totalAmount;
      }
    } catch (e) {
      print('Error calculating average per day: $e');
      return 0;
    }
  }

  List<Map<String, dynamic>> _calculateCategoryBreakdown(
      List<Expense> expenses, List<Category> categories) {
    final Map<int, double> categoryTotals = {};

    for (var expense in expenses) {
      categoryTotals[expense.categoryId] =
          (categoryTotals[expense.categoryId] ?? 0) + expense.amount;
    }

    final breakdown = <Map<String, dynamic>>[];
    for (var category in categories) {
      final amount = categoryTotals[category.categoryId] ?? 0;
      if (amount > 0) {
        breakdown.add({
          'name': category.name,
          'icon': category.icon,
          'color': category.color,
          'amount': amount,
        });
      }
    }

    // Sort by amount descending
    breakdown.sort((a, b) => b['amount'].compareTo(a['amount']));
    return breakdown;
  }

  String _getWeekdayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Senin';
      case 2:
        return 'Selasa';
      case 3:
        return 'Rabu';
      case 4:
        return 'Kamis';
      case 5:
        return 'Jumat';
      case 6:
        return 'Sabtu';
      case 7:
        return 'Minggu';
      default:
        return 'Unknown';
    }
  }
}
