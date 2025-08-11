import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../models/money_type.dart';
import '../services/database_service.dart';
import '../services/balance_reset_service.dart';

class AddExpensePage extends StatefulWidget {
  const AddExpensePage({super.key});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _dbService = DatabaseService();
  final _balanceService = BalanceResetService();

  late Future<List<Category>> _categories;
  Category? _selectedCategory;
  MoneyType _selectedMoneyType = MoneyType.cash;
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  // Asumsi ada user yang sedang login dengan id 1
  final int _currentUserId = 1;

  @override
  void initState() {
    super.initState();
    print('AddExpensePage: Loading categories...');
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      _categories = _dbService.getCategories();
      final categories = await _categories;
      print('AddExpensePage: Loaded ${categories.length} categories');
      for (var category in categories) {
        print('  - ${category.name} (ID: ${category.categoryId})');
      }

      // Jika ada kategori dan belum ada yang dipilih, pilih yang pertama sebagai default
      if (categories.isNotEmpty && _selectedCategory == null) {
        setState(() {
          _selectedCategory = categories.first;
        });
        print('Default category selected: ${categories.first.name}');
      }
    } catch (error) {
      print('AddExpensePage: Error loading categories: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat kategori: $error'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Coba Lagi',
              textColor: Colors.white,
              onPressed: _loadCategories,
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(), // Tidak bisa pilih tanggal masa depan
      helpText: 'Pilih tanggal pengeluaran',
      cancelText: 'Batal',
      confirmText: 'OK',
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });

      // Warning jika tanggal terlalu jauh di masa lalu (lebih dari 3 bulan)
      final now = DateTime.now();
      final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);

      if (picked.isBefore(threeMonthsAgo)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Perhatian: Tanggal yang dipilih cukup lama. Pastikan ini benar.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      }
    }
  }

  void _submitForm() async {
    print('Submit form called');
    print('Form valid: ${_formKey.currentState?.validate()}');
    print(
        'Selected category: ${_selectedCategory?.name} (ID: ${_selectedCategory?.categoryId})');

    // Validasi form dan kategori
    if (!_formKey.currentState!.validate()) {
      print('Form validation failed');
      return;
    }

    if (_selectedCategory == null) {
      print('No category selected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih kategori terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final expenseAmount = double.parse(_amountController.text);

      // Check if expense will make remaining balance negative
      final remainingBalance =
          await _balanceService.calculateRemainingBalance(_currentUserId);
      final newRemainingBalance = remainingBalance - expenseAmount;

      if (newRemainingBalance < 0) {
        // Show warning dialog
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Peringatan Saldo'),
            content: Text(
                'Pengeluaran ini akan membuat saldo tersisa menjadi negatif.\n\n'
                'Saldo tersisa saat ini: Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '').format(remainingBalance)}\n'
                'Setelah pengeluaran: Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '').format(newRemainingBalance)}\n\n'
                'Apakah Anda yakin ingin melanjutkan?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Lanjutkan'),
              ),
            ],
          ),
        );

        if (shouldContinue != true) {
          return;
        }
      }

      final newExpense = Expense(
        userId: _currentUserId,
        categoryId: _selectedCategory!.categoryId!,
        amount: expenseAmount,
        description: _descriptionController.text,
        expenseDate: _selectedDate,
        moneyType: _selectedMoneyType,
        createdAt: DateTime.now(),
      );

      print('Creating expense: ${newExpense.toMap()}');
      await _dbService.insertExpense(newExpense);
      print('Expense successfully added to database');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newRemainingBalance < 0
                ? 'Pengeluaran ditambahkan! Saldo tersisa sekarang negatif.'
                : 'Pengeluaran berhasil ditambahkan!'),
            backgroundColor:
                newRemainingBalance < 0 ? Colors.orange : Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      print('Error adding expense: $e');
    }
  }

  // Add some animation and haptic feedback
  void _onQuickAmountTap(int amount) {
    HapticFeedback.lightImpact();
    _amountController.text = amount.toString();
    // Add small animation feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Jumlah diset ke Rp ${NumberFormat('#,###').format(amount)}'),
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Tambah Pengeluaran',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Header Card dengan informasi saldo
              _buildBalanceInfoCard(),

              const SizedBox(height: 24),

              // Date dan Category - responsif layout
              LayoutBuilder(
                builder: (context, constraints) {
                  // Jika layar terlalu sempit, gunakan Column
                  if (constraints.maxWidth < 400) {
                    return Column(
                      children: [
                        _buildDateCard(),
                        const SizedBox(height: 16),
                        _buildCategoryCard(),
                      ],
                    );
                  } else {
                    // Jika layar cukup lebar, gunakan Row
                    return Row(
                      children: [
                        Expanded(child: _buildDateCard()),
                        const SizedBox(width: 16),
                        Expanded(child: _buildCategoryCard()),
                      ],
                    );
                  }
                },
              ),

              const SizedBox(height: 20),

              // Quick amount buttons
              _buildQuickAmountButtons(),

              const SizedBox(height: 20),

              // Amount Input dengan design menarik
              _buildAmountCard(),

              const SizedBox(height: 20),

              // Money Type Card
              _buildMoneyTypeCard(),

              const SizedBox(height: 20),

              // Description Card
              _buildDescriptionCard(),

              const SizedBox(height: 32),

              // Submit button dengan animasi
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceInfoCard() {
    return FutureBuilder<double>(
      future: _balanceService.calculateRemainingBalance(_currentUserId),
      builder: (context, snapshot) {
        final remainingBalance = snapshot.data ?? 0.0;
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkMode
                  ? [Colors.blue.shade800, Colors.blue.shade600]
                  : [Colors.blue.shade600, Colors.blue.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(isDarkMode ? 0.2 : 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(isDarkMode ? 0.15 : 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Saldo Tersisa',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Rp ${NumberFormat('#,###').format(remainingBalance)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAmountCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? Theme.of(context).cardColor : Colors.white;
    final borderColor =
        isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300;
    final fillColor = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.green.shade800.withOpacity(0.3)
                        : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.monetization_on,
                    color: isDarkMode
                        ? Colors.green.shade300
                        : Colors.green.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Jumlah Pengeluaran',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Masukkan jumlah',
                labelStyle: TextStyle(
                  color:
                      isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                prefixText: 'Rp ',
                prefixStyle: TextStyle(
                  color: isDarkMode
                      ? Colors.green.shade300
                      : Colors.green.shade600,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: isDarkMode
                          ? Colors.green.shade300
                          : Colors.green.shade600,
                      width: 2),
                ),
                filled: true,
                fillColor: fillColor,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              keyboardType: TextInputType.number,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Jumlah tidak boleh kosong';
                }
                if (double.tryParse(value) == null) {
                  return 'Masukkan angka yang valid';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? Theme.of(context).cardColor : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final containerColor = isDarkMode
        ? Colors.blue.shade800.withOpacity(0.3)
        : Colors.blue.shade50;
    final borderColor =
        isDarkMode ? Colors.blue.shade600 : Colors.blue.shade200;

    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _selectDate(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: containerColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: borderColor),
                    ),
                    child: Icon(
                      Icons.calendar_today,
                      color: isDarkMode
                          ? Colors.blue.shade300
                          : Colors.blue.shade600,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tanggal',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('dd MMM yyyy', 'id_ID').format(_selectedDate),
                style: TextStyle(
                  fontSize: 13,
                  color:
                      isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? Theme.of(context).cardColor : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final containerColor = isDarkMode
        ? Colors.orange.shade800.withOpacity(0.3)
        : Colors.orange.shade50;
    final borderColor =
        isDarkMode ? Colors.orange.shade600 : Colors.orange.shade200;
    final fillColor = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50;

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
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: borderColor),
                  ),
                  child: Icon(
                    Icons.category,
                    color: isDarkMode
                        ? Colors.orange.shade300
                        : Colors.orange.shade600,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kategori',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Category>>(
              future: _categories,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                } else if (snapshot.hasError) {
                  print('Error loading categories: ${snapshot.error}');
                  return Column(
                    children: [
                      Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          _loadCategories();
                        },
                        child: const Text('Refresh'),
                      ),
                    ],
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  print('No categories found in database');
                  return Column(
                    children: [
                      const Text(
                        'Tidak ada kategori tersedia',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _loadCategories,
                        child: const Text('Refresh'),
                      ),
                    ],
                  );
                }

                final categories = snapshot.data!;

                // Pastikan _selectedCategory adalah valid atau null
                Category? validSelectedCategory = _selectedCategory;
                if (validSelectedCategory != null) {
                  final isValidCategory = categories.any(
                      (c) => c.categoryId == validSelectedCategory!.categoryId);
                  if (!isValidCategory) {
                    validSelectedCategory = null;
                    // Update state dalam frame berikutnya untuk menghindari konflik
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() {
                        _selectedCategory = null;
                      });
                    });
                  }
                }

                return DropdownButtonFormField<Category>(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: isDarkMode
                              ? Colors.orange.shade300
                              : Colors.orange.shade600,
                          width: 2),
                    ),
                    filled: true,
                    fillColor: fillColor,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  value: validSelectedCategory,
                  hint: Text(
                    'Pilih kategori',
                    style: TextStyle(
                      color: isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                  dropdownColor:
                      isDarkMode ? Colors.grey.shade800 : Colors.white,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                  ),
                  items: categories.map((Category category) {
                    return DropdownMenuItem<Category>(
                      value: category,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            category.icon,
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              category.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (Category? newValue) {
                    print(
                        'Category selected: ${newValue?.name} (ID: ${newValue?.categoryId})');
                    setState(() {
                      _selectedCategory = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Pilih kategori';
                    }
                    return null;
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoneyTypeCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? Theme.of(context).cardColor : Colors.white;
    final borderColor =
        isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300;
    final fillColor = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.payment,
                  color: isDarkMode
                      ? Colors.orange.shade300
                      : Colors.orange.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tipe Uang',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<MoneyType>(
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDarkMode
                        ? Colors.orange.shade300
                        : Colors.orange.shade600,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: fillColor,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              value: _selectedMoneyType,
              hint: Text(
                'Pilih tipe uang',
                style: TextStyle(
                  color:
                      isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              dropdownColor: isDarkMode ? Colors.grey.shade800 : Colors.white,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
              ),
              items: MoneyType.values.map((MoneyType type) {
                return DropdownMenuItem<MoneyType>(
                  value: type,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        type.icon,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        type.displayName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (MoneyType? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedMoneyType = newValue;
                  });
                }
              },
              validator: (value) {
                if (value == null) {
                  return 'Pilih tipe uang';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? Theme.of(context).cardColor : Colors.white;
    final borderColor =
        isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300;
    final fillColor = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.purple.shade800.withOpacity(0.3)
                        : Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.description,
                    color: isDarkMode
                        ? Colors.purple.shade300
                        : Colors.purple.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Deskripsi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Catatan pengeluaran (opsional)',
                labelStyle: TextStyle(
                  color:
                      isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: isDarkMode
                          ? Colors.purple.shade300
                          : Colors.purple.shade600,
                      width: 2),
                ),
                filled: true,
                fillColor: fillColor,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              maxLines: 2,
              style: TextStyle(
                fontSize: 16,
                color: textColor,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Deskripsi tidak boleh kosong';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAmountButtons() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? Theme.of(context).cardColor : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.teal.shade800.withOpacity(0.3)
                        : Colors.teal.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.speed,
                    color: isDarkMode
                        ? Colors.teal.shade300
                        : Colors.teal.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Jumlah Cepat',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              children: [
                5000,
                15000,
                20000,
              ].map((amount) {
                return ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 80,
                    maxWidth: 120,
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode
                          ? Colors.teal.shade700
                          : Colors.teal.shade500,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    onPressed: () => _onQuickAmountTap(amount),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Rp ${NumberFormat('#,###', 'id_ID').format(amount)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [Colors.green.shade700, Colors.green.shade500]
              : [Colors.green.shade600, Colors.green.shade400],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(isDarkMode ? 0.3 : 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: _submitForm,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Text(
              'Tambah Pengeluaran',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
