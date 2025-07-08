import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LendPage extends StatefulWidget {
  const LendPage({super.key});

  @override
  _LendPageState createState() => _LendPageState();
}

class _LendPageState extends State<LendPage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  List<Map<String, dynamic>> _lendList = [];
  double _totalLendAmount = 0.0;

  // Selection mode variables for main list
  bool _isSelectionMode = false;
  List<String> _selectedPersons = [];

  @override
  void initState() {
    super.initState();
    _loadLendData();
  }

  Future<void> _loadLendData() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? lendJson = prefs.getStringList('lendList');
    double? total = prefs.getDouble('totalLendAmount');

    if (lendJson != null) {
      _lendList = lendJson.map((itemStr) {
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

    if (total != null) _totalLendAmount = total;
    setState(() {});
  }

  Future<void> _saveLendData() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> lendJson = _lendList.map((item) {
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

    await prefs.setStringList('lendList', lendJson);
    await prefs.setDouble('totalLendAmount', _totalLendAmount);
  }

  void _addLendItem() {
    String firstName = _firstNameController.text.trim();
    String lastName = _lastNameController.text.trim();
    String fullName = "$firstName $lastName".trim();
    double? amount = double.tryParse(_amountController.text.trim());
    String description = _descriptionController.text.trim();

    if (firstName.isNotEmpty && amount != null) {
      setState(() {
        // Always add as a new transaction (don't combine)
        _lendList.add({
          'firstName': firstName,
          'lastName': lastName,
          'fullName': fullName,
          'amount': amount,
          'description': description,
          'time': DateTime.now(),
        });

        _totalLendAmount += amount;
        _firstNameController.clear();
        _lastNameController.clear();
        _amountController.clear();
        _descriptionController.clear();
      });
      _saveLendData();

      // Show success popup
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $fullName to Lend list'),
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

  void _deleteTransaction(int transactionIndex) {
    setState(() {
      _totalLendAmount -= _lendList[transactionIndex]['amount'];
      _lendList.removeAt(transactionIndex);
    });
    _saveLendData();
  }

  void _editTransaction(int transactionIndex) {
    final item = _lendList[transactionIndex];
    final TextEditingController firstNameController = TextEditingController(
      text: item['firstName'],
    );
    final TextEditingController lastNameController = TextEditingController(
      text: item['lastName'],
    );
    final TextEditingController amountController = TextEditingController(
      text: item['amount'].toString(),
    );
    final TextEditingController descriptionController = TextEditingController(
      text: item['description'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Transaction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: firstNameController,
                    decoration: InputDecoration(
                      labelText: 'First Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: lastNameController,
                    decoration: InputDecoration(
                      labelText: 'Last Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
                prefixText: '₹',
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              String firstName = firstNameController.text.trim();
              String lastName = lastNameController.text.trim();
              String fullName = "$firstName $lastName".trim();
              double? amount = double.tryParse(amountController.text.trim());
              String description = descriptionController.text.trim();

              if (firstName.isNotEmpty && amount != null) {
                setState(() {
                  // Subtract old amount from total
                  _totalLendAmount -= _lendList[transactionIndex]['amount'];
                  // Update the transaction
                  _lendList[transactionIndex]['firstName'] = firstName;
                  _lendList[transactionIndex]['lastName'] = lastName;
                  _lendList[transactionIndex]['fullName'] = fullName;
                  _lendList[transactionIndex]['amount'] = amount;
                  _lendList[transactionIndex]['description'] = description;
                  // Add new amount to total
                  _totalLendAmount += amount;
                });
                _saveLendData();
                Navigator.pop(context);
                // Refresh the history dialog
                Navigator.pop(context);
                _showLendHistory(firstName, lastName);
              }
            },
            child: Text('Update'),
          ),
        ],
      ),
    );
  }

  void _deleteSelectedPersons() {
    setState(() {
      // Remove all transactions for selected persons
      _lendList.removeWhere((item) {
        String personKey = "${item['firstName']} ${item['lastName']}".trim();
        if (_selectedPersons.contains(personKey)) {
          _totalLendAmount -= item['amount'];
          return true;
        }
        return false;
      });
      _selectedPersons.clear();
      _isSelectionMode = false;
    });
    _saveLendData();
  }

  void _showLendHistory(String firstName, String lastName) {
    // Get all transactions for this person
    List<Map<String, dynamic>> personTransactions = _lendList
        .where(
          (item) =>
              item['firstName'] == firstName && item['lastName'] == lastName,
        )
        .toList();

    // Sort by time (newest first)
    personTransactions.sort(
      (a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime),
    );

    // Calculate total amount for this person
    double totalPersonAmount = personTransactions.fold(
      0.0,
      (sum, item) => sum + (item['amount'] ?? 0.0),
    );

    String fullName = "$firstName $lastName".trim();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$fullName - Lend History'),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              Text(
                'Total Amount: ₹${totalPersonAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              SizedBox(height: 10),
              Divider(),
              SizedBox(height: 10),
              Expanded(
                child: personTransactions.isEmpty
                    ? Center(child: Text('No transactions found'))
                    : ListView.builder(
                        itemCount: personTransactions.length,
                        itemBuilder: (context, index) {
                          final transaction = personTransactions[index];
                          final time = transaction['time'] as DateTime;
                          final description = transaction['description'] ?? '';

                          // Find the original index in _lendList
                          int originalIndex = _lendList.indexWhere(
                            (item) =>
                                item['firstName'] == transaction['firstName'] &&
                                item['lastName'] == transaction['lastName'] &&
                                item['time'] == transaction['time'] &&
                                item['amount'] == transaction['amount'],
                          );

                          return Card(
                            margin: EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Line 1: Transaction number and name
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.green.shade100,
                                        radius: 15,
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          '${transaction['firstName']} ${transaction['lastName']}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),

                                  // Line 2: Amount
                                  Text(
                                    '₹${transaction['amount'].toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.green,
                                    ),
                                  ),
                                  SizedBox(height: 4),

                                  // Description and date
                                  if (description.isNotEmpty) ...[
                                    Text(
                                      description,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                  ],
                                  Text(
                                    'Date: ${time.toString().substring(0, 16)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  SizedBox(height: 8),

                                  // Line 3: Edit and Delete buttons
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        icon: Icon(Icons.edit, size: 16),
                                        label: Text('Edit'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                        onPressed: () =>
                                            _editTransaction(originalIndex),
                                      ),
                                      SizedBox(width: 10),
                                      ElevatedButton.icon(
                                        icon: Icon(Icons.delete, size: 16),
                                        label: Text('Delete'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Text('Delete Transaction'),
                                              content: Text(
                                                'Are you sure you want to delete this transaction?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    _deleteTransaction(
                                                      originalIndex,
                                                    );
                                                    Navigator.pop(
                                                      context,
                                                    ); // Close confirmation dialog
                                                    Navigator.pop(
                                                      context,
                                                    ); // Close history dialog
                                                    _showLendHistory(
                                                      firstName,
                                                      lastName,
                                                    ); // Refresh history
                                                  },
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.red,
                                                      ),
                                                  child: Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildAddLendTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add New Lend',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _firstNameController,
                    autocorrect: false,
                    enableSuggestions: false,
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
                    autocorrect: false,
                    enableSuggestions: false,
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
                labelText: 'Lend Amount',
                border: OutlineInputBorder(),
                hintText: 'Enter amount',
                prefixText: '₹',
              ),
            ),
            SizedBox(height: 10),

            TextField(
              controller: _descriptionController,
              maxLines: 3,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                hintText: 'Enter description (optional)',
              ),
            ),
            SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _addLendItem,
              icon: Icon(Icons.add),
              label: Text('Add Lend'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLendListTab() {
    // Group transactions by person
    Map<String, List<Map<String, dynamic>>> groupedLends = {};
    Map<String, double> personTotals = {};

    for (var item in _lendList) {
      String key = "${item['firstName']} ${item['lastName']}".trim();
      if (!groupedLends.containsKey(key)) {
        groupedLends[key] = [];
        personTotals[key] = 0.0;
      }
      groupedLends[key]!.add(item);
      personTotals[key] = personTotals[key]! + (item['amount'] ?? 0.0);
    }

    // Convert to list for ListView
    List<String> personNames = groupedLends.keys.toList();
    personNames.sort(); // Sort alphabetically

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Lend Amount: ₹${_totalLendAmount.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),

          Text(
            'Lend List (${personNames.length} people)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),

          Expanded(
            child: personNames.isEmpty
                ? Center(child: Text('No lend records found.'))
                : ListView.builder(
                    itemCount: personNames.length,
                    itemBuilder: (context, index) {
                      String personName = personNames[index];
                      List<Map<String, dynamic>> personTransactions =
                          groupedLends[personName]!;
                      double totalAmount = personTotals[personName]!;

                      // Get the most recent transaction for display
                      Map<String, dynamic> latestTransaction =
                          personTransactions.reduce(
                            (a, b) =>
                                (a['time'] as DateTime).isAfter(
                                  b['time'] as DateTime,
                                )
                                ? a
                                : b,
                          );

                      String firstName = latestTransaction['firstName'];
                      String lastName = latestTransaction['lastName'];
                      DateTime latestTime =
                          latestTransaction['time'] as DateTime;

                      bool isSelected = _selectedPersons.contains(personName);

                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onLongPress: () {
                            setState(() {
                              _isSelectionMode = true;
                              _selectedPersons.add(personName);
                            });
                          },
                          onTap: _isSelectionMode
                              ? () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedPersons.remove(personName);
                                      if (_selectedPersons.isEmpty) {
                                        _isSelectionMode = false;
                                      }
                                    } else {
                                      _selectedPersons.add(personName);
                                    }
                                  });
                                }
                              : () => _showLendHistory(firstName, lastName),
                          leading: _isSelectionMode
                              ? Checkbox(
                                  value: isSelected,
                                  onChanged: (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        _selectedPersons.add(personName);
                                      } else {
                                        _selectedPersons.remove(personName);
                                        if (_selectedPersons.isEmpty) {
                                          _isSelectionMode = false;
                                        }
                                      }
                                    });
                                  },
                                )
                              : null,
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      personName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${personTransactions.length} transactions',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Last transaction: ${latestTime.toString().substring(0, 16)}',
                                style: TextStyle(fontSize: 12),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Tap to view full history',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                          trailing: Text(
                            '₹${totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(height: 10),
          if (_isSelectionMode)
            Row(
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.delete),
                  label: Text('Delete Selected People'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 174, 158, 156),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Delete Selected People'),
                        content: Text(
                          'Are you sure you want to delete all transactions for ${_selectedPersons.length} selected people?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              _deleteSelectedPersons();
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: Text('Delete All'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Lend Management'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Add Lend', icon: Icon(Icons.add)),
              Tab(text: 'Lend List', icon: Icon(Icons.list)),
            ],
          ),
        ),
        body: TabBarView(children: [_buildAddLendTab(), _buildLendListTab()]),
      ),
    );
  }
}
