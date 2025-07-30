import 'package:flutter/material.dart';
import 'cost_split_page.dart';

class IndividualShareBillPage extends StatelessWidget {
  final Group group;

  const IndividualShareBillPage({super.key, required this.group});

  Map<String, double> _calculateIndividualAmounts() {
    Map<String, double> amounts = {};

    // Initialize all members with 0
    for (String member in group.members) {
      amounts[member] = 0.0;
    }

    // Calculate total amount each member owes
    for (var expense in group.expenses) {
      double splitAmount = expense['splitAmount'] as double;
      for (String member in group.members) {
        amounts[member] = amounts[member]! + splitAmount;
      }
    }

    return amounts;
  }

  @override
  Widget build(BuildContext context) {
    final individualAmounts = _calculateIndividualAmounts();

    return Scaffold(
      appBar: AppBar(
        title: Text('Individual Share Bill'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Total Expenses: ${group.expenses.length}',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            Text(
              'Individual Share Details:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            Expanded(
              child: ListView.builder(
                itemCount: group.members.length,
                itemBuilder: (context, index) {
                  String member = group.members[index];
                  double amount = individualAmounts[member] ?? 0.0;

                  return Card(
                    margin: EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.blue,
                            radius: 25,
                            child: Text(
                              member[0].toUpperCase(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Total Share Amount',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Text(
                              '₹${amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
