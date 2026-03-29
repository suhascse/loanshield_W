import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ExpensesTrackerTab extends StatefulWidget {
  const ExpensesTrackerTab({super.key});

  @override
  State<ExpensesTrackerTab> createState() => _ExpensesTrackerTabState();
}

class _ExpensesTrackerTabState extends State<ExpensesTrackerTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final List<Expense> _expenses = [
    Expense(
      category: 'Food & Dining',
      amount: 5000,
      icon: Icons.restaurant,
      color: const Color(0xFFE74C3C),
      date: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Expense(
      category: 'Transportation',
      amount: 3000,
      icon: Icons.directions_car,
      color: const Color(0xFF3498DB),
      date: DateTime.now().subtract(const Duration(days: 5)),
    ),
    Expense(
      category: 'Shopping',
      amount: 8000,
      icon: Icons.shopping_bag,
      color: const Color(0xFF9B59B6),
      date: DateTime.now().subtract(const Duration(days: 7)),
    ),
    Expense(
      category: 'Entertainment',
      amount: 2000,
      icon: Icons.movie,
      color: const Color(0xFFE67E22),
      date: DateTime.now().subtract(const Duration(days: 10)),
    ),
    Expense(
      category: 'Utilities',
      amount: 4000,
      icon: Icons.lightbulb,
      color: const Color(0xFFF39C12),
      date: DateTime.now().subtract(const Duration(days: 15)),
    ),
  ];

  double get _totalExpenses => _expenses.fold(0, (sum, expense) => sum + expense.amount);
  final double _monthlyBudget = 50000;

  void _showAddExpenseDialog() {
    final amountController = TextEditingController();
    String selectedCategory = 'Food & Dining';
    
    final categories = [
      {'name': 'Food & Dining', 'icon': Icons.restaurant, 'color': const Color(0xFFE74C3C)},
      {'name': 'Transportation', 'icon': Icons.directions_car, 'color': const Color(0xFF3498DB)},
      {'name': 'Shopping', 'icon': Icons.shopping_bag, 'color': const Color(0xFF9B59B6)},
      {'name': 'Entertainment', 'icon': Icons.movie, 'color': const Color(0xFFE67E22)},
      {'name': 'Utilities', 'icon': Icons.lightbulb, 'color': const Color(0xFFF39C12)},
      {'name': 'Healthcare', 'icon': Icons.local_hospital, 'color': const Color(0xFF27AE60)},
      {'name': 'Education', 'icon': Icons.school, 'color': const Color(0xFF1ABC9C)},
      {'name': 'Other', 'icon': Icons.more_horiz, 'color': const Color(0xFF95A5A6)},
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Expense'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: categories
                    .map((cat) => DropdownMenuItem(
                          value: cat['name'] as String,
                          child: Row(
                            children: [
                              Icon(cat['icon'] as IconData, color: cat['color'] as Color, size: 20),
                              const SizedBox(width: 12),
                              Text(cat['name'] as String),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (value) => setDialogState(() => selectedCategory = value!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (amountController.text.isNotEmpty) {
                  final category = categories.firstWhere((cat) => cat['name'] == selectedCategory);
                  setState(() {
                    _expenses.insert(
                      0,
                      Expense(
                        category: selectedCategory,
                        amount: double.parse(amountController.text),
                        icon: category['icon'] as IconData,
                        color: category['color'] as Color,
                        date: DateTime.now(),
                      ),
                    );
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    double budgetUsedPercentage = (_totalExpenses / _monthlyBudget) * 100;
    bool isOverBudget = _totalExpenses > _monthlyBudget;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Expenses'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddExpenseDialog,
            tooltip: 'Add Expense',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Budget Overview Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isOverBudget
                      ? [const Color(0xFFE74C3C), const Color(0xFFE74C3C).withOpacity(0.7)]
                      : [const Color(0xFF0B3C5D), const Color(0xFF1ABC9C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0B3C5D).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Expenses',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${budgetUsedPercentage.toStringAsFixed(0)}% Used',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹ ${_totalExpenses.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '/ ₹ ${_monthlyBudget.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (budgetUsedPercentage / 100).clamp(0.0, 1.0),
                      minHeight: 12,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isOverBudget ? Colors.white : Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isOverBudget
                            ? 'Over budget by ₹${(_totalExpenses - _monthlyBudget).toStringAsFixed(0)}'
                            : 'Remaining: ₹${(_monthlyBudget - _totalExpenses).toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isOverBudget)
                        const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Category Breakdown
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Spending by Category',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B3C5D),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._getCategoryTotals().entries.map((entry) {
                    return _buildCategoryBar(
                      entry.key['name'] as String,
                      entry.key['icon'] as IconData,
                      entry.key['color'] as Color,
                      entry.value,
                      _totalExpenses,
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Recent Transactions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Transactions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B3C5D),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ..._expenses.take(10).map((expense) => _buildExpenseCard(expense)).toList(),
          ],
        ),
      ),
    );
  }

  Map<Map<String, dynamic>, double> _getCategoryTotals() {
    Map<Map<String, dynamic>, double> totals = {};
    
    for (var expense in _expenses) {
      var key = {
        'name': expense.category,
        'icon': expense.icon,
        'color': expense.color,
      };
      
      var existingKey = totals.keys.firstWhere(
        (k) => k['name'] == expense.category,
        orElse: () => key,
      );
      
      if (totals.containsKey(existingKey)) {
        totals[existingKey] = totals[existingKey]! + expense.amount;
      } else {
        totals[key] = expense.amount;
      }
    }
    
    return totals;
  }

  Widget _buildCategoryBar(String category, IconData icon, Color color, double amount, double total) {
    double percentage = (amount / total) * 100;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C2C2C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '₹ ${amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: expense.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(expense.icon, color: expense.color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.category,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C2C2C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(expense.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₹ ${expense.amount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0B3C5D),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '$difference days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class Expense {
  final String category;
  final double amount;
  final IconData icon;
  final Color color;
  final DateTime date;

  Expense({
    required this.category,
    required this.amount,
    required this.icon,
    required this.color,
    required this.date,
  });
}