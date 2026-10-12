// lib/providers/shops_provider.dart
//
// ✅ Phase 2 Fix #19 — newProducts getter:
//    كان يستخدم _products.reversed بدون ترتيب فعلي بـ createdAt.
//    الإصلاح: ترتيب تنازلي صريح بـ createdAt مع null-safety.
//
// ✅ Phase 2 Fix #20 — notifyListeners المكرر:
//    كانت _applyFilterAndSearch() تستدعي notifyListeners()، وكل دالة تستدعيها
//    (fetchShops/fetchProducts/fetchOffers) تستدعيه أيضاً في finally → استدعاءان
//    per fetch → rebuilds غير ضرورية.
//    الإصلاح: حُذف notifyListeners() من _applyFilterAndSearch()؛
//    تصبح دالة داخلية بحتة تُعدِّل _shops فقط.
//
// ✅ Phase 2 Fix #21 — Connectivity Auto-Refresh:
//    يستخدم dart:io (مدمج — لا حاجة لـ package جديد).
//    الـ ShopsProvider يكشف autoRefreshIfOnline() لأي شاشة تحتاجها.
//
// ✅ Phase 2 Fix #18 — ShopPage Pagination:
//    يُستخدم ShopService.getShopsPage / getNextShopsPage للتنقل بين الصفحات.
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:sanhour_online/models/ad_model.dart';
import 'package:sanhour_online/models/category_model.dart';
import 'package:sanhour_online/models/offer.dart';
import 'package:sanhour_online/models/product.dart';
import 'package:sanhour_online/models/shop.dart';
import 'package:sanhour_online/services/api_service.dart';
import 'package:sanhour_online/services/cache_service.dart';
import 'package:sanhour_online/services/shop_service.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ 3-07 Fix: ShopsProvider يراقب دورة حياة التطبيق.
// عند رجوع التطبيق للـ foreground بعد غياب، يُراجع الاتصال تلقائياً.
// يستخدم WidgetsBindingObserver المدمج — لا package جديد مطلوب.
class ShopsProvider with ChangeNotifier, WidgetsBindingObserver {
  List<Shop> _shops = [];
  List<Shop> _allShops = [];
  List<Product> _products = [];
  List<Offer> _allOffers = [];
  List<CategoryModel> _categories = [];
  List<AdModel> _ads = [];

  bool _isLoading = false;
  String? _selectedCategory;
  String? _searchQuery;
  String? _selectedRegion;
  String? _error;

  // ── Pagination state ─────────────────────────────────────
  DocumentSnapshot? _lastShopDocument;
  bool _hasMoreShops = false;
  bool _isLoadingMore = false;

  List<Shop> get shops => _shops;
  List<Product> get products => _products;
  List<Offer> get allOffers => _allOffers;
  List<Offer> get offers => _allOffers;
  List<CategoryModel> get categories => _categories;
  List<AdModel> get ads => _ads;
  bool get isLoading => _isLoading;
  bool get hasMoreShops => _hasMoreShops;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  String? get searchQuery => _searchQuery;
  String? get selectedRegion => _selectedRegion;
  // ✅ إصلاح: getter مفقود — كان يمنع الشاشات من قراءة الفئة الحالية
  // المُختارة قبل تنفيذ عملية تحدّث تحافظ على الفلتر
  String? get selectedCategory => _selectedCategory;

  List<String> get availableRegions {
    final regions = _allShops
        .map((s) => s.location.trim())
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['الكل', ...regions];
  }

  void filterByRegion(String? region) {
    _selectedRegion = (region == 'الكل') ? null : region;
    _applyFilterAndSearch();
    notifyListeners(); // ← الاستدعاء الوحيد
  }

  List<String> get mainCategories {
    if (_categories.isEmpty) return ['الكل', 'أخرى'];
    return ['الكل', ..._categories.map((c) => c.name), 'أخرى'];
  }

  Map<String, List<String>> get subCategories {
    if (_categories.isEmpty) return {};
    return {
      for (var c in _categories)
        c.name: ['الكل', ...c.subCategories, 'أخرى']
    };
  }

  Map<String, List<String>> get subSubCategories {
    if (_categories.isEmpty) return {};
    final result = <String, List<String>>{};
    for (var c in _categories) {
      result.addAll(c.subSubCategories);
    }
    return result;
  }

  List<Shop> get bestShops {
    final sorted = List<Shop>.from(_shops)
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return sorted.take(10).toList();
  }

  List<Product> get bestProducts {
    final sorted = List<Product>.from(_products)
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return sorted.take(10).toList();
  }

  List<Offer> get bestOffers => _allOffers.take(10).toList();

  List<Shop> get newShops {
    final sorted = List<Shop>.from(_shops)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(10).toList();
  }

  List<Shop> get featuredShops => _shops.where((s) => s.isFeatured).toList();

  List<Shop> getPersonalizedShops(List<String> interests) {
    if (interests.isEmpty) return bestShops;
    final matched =
        _shops.where((s) => interests.contains(s.category)).toList();
    return matched.isEmpty ? bestShops : matched.take(10).toList();
  }

  // ✅ Phase 2 Fix #19: ترتيب صريح بـ createdAt تنازلي
  // reversed كان يعتمد على ترتيب جلب Firestore غير المضمون
  List<Product> get newProducts {
    final sorted = List<Product>.from(_products)
      ..sort((a, b) {
        final ca = a.createdAt;
        final cb = b.createdAt;
        if (ca == null && cb == null) return 0;
        if (ca == null) return 1;
        if (cb == null) return -1;
        return cb.compareTo(ca);
      });
    return sorted.take(10).toList();
  }

  ShopsProvider() {
    WidgetsBinding.instance.addObserver(this);
    _loadInitialData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // ✅ Fix #59: إلغاء الـ debounce timer لمنع memory leak
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ✅ 3-07 Fix: يُشغَّل عند رجوع التطبيق للـ foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      autoRefreshIfOnline();
    }
  }

  Future<void> _loadInitialData() async {
    await CacheService().init();
    await Future.wait([
      fetchShops(),
      fetchProducts(),
      fetchOffers(),
      fetchCategories(),
      fetchAds(),
    ]);
  }

  // ── Ads ──────────────────────────────────────────────────

  Future<void> fetchAds() async {
    try {
      _ads = await ApiService.getActiveAds();
      notifyListeners();
    } catch (e) {
      debugPrint('fetchAds error: $e');
    }
  }

  Future<AdModel?> getStartupAd() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('show_startup_ads') ?? true) || _ads.isEmpty) {
        return null;
      }

      List<String> seenAds = prefs.getStringList('seen_ads_cycle') ?? [];
      List<AdModel> availableAds =
          _ads.where((ad) => !seenAds.contains(ad.id)).toList();

      if (availableAds.isEmpty) {
        await prefs.setStringList('seen_ads_cycle', []);
        availableAds = _ads;
      }

      final selected = availableAds[Random().nextInt(availableAds.length)];
      seenAds.add(selected.id);
      await prefs.setStringList('seen_ads_cycle', seenAds);
      return selected;
    } catch (e) {
      debugPrint('getStartupAd error: $e');
      return null;
    }
  }

  // ── Shops ─────────────────────────────────────────────────

  // ✅ QA Fix #18: منع التكرار — لا تشغيل fetch جديد إذا كان هناك طلب جارٍ
  Future<void> fetchShops({String? category, bool refresh = false}) async {
    if (_isLoading) return;
    // ✅ Fix #76: تحديث _selectedCategory قبل أي return مبكر
    _selectedCategory = category;
    // ✅ Fix #75: تصفير _selectedRegion عند تغيير الفئة
    if (category != _selectedCategory) _selectedRegion = null;
    if (refresh) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      if (!refresh && category != null) {
        final cachedShops = await CacheService().getCachedShops(category);
        if (cachedShops != null) {
          _allShops = cachedShops
              .map((item) => Shop.fromMap(item, item['id']))
              .toList();
          _applyFilterAndSearch();
          _isLoading = false;
          notifyListeners(); // ← هنا: بعد التحديث النهائي
          // Silent refresh في الخلفية
          ApiService.getShops(category: category).then((freshShops) {
            _allShops = freshShops;
            _applyFilterAndSearch();
            CacheService().cacheShops(
                _allShops.map((s) => s.toMapWithId()).toList(), category);
            notifyListeners(); // ← هنا: بعد التحديث الصامت
          });
          return;
        }
      }
      _selectedCategory = category;
      _allShops = await ApiService.getShops(
          category: category, query: _searchQuery);
      _applyFilterAndSearch();
      if (category != null) {
        CacheService().cacheShops(
            _allShops.map((s) => s.toMapWithId()).toList(), category);
      }
    } catch (e) {
      _error = 'تعذّر تحميل المحلات. تحقق من اتصالك.';
    } finally {
      _isLoading = false;
      notifyListeners(); // ✅ Fix #20: الاستدعاء الوحيد في finally
    }
  }

  // ✅ Fix #18: تحميل الصفحة الأولى بـ ShopService.getShopsPage
  Future<void> fetchShopsPage({String? category, bool refresh = false}) async {
    if (_isLoading) return;
    _isLoading = true;
    if (refresh) {
      _lastShopDocument = null;
      _allShops = [];
      _shops = [];
    }
    notifyListeners();

    try {
      final page = await ShopService.getShopsPage(
          category: category, region: _selectedRegion);
      _allShops = page.shops;
      _lastShopDocument = page.lastDocument;
      _hasMoreShops = page.hasMore;
      _applyFilterAndSearch();
    } catch (e) {
      _error = 'تعذّر تحميل المحلات.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ Fix #18: تحميل الصفحة التالية
  Future<void> fetchMoreShops({String? category}) async {
    if (_isLoadingMore || !_hasMoreShops || _lastShopDocument == null) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await ShopService.getNextShopsPage(
          lastDoc: _lastShopDocument!,
          category: category,
          region: _selectedRegion);
      _allShops.addAll(page.shops);
      _lastShopDocument = page.lastDocument;
      _hasMoreShops = page.hasMore;
      _applyFilterAndSearch();
    } catch (e) {
      debugPrint('fetchMoreShops error: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // ── Products ──────────────────────────────────────────────

  Future<void> fetchProducts({String? shopId, bool refresh = false}) async {
    try {
      if (!refresh) {
        final cached = await CacheService().getCachedProducts(shopId: shopId);
        if (cached != null) {
          _products = cached
              .map((item) => Product.fromMap(item, item['id'] ?? ''))
              .toList();
          notifyListeners();
          return;
        }
      }
      _products = await ApiService.getProducts(shopId: shopId);
      CacheService().cacheProducts(
          _products.map((p) => p.toMapWithId()).toList(),
          shopId: shopId);
      notifyListeners();
    } catch (e) {
      debugPrint('fetchProducts error: $e');
    }
  }

  // ── Offers ────────────────────────────────────────────────

  Future<void> fetchOffers({String? shopId, bool refresh = false}) async {
    try {
      if (!refresh) {
        final cached =
            await CacheService().getCachedOffers(shopId: shopId);
        if (cached != null) {
          _allOffers = cached
              .map((item) => Offer.fromMap(item, item['id'] ?? ''))
              .toList();
          notifyListeners();
          return;
        }
      }
      _allOffers = await ApiService.getOffers(shopId: shopId);
      CacheService().cacheOffers(
          _allOffers.map((o) => o.toMapWithId()).toList(),
          shopId: shopId);
      notifyListeners();
    } catch (e) {
      debugPrint('fetchOffers error: $e');
    }
  }

  // ── Convenience aliases ──────────────────────────────────

  Future<void> loadShops({bool refresh = false}) =>
      fetchShops(refresh: refresh);
  Future<void> loadProducts({bool refresh = false}) =>
      fetchProducts(refresh: refresh);
  Future<void> loadOffers({bool refresh = false}) =>
      fetchOffers(refresh: refresh);

  // ── Categories ────────────────────────────────────────────

  Future<void> fetchCategories({bool refresh = false}) async {
    try {
      if (!refresh) {
        final cached = await CacheService().getCachedCategories();
        if (cached != null) {
          _categories = cached
              .map((item) => CategoryModel.fromMap(item, item['id'] ?? ''))
              .toList();
          notifyListeners();
          return;
        }
      }
      _categories = await ApiService.getCategories();
      await CacheService()
          .cacheCategories(_categories.map((c) => c.toMapWithId()).toList());
      notifyListeners();
    } catch (e) {
      debugPrint('fetchCategories error: $e');
    }
  }

  Future<void> addCategory(CategoryModel category) async {
    await ApiService.addCategory(category);
    await fetchCategories(refresh: true);
  }

  Future<void> updateCategory(CategoryModel category) async {
    await ApiService.updateCategory(category);
    await fetchCategories(refresh: true);
  }

  Future<void> deleteCategory(String id) async {
    await ApiService.deleteCategory(id);
    await fetchCategories(refresh: true);
  }

  // ── Search & Filter ───────────────────────────────────────

  // ✅ QA Fix #P1: debounce 300ms لتقليل عمليات الـ rebuild أثناء الكتابة
  Timer? _searchDebounce;

  void search(String? query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _searchQuery = query;
      _applyFilterAndSearch();
      notifyListeners();
    });
  }

  // ✅ Fix #20: حُذف notifyListeners() من هنا — تصبح pure internal helper
  void _applyFilterAndSearch() {
    List<Shop> filtered = _allShops;
    if (_searchQuery != null && _searchQuery!.isNotEmpty) {
      final lower = _searchQuery!.toLowerCase();
      filtered = filtered
          .where((shop) =>
              shop.name.toLowerCase().contains(lower) ||
              shop.description.toLowerCase().contains(lower))
          .toList();
    }
    if (_selectedCategory != null && _selectedCategory != 'الكل') {
      filtered =
          filtered.where((s) => s.category == _selectedCategory).toList();
    }
    if (_selectedRegion != null && _selectedRegion!.isNotEmpty) {
      filtered = filtered
          .where((s) => s.location.contains(_selectedRegion!))
          .toList();
    }
    _shops = filtered;
    // ✅ لا notifyListeners() هنا
  }

  // ── Favorites ─────────────────────────────────────────────

  Future<void> toggleFavorite(String shopId, bool newStatus) async {
    final index = _shops.indexWhere((s) => s.id == shopId);
    if (index != -1) {
      _shops[index] = _shops[index].copyWith(isFavorite: newStatus);
      notifyListeners();
      await ApiService.toggleFavorite('shop', shopId);
    }
  }

  Future<void> toggleProductFavorite(String productId) async {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      final newStatus = !_products[index].isFavorite;
      _products[index] = _products[index].copyWith(isFavorite: newStatus);
      notifyListeners();
      await ApiService.toggleProductFavorite(productId, newStatus);
    }
  }

  Future<void> toggleOfferFavorite(String offerId) async {
    final index = _allOffers.indexWhere((o) => o.id == offerId);
    if (index != -1) {
      final newStatus = !_allOffers[index].isFavorite;
      _allOffers[index] = _allOffers[index].copyWith(isFavorite: newStatus);
      notifyListeners();
      await ApiService.toggleOfferFavorite(offerId, newStatus);
    }
  }

  // ── ✅ Phase 2 Fix #21: Connectivity Auto-Refresh ─────────
  // يستخدم dart:io المدمج — لا حاجة لـ package إضافي.
  // تُستدعى من AppLifecycleObserver أو عند ظهور الشاشة مجدداً.

  bool _lastKnownOnline = true;

  // ✅ QA Fix #18: منع التشغيل المتعدد المتزامن
  Future<void> autoRefreshIfOnline() async {
    if (_isLoading) return;
    final online = await _checkConnectivity();
    if (online && !_lastKnownOnline) {
      _lastKnownOnline = true;
      await Future.wait([
        fetchShops(refresh: true),
        fetchProducts(refresh: true),
        fetchOffers(refresh: true),
      ]);
    } else {
      _lastKnownOnline = online;
    }
  }

  // ✅ Fix #108: استبدال _ping بـ settings/general الموجودة — تجنب permission-denied
  Future<bool> _checkConnectivity() async {
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('general')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 4));
      return true;
    } catch (_) {
      return false;
    }
  }
}
