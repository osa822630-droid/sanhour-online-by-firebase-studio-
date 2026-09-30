// lib/widgets/force_update_dialog.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ForceUpdateChecker {
  static Future<void> check(BuildContext context) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings').doc('general').get();
      if (!doc.exists) return;
      final data = doc.data()!;
      final forceUpdate = data['forceUpdate'] ?? false;
      if (!forceUpdate) return;

      final minVersion = data['minRequiredVersion'] ?? '';
      if (minVersion.isEmpty) return;

      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      if (_isVersionLower(currentVersion, minVersion)) {
        if (!context.mounted) return;
        _showUpdateDialog(context,
            message: data['updateMessage'] ?? 'يرجى تحديث التطبيق للاستمرار في الاستخدام.',
            minVersion: minVersion);
      }
    } catch (_) {}
  }

  static bool _isVersionLower(String current, String minimum) {
    try {
      final cur = current.split('.').map(int.parse).toList();
      final min = minimum.split('.').map(int.parse).toList();
      for (int i = 0; i < 3; i++) {
        final c = i < cur.length ? cur[i] : 0;
        final m = i < min.length ? min[i] : 0;
        if (c < m) return true;
        if (c > m) return false;
      }
      return false;
    } catch (_) { return false; }
  }

  static void _showUpdateDialog(BuildContext context,
      {required String message, required String minVersion}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.system_update_alt, color: Colors.deepPurple),
            SizedBox(width: 10),
            Text('تحديث مطلوب'),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(height: 1.6)),
            const SizedBox(height: 12),
            Text('الإصدار المطلوب: $minVersion',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => launchUrl(
                    Uri.parse('https://play.google.com/store/apps/details?id=com.sanhour.online'),
                    mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.download),
                label: const Text('تحديث الآن', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
