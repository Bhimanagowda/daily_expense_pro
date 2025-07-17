import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'l10n/app_localizations.dart';

class SettingsPage extends StatefulWidget {
  final Function(Locale) onLanguageChanged;
  final Function(bool)? onThemeChanged;

  const SettingsPage({
    super.key,
    required this.onLanguageChanged,
    this.onThemeChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _selectedLanguage = 'en';
  bool _isDarkMode = false;
  bool _isLoading = true;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _getAppVersion();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('language_code') ?? 'en';
      _isDarkMode = prefs.getBool('dark_mode') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _saveThemePreference(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', isDark);
    setState(() {
      _isDarkMode = isDark;
    });

    // Notify parent about theme change
    widget.onThemeChanged?.call(isDark);
  }

  Future<void> _saveLanguagePreference(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
    setState(() {
      _selectedLanguage = languageCode;
    });

    // Notify parent about language change
    widget.onLanguageChanged(Locale(languageCode));
  }

  Future<void> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
      });
    } catch (e) {
      setState(() {
        _appVersion = '1.0.0';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.settings),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.language,
                                color: Colors.blue,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                localizations.language,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            localizations.changeLanguage,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // English Option
                          RadioListTile<String>(
                            title: Text(localizations.english),
                            subtitle: Text('English'),
                            value: 'en',
                            groupValue: _selectedLanguage,
                            onChanged: (String? value) {
                              if (value != null) {
                                _saveLanguagePreference(value);
                              }
                            },
                            activeColor: Colors.blue,
                          ),

                          // Kannada Option
                          RadioListTile<String>(
                            title: Text(localizations.kannada),
                            subtitle: Text('ಕನ್ನಡ'),
                            value: 'kn',
                            groupValue: _selectedLanguage,
                            onChanged: (String? value) {
                              if (value != null) {
                                _saveLanguagePreference(value);
                              }
                            },
                            activeColor: Colors.blue,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Dark Mode Card
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.dark_mode,
                                color: Colors.blue,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Theme',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SwitchListTile(
                            title: Text('Dark Mode'),
                            subtitle: Text(
                              _isDarkMode
                                  ? 'Dark theme enabled'
                                  : 'Light theme enabled',
                            ),
                            value: _isDarkMode,
                            onChanged: (bool value) {
                              _saveThemePreference(value);
                            },
                            activeColor: Colors.blue,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Version info card
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'App Information',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          ListTile(
                            title: Text('Version'),
                            subtitle: Text(
                              _appVersion.isNotEmpty
                                  ? _appVersion
                                  : 'Loading...',
                            ),
                            leading: Icon(Icons.android, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
