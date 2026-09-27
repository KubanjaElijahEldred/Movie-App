import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool darkMode = true;
  bool notifications = true;
  bool autoPlay = true;
  String quality = 'HD';

  @override
  Widget build(BuildContext context) {
    // Previously a bare Container with no Scaffold, so this screen had no
    // in-app way back once it was pushed from the sidebar.
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151827),
        foregroundColor: Colors.white,
        title: const Text('Settings', style: TextStyle(fontSize: 18)),
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manage your preferences',
              style: TextStyle(color: Colors.white60, fontSize: 16),
            ),
            SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _buildSection('Appearance'),
                  _buildSwitchTile(
                    'Dark Mode',
                    'Use dark theme',
                    darkMode,
                    (value) => setState(() => darkMode = value),
                  ),
                  SizedBox(height: 30),
                  _buildSection('Playback'),
                  _buildSwitchTile(
                    'Auto-Play Trailers',
                    'Automatically play trailers when viewing details',
                    autoPlay,
                    (value) => setState(() => autoPlay = value),
                  ),
                  _buildQualityTile(),
                  SizedBox(height: 30),
                  _buildSection('Notifications'),
                  _buildSwitchTile(
                    'Push Notifications',
                    'Receive updates about new releases',
                    notifications,
                    (value) => setState(() => notifications = value),
                  ),
                  SizedBox(height: 30),
                  _buildSection('Account'),
                  _buildActionTile('Clear Cache', Icons.delete_outline, () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Cache cleared successfully')),
                    );
                  }),
                  _buildActionTile(
                      'Privacy Policy', Icons.privacy_tip_outlined, () {}),
                  _buildActionTile(
                      'Terms of Service', Icons.description_outlined, () {}),
                  SizedBox(height: 20),
                  _buildActionTile('Sign Out', Icons.logout, () {},
                      isDestructive: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
      String title, String subtitle, bool value, Function(bool) onChanged) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1A1F26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.amber,
          ),
        ],
      ),
    );
  }

  Widget _buildQualityTile() {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1A1F26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Video Quality',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 4),
                Text(
                  'Select preferred streaming quality',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
          DropdownButton<String>(
            value: quality,
            dropdownColor: Color(0xFF1A1F26),
            underline: SizedBox(),
            style: TextStyle(color: Colors.white),
            items: ['SD', 'HD', '4K'].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (value) => setState(() => quality = value!),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(String title, IconData icon, VoidCallback onTap,
      {bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFF1A1F26),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: isDestructive ? Colors.red : Colors.white70),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isDestructive ? Colors.red : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white30),
          ],
        ),
      ),
    );
  }
}
