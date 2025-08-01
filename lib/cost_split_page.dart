import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'group_detail_page.dart';
import 'individual_share_bill.dart';
import 'package:audioplayers/audioplayers.dart';
import 'sound_helper.dart';

// Add the missing constants
const List<String> _categories = [
  'Categories',
  'Food & Dining',
  'Transportation',
  'Shopping',
  'Entertainment',
  'Bills & Utilities',
  'Healthcare',
  'Travel',
  'Education',
  'Groceries',
  'Other',
];

const List<String> _paymentMethods = [
  'Payment Method',
  'Cash',
  'Credit Card',
  'Debit Card',
  'UPI',
  'Net Banking',
  'Digital Wallet',
];

class Group {
  String id;
  String name;
  List<String> members;
  List<Map<String, dynamic>> expenses;

  Group({
    required this.id,
    required this.name,
    required this.members,
    required this.expenses,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'members': members,
    'expenses': expenses,
  };

  factory Group.fromJson(Map<String, dynamic> json) => Group(
    id: json['id'],
    name: json['name'],
    members: List<String>.from(json['members']),
    expenses: List<Map<String, dynamic>>.from(json['expenses']),
  );
}

class CostSplitPage extends StatefulWidget {
  const CostSplitPage({super.key});

  @override
  _CostSplitPageState createState() => _CostSplitPageState();
}

class _CostSplitPageState extends State<CostSplitPage> {
  List<Group> _groups = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  String _selectedCategory = _categories[0];
  String _selectedPaymentMethod = _paymentMethods[0];
  String? _selectedGroupId;


  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final groupsJson = prefs.getString('cost_split_groups') ?? '[]';
    final List<dynamic> groupsList = json.decode(groupsJson);

    setState(() {
      _groups = groupsList.map((g) => Group.fromJson(g)).toList();
    });
  }

  Future<void> _saveGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final groupsJson = json.encode(_groups.map((g) => g.toJson()).toList());
    await prefs.setString('cost_split_groups', groupsJson);
  }

  void _createGroup() {
    showDialog(
      context: context,
      builder: (context) => CreateGroupDialog(
        onGroupCreated: (Group group) {
          setState(() {
            _groups.add(group);
          });
          _saveGroups();
        },
      ),
    );
  }

  void _addGroupExpense() {
    String name = _nameController.text.trim();
    double? price = double.tryParse(_priceController.text.trim());

    if (name.isNotEmpty &&
        price != null &&
        _selectedCategory != 'Categories' &&
        _selectedPaymentMethod != 'Payment Method' &&
        _selectedGroupId != null) {
      // Find the selected group
      Group? selectedGroup = _groups.firstWhere(
        (group) => group.id == _selectedGroupId,
      );

      final splitAmount = price / selectedGroup.members.length;

      final expense = {
        'category': _selectedCategory,
        'name': name,
        'price': price,
        'paymentMethod': _selectedPaymentMethod,
        'time': DateTime.now().toIso8601String(),
        'splitAmount': splitAmount,
      };

      setState(() {
        selectedGroup.expenses.insert(0, expense);
        _nameController.clear();
        _priceController.clear();
        _selectedCategory = _categories[0];
        _selectedPaymentMethod = _paymentMethods[0];
        _selectedGroupId = null;
      });

      _saveGroups();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Expense added to ${selectedGroup.name}! Each member owes ₹${splitAmount.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'View Details',
            textColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      IndividualShareBillPage(group: selectedGroup),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Share Bill')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Groups Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Groups',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _createGroup,
                  icon: Icon(Icons.add),
                  label: Text('Create Group'),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Groups List
            _groups.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group, size: 80, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text(
                          'No groups yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap "Create Group" to get started',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: _groups.map((group) {
                      return Card(
                        margin: EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green,
                            child: Icon(Icons.group, color: Colors.white),
                          ),
                          title: Text(group.name),
                          subtitle: Text(
                            '${group.members.length} members • ${group.expenses.length} expenses',
                          ),
                          trailing: Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GroupDetailPage(
                                  group: group,
                                  onGroupUpdated: (updatedGroup) {
                                    setState(() {
                                      int index = _groups.indexWhere(
                                        (g) => g.id == updatedGroup.id,
                                      );
                                      if (index != -1) {
                                        _groups[index] = updatedGroup;
                                      }
                                    });
                                    _saveGroups();
                                  },
                                ),
                              ),
                            );
                          },
                          onLongPress: () => _showDeleteGroupDialog(group),
                        ),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  void _showDeleteGroupDialog(Group group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Group'),
        content: Text(
          'Are you sure you want to delete "${group.name}"? This will remove all expenses and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() {
                _groups.removeWhere((g) => g.id == group.id);
              });
              _saveGroups();
              Navigator.pop(context);
              await SoundHelper.playDeleteSound();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Group "${group.name}" deleted'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class CreateGroupDialog extends StatefulWidget {
  final Function(Group) onGroupCreated;

  const CreateGroupDialog({super.key, required this.onGroupCreated});

  @override
  _CreateGroupDialogState createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _memberController = TextEditingController();
  final List<String> _members = [];

  void _addMember() {
    String member = _memberController.text.trim();
    if (member.isNotEmpty && !_members.contains(member)) {
      setState(() {
        _members.add(member);
        _memberController.clear();
      });
    }
  }

  void _removeMember(int index) {
    setState(() {
      _members.removeAt(index);
    });
  }

  void _createGroup() {
    String groupName = _groupNameController.text.trim();
    if (groupName.isNotEmpty && _members.length >= 2) {
      final group = Group(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: groupName,
        members: List.from(_members),
        expenses: [],
      );
      widget.onGroupCreated(group);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Create New Group'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                labelText: 'Group Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _memberController,
                    decoration: InputDecoration(
                      labelText: 'Member Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(onPressed: _addMember, child: Text('Add')),
              ],
            ),
            SizedBox(height: 16),
            if (_members.isNotEmpty) ...[
              Text('Members:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              ...List.generate(_members.length, (index) {
                return ListTile(
                  dense: true,
                  title: Text(_members[index]),
                  trailing: IconButton(
                    icon: Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => _removeMember(index),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _members.length >= 2 ? _createGroup : null,
          child: Text('Create'),
        ),
      ],
    );
  }
}
