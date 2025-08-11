// pages/edit_expense_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../models/money_type.dart';
import '../services/database_service.dart';
import '../services/balance_reset_service.dart';

class EditExpensePage extends StatefulWidget {
  final Expense expense;
  const EditExpensePage({super.key, required this.expense});

  @override
  State<EditExpensePage> createState() => _EditExpensePageState();
}

class _EditExpensePageState extends State<EditExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _dbService = DatabaseService();
  final _balanceService = BalanceResetService();

  late Future<List<Category>> _categories;
  Category? _selectedCategory;
  late MoneyType _selectedMoneyType;
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _descriptionController =
        TextEditingController(text: widget.expense.description);
    _amountController =
        TextEditingController(text: widget.expense.amount.toString());
    _selectedDate = widget.expense.expenseDate;
    _selectedMoneyType = widget.expense.moneyType;

    print(
        'EditExpensePage: Loading categories for expense with categoryId: ${widget.expense.categoryId}');
    _loadCategoriesAndSelectCurrent();
  }

  Future<void> _loadCategoriesAndSelectCurrent() async {
    try {
      final categories = await _dbService.getCategories();
      print('EditExpensePage: Loaded ${categories.length} categories');

      // Cari kategori yang sesuai dengan expense
      final currentCategory = categories.firstWhere(
        (c) => c.categoryId == widget.expense.categoryId,
        orElse: () => categories.isNotEmpty
            ? categories.first
            : Category(
                categoryId: -1,
                name: 'Unknown Category',
                icon: '❓',
                color: 'grey',
                createdAt: DateTime.now(),
              ),
      );

      if (mounted) {
        setState(() {
          _categories = Future.value(categories);
          _selectedCategory = currentCategory;
        });
        print(
            'EditExpensePage: Selected category: ${currentCategory.name} (ID: ${currentCategory.categoryId})');
      }
    } catch (error) {
      print('EditExpensePage: Error loading categories: $error');
      if (mounted) {
        setState(() {
          _categories = Future.error(error);
        });
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
    if (_formKey.currentState!.validate() && _selectedCategory != null) {
      try {
        final newAmount = double.parse(_amountController.text);
        final amountDifference = newAmount - widget.expense.amount;

        // Check if the updated expense will make remaining balance negative
        if (amountDifference > 0) {
          final remainingBalance = await _balanceService
              .calculateRemainingBalance(widget.expense.userId);
          final newRemainingBalance = remainingBalance - amountDifference;

          if (newRemainingBalance < 0) {
            // Show warning dialog
            final shouldContinue = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Peringatan Saldo'),
                content: Text(
                    'Perubahan pengeluaran ini akan membuat saldo tersisa menjadi negatif.\n\n'
                    'Saldo tersisa saat ini: Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '').format(remainingBalance)}\n'
                    'Setelah perubahan: Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '').format(newRemainingBalance)}\n\n'
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
        }

        final updatedExpense = Expense(
          expenseId: widget.expense.expenseId,
          userId: widget.expense.userId,
          categoryId: _selectedCategory!.categoryId!,
          amount: newAmount,
          description: _descriptionController.text,
          expenseDate: _selectedDate,
          moneyType: _selectedMoneyType,
          createdAt: widget.expense.createdAt,
          updatedAt: DateTime.now(),
        );

        await _dbService.updateExpense(updatedExpense);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Pengeluaran berhasil diperbarui!'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error memperbarui pengeluaran: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mohon lengkapi semua field dan pilih kategori'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Edit Pengeluaran',
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
              // Header Card dengan informasi expense
              _buildExpenseInfoCard(),

              const SizedBox(height: 24),

              // Amount Input dengan design menarik
              _buildAmountCard(),

              const SizedBox(height: 20),

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

  Widget _buildExpenseInfoCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [Colors.orange.shade800, Colors.orange.shade600]
              : [Colors.orange.shade600, Colors.orange.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(isDarkMode ? 0.2 : 0.3),
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
              Icons.edit,
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
                  'Edit Pengeluaran',
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
                    'Rp ${NumberFormat('#,###').format(widget.expense.amount)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    DateFormat('dd MMMM yyyy', 'id_ID')
                        .format(widget.expense.expenseDate),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
                  Icon(
                    Icons.calendar_today,
                    color: isDarkMode
                        ? Colors.blue.shade300
                        : Colors.blue.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tanggal',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  DateFormat('dd MMM yyyy', 'id_ID').format(_selectedDate),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? Colors.blue.shade300
                        : Colors.blue.shade700,
                  ),
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
    final fillColor = isDarkMode
        ? Colors.orange.shade800.withOpacity(0.3)
        : Colors.orange.shade50;
    final borderColor =
        isDarkMode ? Colors.orange.shade600 : Colors.orange.shade200;

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
                  Icons.category,
                  color: isDarkMode
                      ? Colors.orange.shade300
                      : Colors.orange.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Kategori',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
                  return const Text(
                    'Error loading',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text(
                    'No categories',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  );
                }

                final categories = snapshot.data!;

                // Pastikan _selectedCategory adalah valid atau cari yang sesuai
                Category? validSelectedCategory = _selectedCategory;
                if (validSelectedCategory != null) {
                  final isValidCategory = categories.any(
                      (c) => c.categoryId == validSelectedCategory!.categoryId);
                  if (!isValidCategory) {
                    // Coba cari kategori berdasarkan expense.categoryId
                    validSelectedCategory = categories.firstWhere(
                      (c) => c.categoryId == widget.expense.categoryId,
                      orElse: () => categories.isNotEmpty
                          ? categories.first
                          : Category(
                              categoryId: -1,
                              name: 'Unknown Category',
                              icon: '❓',
                              color: 'grey',
                              createdAt: DateTime.now(),
                            ),
                    );
                    // Update state dalam frame berikutnya
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() {
                        _selectedCategory = validSelectedCategory;
                      });
                    });
                  }
                } else if (categories.isNotEmpty) {
                  // Jika tidak ada kategori yang dipilih, cari berdasarkan expense
                  validSelectedCategory = categories.firstWhere(
                    (c) => c.categoryId == widget.expense.categoryId,
                    orElse: () => categories.first,
                  );
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() {
                      _selectedCategory = validSelectedCategory;
                    });
                  });
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
                        'EditExpensePage: Category selected: ${newValue?.name} (ID: ${newValue?.categoryId})');
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
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final borderColor =
        isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300;
    final fillColor = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50;

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
                  'Deskripsi Pengeluaran',
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
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ceritakan tentang pengeluaran ini...',
                hintStyle: TextStyle(
                  color:
                      isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
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
                contentPadding: const EdgeInsets.all(16),
              ),
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

  Widget _buildSubmitButton() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [Colors.blue.shade800, Colors.blue.shade700]
              : [Colors.blue.shade600, Colors.blue.shade500],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            _submitForm();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.save,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Update Pengeluaran',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
