// lib/services/local_favorites_service.dart
// ✅ Q1-5: تخزين المفضلة محلياً للضيف وللمستخدمين في وضع الاختبار
// يُستخدم كـ fallback عندما يكون currentUser = null
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalFavoritesService {
  static const _key = 'local_favorites_map';

  /// يجلب خريطة المفضلة المحلية: {'shop': ['id1','id2'], 'product': [...], ...}
  static Future<Map<String, Set<String>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw));
      return decoded.map((k, v) => MapEntry(k, Set<String>.from(v as List)));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _save(Map<String, Set<String>> data) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(data.map((k, v) => MapEntry(k, v.toList())));
    await prefs.setString(_key, encoded);
  }

  static Future<bool> isFavorite(String type, String id) async {
    final data = await load();
    return data[type]?.contains(id) ?? false;
  }

  static Future<void> add(String type, String id) async {
    final data = await load();
    data.putIfAbsent(type, () => {}).add(id);
    await _save(data);
  }

  static Future<void> remove(String type, String id) async {
    final data = await load();
    data[type]?.remove(id);
    await _save(data);
  }

  static Future<Set<String>> getIds(String type) async {
    final data = await load();
    return data[type] ?? {};
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
