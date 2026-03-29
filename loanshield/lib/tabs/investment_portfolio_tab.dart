import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InvestmentPortfolioTab extends StatefulWidget {
  const InvestmentPortfolioTab({super.key});

  @override
  State<InvestmentPortfolioTab> createState() => _InvestmentPortfolioTabState();
}

class _InvestmentPortfolioTabState extends State<InvestmentPortfolioTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final List<Investment> _investments = [
    Investment(
      name: 'Mutual Fund - Growth',
      amount: 50000,
      currentValue: 56000,
      type: 'Mutual Fund',
      date: DateTime(2024, 6, 15),
    ),
    Investment(
      name: 'Fixed Deposit',
      amount: 100000,
      currentValue: 107500,
      type: 'FD',
      date: DateTime(2024, 1, 1),
    ),
    Investment(
      name: 'Stocks - Tech Sector',
      amount: 75000,
      currentValue: 82500,
      type: 'Stocks',
      date: DateTime(2024, 8, 20),
    ),
  ];

  double get _totalInvested => _investments.fold(0, (sum, inv) => sum + inv.amount);
  double get _totalCurrentValue => _investments.fold(0, (sum, inv) => sum + inv.currentValue);
  double get _totalReturns => _totalCurrentValue - _totalInvested;
  double get _returnPercentage => (_totalReturns / _totalInvested) * 100;

  void _showAddInvestmentDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final currentValueController = TextEditingController();
    String selectedType = 'Mutual Fund';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Investment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Investment Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: ['Mutual Fund', 'FD', 'Stocks', 'Bonds', 'Gold', 'Other']
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (value) => selectedType = value!,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Invested Amount',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: currentValueController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Current Value',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  amountController.text.isNotEmpty &&
                  currentValueController.text.isNotEmpty) {
                setState(() {
                  _investments.add(
                    Investment(
                      name: nameController.text,
                      amount: double.parse(amountController.text),
                      currentValue: double.parse(currentValueController.text),
                      type: selectedType,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Investment Portfolio'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddInvestmentDialog,
            tooltip: 'Add Investment',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Portfolio Summary Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _totalReturns >= 0
                      ? [const Color(0xFF27AE60), const Color(0xFF27AE60).withOpacity(0.7)]
                      : [const Color(0xFFE74C3C), const Color(0xFFE74C3C).withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (_totalReturns >= 0 ? const Color(0xFF27AE60) : const Color(0xFFE74C3C))
                        .withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Total Portfolio Value',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹ ${_totalCurrentValue.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem('Invested', '₹ ${_totalInvested.toStringAsFixed(0)}'),
                      Container(height: 40, width: 1, color: Colors.white30),
                      _buildSummaryItem(
                        'Returns',
                        '${_totalReturns >= 0 ? '+' : ''}₹ ${_totalReturns.toStringAsFixed(0)}',
                      ),
                      Container(height: 40, width: 1, color: Colors.white30),
                      _buildSummaryItem(
                        'Return %',
                        '${_returnPercentage >= 0 ? '+' : ''}${_returnPercentage.toStringAsFixed(1)}%',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Investment Type Distribution
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
                    'Asset Distribution',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B3C5D),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._getAssetDistribution().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildDistributionBar(
                        entry.key,
                        entry.value,
                        _totalInvested,
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Investments List
            const Text(
              'Your Investments',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B3C5D),
              ),
            ),
            const SizedBox(height: 12),
            
            ..._investments.map((investment) => _buildInvestmentCard(investment)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Map<String, double> _getAssetDistribution() {
    Map<String, double> distribution = {};
    for (var investment in _investments) {
      distribution[investment.type] = (distribution[investment.type] ?? 0) + investment.amount;
    }
    return distribution;
  }

  Widget _buildDistributionBar(String type, double amount, double total) {
    double percentage = (amount / total) * 100;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              type,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C2C2C),
              ),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1ABC9C),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1ABC9C)),
          ),
        ),
      ],
    );
  }

  Widget _buildInvestmentCard(Investment investment) {
    double returns = investment.currentValue - investment.amount;
    double returnPercentage = (returns / investment.amount) * 100;
    bool isProfit = returns >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      investment.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C2C2C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1ABC9C).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        investment.type,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1ABC9C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isProfit
                      ? const Color(0xFF27AE60).withOpacity(0.1)
                      : const Color(0xFFE74C3C).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isProfit ? Icons.trending_up : Icons.trending_down,
                      size: 16,
                      color: isProfit ? const Color(0xFF27AE60) : const Color(0xFFE74C3C),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${returnPercentage >= 0 ? '+' : ''}${returnPercentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isProfit ? const Color(0xFF27AE60) : const Color(0xFFE74C3C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invested',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹ ${investment.amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C2C2C),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Current Value',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹ ${investment.currentValue.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1ABC9C),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class Investment {
  final String name;
  final double amount;
  final double currentValue;
  final String type;
  final DateTime date;

  Investment({
    required this.name,
    required this.amount,
    required this.currentValue,
    required this.type,
    required this.date,
  });
}