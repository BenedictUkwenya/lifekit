import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

// --- SECURITY ---
class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Password & Security")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildPassField("Current Password"),
            const SizedBox(height: 16),
            _buildPassField("New Password"),
            const SizedBox(height: 16),
            _buildPassField("Confirm New Password"),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text(
                  "Update Password",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassField(String label) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

// --- NOTIFICATIONS ---
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool push = true;
  bool email = true;
  bool promo = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notification Preferences")),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text("Push Notifications"),
            value: push,
            onChanged: (v) => setState(() => push = v),
            activeColor: AppColors.primary,
          ),
          SwitchListTile(
            title: const Text("Email Notifications"),
            value: email,
            onChanged: (v) => setState(() => email = v),
            activeColor: AppColors.primary,
          ),
          SwitchListTile(
            title: const Text("Promotional Offers"),
            value: promo,
            onChanged: (v) => setState(() => promo = v),
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

// --- LANGUAGES ---
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Languages")),
      body: ListView(
        children: const [
          ListTile(
            title: Text("English (US)"),
            trailing: Icon(Icons.check, color: AppColors.primary),
          ),
          ListTile(title: Text("French")),
          ListTile(title: Text("Spanish")),
        ],
      ),
    );
  }
}

// --- HELP CENTER ---
class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Help Center")),
      body: const Center(child: Text("FAQ and Support Chat coming soon")),
    );
  }
}
