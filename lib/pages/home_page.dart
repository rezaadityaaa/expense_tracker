// pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart'; // Import slidable
import '../models/expense.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import 'add_expense_page.dart';
import 'edit_expense_page.dart'; // Halaman edit pengeluaran

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _dbService = DatabaseService();
  late Future<List<Expense>> _allExpenses;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'date'; // 'date', 'amount', 'category'
  bool _sortAscending = false; // false = descending (newest first)

  // Contoh user ID yang aktif
  final int _currentUserId = 1;

  @override
  void initState() {
    super.initState();
    _fetchExpenses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _fetchExpenses() {
    setState(() {
      _allExpenses = _dbService.getExpensesByUser(_currentUserId);
    });
  }

  void _navigateToAddExpense() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddExpensePage()),
    );
    if (result == true) {
      _fetchExpenses();
    }
  }

  // Metode untuk menghapus pengeluaran
  void _deleteExpense(int expenseId) async {
    final expense = await _dbService.getExpensesByUser(_currentUserId).then(
          (expenses) => expenses.firstWhere((e) => e.expenseId == expenseId),
        );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('Konfirmasi Hapus'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Apakah Anda yakin ingin menghapus pengeluaran ini?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.description,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rp ${NumberFormat('#,###').format(expense.amount)}',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    DateFormat('dd MMM yyyy, HH:mm')
                        .format(expense.expenseDate),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tindakan ini tidak dapat dibatalkan.',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dbService.deleteExpense(expenseId);
        _fetchExpenses();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Pengeluaran "${expense.description}" berhasil dihapus'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error menghapus pengeluaran: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Metode untuk navigasi ke halaman edit
  void _navigateToEditExpense(Expense expense) async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditExpensePage(expense: expense),
        ),
      );
      if (result == true) {
        _fetchExpenses();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pengeluaran berhasil diperbarui'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error membuka halaman edit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddExpense,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildSummaryCard(),
        _buildSearchBox(),
        _buildSortFilterBar(),
        Expanded(
          child: FutureBuilder<List<Expense>>(
            future: _allExpenses,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('Belum ada pengeluaran.'));
              }

              // Pengelompokan data
              final groupedExpenses = _groupExpensesByDate(snapshot.data!);

              if (groupedExpenses.isEmpty && _searchQuery.isNotEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tidak ada hasil untuk "$_searchQuery"',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (groupedExpenses.isEmpty) {
                return const Center(child: Text('Belum ada pengeluaran.'));
              }

              return ListView.builder(
                itemCount: groupedExpenses.keys.length,
                itemBuilder: (context, index) {
                  final date = groupedExpenses.keys.elementAt(index);
                  final expenses = groupedExpenses[date]!;
                  return _buildDailyExpenseGroup(date, expenses);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: 'Cari pengeluaran...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: (query) {
          setState(() {
            _searchQuery = query.toLowerCase();
          });
        },
      ),
    );
  }

  Widget _buildSummaryCard() {
    return FutureBuilder<List<Expense>>(
      future: _allExpenses,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }

        final expenses = snapshot.data!;
        final filteredExpenses = _getFilteredExpenses(expenses);
        final totalAmount = filteredExpenses.fold<double>(
            0, (sum, expense) => sum + expense.amount);
        final totalCount = filteredExpenses.length;

        return Container(
          margin: const EdgeInsets.all(16),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.receipt_long,
                          color: Colors.blue.shade700, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Pengeluaran',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Rp ${NumberFormat('#,###').format(totalAmount)}',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '$totalCount transaksi',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_searchQuery.isNotEmpty ||
                      _sortBy != 'date' ||
                      _sortAscending) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.filter_list,
                            color: Colors.orange.shade600, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Filter aktif${_searchQuery.isNotEmpty ? ' • Pencarian: "$_searchQuery"' : ''}',
                          style: TextStyle(
                            color: Colors.orange.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Expense> _getFilteredExpenses(List<Expense> expenses) {
    List<Expense> filtered = expenses;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((expense) {
        return expense.description
            .toLowerCase()
            .contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Sort expenses
    filtered.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'amount':
          comparison = a.amount.compareTo(b.amount);
          break;
        case 'description':
          comparison = a.description.compareTo(b.description);
          break;
        case 'date':
        default:
          comparison = a.expenseDate.compareTo(b.expenseDate);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  Map<String, List<Expense>> _groupExpensesByDate(List<Expense> expenses) {
    // Filter berdasarkan search query
    final filteredExpenses = expenses.where((expense) {
      if (_searchQuery.isEmpty) return true;
      return expense.description.toLowerCase().contains(_searchQuery) ||
          expense.amount.toString().contains(_searchQuery);
    }).toList();

    // Sort expenses berdasarkan pilihan user
    filteredExpenses.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'amount':
          comparison = a.amount.compareTo(b.amount);
          break;
        case 'category':
          comparison = a.categoryId.compareTo(b.categoryId);
          break;
        case 'date':
        default:
          comparison = a.expenseDate.compareTo(b.expenseDate);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    final Map<String, List<Expense>> grouped = {};
    for (var expense in filteredExpenses) {
      final dateKey = DateFormat('yyyy-MM-dd').format(expense.expenseDate);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(expense);
    }

    // Sort each day's expenses too
    for (var key in grouped.keys) {
      grouped[key]!.sort((a, b) {
        int comparison;
        switch (_sortBy) {
          case 'amount':
            comparison = a.amount.compareTo(b.amount);
            break;
          case 'category':
            comparison = a.categoryId.compareTo(b.categoryId);
            break;
          case 'date':
          default:
            comparison = a.createdAt.compareTo(b.createdAt);
            break;
        }
        return _sortAscending ? comparison : -comparison;
      });
    }

    return grouped;
  }

  Widget _buildDailyExpenseGroup(String date, List<Expense> expenses) {
    final totalAmount =
        expenses.fold<double>(0, (sum, item) => sum + item.amount);
    final dateString = _formatDateHeader(date);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ExpansionTile(
        title: Text(
          dateString,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: Text(
          'Rp ${totalAmount.toStringAsFixed(0)}',
          style:
              const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        children:
            expenses.map((expense) => _buildExpenseItem(expense)).toList(),
      ),
    );
  }

  String _formatDateHeader(String dateKey) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final yesterday = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 1)));
    if (dateKey == today) {
      return 'Hari Ini';
    } else if (dateKey == yesterday) {
      return 'Kemarin';
    } else {
      return DateFormat('EEEE, d MMMM yyyy', 'id_ID')
          .format(DateTime.parse(dateKey));
    }
  }

  Widget _buildExpenseItem(Expense expense) {
    return FutureBuilder<List<Category>>(
      future: _dbService.getCategories(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }
        final category = snapshot.data!
            .firstWhere((c) => c.categoryId == expense.categoryId);

        return Slidable(
          key: ValueKey(expense.expenseId),
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            children: [
              SlidableAction(
                onPressed: (context) => _navigateToEditExpense(expense),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                icon: Icons.edit,
                label: 'Edit',
              ),
              SlidableAction(
                onPressed: (context) => _deleteExpense(expense.expenseId!),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                icon: Icons.delete,
                label: 'Hapus',
              ),
            ],
          ),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      Color(int.parse(category.color.replaceAll('#', '0xff')))
                          .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  category.icon,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              title: Text(
                expense.description,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: TextStyle(
                      color: Color(
                          int.parse(category.color.replaceAll('#', '0xff'))),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    DateFormat('dd MMM yyyy, HH:mm')
                        .format(expense.expenseDate),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rp ${NumberFormat('#,###').format(expense.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Geser untuk aksi',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              isThreeLine: true,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Text(
            'Urutkan:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSortChip('date', 'Tanggal', Icons.calendar_today),
                  const SizedBox(width: 8),
                  _buildSortChip('amount', 'Jumlah', Icons.attach_money),
                  const SizedBox(width: 8),
                  _buildSortChip('category', 'Kategori', Icons.category),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              color: Colors.blue.shade700,
            ),
            onPressed: () {
              setState(() {
                _sortAscending = !_sortAscending;
              });
            },
            tooltip: _sortAscending ? 'Urutkan Menurun' : 'Urutkan Menaik',
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String value, String label, IconData icon) {
    final isSelected = _sortBy == value;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _sortBy = value;
          });
        }
      },
      selectedColor: Colors.blue.shade700,
      backgroundColor: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}
