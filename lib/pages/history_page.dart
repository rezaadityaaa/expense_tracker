import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../models/expense_with_category.dart';
import '../models/money_type.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _selectedFilter = 'weekly'; // weekly, monthly, yearly
  DateTime _selectedDate = DateTime.now();
  List<ExpenseWithCategory> _expenses = [];
  bool _isLoading = true;

  double _totalCash = 0.0;
  double _totalDigital = 0.0;
  double _weeklyStartBalance = 0.0;
  double _weeklyEndBalance = 0.0;

  // For monthly and yearly breakdown
  List<Map<String, dynamic>> _weeklyBreakdown = [];
  List<Map<String, dynamic>> _monthlyBreakdown = [];
  List<Map<String, dynamic>> _dailyBreakdown = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_selectedFilter == 'weekly') {
        await _loadWeeklyData();
      } else if (_selectedFilter == 'monthly') {
        await _loadMonthlyData();
      } else {
        await _loadYearlyData();
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadWeeklyData() async {
    // Get start and end of selected week
    final startOfWeek = _getStartOfWeek(_selectedDate);
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    // Get expenses for the week
    _expenses = await DatabaseService().getExpensesByDateRange(
        startOfWeek, endOfWeek.add(const Duration(hours: 23, minutes: 59)));

    // Calculate totals
    _totalCash = _expenses
        .where((e) => e.moneyType == MoneyType.cash)
        .fold(0.0, (sum, e) => sum + e.amount);
    _totalDigital = _expenses
        .where((e) => e.moneyType == MoneyType.balance)
        .fold(0.0, (sum, e) => sum + e.amount);

    // Calculate running balance based on all previous expenses
    _weeklyStartBalance = await _calculateInitialBalance(startOfWeek);
    _weeklyEndBalance = _weeklyStartBalance - (_totalCash + _totalDigital);

    // Calculate daily breakdown for the week
    _dailyBreakdown = await _calculateDailyBreakdown(startOfWeek, endOfWeek);
  }

  Future<void> _loadMonthlyData() async {
    // Implementation for monthly data
    final startOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final endOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

    _expenses = await DatabaseService().getExpensesByDateRange(
        startOfMonth, endOfMonth.add(const Duration(hours: 23, minutes: 59)));

    _totalCash = _expenses
        .where((e) => e.moneyType == MoneyType.cash)
        .fold(0.0, (sum, e) => sum + e.amount);
    _totalDigital = _expenses
        .where((e) => e.moneyType == MoneyType.balance)
        .fold(0.0, (sum, e) => sum + e.amount);

    // Calculate weekly breakdown for the month
    _weeklyBreakdown =
        await _calculateWeeklyBreakdown(startOfMonth, endOfMonth);
  }

  Future<void> _loadYearlyData() async {
    // Implementation for yearly data
    final startOfYear = DateTime(_selectedDate.year, 1, 1);
    final endOfYear = DateTime(_selectedDate.year, 12, 31);

    _expenses = await DatabaseService().getExpensesByDateRange(
        startOfYear, endOfYear.add(const Duration(hours: 23, minutes: 59)));

    _totalCash = _expenses
        .where((e) => e.moneyType == MoneyType.cash)
        .fold(0.0, (sum, e) => sum + e.amount);
    _totalDigital = _expenses
        .where((e) => e.moneyType == MoneyType.balance)
        .fold(0.0, (sum, e) => sum + e.amount);

    // Calculate monthly breakdown for the year
    _monthlyBreakdown =
        await _calculateMonthlyBreakdown(startOfYear, endOfYear);
  }

  DateTime _getStartOfWeek(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - daysFromMonday);
  }

  Future<List<Map<String, dynamic>>> _calculateWeeklyBreakdown(
      DateTime startOfMonth, DateTime endOfMonth) async {
    List<Map<String, dynamic>> weeklyData = [];
    DateTime currentWeekStart = _getStartOfWeek(startOfMonth);

    // Calculate initial balance at the start of the month
    double runningBalance = await _calculateInitialBalance(startOfMonth);

    while (currentWeekStart.isBefore(endOfMonth) ||
        currentWeekStart.isAtSameMomentAs(endOfMonth)) {
      DateTime weekEnd = currentWeekStart.add(const Duration(days: 6));

      // Get expenses for this week
      List<ExpenseWithCategory> weekExpenses = await DatabaseService()
          .getExpensesByDateRange(currentWeekStart,
              weekEnd.add(const Duration(hours: 23, minutes: 59)));

      double weekTotalCash = weekExpenses
          .where((e) => e.moneyType == MoneyType.cash)
          .fold(0.0, (sum, e) => sum + e.amount);
      double weekTotalDigital = weekExpenses
          .where((e) => e.moneyType == MoneyType.balance)
          .fold(0.0, (sum, e) => sum + e.amount);

      double weekTotal = weekTotalCash + weekTotalDigital;
      double weekStartBalance = runningBalance;
      double weekEndBalance = runningBalance - weekTotal;

      weeklyData.add({
        'week': 'Minggu ${weeklyData.length + 1}',
        'dateRange':
            '${DateFormat('d MMM', 'id_ID').format(currentWeekStart)} - ${DateFormat('d MMM', 'id_ID').format(weekEnd)}',
        'startBalance': weekStartBalance,
        'endBalance': weekEndBalance,
        'totalCash': weekTotalCash,
        'totalDigital': weekTotalDigital,
        'totalExpense': weekTotal,
      });

      runningBalance = weekEndBalance;
      currentWeekStart = currentWeekStart.add(const Duration(days: 7));
    }

    return weeklyData;
  }

  Future<List<Map<String, dynamic>>> _calculateMonthlyBreakdown(
      DateTime startOfYear, DateTime endOfYear) async {
    List<Map<String, dynamic>> monthlyData = [];

    // Calculate initial balance at the start of the year
    double runningBalance = await _calculateInitialBalance(startOfYear);

    for (int month = 1; month <= 12; month++) {
      DateTime monthStart = DateTime(startOfYear.year, month, 1);
      DateTime monthEnd = DateTime(startOfYear.year, month + 1, 0);

      // Get expenses for this month
      List<ExpenseWithCategory> monthExpenses = await DatabaseService()
          .getExpensesByDateRange(
              monthStart, monthEnd.add(const Duration(hours: 23, minutes: 59)));

      double monthTotalCash = monthExpenses
          .where((e) => e.moneyType == MoneyType.cash)
          .fold(0.0, (sum, e) => sum + e.amount);
      double monthTotalDigital = monthExpenses
          .where((e) => e.moneyType == MoneyType.balance)
          .fold(0.0, (sum, e) => sum + e.amount);

      double monthTotal = monthTotalCash + monthTotalDigital;
      double monthStartBalance = runningBalance;
      double monthEndBalance = runningBalance - monthTotal;

      monthlyData.add({
        'month': DateFormat('MMMM', 'id_ID').format(monthStart),
        'startBalance': monthStartBalance,
        'endBalance': monthEndBalance,
        'totalCash': monthTotalCash,
        'totalDigital': monthTotalDigital,
        'totalExpense': monthTotal,
      });

      runningBalance = monthEndBalance;
    }

    return monthlyData;
  }

  Future<List<Map<String, dynamic>>> _calculateDailyBreakdown(
      DateTime startOfWeek, DateTime endOfWeek) async {
    List<Map<String, dynamic>> dailyData = [];

    // Calculate initial balance at the start of the week
    double runningBalance = await _calculateInitialBalance(startOfWeek);

    // List of Indonesian day names
    final dayNames = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu'
    ];

    for (int i = 0; i < 7; i++) {
      DateTime currentDay = startOfWeek.add(Duration(days: i));
      DateTime dayEnd = DateTime(
          currentDay.year, currentDay.month, currentDay.day, 23, 59, 59);

      // Get expenses for this day
      List<ExpenseWithCategory> dayExpenses =
          await DatabaseService().getExpensesByDateRange(currentDay, dayEnd);

      double dayTotalCash = dayExpenses
          .where((e) => e.moneyType == MoneyType.cash)
          .fold(0.0, (sum, e) => sum + e.amount);
      double dayTotalDigital = dayExpenses
          .where((e) => e.moneyType == MoneyType.balance)
          .fold(0.0, (sum, e) => sum + e.amount);

      double dayTotal = dayTotalCash + dayTotalDigital;
      double dayStartBalance = runningBalance;
      double dayEndBalance = runningBalance - dayTotal;

      dailyData.add({
        'day': dayNames[i],
        'date': DateFormat('d MMM', 'id_ID').format(currentDay),
        'fullDate': currentDay,
        'startBalance': dayStartBalance,
        'endBalance': dayEndBalance,
        'totalCash': dayTotalCash,
        'totalDigital': dayTotalDigital,
        'totalExpense': dayTotal,
        'expenseCount': dayExpenses.length,
        'expenses': dayExpenses,
      });

      runningBalance = dayEndBalance;
    }

    return dailyData;
  }

  // Helper method to calculate initial balance based on all previous expenses
  Future<double> _calculateInitialBalance(DateTime fromDate) async {
    final prefs = await SharedPreferences.getInstance();

    // Get current balance dari SharedPreferences (data dana yang sebenarnya)
    double currentTotalBalance = prefs.getDouble('totalBalance') ?? 0.0;

    // Get all expenses from current week/month/year until now
    List<ExpenseWithCategory> expensesFromPeriod = await DatabaseService()
        .getExpensesByDateRange(fromDate, DateTime.now());

    double totalExpensesFromPeriod =
        expensesFromPeriod.fold(0.0, (sum, expense) => sum + expense.amount);

    // Calculate balance at the start of period: current balance + expenses that happened in this period
    double initialBalance = currentTotalBalance + totalExpensesFromPeriod;

    return initialBalance;
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
            locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
        .format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                : [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Column(
          children: [
            _buildFilterSection(),
            _buildDateSelector(),
            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (_selectedFilter == 'weekly') ...[
                        _buildWeeklyRecap(),
                        const SizedBox(height: 16),
                        _buildExpensesList(),
                      ] else if (_selectedFilter == 'monthly') ...[
                        _buildMonthlyRecap(),
                      ] else ...[
                        _buildYearlyRecap(),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildFilterButton('Harian', 'weekly'),
          _buildFilterButton('Bulanan', 'monthly'),
          _buildFilterButton('Tahunan', 'yearly'),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String title, String filter) {
    final isSelected = _selectedFilter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = filter;
          });
          _loadData();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _getDateRangeText(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            onPressed: _showDatePicker,
            icon: const Icon(Icons.calendar_today),
          ),
        ],
      ),
    );
  }

  String _getDateRangeText() {
    if (_selectedFilter == 'weekly') {
      final startOfWeek = _getStartOfWeek(_selectedDate);
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      return '${DateFormat('d MMM', 'id_ID').format(startOfWeek)} - ${DateFormat('d MMM yyyy', 'id_ID').format(endOfWeek)}';
    } else if (_selectedFilter == 'monthly') {
      return DateFormat('MMMM yyyy', 'id_ID').format(_selectedDate);
    } else {
      return DateFormat('yyyy', 'id_ID').format(_selectedDate);
    }
  }

  void _showDatePicker() async {
    if (_selectedFilter == 'weekly' || _selectedFilter == 'monthly') {
      final date = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
      if (date != null) {
        setState(() {
          _selectedDate = date;
        });
        _loadData();
      }
    } else {
      // Year picker
      final year = await showDialog<int>(
        context: context,
        builder: (context) =>
            _YearPickerDialog(initialYear: _selectedDate.year),
      );
      if (year != null) {
        setState(() {
          _selectedDate = DateTime(year);
        });
        _loadData();
      }
    }
  }

  Widget _buildWeeklyRecap() {
    return Column(
      children: [
        // Main Summary Card
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recap Mingguan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Saldo Awal'),
                        Text(
                          _formatCurrency(_weeklyStartBalance),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Saldo Akhir'),
                        Text(
                          _formatCurrency(_weeklyEndBalance),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _weeklyEndBalance >= 0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        const Text('Cash'),
                        Text(
                          _formatCurrency(_totalCash),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Digital'),
                        Text(
                          _formatCurrency(_totalDigital),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Total'),
                        Text(
                          _formatCurrency(_totalCash + _totalDigital),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Daily Breakdown Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Breakdown Harian',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (_dailyBreakdown.isEmpty)
                  const Text('Tidak ada data harian')
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _dailyBreakdown.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final day = _dailyBreakdown[index];
                      final isToday =
                          DateFormat('yyyy-MM-dd').format(day['fullDate']) ==
                              DateFormat('yyyy-MM-dd').format(DateTime.now());

                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: isToday
                            ? BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              )
                            : null,
                        child: Padding(
                          padding: isToday
                              ? const EdgeInsets.all(8)
                              : EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '${day['day']} (${day['date']})',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isToday
                                              ? Colors.blue.shade700
                                              : null,
                                        ),
                                      ),
                                      if (isToday) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade600,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: const Text(
                                            'Hari Ini',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    '${day['expenseCount']} transaksi',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Saldo: ${_formatCurrency(day['startBalance'])} → ${_formatCurrency(day['endBalance'])}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (day['totalExpense'] > 0)
                                        Row(
                                          children: [
                                            if (day['totalCash'] > 0) ...[
                                              Text(
                                                'Cash: ${_formatCurrency(day['totalCash'])}',
                                                style: const TextStyle(
                                                    fontSize: 11),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            if (day['totalDigital'] > 0) ...[
                                              Text(
                                                'Digital: ${_formatCurrency(day['totalDigital'])}',
                                                style: const TextStyle(
                                                    fontSize: 11),
                                              ),
                                            ],
                                          ],
                                        ),
                                    ],
                                  ),
                                  if (day['totalExpense'] > 0)
                                    Text(
                                      _formatCurrency(day['totalExpense']),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    )
                                  else
                                    Text(
                                      'Tidak ada pengeluaran',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyRecap() {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recap Bulanan - ${DateFormat('MMMM yyyy', 'id_ID').format(_selectedDate)}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                    'Total Pengeluaran: ${_formatCurrency(_totalCash + _totalDigital)}'),
                Text('Cash: ${_formatCurrency(_totalCash)}'),
                Text('Digital: ${_formatCurrency(_totalDigital)}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Breakdown Mingguan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (_weeklyBreakdown.isEmpty)
                  const Text('Tidak ada data mingguan')
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _weeklyBreakdown.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final week = _weeklyBreakdown[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${week['week']} (${week['dateRange']})',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Saldo Awal'),
                                    Text(
                                      _formatCurrency(week['startBalance']),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Saldo Akhir'),
                                    Text(
                                      _formatCurrency(week['endBalance']),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: week['endBalance'] >= 0
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    'Cash: ${_formatCurrency(week['totalCash'])}'),
                                Text(
                                    'Digital: ${_formatCurrency(week['totalDigital'])}'),
                                Text(
                                  'Total: ${_formatCurrency(week['totalExpense'])}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildYearlyRecap() {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recap Tahunan - ${_selectedDate.year}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                    'Total Pengeluaran: ${_formatCurrency(_totalCash + _totalDigital)}'),
                Text('Cash: ${_formatCurrency(_totalCash)}'),
                Text('Digital: ${_formatCurrency(_totalDigital)}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Breakdown Bulanan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (_monthlyBreakdown.isEmpty)
                  const Text('Tidak ada data bulanan')
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _monthlyBreakdown.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final month = _monthlyBreakdown[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              month['month'],
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Saldo Awal'),
                                    Text(
                                      _formatCurrency(month['startBalance']),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Saldo Akhir'),
                                    Text(
                                      _formatCurrency(month['endBalance']),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: month['endBalance'] >= 0
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    'Cash: ${_formatCurrency(month['totalCash'])}'),
                                Text(
                                    'Digital: ${_formatCurrency(month['totalDigital'])}'),
                                Text(
                                  'Total: ${_formatCurrency(month['totalExpense'])}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpensesList() {
    if (_expenses.isEmpty) {
      return Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.receipt_long,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                'Tidak ada pengeluaran',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                'pada periode ini',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Group expenses by date
    Map<String, List<ExpenseWithCategory>> groupedExpenses = {};
    for (var expense in _expenses) {
      String dateKey = DateFormat('yyyy-MM-dd').format(expense.expenseDate);
      if (!groupedExpenses.containsKey(dateKey)) {
        groupedExpenses[dateKey] = [];
      }
      groupedExpenses[dateKey]!.add(expense);
    }

    // Sort dates in descending order (newest first)
    var sortedDates = groupedExpenses.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.list_alt, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Daftar Pengeluaran',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_expenses.length} transaksi',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedDates.length,
            itemBuilder: (context, dateIndex) {
              String dateKey = sortedDates[dateIndex];
              List<ExpenseWithCategory> dayExpenses = groupedExpenses[dateKey]!;
              DateTime date = DateTime.parse(dateKey);

              double dayTotal =
                  dayExpenses.fold(0.0, (sum, expense) => sum + expense.amount);
              bool isToday = DateFormat('yyyy-MM-dd').format(date) ==
                  DateFormat('yyyy-MM-dd').format(DateTime.now());

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    color: isToday ? Colors.amber.shade50 : Colors.grey.shade50,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: isToday
                                  ? Colors.amber.shade700
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_getDayName(date)}, ${DateFormat('d MMMM yyyy', 'id_ID').format(date)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isToday
                                    ? Colors.amber.shade700
                                    : Colors.grey.shade700,
                              ),
                            ),
                            if (isToday) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade600,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Hari Ini',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatCurrency(dayTotal),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            Text(
                              '${dayExpenses.length} transaksi',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Expenses for this date
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: dayExpenses.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (context, expenseIndex) {
                      final expense = dayExpenses[expenseIndex];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            // Money Type Icon
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: expense.moneyType == MoneyType.cash
                                    ? Colors.green.shade100
                                    : Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: expense.moneyType == MoneyType.cash
                                      ? Colors.green.shade300
                                      : Colors.blue.shade300,
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  expense.moneyType.icon,
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Expense Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    expense.description,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          expense.categoryName,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormat('HH:mm', 'id_ID')
                                            .format(expense.expenseDate),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Amount
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatCurrency(expense.amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  expense.moneyType.displayName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: expense.moneyType == MoneyType.cash
                                        ? Colors.green.shade600
                                        : Colors.blue.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (dateIndex < sortedDates.length - 1)
                    const SizedBox(height: 8),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _getDayName(DateTime date) {
    const dayNames = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu'
    ];
    return dayNames[date.weekday - 1];
  }
}

class _YearPickerDialog extends StatelessWidget {
  final int initialYear;

  const _YearPickerDialog({required this.initialYear});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pilih Tahun'),
      content: SizedBox(
        width: 300,
        height: 300,
        child: YearPicker(
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          selectedDate: DateTime(initialYear),
          onChanged: (date) {
            Navigator.of(context).pop(date.year);
          },
        ),
      ),
    );
  }
}
