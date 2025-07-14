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
          'fullName': item['fullName'],
          'firstNameLower':
              item['firstNameLower'] ?? item['firstName'].toLowerCase(),
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
        'fullName': item['firstName'],
        'firstNameLower':
            item['firstNameLower'] ?? item['firstName'].toLowerCase(),
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
    double? amount = double.tryParse(_amountController.text.trim());
    String description = _descriptionController.text.trim();

    if (firstName.isNotEmpty && amount != null) {
      setState(() {
        // Store names in lowercase for case-insensitive comparison
        _lendList.add({
          'firstName': firstName,
          'fullName': firstName, // Use firstName as fullName
          'firstNameLower': firstName.toLowerCase(),
          'amount': amount,
          'description': description,
          'time': DateTime.now(),
        });

        _totalLendAmount += amount;
        _firstNameController.clear();
        _amountController.clear();
        _descriptionController.clear();
      });
      _saveLendData();

      // Show success popup
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $firstName to Lend list'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      // Show error popup if fields are empty
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter name and amount'),
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

    // Replace yellow/black warning with a simple green confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Transaction deleted successfully'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _editTransaction(int transactionIndex) {
    final item = _lendList[transactionIndex];
    final TextEditingController firstNameController = TextEditingController(
      text: item['firstName'],
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
            TextField(
              controller: firstNameController,
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
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
              double? amount = double.tryParse(amountController.text.trim());
              String description = descriptionController.text.trim();

              if (firstName.isNotEmpty && amount != null) {
                setState(() {
                  // Subtract old amount from total
                  _totalLendAmount -= _lendList[transactionIndex]['amount'];
                  // Update the transaction
                  _lendList[transactionIndex]['firstName'] = firstName;
                  _lendList[transactionIndex]['fullName'] = firstName;
                  _lendList[transactionIndex]['firstNameLower'] = firstName
                      .toLowerCase();
                  _lendList[transactionIndex]['amount'] = amount;
                  _lendList[transactionIndex]['description'] = description;
                  // Add new amount to total
                  _totalLendAmount += amount;
                });
                _saveLendData();
                Navigator.pop(context);
                // Refresh the history dialog
                Navigator.pop(context);
                _showLendHistory(firstName);
              }
            },
            child: Text('Update'),
          ),
        ],
      ),
    );
  }

  void _deleteSelectedPersons() {
    // Create a copy of the selected persons for the confirmation message
    List<String> selectedPersonsCopy = List.from(_selectedPersons);

    // Convert to lowercase for case-insensitive comparison
    List<String> selectedPersonsLower = selectedPersonsCopy
        .map((name) => name.toLowerCase())
        .toList();

    // Count how many transactions will be deleted
    int transactionsToDelete = 0;
    double amountToSubtract = 0.0;

    // First calculate what will be deleted
    for (var item in _lendList) {
      String personKey = (item['fullName']?.toString().trim() ?? '')
          .toLowerCase();
      if (selectedPersonsLower.contains(personKey)) {
        transactionsToDelete++;
        amountToSubtract += (item['amount'] is num) ? item['amount'] : 0.0;
      }
    }

    if (transactionsToDelete > 0) {
      setState(() {
        // Create a new list without the selected persons
        List<Map<String, dynamic>> newLendList = [];

        for (var item in _lendList) {
          String personKey = (item['fullName']?.toString().trim() ?? '')
              .toLowerCase();
          if (!selectedPersonsLower.contains(personKey)) {
            newLendList.add(item);
          }
        }

        // Replace the old list with the new one
        _lendList = newLendList;

        // Update the total amount
        _totalLendAmount -= amountToSubtract;
        if (_totalLendAmount < 0) {
          _totalLendAmount = 0; // Prevent negative totals
        }

        // Clear selection mode
        _selectedPersons.clear();
        _isSelectionMode = false;
      });

      // Save the updated data
      _saveLendData();

      // Show confirmation with green background instead of yellow/black
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deleted $transactionsToDelete transactions for ${selectedPersonsCopy.length} people',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      // Show message with green background instead of orange/black
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No transactions found for the selected people'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showLendHistory(String name) {
    // Convert input name to lowercase for case-insensitive comparison
    String nameLower = name.toLowerCase();

    // Get all transactions for this person (case-insensitive)
    List<Map<String, dynamic>> personTransactions = _lendList.where((item) {
      String itemName = (item['firstName'] ?? '').toString().toLowerCase();
      return itemName == nameLower;
    }).toList();

    // Sort by time (newest first)
    personTransactions.sort(
      (a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime),
    );

    // Calculate total amount for this person
    double totalPersonAmount = personTransactions.fold(
      0.0,
      (sum, item) => sum + ((item['amount'] is num) ? item['amount'] : 0.0),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Total: ₹${totalPersonAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: personTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = personTransactions[index];
                      return ListTile(
                        title: Text(
                          '₹${transaction['amount'].toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDateTime(transaction['time'] as DateTime),
                            ),
                            if (transaction['description'] != null &&
                                transaction['description']
                                    .toString()
                                    .isNotEmpty)
                              Text(
                                transaction['description'].toString(),
                                style: TextStyle(fontStyle: FontStyle.italic),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                Navigator.pop(context);
                                _editTransaction(
                                  _lendList.indexOf(transaction),
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                Navigator.pop(context);
                                _showDeleteConfirmation(
                                  _lendList.indexOf(transaction),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAddLendTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add New Lend',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),

          TextField(
            controller: _firstNameController,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
              hintText: 'Enter name',
            ),
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
    );
  }

  Widget _buildLendListTab() {
    // Group transactions by person (case-insensitive)
    Map<String, List<Map<String, dynamic>>> groupedLends = {};
    Map<String, double> personTotals = {};
    Map<String, String> displayNames =
        {}; // To preserve original case for display

    for (var item in _lendList) {
      // Use lowercase fullName as key for case-insensitive grouping
      String fullName = (item['fullName'] ?? '').toString().trim();
      String lowerKey = fullName.toLowerCase();

      if (!groupedLends.containsKey(lowerKey)) {
        groupedLends[lowerKey] = [];
        personTotals[lowerKey] = 0.0;
        displayNames[lowerKey] = fullName; // Store original case for display
      }

      groupedLends[lowerKey]!.add(item);
      personTotals[lowerKey] =
          personTotals[lowerKey]! +
          ((item['amount'] is num) ? item['amount'] : 0.0);
    }

    // Convert to list for ListView
    List<String> personKeys = groupedLends.keys.toList();
    personKeys.sort(); // Sort alphabetically

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Wrap this Text widget with Expanded to prevent overflow
              Expanded(
                child: Text(
                  'Total Lend: ₹${_totalLendAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                  overflow:
                      TextOverflow.ellipsis, // Handle text overflow gracefully
                ),
              ),
              if (_isSelectionMode)
                // Add some spacing between the text and button
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.cancel, size: 16), // Make icon smaller
                    label: Text(
                      'Cancel',
                      style: TextStyle(fontSize: 12),
                    ), // Make text smaller
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ), // Smaller padding
                      minimumSize: Size(0, 32), // Smaller minimum size
                    ),
                    onPressed: () {
                      setState(() {
                        _isSelectionMode = false;
                        _selectedPersons.clear();
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
        Divider(),
        Expanded(
          child: personKeys.isEmpty
              ? Center(child: Text('No lend records found.'))
              : ListView.builder(
                  itemCount: personKeys.length,
                  itemBuilder: (context, index) {
                    String personKey = personKeys[index];
                    String displayName = displayNames[personKey] ?? personKey;
                    List<Map<String, dynamic>> personTransactions =
                        groupedLends[personKey]!;
                    double totalAmount = personTotals[personKey]!;

                    // Get the most recent transaction for display
                    Map<String, dynamic> latestTransaction = personTransactions
                        .reduce(
                          (a, b) =>
                              (a['time'] as DateTime).isAfter(
                                b['time'] as DateTime,
                              )
                              ? a
                              : b,
                        );

                    DateTime latestTime = latestTransaction['time'] as DateTime;

                    bool isSelected = _selectedPersons
                        .map((name) => name.toLowerCase())
                        .contains(personKey);

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      elevation: isSelected ? 4 : 1,
                      color: isSelected ? Colors.blue.shade50 : null,
                      child: ListTile(
                        onLongPress: () {
                          setState(() {
                            _isSelectionMode = true;
                            _selectedPersons.add(personKey);
                          });
                        },
                        onTap: _isSelectionMode
                            ? () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedPersons.removeWhere(
                                      (name) => name.toLowerCase() == personKey,
                                    );
                                    if (_selectedPersons.isEmpty) {
                                      _isSelectionMode = false;
                                    }
                                  } else {
                                    _selectedPersons.add(personKey);
                                  }
                                });
                              }
                            : () => _showLendHistory(displayName),
                        leading: _isSelectionMode
                            ? Checkbox(
                                value: isSelected,
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      _selectedPersons.add(personKey);
                                    } else {
                                      _selectedPersons.removeWhere(
                                        (name) =>
                                            name.toLowerCase() == personKey,
                                      );
                                      if (_selectedPersons.isEmpty) {
                                        _isSelectionMode = false;
                                      }
                                    }
                                  });
                                },
                              )
                            : CircleAvatar(
                                child: Text(
                                  displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : '?',
                                ),
                              ),
                        title: Text(
                          displayName,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Last Lend: ${_formatDateTime(latestTime)}',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${totalAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              '${personTransactions.length} transaction${personTransactions.length != 1 ? 's' : ''}',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_isSelectionMode)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: Icon(Icons.delete),
              label: Text('Delete Selected (${_selectedPersons.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: Size(double.infinity, 50),
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
                          Navigator.pop(context);
                          _deleteSelectedPersons();
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
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Lend Section'),
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

  String _formatDateTime(DateTime dateTime) {
    // Format: "YYYY-MM-DD hh:mm:ss AM/PM"
    String year = dateTime.year.toString();
    String month = dateTime.month.toString().padLeft(2, '0');
    String day = dateTime.day.toString().padLeft(2, '0');

    String hour =
        (dateTime.hour > 12
                ? dateTime.hour - 12
                : dateTime.hour == 0
                ? 12
                : dateTime.hour)
            .toString()
            .padLeft(2, '0');
    String minute = dateTime.minute.toString().padLeft(2, '0');
    String second = dateTime.second.toString().padLeft(2, '0');
    String period = dateTime.hour >= 12 ? 'PM' : 'AM';

    return "$year-$month-$day $hour:$minute:$second $period";
  }

  // Update the delete confirmation dialog
  void _showDeleteConfirmation(int transactionIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Transaction'),
        content: Text('Are you sure you want to delete this transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTransaction(transactionIndex);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green, // Changed from red to green
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }
}
