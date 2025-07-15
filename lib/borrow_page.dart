import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

const List<String> _paymentMethods = ['Payment Method', 'Cash', 'Online'];

const Map<String, IconData> _paymentIcons = {
  'Cash': Icons.money,
  'Online': Icons.credit_card,
};

class BorrowPage extends StatefulWidget {
  const BorrowPage({super.key});

  @override
  _BorrowPageState createState() => _BorrowPageState();
}

class _BorrowPageState extends State<BorrowPage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedPaymentMethod = _paymentMethods[0];

  List<Map<String, dynamic>> _borrowList = [];
  double _totalBorrowAmount = 0.0;

  // Selection mode variables for main list
  bool _isSelectionMode = false;
  List<String> _selectedPersons = [];

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
          'fullName': item['fullName'],
          'firstNameLower':
              item['firstNameLower'] ?? item['firstName'].toLowerCase(),
          'amount': item['amount'],
          'description': item['description'],
          'paymentMethod': item['paymentMethod'] ?? 'Cash',
          'time': DateTime.parse(item['time']),
          'type': item['type'] ?? 'borrow',
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
        'fullName': item['firstName'],
        'firstNameLower':
            item['firstNameLower'] ?? item['firstName'].toLowerCase(),
        'amount': item['amount'],
        'description': item['description'],
        'paymentMethod': item['paymentMethod'] ?? 'Cash',
        'time': (item['time'] as DateTime).toIso8601String(),
        'type': item['type'] ?? 'borrow',
      };
      return jsonEncode(itemMap);
    }).toList();

    await prefs.setStringList('borrowList', borrowJson);
    await prefs.setDouble('totalBorrowAmount', _totalBorrowAmount);
  }

  void _addBorrowItem() {
    String firstName = _firstNameController.text.trim();
    double? amount = double.tryParse(_amountController.text.trim());
    String description = _descriptionController.text.trim();

    if (firstName.isNotEmpty &&
        amount != null &&
        _selectedPaymentMethod != 'Payment Method') {
      setState(() {
        _borrowList.add({
          'firstName': firstName,
          'fullName': firstName,
          'firstNameLower': firstName.toLowerCase(),
          'amount': amount,
          'description': description,
          'paymentMethod': _selectedPaymentMethod,
          'time': DateTime.now(),
        });

        _totalBorrowAmount += amount;
        _firstNameController.clear();
        _amountController.clear();
        _descriptionController.clear();
        _selectedPaymentMethod = _paymentMethods[0];
      });
      _saveBorrowData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $firstName to Borrow list'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else if (_selectedPaymentMethod == 'Payment Method') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please select a payment method')));
    }
  }

  void _deleteTransaction(int transactionIndex) {
    final item = _borrowList[transactionIndex];
    final bool isReturn = item['type'] == 'return';
    final double amount = item['amount'];

    setState(() {
      // For return transactions, we need to add the negative amount back
      _totalBorrowAmount -=
          amount; // This adds for returns (negative amount) and subtracts for borrows
      _borrowList.removeAt(transactionIndex);
    });
    _saveBorrowData();

    // Replace yellow/black warning with a simple green confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isReturn
              ? 'Return transaction deleted'
              : 'Transaction deleted successfully',
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _editTransaction(int transactionIndex) {
    final item = _borrowList[transactionIndex];
    final bool isReturn = item['type'] == 'return';
    final TextEditingController firstNameController = TextEditingController(
      text: item['firstName'],
    );
    final TextEditingController amountController = TextEditingController(
      // For return transactions, show the absolute value
      text: (isReturn ? item['amount'].abs() : item['amount']).toString(),
    );
    final TextEditingController descriptionController = TextEditingController(
      text: item['description'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isReturn ? 'Edit Return' : 'Edit Transaction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: firstNameController,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
              ],
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
                labelText: isReturn ? 'Return Amount' : 'Amount',
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
                  _totalBorrowAmount -= _borrowList[transactionIndex]['amount'];

                  // Update the transaction
                  _borrowList[transactionIndex]['firstName'] = firstName;
                  _borrowList[transactionIndex]['fullName'] = firstName;
                  _borrowList[transactionIndex]['firstNameLower'] = firstName
                      .toLowerCase();

                  // For return transactions, keep the amount negative
                  _borrowList[transactionIndex]['amount'] = isReturn
                      ? -amount
                      : amount;
                  _borrowList[transactionIndex]['description'] = description;

                  // Add new amount to total
                  _totalBorrowAmount += (isReturn ? -amount : amount);
                });
                _saveBorrowData();
                Navigator.pop(context);
                // Refresh the history dialog
                Navigator.pop(context);
                _showBorrowHistory(firstName);
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
    for (var item in _borrowList) {
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
        List<Map<String, dynamic>> newBorrowList = [];

        for (var item in _borrowList) {
          String personKey = (item['fullName']?.toString().trim() ?? '')
              .toLowerCase();
          if (!selectedPersonsLower.contains(personKey)) {
            newBorrowList.add(item);
          }
        }

        // Replace the old list with the new one
        _borrowList = newBorrowList;

        // Update the total amount
        _totalBorrowAmount -= amountToSubtract;
        if (_totalBorrowAmount < 0) {
          _totalBorrowAmount = 0; // Prevent negative totals
        }

        // Clear selection mode
        _selectedPersons.clear();
        _isSelectionMode = false;
      });

      // Save the updated data
      _saveBorrowData();

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

  void _showBorrowHistory(String name) {
    // Convert input name to lowercase for case-insensitive comparison
    String nameLower = name.toLowerCase();

    // Get all transactions for this person (case-insensitive)
    List<Map<String, dynamic>> personTransactions = _borrowList.where((item) {
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
                          color: Colors.red,
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
                      final bool isReturn = transaction['type'] == 'return';
                      final double amount = transaction['amount'];

                      return ListTile(
                        title: Text(
                          '₹${amount.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isReturn ? Colors.green : Colors.red,
                          ),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: isReturn
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          child: Icon(
                            isReturn ? Icons.keyboard_return : Icons.money_off,
                            color: isReturn ? Colors.green : Colors.red,
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
                            SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: transaction['paymentMethod'] == 'Cash'
                                    ? Colors.green.shade100
                                    : Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _paymentIcons[transaction['paymentMethod']] ??
                                        Icons.money,
                                    size: 10,
                                    color:
                                        transaction['paymentMethod'] == 'Cash'
                                        ? Colors.green.shade700
                                        : Colors.blue.shade700,
                                  ),
                                  SizedBox(width: 2),
                                  Text(
                                    '${transaction['paymentMethod'] ?? 'Cash'}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color:
                                          transaction['paymentMethod'] == 'Cash'
                                          ? Colors.green.shade700
                                          : Colors.blue.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
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
                                  _borrowList.indexOf(transaction),
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                Navigator.pop(context);
                                _showDeleteConfirmation(
                                  _borrowList.indexOf(transaction),
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

  void _showPersonDetails(int index) {
    final item = _borrowList[index];

    // Create a fullName from the item
    String fullName = "${item['firstName']} ${item['lastName']}".trim();

    // Call _showBorrowHistory with a single parameter
    _showBorrowHistory(fullName);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Borrow Section'),
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
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add New Borrow',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),

          TextField(
            controller: _firstNameController,
            autocorrect: false,
            enableSuggestions: false,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
            ],
            decoration: InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
              hintText: 'Enter name (alphabets only)',
            ),
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

          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Payment Method',
              border: OutlineInputBorder(),
              hintText: 'Select payment method',
            ),
            value: _selectedPaymentMethod,
            items: _paymentMethods.map((String method) {
              return DropdownMenuItem<String>(
                value: method,
                enabled: method != 'Payment Method',
                child: Row(
                  children: [
                    if (method != 'Payment Method') ...[
                      Icon(_paymentIcons[method], size: 16),
                      SizedBox(width: 8),
                    ],
                    Text(method),
                  ],
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedPaymentMethod = newValue!;
              });
            },
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
    // Group transactions by person (case-insensitive)
    Map<String, List<Map<String, dynamic>>> groupedBorrows = {};
    Map<String, double> personTotals = {};
    Map<String, String> displayNames =
        {}; // To preserve original case for display

    for (var item in _borrowList) {
      // Use lowercase fullName as key for case-insensitive grouping
      String fullName = (item['fullName'] ?? '').toString().trim();
      String lowerKey = fullName.toLowerCase();

      if (!groupedBorrows.containsKey(lowerKey)) {
        groupedBorrows[lowerKey] = [];
        personTotals[lowerKey] = 0.0;
        displayNames[lowerKey] = fullName; // Store original case for display
      }

      groupedBorrows[lowerKey]!.add(item);
      personTotals[lowerKey] =
          personTotals[lowerKey]! +
          ((item['amount'] is num) ? item['amount'] : 0.0);
    }

    // Convert to list for ListView
    List<String> personKeys = groupedBorrows.keys.toList();
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
                  'Total Borrow: ₹${_totalBorrowAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
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
              ? Center(child: Text('No borrow records found.'))
              : ListView.builder(
                  itemCount: personKeys.length,
                  itemBuilder: (context, index) {
                    String personKey = personKeys[index];
                    String displayName = displayNames[personKey] ?? personKey;
                    List<Map<String, dynamic>> personTransactions =
                        groupedBorrows[personKey]!;
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
                      child: Column(
                        children: [
                          ListTile(
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
                                          (name) =>
                                              name.toLowerCase() == personKey,
                                        );
                                        if (_selectedPersons.isEmpty) {
                                          _isSelectionMode = false;
                                        }
                                      } else {
                                        _selectedPersons.add(personKey);
                                      }
                                    });
                                  }
                                : () => _showBorrowHistory(displayName),
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
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Last Borrow: ${_formatDateTime(latestTime)}',
                                  style: TextStyle(fontSize: 12),
                                ),
                                SizedBox(height: 4),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        latestTransaction['paymentMethod'] ==
                                            'Cash'
                                        ? Colors.green.shade100
                                        : Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _paymentIcons[latestTransaction['paymentMethod']] ??
                                            Icons.money,
                                        size: 10,
                                        color:
                                            latestTransaction['paymentMethod'] ==
                                                'Cash'
                                            ? Colors.green.shade700
                                            : Colors.blue.shade700,
                                      ),
                                      SizedBox(width: 2),
                                      Text(
                                        '${latestTransaction['paymentMethod'] ?? 'Cash'}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color:
                                              latestTransaction['paymentMethod'] ==
                                                  'Cash'
                                              ? Colors.green.shade700
                                              : Colors.blue.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
                                    color: Colors.red,
                                  ),
                                ),
                                Text(
                                  '${personTransactions.length} transaction${personTransactions.length != 1 ? 's' : ''}',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          // Add Return Amount button below the ListTile
                          if (!_isSelectionMode && totalAmount > 0)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 8.0,
                                left: 8.0,
                                right: 8.0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    icon: Icon(Icons.keyboard_return, size: 16),
                                    label: Text('Return Amount'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      textStyle: TextStyle(fontSize: 12),
                                    ),
                                    onPressed: () =>
                                        _showReturnAmountDialogForPerson(
                                          displayName,
                                          totalAmount,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                        ],
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

  // Helper method to process return amount for a person
  void _processReturnAmount(
    String personName,
    List<Map<String, dynamic>> transactions,
    double returnAmount,
    String description,
    String paymentMethod,
  ) {
    setState(() {
      _borrowList.add({
        'firstName': personName,
        'fullName': personName,
        'firstNameLower': personName.toLowerCase(),
        'amount': -returnAmount,
        'description': description.isEmpty ? 'Amount returned' : description,
        'paymentMethod': paymentMethod,
        'time': DateTime.now(),
        'type': 'return',
      });

      _totalBorrowAmount -= returnAmount;
      if (_totalBorrowAmount < 0) _totalBorrowAmount = 0;
    });

    _saveBorrowData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '₹${returnAmount.toStringAsFixed(2)} returned to $personName via $paymentMethod',
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Simplified method to show return amount dialog for a person
  void _showReturnAmountDialogForPerson(String personName, double totalAmount) {
    final TextEditingController returnAmountController =
        TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    String selectedPaymentMethod = 'Cash'; // Default to Cash

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Return Amount'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total Borrowed from $personName: ₹${totalAmount.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              TextField(
                controller: returnAmountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Return Amount',
                  border: OutlineInputBorder(),
                  prefixText: '₹',
                  hintText: 'Enter amount being returned',
                ),
              ),
              SizedBox(height: 10),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(),
                ),
                value: selectedPaymentMethod,
                items: ['Cash', 'Online'].map((String method) {
                  return DropdownMenuItem<String>(
                    value: method,
                    child: Row(
                      children: [
                        Icon(_paymentIcons[method], size: 16),
                        SizedBox(width: 8),
                        Text(method),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedPaymentMethod = newValue!;
                  });
                },
              ),
              SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  hintText: 'Optional note about this return',
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
                double? returnAmount = double.tryParse(
                  returnAmountController.text.trim(),
                );
                String description = descriptionController.text.trim();

                if (returnAmount != null && returnAmount > 0) {
                  if (returnAmount > totalAmount) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Return amount cannot exceed total borrowed amount',
                        ),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } else {
                    _processReturnAmount(
                      personName,
                      [],
                      returnAmount,
                      description,
                      selectedPaymentMethod,
                    );
                    Navigator.pop(context);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a valid return amount'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: Text('Return'),
            ),
          ],
        ),
      ),
    );
  }
}
