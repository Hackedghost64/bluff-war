import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class UpdateService {
  static const String repoOwner = "Hackedghost64";
  static const String repoName = "bluff-war";

  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['tag_name'] as String;
        final downloadUrl = data['html_url'] as String;

        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        if (_isNewer(currentVersion, latestVersion)) {
          if (context.mounted) {
            _showUpdateDialog(context, latestVersion, downloadUrl);
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to check for updates: $e');
    }
  }

  static bool _isNewer(String current, String latest) {
    // Basic version comparison (e.g., 1.0.0 vs v1.0.1)
    final cleanLatest = latest.startsWith('v') ? latest.substring(1) : latest;
    return cleanLatest != current; 
  }

  static void _showUpdateDialog(BuildContext context, String version, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.blueGrey[900],
        title: const Text('NEW VERSION AVAILABLE', style: TextStyle(color: Colors.white, letterSpacing: 2)),
        content: Text('A new version ($version) is available on GitHub. Would you like to update now?', 
          style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('LATER')),
          ElevatedButton(
            onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            child: const Text('UPDATE NOW'),
          ),
        ],
      ),
    );
  }
}
