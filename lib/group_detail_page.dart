import 'package:flutter/material.dart';
import 'sound_helper.dart';
import 'cost_split_page.dart';
import 'package:flutter/services.dart';

const List<String> _categories = [
  'Categories',
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

const List<String> _paymentMethods = ['Payment Method', 'Cash', 'Online'];

class GroupDetailPage extends StatefulWidget {
  final Group group;
  final Function(Group) onGroupUpdated;

  const GroupDetailPage({
    super.key,
    required this.group,
    required this.onGroupUpdated,
  });

  @override
  _GroupDetailPageState createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  String _selectedCategory = _categories[0];
  String _selectedPaymentMethod = _paymentMethods[0];
  String _selectedPaidBy = '';
  List<String> _selectedMembers = [];
  int? _selectedMembersCount;

  List<Map<String, dynamic>> _settlementState = [];

  @override
  void initState() {
    super.initState();
    _selectedPaidBy = widget.group.members.isNotEmpty
        ? widget.group.members[0]
        : '';
    _selectedMembers = List.from(widget.group.members); // default: all
  }

  Future<void> _addExpense() async {
    String name = _nameController.text.trim();
    double? price = double.tryParse(_priceController.text.trim());

    // Validate name: only alphabets and spaces
    final nameRegExp = RegExp(r'^[A-Za-z ]+$'); // Only alphabets and spaces
    String errorMessage = '';

    if (name.isEmpty) {
      errorMessage = 'Please enter expense name';
    } else if (!nameRegExp.hasMatch(name)) {
      errorMessage = 'Expense name must contain only alphabets and spaces';
    } else if (price == null || price <= 0) {
      errorMessage = 'Please enter valid amount';
    } else if (_selectedCategory == 'Categories') {
      errorMessage = 'Please select a category';
    } else if (_selectedPaymentMethod == 'Payment Method') {
      errorMessage = 'Please select payment method';
    } else if (_selectedPaidBy.isEmpty) {
      errorMessage = 'Please select who paid';
    } else if (_selectedMembers.isEmpty) {
      errorMessage = 'Please select at least one member';
    }

    if (errorMessage.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
      return;
    }

    final splitAmount = price! / _selectedMembers.length;

    final expense = {
      'category': _selectedCategory,
      'name': name,
      'price': price,
      'paymentMethod': _selectedPaymentMethod,
      'time': DateTime.now().toIso8601String(),
      'splitAmount': splitAmount,
      'paidBy': _selectedPaidBy,
      'excludedMembers': widget.group.members
          .where((m) => !_selectedMembers.contains(m))
          .toList(),
    };

    setState(() {
      widget.group.expenses.insert(0, expense);
      _nameController.clear();
      _priceController.clear();
      _selectedCategory = _categories[0];
      _selectedPaymentMethod = _paymentMethods[0];
      // Don't reset _selectedPaidBy to keep it selected
      _selectedMembers = List.from(widget.group.members);
    });

    widget.onGroupUpdated(widget.group);

    // Play add sound
    await SoundHelper.playAddSound();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Expense added! $_selectedPaidBy paid ₹${price.toStringAsFixed(2)}',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  Map<String, Map<String, double>> _calculateSettlements() {
    Map<String, Map<String, double>> settlements = {};

    // Initialize settlements map
    for (String member in widget.group.members) {
      settlements[member] = {};
      for (String otherMember in widget.group.members) {
        if (member != otherMember) {
          settlements[member]![otherMember] = 0.0;
        }
      }
    }

    // Calculate who owes whom
    for (var expense in widget.group.expenses) {
      String paidBy = expense['paidBy'] ?? widget.group.members[0];
      double splitAmount = expense['splitAmount'] as double;

      // Each member (except who paid) owes the payer
      for (String member in widget.group.members) {
        if (member != paidBy) {
          settlements[member]![paidBy] =
              (settlements[member]![paidBy] ?? 0.0) + splitAmount;
        }
      }
    }

    return settlements;
  }

  void _deleteMember(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Member'),
        content: Text(
          'Are you sure you want to remove ${widget.group.members[index]} from the group?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                widget.group.members.removeAt(index);
              });
              widget.onGroupUpdated(widget.group);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Member removed successfully'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showMemberOptions(String member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Member Options'),
        content: Text('What would you like to do with $member?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearMemberAmount(member);
            },
            child: Text('Clear Amount', style: TextStyle(color: Colors.orange)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDeleteMember(member);
            },
            child: Text('Delete Member', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _clearMemberAmount(String member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear Amount'),
        content: Text(
          'Are you sure you want to clear all expenses for $member? This will remove all expenses they paid and their share from other expenses.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                // Remove all expenses where this member paid
                widget.group.expenses.removeWhere(
                  (expense) => expense['paidBy'] == member,
                );

                // For remaining expenses, exclude this member from split calculation
                // but keep them in the group
                for (var expense in widget.group.expenses) {
                  // Recalculate split among remaining active members
                  // (all members except the one being cleared)
                  int activeMembersCount = widget.group.members.length - 1;
                  if (activeMembersCount > 0) {
                    expense['splitAmount'] =
                        (expense['price'] as double) / activeMembersCount;
                    // Mark which member is excluded from this expense
                    expense['excludedMembers'] =
                        expense['excludedMembers'] ?? [];
                    if (!expense['excludedMembers'].contains(member)) {
                      expense['excludedMembers'].add(member);
                    }
                  }
                }
              });
              widget.onGroupUpdated(widget.group);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Amount cleared for $member'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: Text('Clear', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  void _addNewMember() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Member'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Member Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              String name = controller.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter member name'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              if (widget.group.members.contains(name)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Member already exists'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              setState(() {
                widget.group.members.add(name);
                _selectedMembers = List.from(widget.group.members);

                // Exclude new member from all existing expenses
                for (var expense in widget.group.expenses) {
                  expense['excludedMembers'] = expense['excludedMembers'] ?? [];
                  if (!expense['excludedMembers'].contains(name)) {
                    expense['excludedMembers'].add(name);
                  }
                }
              });
              widget.onGroupUpdated(widget.group);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$name added to group'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteMember(String member) {
    if (widget.group.members.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot delete member. Group must have at least 2 members.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Member'),
        content: Text(
          'Are you sure you want to remove $member from the group? This will also remove all expenses paid by this member.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                // Remove member from group
                widget.group.members.remove(member);

                // Remove expenses paid by this member
                widget.group.expenses.removeWhere(
                  (expense) => expense['paidBy'] == member,
                );

                // Recalculate split amounts for remaining expenses
                for (var expense in widget.group.expenses) {
                  expense['splitAmount'] =
                      (expense['price'] as double) /
                      widget.group.members.length;
                }
              });
              widget.onGroupUpdated(widget.group);
              Navigator.pop(context);
              SoundHelper.playDeleteSound();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$member removed from group'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSettlementDetails() {
    // Pairwise ledger: who owes whom how much
    Map<String, Map<String, double>> ledger = {};

    // Initialize ledger
    for (var m in widget.group.members) {
      ledger[m] = {};
      for (var n in widget.group.members) {
        if (m != n) ledger[m]![n] = 0.0;
      }
    }

    // For each expense, update the ledger
    for (var expense in widget.group.expenses.reversed) {
      double amount = expense['price'] as double;
      String paidBy = expense['paidBy'] ?? widget.group.members[0];
      String category = expense['category'] ?? '';

      if (category == 'Settlement') {
        // Handle settlement payments - reduce debt directly
        List<dynamic> includedMembers = widget.group.members
            .where((m) => !(expense['excludedMembers'] ?? []).contains(m))
            .toList();
        if (includedMembers.length == 1) {
          String payer = includedMembers[0];
          // Reduce the debt from payer to receiver
          ledger[payer]![paidBy] = (ledger[payer]![paidBy] ?? 0) - amount;
          if (ledger[payer]![paidBy]! < 0) {
            ledger[payer]![paidBy] = 0;
          }
        }
      } else {
        // Handle regular expenses
        List<dynamic> includedMembers = widget.group.members
            .where((m) => !(expense['excludedMembers'] ?? []).contains(m))
            .toList();
        double share = amount / includedMembers.length;

        for (var member in includedMembers) {
          if (member != paidBy) {
            ledger[member]![paidBy] = (ledger[member]![paidBy] ?? 0) + share;
          }
        }
      }
    }

    // Net off mutual debts for each pair
    for (var m in widget.group.members) {
      for (var n in widget.group.members) {
        if (m != n) {
          double owe = ledger[m]![n] ?? 0;
          double owed = ledger[n]![m] ?? 0;
          if (owe > owed) {
            ledger[m]![n] = owe - owed;
            ledger[n]![m] = 0;
          } else {
            ledger[n]![m] = owed - owe;
            ledger[m]![n] = 0;
          }
        }
      }
    }

    // Prepare settlements list
    List<Map<String, dynamic>> settlements = [];
    for (var m in widget.group.members) {
      for (var n in widget.group.members) {
        if (m != n && (ledger[m]![n] ?? 0) > 0.01) {
          settlements.add({'from': m, 'to': n, 'amount': ledger[m]![n]!});
        }
      }
    }

    // Always update settlement state to reflect current calculations
    _settlementState = settlements;

    if (_settlementState.isEmpty) {
      return [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 32),
                SizedBox(height: 8),
                Text(
                  'All Settled! 🎉',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Text(
                  'No one owes anyone money',
                  style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Column(
          children: _settlementState.map((settlement) {
            return Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: InkWell(
                onLongPress: () async {
                  final controller = TextEditingController();
                  double maxReturn = settlement['amount'];
                  double? enteredAmount = await showDialog<double>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Return Amount'),
                      content: TextField(
                        controller: controller,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText:
                              'Enter amount to return (max ₹${maxReturn.toStringAsFixed(2)})',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, null),
                          child: Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            double? value = double.tryParse(controller.text);
                            if (value == null ||
                                value <= 0 ||
                                value > maxReturn) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Enter valid amount (max ₹${maxReturn.toStringAsFixed(2)})',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            Navigator.pop(context, value);
                          },
                          child: Text('Return'),
                        ),
                      ],
                    ),
                  );
                  if (enteredAmount != null) {
                    // Create a payment expense to track the settlement
                    final paymentExpense = {
                      'category': 'Settlement',
                      'name':
                          'Payment: ${settlement['from']} to ${settlement['to']}',
                      'price': enteredAmount,
                      'paymentMethod': 'Settlement',
                      'time': DateTime.now().toIso8601String(),
                      'splitAmount': enteredAmount,
                      'paidBy':
                          settlement['to'], // The person receiving the payment
                      'excludedMembers': widget.group.members
                          .where((m) => m != settlement['from'])
                          .toList(), // Only the payer is included
                    };

                    setState(() {
                      widget.group.expenses.insert(0, paymentExpense);
                    });

                    widget.onGroupUpdated(widget.group);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${settlement['from']} paid ₹${enteredAmount.toStringAsFixed(2)} to ${settlement['to']}',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                child: Row(
                  children: [
                    Icon(Icons.arrow_forward, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.orange
                                : Colors.black87,
                          ),
                          children: [
                            TextSpan(
                              text: settlement['from'],
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: ' pays '),
                            TextSpan(
                              text: settlement['to'],
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: ' '),
                            TextSpan(
                              text:
                                  '₹${settlement['amount'].toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.group.name)),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Members Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Group Members (${widget.group.members.length})',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _addNewMember,
                  icon: Icon(Icons.person_add, size: 16),
                  label: Text('Add Member'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.group.members.map((member) {
                    return Chip(
                      label: Text(member),
                      avatar: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(
                          member[0].toUpperCase(),
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      onDeleted: widget.group.members.length > 2
                          ? () => _confirmDeleteMember(member)
                          : null,
                      deleteIcon: Icon(Icons.close, size: 16),
                    );
                  }).toList(),
                ),
              ),
            ),
            SizedBox(height: 20),

            // Add expense form
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add New Expense',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),

                    // Who Paid dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedPaidBy.isEmpty ? null : _selectedPaidBy,
                      decoration: InputDecoration(
                        labelText: 'Who Paid?',
                        border: OutlineInputBorder(),
                      ),
                      items: widget.group.members.map((member) {
                        return DropdownMenuItem(
                          value: member,
                          child: Text(member),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPaidBy = value ?? '';
                        });
                      },
                    ),
                    SizedBox(height: 12),

                    // With this:
                    InkWell(
                      onTap: () async {
                        final selected = await showDialog<List<String>>(
                          context: context,
                          builder: (context) {
                            List<String> tempSelected = List.from(
                              _selectedMembers,
                            );
                            return AlertDialog(
                              title: Text('Select Members'),
                              content: StatefulBuilder(
                                builder: (context, setState) {
                                  return SizedBox(
                                    width: double.maxFinite,
                                    child: ListView(
                                      shrinkWrap: true,
                                      children: widget.group.members.map((
                                        member,
                                      ) {
                                        return CheckboxListTile(
                                          value: tempSelected.contains(member),
                                          title: Text(member),
                                          onChanged: (checked) {
                                            setState(() {
                                              if (checked == true) {
                                                tempSelected.add(member);
                                              } else {
                                                tempSelected.remove(member);
                                              }
                                            });
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  );
                                },
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, null),
                                  child: Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () =>
                                      Navigator.pop(context, tempSelected),
                                  child: Text('OK'),
                                ),
                              ],
                            );
                          },
                        );
                        if (selected != null && selected.isNotEmpty) {
                          setState(() {
                            _selectedMembers = selected;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Select Members',
                          border: OutlineInputBorder(),
                        ),
                        child: Wrap(
                          spacing: 4,
                          children: _selectedMembers
                              .map((m) => Chip(label: Text(m)))
                              .toList(),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),

                    // Category dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          enabled: category != 'Categories',
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value!;
                        });
                      },
                    ),
                    SizedBox(height: 12),

                    // Payment method dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedPaymentMethod,
                      decoration: InputDecoration(
                        labelText: 'Payment Method',
                        border: OutlineInputBorder(),
                      ),
                      items: _paymentMethods.map((method) {
                        return DropdownMenuItem(
                          value: method,
                          enabled: method != 'Payment Method',
                          child: Text(method),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPaymentMethod = value!;
                        });
                      },
                    ),
                    SizedBox(height: 12),

                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Expense Name',
                        border: OutlineInputBorder(),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z ]')),
                      ],
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(),
                        prefixText: '₹',
                      ),
                    ),
                    SizedBox(height: 12),

                    ElevatedButton(
                      onPressed: _addExpense,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: Size(double.infinity, 45),
                      ),
                      child: Text('Add Expense'),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Settlement Details Section
            if (widget.group.expenses.isNotEmpty) ...[
              Text(
                'Settlement Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Card(
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(children: _buildSettlementDetails()),
                ),
              ),
              SizedBox(height: 20),
            ],

            // Group Expenses Section
            Text(
              'Payment History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),

            widget.group.expenses.isEmpty
                ? SizedBox(
                    height: 100,
                    child: Center(
                      child: Text(
                        'No expenses yet',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  )
                : Column(
                    children: widget.group.expenses.map((expense) {
                      final price = expense['price'] as double;
                      final splitAmount = expense['splitAmount'] as double;

                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: ExpansionTile(
                          title: Row(
                            children: [
                              Expanded(child: Text(expense['name'])),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Delete Expense',
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('Delete Expense'),
                                      content: Text(
                                        'Are you sure you want to delete this expense?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            setState(() {
                                              widget.group.expenses.remove(
                                                expense,
                                              );
                                            });
                                            widget.onGroupUpdated(widget.group);
                                            Navigator.pop(context);
                                            SoundHelper.playDeleteSound();
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Expense deleted',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          },
                                          child: Text(
                                            'Delete',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Split Details:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  ...widget.group.members.map((member) {
                                    // Check if member is excluded from this expense
                                    List<dynamic> excludedMembers =
                                        expense['excludedMembers'] ?? [];
                                    bool isExcluded = excludedMembers.contains(
                                      member,
                                    );

                                    return Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            member,
                                            style: TextStyle(
                                              color: isExcluded
                                                  ? Colors.grey
                                                  : null,
                                              decoration: isExcluded
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                          Text(
                                            isExcluded
                                                ? '₹0.00'
                                                : '₹${splitAmount.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isExcluded
                                                  ? Colors.grey
                                                  : Colors.green,
                                              decoration: isExcluded
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _Balance {
  final String member;
  double amount;
  _Balance(this.member, this.amount);
}
