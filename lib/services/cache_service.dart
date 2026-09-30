// lib/services/cache_service.dart
//
// ✅ P2-03 Fix: حُذف الـ plaintext fallback block بالكامل من init().
//
// المشكلة الأصلية:
//   عند فشل فتح صناديق Hive المشفَّرة، الكود القديم كان يفتح صناديق
//   بدون تشفير، مما يُخزِّن بيانات المستخدم على القرص بدون حماية.
//
// الإصلاح:
//   عند فشل التشفير، نُحاول recovery (حذف صناديق تالفة + مفتاح جديد).
//   إذا فشل Recovery أيضاً: التطبيق يعمل بدون كاش (degraded mode).
//
// الإصلاح:
//   عند فشل التشفير نُجرب استراتيجية recovery واحدة:
//     1. حذف صناديق Hive القديمة التالفة (قد تكون مشفَّرة بمفتاح مختلف).
//     2. توليد مفتاح تشفير جديد وإعادة فتح الصناديق.
//   إذا فشل Recovery أيضاً، التطبيق يعمل بدون كاش (degraded mode):
//     _isInitialized = false — كل دوال الكاش تُرجع null/تتخطى الحفظ.
//   هذا أفضل من الكتابة plaintext — المستخدم لا يلاحظ فرقاً وظيفياً
//   لأن التطبيق يجلب من Firestore مباشرة كـ fallback.
import 'dart:developer' as developer;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static const String _shopsBox = 'shops_cache';
  static const String _productsBox = 'products_cache';
  static const String _offersBox = 'offers_cache';
  static const String _userBox = 'user_cache';
  static const String _categoriesBox = 'categories_cache';
  static const String _encKeyName = 'hive_enc_key_v3';

  static const _secureStorage = FlutterSecureStorage(
    // ✅ encryptedSharedPreferences deprecated → use default Android keystore
    aOptions: AndroidOptions.defaultOptions,
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const Duration cacheDuration = Duration(hours: 1);

  Box? _shopsCache;
  Box? _productsCache;
  Box? _offersCache;
  Box? _userCache;
  Box? _categoriesCache;

  // ✅ P2-03: _isInitialized = false → يعني degraded mode، لا plaintext
  bool _isInitialized = false;

  Future<List<int>> _getOrCreateEncryptionKey() async {
    try {
      final stored = await _secureStorage.read(key: _encKeyName);
      if (stored != null && stored.isNotEmpty) {
        return stored.split(',').map(int.parse).toList();
      }
    } catch (e) {
      developer.log('SecureStorage read error: $e', name: 'CacheService');
    }
    final rng = Random.secure();
    final key = List<int>.generate(32, (_) => rng.nextInt(256));
    try {
      await _secureStorage.write(key: _encKeyName, value: key.join(','));
    } catch (e) {
      developer.log('SecureStorage write error: $e', name: 'CacheService');
    }
    return key;
  }

  // ✅ P2-03: مسح مفتاح التشفير القديم وتوليد مفتاح جديد نظيف
  Future<List<int>> _rotateEncryptionKey() async {
    try {
      await _secureStorage.delete(key: _encKeyName);
    } catch (_) {}
    final rng = Random.secure();
    final key = List<int>.generate(32, (_) => rng.nextInt(256));
    try {
      await _secureStorage.write(key: _encKeyName, value: key.join(','));
    } catch (e) {
      developer.log('Key rotation write error: $e', name: 'CacheService');
    }
    return key;
  }

  // ✅ P2-03: حذف صناديق Hive المشفَّرة التالفة من القرص
  Future<void> _deleteCorruptedBoxes() async {
    for (final boxName in [
      _shopsBox,
      _productsBox,
      _offersBox,
      _userBox,
      _categoriesBox,
    ]) {
      try {
        await Hive.deleteBoxFromDisk(boxName);
      } catch (e) {
        developer.log('Could not delete box $boxName: $e',
            name: 'CacheService');
      }
    }
  }

  Future<void> init() async {
    if (_isInitialized) return;

    await Hive.initFlutter();

    // ── المحاولة الأولى: فتح بالمفتاح الحالي ─────────────────────────────
    try {
      final encryptionKey = await _getOrCreateEncryptionKey();
      await _openAllBoxes(HiveAesCipher(encryptionKey));
      _isInitialized = true;
      _cleanExpiredData();
      return;
    } catch (firstError) {
      developer.log(
          'Cache Init (attempt 1) failed: $firstError — trying key rotation',
          name: 'CacheService');
    }

    // ── المحاولة الثانية: Recovery — حذف الصناديق التالفة + مفتاح جديد ────
    // ✅ P2-03: لا plaintext هنا — فقط محاولة إعادة بناء مشفَّرة
    try {
      await _deleteCorruptedBoxes();
      final freshKey = await _rotateEncryptionKey();
      await _openAllBoxes(HiveAesCipher(freshKey));
      _isInitialized = true;
      _cleanExpiredData();
      developer.log('Cache recovered with fresh encryption key',
          name: 'CacheService');
      return;
    } catch (secondError) {
      developer.log(
          'Cache Init (attempt 2) failed: $secondError — running in degraded mode (no cache)',
          name: 'CacheService');
      // ✅ P2-03: degraded mode — التطبيق يعمل بدون كاش ويجلب من Firestore مباشرة.
      // لا كتابة plaintext على القرص بأي شكل.
      _isInitialized = false;
    }
  }

  Future<void> _openAllBoxes(HiveAesCipher cipher) async {
    _shopsCache =
        await Hive.openBox(_shopsBox, encryptionCipher: cipher);
    _productsCache =
        await Hive.openBox(_productsBox, encryptionCipher: cipher);
    _offersCache =
        await Hive.openBox(_offersBox, encryptionCipher: cipher);
    _userCache =
        await Hive.openBox(_userBox, encryptionCipher: cipher);
    _categoriesCache =
        await Hive.openBox(_categoriesBox, encryptionCipher: cipher);
  }

  // ==========================================================
  // 1. المحلات (Shops)
  // ==========================================================

  Future<void> cacheShops(List<dynamic> shops, String category) async {
    if (!_isInitialized || _shopsCache == null) return;
    try {
      await _shopsCache!.put('cat_$category', {
        'data': shops,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'category': category,
      });
    } catch (e) {
      developer.log('cacheShops error: $e', name: 'CacheService');
    }
  }

  Future<List<dynamic>?> getCachedShops(String category) async {
    if (!_isInitialized || _shopsCache == null) return null;
    try {
      final cached = _shopsCache!.get('cat_$category');
      if (cached != null && _isCacheValid(cached['timestamp'] as int)) {
        return cached['data'] as List<dynamic>;
      } else if (cached != null) {
        await _shopsCache!.delete('cat_$category');
      }
    } catch (e) {
      developer.log('getCachedShops error: $e', name: 'CacheService');
    }
    return null;
  }

  // ==========================================================
  // 2. المنتجات (Products)
  // ==========================================================

  Future<void> cacheProducts(List<dynamic> products,
      {String? shopId, String? category}) async {
    if (!_isInitialized || _productsCache == null) return;
    try {
      final key = _generateProductKey(shopId, category);
      await _productsCache!.put(key, {
        'data': products,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'shopId': shopId,
        'category': category,
      });
    } catch (e) {
      developer.log('cacheProducts error: $e', name: 'CacheService');
    }
  }

  Future<List<dynamic>?> getCachedProducts(
      {String? shopId, String? category}) async {
    if (!_isInitialized || _productsCache == null) return null;
    try {
      final key = _generateProductKey(shopId, category);
      final cached = _productsCache!.get(key);
      if (cached != null && _isCacheValid(cached['timestamp'] as int)) {
        return cached['data'] as List<dynamic>;
      } else if (cached != null) {
        await _productsCache!.delete(key);
      }
    } catch (e) {
      developer.log('getCachedProducts error: $e', name: 'CacheService');
    }
    return null;
  }

  String _generateProductKey(String? shopId, String? category) {
    if (shopId != null) return 'shop_$shopId';
    if (category != null) return 'cat_$category';
    return 'all_products';
  }

  // ==========================================================
  // 3. العروض (Offers)
  // ==========================================================

  Future<void> cacheOffers(List<dynamic> offers, {String? shopId}) async {
    if (!_isInitialized || _offersCache == null) return;
    try {
      final key = shopId != null ? 'shop_$shopId' : 'all_offers';
      await _offersCache!.put(key, {
        'data': offers,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'shopId': shopId,
      });
    } catch (e) {
      developer.log('cacheOffers error: $e', name: 'CacheService');
    }
  }

  Future<List<dynamic>?> getCachedOffers({String? shopId}) async {
    if (!_isInitialized || _offersCache == null) return null;
    try {
      final key = shopId != null ? 'shop_$shopId' : 'all_offers';
      final cached = _offersCache!.get(key);
      if (cached != null && _isCacheValid(cached['timestamp'] as int)) {
        return cached['data'] as List<dynamic>;
      } else if (cached != null) {
        await _offersCache!.delete(key);
      }
    } catch (e) {
      developer.log('getCachedOffers error: $e', name: 'CacheService');
    }
    return null;
  }

  // ==========================================================
  // 4. الفئات (Categories)
  // ==========================================================

  Future<void> cacheCategories(List<dynamic> categories) async {
    if (!_isInitialized || _categoriesCache == null) return;
    try {
      await _categoriesCache!.put('all_categories', {
        'data': categories,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      developer.log('cacheCategories error: $e', name: 'CacheService');
    }
  }

  Future<List<dynamic>?> getCachedCategories() async {
    if (!_isInitialized || _categoriesCache == null) return null;
    try {
      final cached = _categoriesCache!.get('all_categories');
      if (cached != null &&
          _isCacheValid(cached['timestamp'] as int,
              duration: const Duration(days: 1))) {
        return cached['data'] as List<dynamic>;
      } else if (cached != null) {
        await _categoriesCache!.delete('all_categories');
      }
    } catch (e) {
      developer.log('getCachedCategories error: $e', name: 'CacheService');
    }
    return null;
  }

  // ==========================================================
  // 5. بيانات المستخدم
  // ==========================================================

  Future<void> cacheUserData(Map<String, dynamic> userData) async {
    if (!_isInitialized || _userCache == null) return;
    try {
      await _userCache!.put('user_data', {
        'data': userData,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      developer.log('cacheUserData error: $e', name: 'CacheService');
    }
  }

  // ✅ QA Fix #P3: إضافة تحقق من انتهاء صلاحية الـ cache (30 دقيقة)
  Future<Map<String, dynamic>?> getCachedUserData() async {
    if (!_isInitialized || _userCache == null) return null;
    try {
      final cached = _userCache!.get('user_data');
      if (cached == null) return null;
      if (!_isCacheValid(cached['timestamp'] as int,
          duration: const Duration(minutes: 30))) {
        await _userCache!.delete('user_data');
        return null;
      }
      return Map<String, dynamic>.from(cached['data'] as Map);
    } catch (e) {
      developer.log('getCachedUserData error: \$e', name: 'CacheService');
      return null;
    }
  }

  // ==========================================================
  // 6. البحث
  // ==========================================================

  Future<void> cacheSearchResults(String query, List<dynamic> results) async {
    if (!_isInitialized || _userCache == null) return;
    try {
      await _userCache!.put('search_$query', {
        'data': results,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      final recentSearches = await getRecentSearches();
      recentSearches.remove(query);
      recentSearches.insert(0, query);
      if (recentSearches.length > 10) recentSearches.removeLast();
      await _userCache!.put('recent_searches', recentSearches);
    } catch (e) {
      developer.log('cacheSearchResults error: $e', name: 'CacheService');
    }
  }

  Future<List<String>> getRecentSearches() async {
    if (!_isInitialized || _userCache == null) return [];
    try {
      final data = _userCache!.get('recent_searches');
      if (data is List) return List<String>.from(data);
    } catch (_) {}
    return [];
  }

  // ==========================================================
  // 7. الصيانة والتنظيف
  // ==========================================================

  bool _isCacheValid(int timestamp, {Duration duration = cacheDuration}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return now - timestamp < duration.inMilliseconds;
  }

  // ✅ QA Fix #20: تأخير التنظيف 5 ثوانٍ لإعطاء الأولوية لبدء التطبيق وتجنب jank
  Future<void> _cleanExpiredData() async {
    Future.delayed(const Duration(seconds: 5), () async {
      final boxes = <Box?>[
        _shopsCache,
        _productsCache,
        _offersCache,
        _categoriesCache,
      ];
      for (final box in boxes) {
        if (box != null && box.isOpen) {
          await _cleanBox(box, box.name);
        }
      }
    });
  }

  Future<void> _cleanBox(Box box, String boxName) async {
    if (!box.isOpen) return;
    final keysToRemove = <dynamic>[];
    for (final key in box.keys) {
      try {
        final cached = box.get(key);
        if (cached == null ||
            cached is! Map ||
            !cached.containsKey('timestamp') ||
            !_isCacheValid(cached['timestamp'] as int)) {
          keysToRemove.add(key);
        }
      } catch (_) {
        keysToRemove.add(key);
      }
    }
    if (keysToRemove.isNotEmpty) {
      await box.deleteAll(keysToRemove);
      debugPrint(
          '🧹 CacheService: removed ${keysToRemove.length} expired items from $boxName');
    }
  }

  Future<void> clearAllCache() async {
    if (!_isInitialized) return;
    for (final box in [_shopsCache, _productsCache, _offersCache, _categoriesCache]) {
      try {
        await box?.clear();
      } catch (_) {}
    }
    // _userCache مقصود — يبقى لإبقاء جلسة المستخدم
  }
}
