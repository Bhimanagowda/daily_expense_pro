import 'package:flutter/material.dart';
import 'dart:async';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:horizontal_week_calendar/horizontal_week_calendar.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Demo Flutter App',
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

  List<Map<String, dynamic>> _items = [];
  double _totalAmount = 0.0;
  final List<int> _selectedIndexes = [];
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _now = DateTime.now();
      });
    });
    _loadItems();
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
            'name': item['name'],
            'price': item['price'],
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
          'name': item['name'],
          'price': item['price'],
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
    if (name.isNotEmpty && price != null) {
      setState(() {
        _items.add({'name': name, 'price': price, 'time': DateTime.now()});
        _totalAmount += price;
        _nameController.clear();
        _priceController.clear();
        _currentIndex = 1; // Switch to Details tab after adding
      });
      _saveItems(); // Save after adding
    }
  }

  Future<void> _downloadExcel() async {
    String? fileName = await _askFileName(context);
    if (fileName == null || fileName.isEmpty) return;

    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Sheet1'];
    sheetObject.appendRow(['Name', 'DateTime', 'Price']);
    for (var item in _items) {
      sheetObject.appendRow([
        item['name'],
        (item['time'] as DateTime).toString().substring(0, 16),
        item['price'].toString(),
      ]);
    }

    // Add an empty row for spacing (optional)
    sheetObject.appendRow(['', '', '']);

    // Add the total row
    sheetObject.appendRow(['Total', '', _totalAmount.toStringAsFixed(2)]);

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

  Widget _buildHomePage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Date & Time: ${_now.toString().substring(0, 16)}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Item Name',
              border: OutlineInputBorder(),
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
          SizedBox(height: 20),
          ElevatedButton(onPressed: _addItem, child: Text('Add')),
        ],
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
                label: Text('Download'),
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
                        title: Text(item['name']),
                        subtitle: Text(
                          'DATETIME: ${time.toString().substring(0, 16)}',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: Text('₹${item['price'].toStringAsFixed(2)}'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Daily Expenditure')),
      body: _currentIndex == 0 ? _buildHomePage() : _buildDetailsPage(),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.details), label: 'Details'),
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
}
