import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

class EmiCalculatorTab extends StatefulWidget {
  const EmiCalculatorTab({super.key});

  @override
  State<EmiCalculatorTab> createState() => _EmiCalculatorTabState();
}

class _EmiCalculatorTabState extends State<EmiCalculatorTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _principalController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  
  double _loanAmount = 500000;
  double _interestRate = 10.5;
  int _loanTenure = 5; // in years
  
  double _emiAmount = 0;
  double _totalPayment = 0;
  double _totalInterest = 0;

  @override
  void initState() {
    super.initState();
    _principalController.text = _loanAmount.toStringAsFixed(0);
    _rateController.text = _interestRate.toString();
    _calculateEMI();
  }

  void _calculateEMI() {
    double principal = _loanAmount;
    double monthlyRate = _interestRate / (12 * 100);
    int months = _loanTenure * 12;

    if (monthlyRate == 0) {
      _emiAmount = principal / months;
    } else {
      _emiAmount = principal * monthlyRate * 
          pow(1 + monthlyRate, months) / 
          (pow(1 + monthlyRate, months) - 1);
    }

    _totalPayment = _emiAmount * months;
    _totalInterest = _totalPayment - principal;

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('EMI Calculator'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Result Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0B3C5D), Color(0xFF1ABC9C)],
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
                  const Text(
                    'Monthly EMI',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹ ${_emiAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoColumn(
                        'Principal',
                        '₹ ${_loanAmount.toStringAsFixed(0)}',
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.white30,
                      ),
                      _buildInfoColumn(
                        'Interest',
                        '₹ ${_totalInterest.toStringAsFixed(0)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Payment',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '₹ ${_totalPayment.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Input Section
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
                    'Loan Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B3C5D),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Loan Amount Slider
                  _buildSliderSection(
                    'Loan Amount',
                    _loanAmount,
                    100000,
                    10000000,
                    100000,
                    (value) {
                      setState(() {
                        _loanAmount = value;
                        _principalController.text = value.toStringAsFixed(0);
                        _calculateEMI();
                      });
                    },
                    _principalController,
                  ),
                  const SizedBox(height: 24),

                  // Interest Rate Slider
                  _buildSliderSection(
                    'Interest Rate (% p.a.)',
                    _interestRate,
                    1,
                    30,
                    0.5,
                    (value) {
                      setState(() {
                        _interestRate = value;
                        _rateController.text = value.toStringAsFixed(1);
                        _calculateEMI();
                      });
                    },
                    _rateController,
                  ),
                  const SizedBox(height: 24),

                  // Loan Tenure
                  const Text(
                    'Loan Tenure',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C2C2C),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$_loanTenure Years',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1ABC9C),
                          ),
                        ),
                      ),
                      Text(
                        '${_loanTenure * 12} Months',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _loanTenure.toDouble(),
                    min: 1,
                    max: 30,
                    divisions: 29,
                    activeColor: const Color(0xFF1ABC9C),
                    inactiveColor: Colors.grey.shade300,
                    label: '$_loanTenure years',
                    onChanged: (value) {
                      setState(() {
                        _loanTenure = value.toInt();
                        _calculateEMI();
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Breakdown Chart
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
                    'Payment Breakdown',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B3C5D),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildBreakdownBar(),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildLegend(
                        'Principal',
                        const Color(0xFF0B3C5D),
                        (_loanAmount / _totalPayment * 100).toStringAsFixed(1),
                      ),
                      _buildLegend(
                        'Interest',
                        const Color(0xFF1ABC9C),
                        (_totalInterest / _totalPayment * 100).toStringAsFixed(1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSliderSection(
    String label,
    double value,
    double min,
    double max,
    double divisions,
    Function(double) onChanged,
    TextEditingController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C2C2C),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            prefixText: label.contains('Rate') ? '' : '₹ ',
            suffixText: label.contains('Rate') ? '%' : '',
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1ABC9C),
          ),
          onChanged: (text) {
            if (text.isNotEmpty) {
              double? newValue = double.tryParse(text);
              if (newValue != null && newValue >= min && newValue <= max) {
                onChanged(newValue);
              }
            }
          },
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: ((max - min) / divisions).toInt(),
          activeColor: const Color(0xFF1ABC9C),
          inactiveColor: Colors.grey.shade300,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildBreakdownBar() {
    double principalPercentage = _loanAmount / _totalPayment;
    
    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Expanded(
              flex: (principalPercentage * 100).toInt(),
              child: Container(
                color: const Color(0xFF0B3C5D),
              ),
            ),
            Expanded(
              flex: ((1 - principalPercentage) * 100).toInt(),
              child: Container(
                color: const Color(0xFF1ABC9C),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(String label, Color color, String percentage) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2C2C2C),
              ),
            ),
            Text(
              '$percentage%',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _principalController.dispose();
    _rateController.dispose();
    super.dispose();
  }
}