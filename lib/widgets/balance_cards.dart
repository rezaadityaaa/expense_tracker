// widgets/balance_cards.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../services/balance_reset_service.dart';

class BalanceCards extends StatelessWidget {
  final double totalBalance;
  final List<Expense> expenses;
  final VoidCallback onBalanceChanged;

  const BalanceCards({
    super.key,
    required this.totalBalance,
    required this.expenses,
    required this.onBalanceChanged,
  });

  @override
  Widget build(BuildContext context) {
    final totalExpenses =
        expenses.fold<double>(0, (sum, expense) => sum + expense.amount);
    final remainingBalance = totalBalance - totalExpenses;

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
              onPressed: () => _showBalanceDialog(context),
              tooltip: 'Edit Saldo',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildBalanceCard(
                context,
                'Saldo Mingguan',
                totalBalance,
                Colors.blue,
                Icons.account_balance,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBalanceCard(
                context,
                'Saldo Tersisa',
                remainingBalance,
                remainingBalance >= 0 ? Colors.green : Colors.red,
                remainingBalance >= 0 ? Icons.wallet : Icons.warning,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBalanceCard(
    BuildContext context,
    String title,
    double amount,
    Color color,
    IconData icon, {
    String? subtitle,
  }) {
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

  void _showBalanceDialog(BuildContext context) {
    final totalController =
        TextEditingController(text: totalBalance.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Saldo Mingguan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: totalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Saldo Mingguan',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Saldo akan otomatis direset setiap hari Senin dengan nilai awal = saldo tersisa minggu sebelumnya',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newBalance =
                  double.tryParse(totalController.text) ?? totalBalance;
              await BalanceResetService().saveBalance(newBalance);
              Navigator.pop(context);
              onBalanceChanged();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
