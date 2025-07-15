import 'package:flutter/material.dart';
import 'dart:async';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'chart_page.dart';
import 'borrow_page.dart';
import 'lend_page.dart';
import 'package:flutter/services.dart';

const List<String> _categories = [
  'Categories', // First item as a prompt
  'Restaurants',
  'Transport',
  'Groceries',
  'Vegetables & Fruits',
  'Personal Care',
  'Home & Utilities',
  'Clothing & Accessories',
  'Entertainment',
  'Others',
];

const List<String> _paymentMethods = [
  'Payment Method', // First item as a prompt
  'Cash',
  'Online',
];

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Expense',
      debugShowCheckedModeBanner: false,
      home: ExpenditureScreen(),
    );
  }
}

class ExpenditureScreen extends StatefulWidget {
  const ExpenditureScreen({super.key});

  @override
  _ExpenditureScreenState createState() => _ExpenditureScreenState();
}

class _ExpenditureScreenState extends State<ExpenditureScreen> {
  late Timer _timer;
  DateTime _now = DateTime.now();
  DateTime selectedDate = DateTime(
    2024,
    1,
    15,
  ); // <-- Between minDate and maxDate

  int _currentIndex = 0;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  String _selectedCategory = _categories[0];
  String _selectedPaymentMethod = _paymentMethods[0];

  List<Map<String, dynamic>> _items = [];
  double _totalAmount = 0.0;
  final List<int> _selectedIndexes = [];
  bool _isSelectionMode = false;

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _now = DateTime.now();
      });
    });
    _loadItems();

    // Initialize pages after loading items
    _pages.add(_buildHomePage());
    _pages.add(_buildDetailsPage());
    _pages.add(
      ChartPage(
        items: _items,
        totalAmount: _totalAmount,
        categories: _categories,
      ),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> itemsJson = _items
        .map(
          (item) => jsonEncode({
            'category': item['category'],
            'name': item['name'],
            'price': item['price'],
            'paymentMethod': item['paymentMethod'], // Add this line
            'time': (item['time'] as DateTime).toIso8601String(),
          }),
        )
        .toList();
    prefs.setStringList('items', itemsJson);
    prefs.setDouble('totalAmount', _totalAmount);
  }

  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? itemsJson = prefs.getStringList('items');
    double? total = prefs.getDouble('totalAmount');
    if (itemsJson != null) {
      _items = itemsJson.map((itemStr) {
        final item = jsonDecode(itemStr);
        return {
          'category': item['category'],
          'name': item['name'],
          'price': item['price'],
          'paymentMethod':
              item['paymentMethod'] ?? 'Cash', // Default for old items
          'time': DateTime.parse(item['time']),
        };
      }).toList();
    }
    if (total != null) _totalAmount = total;
    setState(() {});
  }

  void _addItem() {
    String name = _nameController.text.trim();
    double? price = double.tryParse(_priceController.text.trim());

    // Check if a real category and payment method are selected
    if (name.isNotEmpty &&
        price != null &&
        _selectedCategory != 'Categories' &&
        _selectedPaymentMethod != 'Payment Method') {
      setState(() {
        _items.add({
          'category': _selectedCategory,
          'name': name,
          'price': price,
          'paymentMethod': _selectedPaymentMethod,
          'time': DateTime.now(),
        });
        _totalAmount += price;
        _nameController.clear();
        _priceController.clear();
        _currentIndex = 1; // Switch to Details tab after adding
      });
      _saveItems(); // Save after adding
    } else if (_selectedCategory == 'Categories') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please select a category')));
    } else if (_selectedPaymentMethod == 'Payment Method') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please select a payment method')));
    }
  }

  Future<void> _downloadExcel() async {
    // First ask for date range
    DateTimeRange? dateRange = await _askDateRange(context);
    if (dateRange == null) return; // User cancelled

    // Then ask for filename
    String? fileName = await _askFileName(context);
    if (fileName == null || fileName.isEmpty) return;

    // Filter items based on date range
    List<Map<String, dynamic>> filteredItems = _items.where((item) {
      DateTime itemDate = item['time'] as DateTime;
      return itemDate.isAfter(dateRange.start) &&
          itemDate.isBefore(dateRange.end.add(Duration(days: 1)));
    }).toList();

    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Sheet1'];
    sheetObject.appendRow([
      'Category',
      'Name',
      'DateTime',
      'Payment Method',
      'Price',
    ]);

    double totalFilteredAmount = 0;
    for (var item in filteredItems) {
      sheetObject.appendRow([
        item['category'],
        item['name'],
        (item['time'] as DateTime).toString().substring(0, 16),
        item['paymentMethod'] ?? 'Cash',
        item['price'].toString(),
      ]);
      totalFilteredAmount += item['price'];
    }

    // Add an empty row for spacing
    sheetObject.appendRow(['', '', '', '', '']);

    // Add the total row
    sheetObject.appendRow([
      '',
      '',
      '',
      'Total',
      totalFilteredAmount.toStringAsFixed(2),
    ]);

    var fileBytes = excel.encode();

    String filePath;
    if (Platform.isAndroid) {
      filePath = '/storage/emulated/0/Download/$fileName.xlsx';
    } else {
      final directory = await getApplicationDocumentsDirectory();
      filePath = '${directory.path}/$fileName.xlsx';
    }

    File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes!);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Excel file downloaded to $filePath')),
    );
  }

  Future<String?> _askFileName(BuildContext context) async {
    TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter file name'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'File name (without .xlsx)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<DateTimeRange?> _askDateRange(BuildContext context) async {
    return showDialog<DateTimeRange>(
      context: context,
      builder: (context) {
        String selectedOption = 'Today';
        DateTime now = DateTime.now();
        DateTime startDate = DateTime(now.year, now.month, now.day);
        DateTime endDate = now;

        // For custom date range
        DateTime? customStartDate;
        DateTime? customEndDate;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Select Date Range'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedOption,
                      items:
                          [
                            'Today',
                            'Yesterday',
                            'Last 7 days',
                            'Last 30 days',
                            'This month',
                            'Last month',
                            'Custom range',
                          ].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedOption = newValue!;

                          // Calculate date range based on selection
                          switch (selectedOption) {
                            case 'Today':
                              startDate = DateTime(
                                now.year,
                                now.month,
                                now.day,
                              );
                              endDate = now;
                              break;
                            case 'Yesterday':
                              startDate = DateTime(
                                now.year,
                                now.month,
                                now.day - 1,
                              );
                              endDate = DateTime(
                                now.year,
                                now.month,
                                now.day - 1,
                                23,
                                59,
                                59,
                              );
                              break;
                            case 'Last 7 days':
                              startDate = DateTime(
                                now.year,
                                now.month,
                                now.day - 6,
                              );
                              endDate = now;
                              break;
                            case 'Last 30 days':
                              startDate = DateTime(
                                now.year,
                                now.month,
                                now.day - 29,
                              );
                              endDate = now;
                              break;
                            case 'This month':
                              startDate = DateTime(now.year, now.month, 1);
                              endDate = now;
                              break;
                            case 'Last month':
                              final lastMonth = now.month > 1
                                  ? DateTime(now.year, now.month - 1)
                                  : DateTime(now.year - 1, 12);
                              startDate = DateTime(
                                lastMonth.year,
                                lastMonth.month,
                                1,
                              );
                              endDate = DateTime(
                                now.year,
                                now.month,
                                0,
                                23,
                                59,
                                59,
                              );
                              break;
                          }
                        });
                      },
                    ),

                    if (selectedOption == 'Custom range')
                      Column(
                        children: [
                          SizedBox(height: 16),
                          Text('From date:'),
                          OutlinedButton(
                            child: Text(
                              customStartDate == null
                                  ? 'Select start date'
                                  : '${customStartDate!.day}/${customStartDate!.month}/${customStartDate!.year}',
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: customStartDate ?? now,
                                firstDate: DateTime(2020),
                                lastDate: now,
                              );
                              if (picked != null) {
                                setState(() {
                                  customStartDate = picked;
                                  startDate = picked;
                                });
                              }
                            },
                          ),

                          SizedBox(height: 8),
                          Text('To date:'),
                          OutlinedButton(
                            child: Text(
                              customEndDate == null
                                  ? 'Select end date'
                                  : '${customEndDate!.day}/${customEndDate!.month}/${customEndDate!.year}',
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: customEndDate ?? now,
                                firstDate: customStartDate ?? DateTime(2020),
                                lastDate: now,
                              );
                              if (picked != null) {
                                setState(() {
                                  customEndDate = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    23,
                                    59,
                                    59,
                                  );
                                  endDate = customEndDate!;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (selectedOption == 'Custom range' &&
                        (customStartDate == null || customEndDate == null)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Please select both start and end dates',
                          ),
                        ),
                      );
                    } else {
                      Navigator.pop(
                        context,
                        DateTimeRange(start: startDate, end: endDate),
                      );
                    }
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHomePage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDateTime(_now),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Your existing form elements
            Text(
              'Add New Expense',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),

            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
                hintText: 'Select a category',
              ),
              value: _selectedCategory,
              items: _categories.map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  // Make the prompt item disabled or styled differently
                  enabled: category != 'Categories',
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCategory = newValue!;
                });
              },
              // Add a validator to ensure a real category is selected
              validator: (value) {
                if (value == 'Categories') {
                  return 'Please select a category';
                }
                return null;
              },
            ),
            SizedBox(height: 10),
            TextField(
              controller: _nameController,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
              ],
              decoration: InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(),
                hintText: 'Enter item name (alphabets only)',
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _priceController,
              decoration: InputDecoration(
                labelText: 'Item Price',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
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
                  child: Text(method),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedPaymentMethod = newValue!;
                });
              },
            ),
            SizedBox(height: 20),

            // Make Add button bigger
            ElevatedButton(
              onPressed: _addItem,
              child: Text(
                'Add',
                style: TextStyle(
                  fontSize: 18, // Larger text
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 60), // Taller button
                padding: EdgeInsets.symmetric(vertical: 15), // More padding
                side: BorderSide(
                  width: 1.0,
                  color: Colors.blue.shade300,
                ), // Add thin border
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    8.0,
                  ), // Optional: slightly rounded corners
                ),
              ),
            ),

            // Add a larger gap between Add and Lend buttons
            SizedBox(height: 60), // Increased from 10 to 30

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LendPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50), // Full width and height
              ),
              child: Text('Lend'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BorrowPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50), // Full width and height
              ),
              child: Text('Borrow'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsPage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Items:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _items.isEmpty ? null : _downloadExcel,
                icon: Icon(Icons.download),
                label: Text('Download with Date Range'),
              ),
            ],
          ),
          SizedBox(height: 10),
          Expanded(
            child: _items.isEmpty
                ? Text('No items added.')
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final time = item['time'] as DateTime;
                      final isSelected = _selectedIndexes.contains(index);
                      return ListTile(
                        onLongPress: () {
                          setState(() {
                            _isSelectionMode = true;
                            _selectedIndexes.add(index);
                          });
                        },
                        onTap: _isSelectionMode
                            ? () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedIndexes.remove(index);
                                    if (_selectedIndexes.isEmpty) {
                                      _isSelectionMode = false;
                                    }
                                  } else {
                                    _selectedIndexes.add(index);
                                  }
                                });
                              }
                            : null,
                        leading: _isSelectionMode
                            ? Checkbox(
                                value: isSelected,
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      _selectedIndexes.add(index);
                                    } else {
                                      _selectedIndexes.remove(index);
                                      if (_selectedIndexes.isEmpty) {
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
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${item['category']}: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${item['name']}',
                              style: TextStyle(color: Colors.black),
                            ),
                            SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: item['paymentMethod'] == 'Cash'
                                    ? Colors.green.shade100
                                    : Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${item['paymentMethod'] ?? 'Cash'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: item['paymentMethod'] == 'Cash'
                                      ? Colors.green.shade700
                                      : Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text(
                              'DATETIME: ${_formatDateTime(time)}',
                              style: TextStyle(fontSize: 12),
                            ),
                            SizedBox(height: 8),
                          ],
                        ),
                        trailing: Container(
                          margin: EdgeInsets.only(left: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₹${item['price'].toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.edit, size: 20),
                                onPressed: () => _showUpdateDialog(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(height: 10),
          Text(
            'Total Amount: ₹${_totalAmount.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (_isSelectionMode)
            Row(
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.delete),
                  label: Text('Delete Selected'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 174, 158, 156),
                  ),
                  onPressed: () {
                    setState(() {
                      // Remove items in reverse order to avoid index issues
                      _selectedIndexes.sort((a, b) => b.compareTo(a));
                      for (var idx in _selectedIndexes) {
                        _totalAmount -= _items[idx]['price'];
                        _items.removeAt(idx);
                      }
                      _selectedIndexes.clear();
                      _isSelectionMode = false;
                      _saveItems();
                    });
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showUpdateDialog(int index) {
    final item = _items[index];
    final TextEditingController nameController = TextEditingController(
      text: item['name'],
    );
    final TextEditingController priceController = TextEditingController(
      text: item['price'].toString(),
    );
    String selectedCategory = item['category'] ?? _categories[1];
    String selectedPaymentMethod = item['paymentMethod'] ?? _paymentMethods[1];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              value: selectedCategory,
              items: _categories.skip(1).map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? newValue) {
                selectedCategory = newValue!;
              },
            ),
            SizedBox(height: 10),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Payment Method',
                border: OutlineInputBorder(),
              ),
              value: selectedPaymentMethod,
              items: _paymentMethods.skip(1).map((String method) {
                return DropdownMenuItem<String>(
                  value: method,
                  child: Text(method),
                );
              }).toList(),
              onChanged: (String? newValue) {
                selectedPaymentMethod = newValue!;
              },
            ),
            SizedBox(height: 10),
            TextField(
              controller: nameController,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
              ],
              decoration: InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: priceController,
              decoration: InputDecoration(
                labelText: 'Item Price',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
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
              String name = nameController.text.trim();
              double? price = double.tryParse(priceController.text.trim());
              if (name.isNotEmpty && price != null) {
                setState(() {
                  _totalAmount -= _items[index]['price'];
                  _items[index]['name'] = name;
                  _items[index]['price'] = price;
                  _items[index]['category'] = selectedCategory;
                  _items[index]['paymentMethod'] = selectedPaymentMethod;
                  _totalAmount += price;
                });
                _saveItems();
                Navigator.pop(context);
              }
            },
            child: Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Refresh pages when data changes
    _pages[0] = _buildHomePage();
    _pages[1] = _buildDetailsPage();
    _pages[2] = ChartPage(
      items: _items.isNotEmpty ? _items : [], // Ensure we pass a valid list
      totalAmount: _totalAmount > 0
          ? _totalAmount
          : 0.0, // Ensure we pass a valid amount
      categories: _categories,
    );

    return Scaffold(
      appBar: AppBar(title: Text('Daily Expenditure-C')),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.details), label: 'Details'),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart),
            label: 'Analysis',
          ),
        ],
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blue,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }

  // Add this helper method to format the date time with seconds and AM/PM
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
}
