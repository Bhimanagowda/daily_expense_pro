import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class BorrowPage extends StatefulWidget {
  const BorrowPage({super.key});

  @override
  _BorrowPageState createState() => _BorrowPageState();
}

class _BorrowPageState extends State<BorrowPage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  List<Map<String, dynamic>> _borrowList = [];
  double _totalBorrowAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _loadBorrowData();
  }

  Future<void> _loadBorrowData() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? borrowJson = prefs.getStringList('borrowList');
    double? total = prefs.getDouble('totalBorrowAmount');

    if (borrowJson != null) {
      _borrowList = borrowJson.map((itemStr) {
        final item = jsonDecode(itemStr);
        return {
          'firstName': item['firstName'],
          'lastName': item['lastName'],
          'fullName': item['fullName'],
          'amount': item['amount'],
          'description': item['description'],
          'time': DateTime.parse(item['time']),
        };
      }).toList();
    }

    if (total != null) _totalBorrowAmount = total;
    setState(() {});
  }

  Future<void> _saveBorrowData() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> borrowJson = _borrowList.map((item) {
      Map<String, dynamic> itemMap = {
        'firstName': item['firstName'],
        'lastName': item['lastName'],
        'fullName': item['fullName'],
        'amount': item['amount'],
        'description': item['description'],
        'time': (item['time'] as DateTime).toIso8601String(),
      };
      return jsonEncode(itemMap);
    }).toList();

    await prefs.setStringList('borrowList', borrowJson);
    await prefs.setDouble('totalBorrowAmount', _totalBorrowAmount);
  }

  void _addBorrowItem() {
    String firstName = _firstNameController.text.trim();
    String lastName = _lastNameController.text.trim();
    String fullName = "$firstName $lastName".trim();
    double? amount = double.tryParse(_amountController.text.trim());
    String description = _descriptionController.text.trim();

    if (firstName.isNotEmpty && amount != null) {
      setState(() {
        _borrowList.add({
          'firstName': firstName,
          'lastName': lastName,
          'fullName': fullName,
          'amount': amount,
          'description': description,
          'time': DateTime.now(),
        });
        _totalBorrowAmount += amount;
        _firstNameController.clear();
        _lastNameController.clear();
        _amountController.clear();
        _descriptionController.clear();
      });
      _saveBorrowData();

      // Show success popup
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $fullName to Borrow list'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      // Show error popup if fields are empty
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter first name and amount'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Borrow Management'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Add Borrow', icon: Icon(Icons.add)),
              Tab(text: 'Borrow List', icon: Icon(Icons.list)),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildAddBorrowTab(), _buildBorrowListTab()],
        ),
      ),
    );
  }

  Widget _buildAddBorrowTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add New Borrow',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _firstNameController,
                  decoration: InputDecoration(
                    labelText: 'First Name',
                    border: OutlineInputBorder(),
                    hintText: 'Enter first name',
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _lastNameController,
                  decoration: InputDecoration(
                    labelText: 'Last Name',
                    border: OutlineInputBorder(),
                    hintText: 'Enter last name (optional)',
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),

          TextField(
            controller: _amountController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Borrow Amount',
              border: OutlineInputBorder(),
              hintText: 'Enter amount',
              prefixText: '₹',
            ),
          ),
          SizedBox(height: 10),

          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              hintText: 'Enter description (optional)',
            ),
          ),
          SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: _addBorrowItem,
            icon: Icon(Icons.add),
            label: Text('Add Borrow'),
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBorrowListTab() {
    // Group borrow amounts by person
    Map<String, double> personTotals = {};
    for (var item in _borrowList) {
      String fullName = item['fullName'] ?? ''; // Add null check
      double amount = item['amount'] ?? 0.0; // Add null check
      personTotals[fullName] = (personTotals[fullName] ?? 0) + amount;
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Borrow Amount: ₹${_totalBorrowAmount.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),

          // Person breakdown section
          Text(
            'Person Breakdown',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),

          Container(
            height: 120,
            child: personTotals.isEmpty
                ? Center(child: Text('No borrow records found.'))
                : ListView.builder(
                    itemCount: personTotals.length,
                    itemBuilder: (context, index) {
                      String person = personTotals.keys.elementAt(index);
                      double amount = personTotals[person] ?? 0.0;
                      double percentage = _totalBorrowAmount > 0
                          ? (amount / _totalBorrowAmount) * 100
                          : 0.0;

                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            person,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${percentage.toStringAsFixed(1)}% of total',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: Text(
                            '₹${amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          SizedBox(height: 20),
          Text(
            'Borrow List',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),

          Expanded(
            child: _borrowList.isEmpty
                ? Center(child: Text('No borrow records found.'))
                : ListView.builder(
                    itemCount: _borrowList.length,
                    itemBuilder: (context, index) {
                      final item = _borrowList[index];
                      final time = item['time'] as DateTime;
                      final fullName = item['fullName'] ?? ''; // Add null check
                      final description =
                          item['description'] ?? ''; // Add null check

                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (description.isNotEmpty)
                                Text(description), // Fixed the quote issue
                              Text(
                                'Date: ${time.toString().substring(0, 16)}',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: Text(
                            '₹${(item['amount'] ?? 0.0).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBorrowChart(Map<String, double> personTotals) {
    if (personTotals.isEmpty) return Container();

    // Create chart colors
    final List<Color> chartColors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];

    // Create pie chart sections
    List<PieChartSectionData> sections = [];
    int colorIndex = 0;

    personTotals.forEach((person, amount) {
      double percentage = (amount / _totalBorrowAmount) * 100;
      sections.add(
        PieChartSectionData(
          color: chartColors[colorIndex % chartColors.length],
          value: amount,
          title: percentage > 5 ? '${percentage.toStringAsFixed(1)}%' : '',
          radius: 60,
          titleStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      colorIndex++;
    });

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
              pieTouchData: PieTouchData(enabled: false),
            ),
          ),
        ),
        SizedBox(height: 20),

        // Legend
        ...personTotals.entries.map((entry) {
          int index = personTotals.keys.toList().indexOf(entry.key);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  color: chartColors[index % chartColors.length],
                ),
                SizedBox(width: 8),
                Expanded(child: Text(entry.key)),
                Text(
                  '₹${entry.value.toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
