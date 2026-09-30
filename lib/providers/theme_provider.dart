// lib/providers/theme_provider.dart
// ✅ Phase 2 Fix #14: إضافة StreamSubscription لـ _listenToSeason() مع dispose() صحيح.
// قبل هذا الإصلاح، كان الـ Firestore stream يظل نشطاً إلى ما لا نهاية حتى بعد
// تدمير ThemeProvider، مما يُسبب memory leak وأحياناً "setState after dispose".
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ThemeProvider with ChangeNotifier {
  static const String _key = 'themeMode';

  ThemeMode _themeMode = ThemeMode.system;
  String currentSeason = 'none';

  // ✅ Fix #14: حقل لتخزين الـ subscription حتى نستطيع إلغاءه في dispose()
  StreamSubscription<DocumentSnapshot>? _seasonSubscription;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadTheme();
    _listenToSeason();
  }

  // ✅ Fix #14: dispose() يُلغي الـ stream — يمنع memory leak
  @override
  void dispose() {
    _seasonSubscription?.cancel();
    super.dispose();
  }

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    _saveTheme();
    notifyListeners();
  }

  void setTheme(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _saveTheme();
    notifyListeners();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeString = prefs.getString(_key);
      if (themeString == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (themeString == 'light') {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.system;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme: $e');
    }
  }

  Future<void> _saveTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String themeString;
      if (_themeMode == ThemeMode.dark) {
        themeString = 'dark';
      } else if (_themeMode == ThemeMode.light) {
        themeString = 'light';
      } else {
        themeString = 'system';
      }
      await prefs.setString(_key, themeString);
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }

  // ✅ Fix #14: نحفظ الـ subscription في _seasonSubscription بدل إهماله
  void _listenToSeason() {
    _seasonSubscription = FirebaseFirestore.instance
        .collection('settings')
        .doc('general')
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data();
          if (data != null && data.containsKey('season')) {
            final newSeason = data['season'] as String? ?? 'none';
            if (newSeason != currentSeason) {
              currentSeason = newSeason;
              notifyListeners();
            }
          }
        }
      },
      onError: (e) => debugPrint('Error listening to season: $e'),
    );
  }
}
