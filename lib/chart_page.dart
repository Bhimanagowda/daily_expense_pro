import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ChartPage extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final double totalAmount;
  final List<String> categories;

  ChartPage({
    super.key,
    required this.items,
    required this.totalAmount,
    required this.categories,
  });

  // Colors for the pie chart - using more distinct colors
  final List<Color> _chartColors = [
    Colors.amber, // Yellow
    Colors.redAccent, // Red
    Colors.blue, // Blue
    Colors.green, // Green
    Colors.purple, // Purple
    Colors.teal, // Teal
    Colors.pink, // Pink
    Colors.orange, // Orange
    Colors.indigo, // Indigo
    Colors.brown, // Brown
    Colors.cyan, // Cyan
    Colors.deepOrange, // Deep Orange
  ];

  // Calculate category totals
  Map<String, double> _getCategoryTotals() {
    Map<String, double> totals = {};

    // Initialize all categories with 0
    for (String category in categories.skip(1)) {
      // Skip the "Categories" prompt
      totals[category] = 0;
    }

    // Sum up expenses by category
    for (var item in items) {
      // Add null checks to prevent errors
      String category = item['category'] as String? ?? 'Others';
      double price = (item['price'] as num?)?.toDouble() ?? 0.0;
      totals[category] = (totals[category] ?? 0) + price;
    }

    return totals;
  }

  // Calculate payment method totals
  Map<String, double> _getPaymentMethodTotals() {
    Map<String, double> totals = {'Cash': 0.0, 'Online': 0.0};

    for (var item in items) {
      String paymentMethod = item['paymentMethod'] as String? ?? 'Cash';
      double price = (item['price'] as num?)?.toDouble() ?? 0.0;
      totals[paymentMethod] = (totals[paymentMethod] ?? 0) + price;
    }

    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final safeTotal = totalAmount > 0 ? totalAmount : 0.1;
    Map<String, double> categoryTotals = _getCategoryTotals();
    Map<String, double> paymentTotals = _getPaymentMethodTotals();

    final Map<String, Color> categoryColors = {};
    int colorIndex = 0;

    for (var entry in categoryTotals.entries.where((e) => e.value > 0)) {
      categoryColors[entry.key] =
          _chartColors[colorIndex % _chartColors.length];
      colorIndex++;
    }

    return Scaffold(
      appBar: AppBar(title: Text('Expense Analysis')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Payment Method Summary
            Text(
              'Payment Method Summary',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(Icons.money, color: Colors.green, size: 30),
                          SizedBox(height: 8),
                          Text(
                            'Cash',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            '₹${paymentTotals['Cash']!.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(Icons.credit_card, color: Colors.blue, size: 30),
                          SizedBox(height: 8),
                          Text(
                            'Online',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            '₹${paymentTotals['Online']!.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 30),

            Text(
              'Spending by Category',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),

            // If no data, show a message
            if (items.isEmpty)
              SizedBox(
                height: 200,
                child: Center(child: Text('No data to display')),
              )
            else
              _buildPieChart(categoryTotals, safeTotal, categoryColors),

            SizedBox(height: 30),

            Text(
              'Category Breakdown',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),

            // Category breakdown list
            ...categoryTotals.entries.where((e) => e.value > 0).map((entry) {
              double percentage = (entry.value / safeTotal) * 100;

              return Card(
                margin: EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    width: 24,
                    height: 24,
                    color: categoryColors[entry.key],
                  ),
                  title: Text(entry.key),
                  subtitle: Text('${percentage.toStringAsFixed(1)}%'),
                  trailing: Text(
                    '₹${entry.value.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(
    Map<String, double> categoryTotals,
    double safeTotal,
    Map<String, Color> categoryColors,
  ) {
    // Prepare pie chart sections
    List<PieChartSectionData> sections = [];

    categoryTotals.forEach((category, amount) {
      // Only add categories with spending
      if (amount > 0) {
        double percentage = (amount / safeTotal) * 100;

        // Only show text label if the section is large enough (more than 5%)
        String title = percentage > 0
            ? '${percentage.toStringAsFixed(1)}%'
            : '';

        sections.add(
          PieChartSectionData(
            color: categoryColors[category]!,
            value: amount,
            title: title,
            radius: 60,
            titleStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      }
    });

    return SizedBox(
      height: 300,
      child: PieChart(
        PieChartData(
          sections: sections,
          centerSpaceRadius: 40,
          sectionsSpace: 2,
          pieTouchData: PieTouchData(enabled: false),
        ),
      ),
    );
  }
}
