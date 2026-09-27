import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Previously a bare Container with no Scaffold, so this screen had no
    // in-app way back once it was pushed from the sidebar.
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151827),
        foregroundColor: Colors.white,
        title: const Text('Support', style: TextStyle(fontSize: 18)),
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Get help and contact us',
              style: TextStyle(color: Colors.white60, fontSize: 16),
            ),
            SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _buildSection('Contact Us'),
                  _buildContactCard(
                    'Email Support',
                    'support@elijah.movies',
                    Icons.email_outlined,
                    () async {
                      final url = Uri.parse('mailto:support@elijah.movies');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                  ),
                  _buildContactCard(
                    'Live Chat',
                    'Chat with our support team',
                    Icons.chat_outlined,
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Live chat coming soon!')),
                      );
                    },
                  ),
                  _buildContactCard(
                    'Twitter',
                    '@ElijahMovies',
                    Icons.public,
                    () async {
                      final url = Uri.parse('https://twitter.com');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                  SizedBox(height: 30),
                  _buildSection('FAQ'),
                  _buildFaqItem(
                    'How do I add movies to favorites?',
                    'Click the heart icon on any movie detail page to add it to your favorites.',
                  ),
                  _buildFaqItem(
                    'Can I download movies for offline viewing?',
                    'Currently, downloading is available for premium members only.',
                  ),
                  _buildFaqItem(
                    'How do I change video quality?',
                    'Go to Settings > Playback > Video Quality to adjust your preferences.',
                  ),
                  _buildFaqItem(
                    'Is there a premium plan?',
                    'Yes! Premium plans offer ad-free viewing, offline downloads, and early access to new releases.',
                  ),
                  SizedBox(height: 30),
                  _buildSection('About'),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Color(0xFF1A1F26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.movie, color: Colors.amber, size: 32),
                            SizedBox(width: 12),
                            Text(
                              'Elijah',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Version 1.0.0',
                          style: TextStyle(color: Colors.white60, fontSize: 14),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Your ultimate movie streaming companion',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '© 2025 Elijah Movies. All rights reserved.',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
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

  Widget _buildContactCard(
      String title, String subtitle, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFF1A1F26),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.amber),
            ),
            SizedBox(width: 16),
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
            Icon(Icons.chevron_right, color: Colors.white30),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1A1F26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            answer,
            style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}
