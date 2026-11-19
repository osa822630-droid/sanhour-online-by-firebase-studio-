// lib/widgets/force_update_dialog.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ForceUpdateChecker {
  static Future<bool> check(BuildContext context) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('general')
          .get();
      if (!doc.exists) {
        return false;
      }
      final data = doc.data()!;
      final forceUpdate = data['forceUpdate'] ?? false;
      if (!forceUpdate) {
        return false;
      }

      final minVersion = (data['minRequiredVersion'] ?? '').toString().trim();
      if (minVersion.isEmpty) {
        return false;
      }

      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      if (_isVersionLower(currentVersion, minVersion)) {
        if (!context.mounted) {
          return false;
        }
        final customUrl = (data['updateUrl'] ?? '').toString().trim();
        _showUpdateDialog(
          context,
          message: data['updateMessage'] ??
              'يرجى تحديث التطبيق للاستمرار في الاستخدام.',
          minVersion: minVersion,
          customUpdateUrl: customUrl,
        );
        return true;
      }
    } catch (_) {}
    return false;
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
    } catch (_) {
      return false;
    }
  }

  static String _resolveUpdateUrl(String customUpdateUrl) {
    if (customUpdateUrl.isNotEmpty) return customUpdateUrl;
    if (!kIsWeb && Platform.isIOS) {
      return 'https://sanhour.online/download';
    }
    return 'https://play.google.com/store/apps/details?id=com.sanhour.online';
  }

  static void _showUpdateDialog(
    BuildContext context, {
    required String message,
    required String minVersion,
    required String customUpdateUrl,
  }) {
    final targetUrl = _resolveUpdateUrl(customUpdateUrl);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.system_update_alt, color: Color(0xFF3D6B5E)),
            SizedBox(width: 10),
            Text('تحديث مطلوب'),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(message,
                textAlign: TextAlign.center,
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
                  backgroundColor: Color(0xFF3D6B5E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => launchUrl(
                  Uri.parse(targetUrl),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.download),
                label:
                    const Text('تحديث الآن', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
