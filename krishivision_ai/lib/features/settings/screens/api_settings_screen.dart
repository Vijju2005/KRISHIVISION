import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/app_config.dart';

class ApiSettingsScreen extends StatefulWidget {
  const ApiSettingsScreen({super.key});

  @override
  State<ApiSettingsScreen> createState() => _ApiSettingsScreenState();
}

class _ApiSettingsScreenState extends State<ApiSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ipController = TextEditingController();
  bool _useDefault = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('api_base_url');
    if (savedUrl == null || savedUrl.isEmpty) {
      setState(() {
        _ipController.text = AppConfig.backendBaseUrl;
        _useDefault = true;
      });
    } else {
      setState(() {
        _ipController.text = savedUrl;
        _useDefault = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    if (_useDefault) {
      await prefs.remove('api_base_url');
    } else {
      await prefs.setString('api_base_url', _ipController.text.trim());
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Server configurations saved successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('API Server Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Network Configuration',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Set the FastAPI server URL. Real Android devices connected over Wi-Fi must use the local LAN IP of the host PC.',
                    style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    title: const Text('Use Default / Auto-detect', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    value: _useDefault,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setState(() {
                        _useDefault = val;
                        if (val) {
                          _ipController.text = AppConfig.backendBaseUrl;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _ipController,
                    enabled: !_useDefault,
                    decoration: InputDecoration(
                      labelText: 'Server Base URL',
                      hintText: 'e.g., http://192.168.9.103:8000',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.link_rounded),
                    ),
                    validator: (value) {
                      if (_useDefault) return null;
                      if (value == null || value.trim().isEmpty) {
                        return 'Base URL cannot be empty';
                      }
                      final trimVal = value.trim();
                      if (!trimVal.startsWith('http://') && !trimVal.startsWith('https://')) {
                        return 'URL must start with http:// or https://';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Save Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
