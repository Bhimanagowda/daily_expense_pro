import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'auth/login_page.dart';

class ProfilePage extends StatefulWidget {
  final Function(Locale) onLanguageChanged;

  const ProfilePage({super.key, required this.onLanguageChanged});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String username = '';
  String email = '';
  bool isLoading = true;
  String? profileImagePath;
  String appVersion = '';
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _getAppVersion();
  }

  Future<void> _getAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    String? currentUserJson = prefs.getString('currentUser');

    if (currentUserJson != null) {
      Map<String, dynamic> currentUser = jsonDecode(currentUserJson);
      String userId = currentUser['username'];
      String? imagePath = prefs.getString('profileImagePath_$userId');

      setState(() {
        username = currentUser['username'] ?? '';
        email = currentUser['email'] ?? '';
        profileImagePath = imagePath;
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final prefs = await SharedPreferences.getInstance();
        String? currentUserJson = prefs.getString('currentUser');

        if (currentUserJson != null) {
          Map<String, dynamic> currentUser = jsonDecode(currentUserJson);
          String userId = currentUser['username'];
          await prefs.setString('profileImagePath_$userId', image.path);
          setState(() {
            profileImagePath = image.path;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  Future<void> _deleteAccount() async {
    // Show confirmation dialog
    bool confirmDelete =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Delete Account'),
            content: Text(
              'Are you sure you want to delete your account? This will erase all your data and cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmDelete) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      String? currentUserJson = prefs.getString('currentUser');

      if (currentUserJson != null) {
        Map<String, dynamic> currentUser = jsonDecode(currentUserJson);
        String userId = currentUser['username'];

        // Get all users
        List<String> usersJson = prefs.getStringList('users') ?? [];
        List<Map<String, dynamic>> users = usersJson
            .map((userStr) => Map<String, dynamic>.from(jsonDecode(userStr)))
            .toList();

        // Remove current user from the list
        users.removeWhere((user) => user['username'] == userId);

        // Save updated users list
        List<String> updatedUsersJson = users
            .map((user) => jsonEncode(user))
            .toList();
        await prefs.setStringList('users', updatedUsersJson);

        // Delete all user-specific data
        await prefs.remove('items_$userId');
        await prefs.remove('totalAmount_$userId');
        await prefs.remove('borrowList_$userId');
        await prefs.remove('totalBorrowAmount_$userId');
        await prefs.remove('lendList_$userId');
        await prefs.remove('totalLendAmount_$userId');
        await prefs.remove('profileImagePath_$userId');

        // Clear login state
        await prefs.setBool('isLoggedIn', false);
        await prefs.remove('currentUser');

        // Navigate to login page
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) =>
                LoginPage(onLanguageChanged: widget.onLanguageChanged),
          ),
          (route) => false,
        );

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.blue.shade100,
                            backgroundImage: profileImagePath != null
                                ? FileImage(File(profileImagePath!))
                                : null,
                            child: profileImagePath == null
                                ? Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.blue,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: _pickImage,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 30),
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'User Information',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                            SizedBox(height: 20),
                            Row(
                              children: [
                                Icon(Icons.person, color: Colors.blue),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Username',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        username,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                            Row(
                              children: [
                                Icon(Icons.email, color: Colors.blue),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Email',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        email,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 40),

                    // Version info card has been moved to settings page
                    Container(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.delete_forever),
                        label: Text('Delete Account'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: _deleteAccount,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
