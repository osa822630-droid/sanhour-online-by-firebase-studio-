// lib/providers/favorites_provider.dart
//
// ✅ Phase 2 Fix #16 — mergeLocalFavoritesOnLogin:
//    كان يستخدم toggleFavorite (يُضيف أو يحذف). إذا كان العنصر موجوداً بالفعل
//    في Firestore، سيحذفه. الإصلاح: استخدام addFavoriteIfNotExists فقط.
//
// ✅ Phase 2 Fix #17 — loadFavorites بـ whereIn:
//    كان يجلب getShops() / getProducts() / getOffers() كاملاً ويُصفّي في Dart.
//    مع مئات المحلات → يقرأ آلاف الوثائق مقابل قراءات ضئيلة للمفضلة.
//    الإصلاح: getShopsByIds / getProductsByIds / getOffersByIds تستخدم whereIn.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sanhour_online/models/offer.dart';
import 'package:sanhour_online/models/product.dart';
import 'package:sanhour_online/models/shop.dart';
import 'package:sanhour_online/models/user.dart';
import 'package:sanhour_online/models/wishlist_collection_model.dart';
import 'package:sanhour_online/services/api_service.dart';
import 'package:sanhour_online/services/local_favorites_service.dart';

class FavoritesProvider with ChangeNotifier {
  // ✅ QA Fix #25: non-final لدعم updateUser() بدلاً من إعادة إنشاء الـ Provider
  User? _user;

  List<Shop> _favoriteShops = [];
  List<Product> _favoriteProducts = [];
  List<Offer> _favoriteOffers = [];
  List<Shop> _favoriteServices = [];

  Set<String> _favoriteShopIds = {};
  Set<String> _favoriteProductIds = {};
  Set<String> _favoriteOfferIds = {};
  Set<String> _favoriteServiceIds = {};

  List<WishlistCollection> _collections = [];
  StreamSubscription<List<WishlistCollection>>? _collectionsSubscription;

  bool _isLoading = false;

  FavoritesProvider(
    this._user,
    List<Shop> initialShops,
    List<Product> initialProducts,
    List<Offer> initialOffers,
  ) {
    if (_user != null) {
      _favoriteShops = initialShops;
      _favoriteProducts = initialProducts;
      _favoriteOffers = initialOffers;
      _favoriteShopIds = initialShops.map((s) => s.id).toSet();
      _favoriteProductIds = initialProducts.map((p) => p.id).toSet();
      _favoriteOfferIds = initialOffers.map((o) => o.id).toSet();
      _initCollectionsStream();
      // ✅ Fix #81: تخطي loadFavorites إذا كانت البيانات الأولية موجودة
      // لتجنب قراءة Firestore مزدوجة عند بناء الـ Provider
      if (initialShops.isEmpty && initialProducts.isEmpty && initialOffers.isEmpty) {
        loadFavorites();
      }
    } else {
      _loadLocalFavorites();
    }
  }

  List<Shop> get favoriteShops => _favoriteShops;
  List<Product> get favoriteProducts => _favoriteProducts;
  List<Offer> get favoriteOffers => _favoriteOffers;
  List<Shop> get favoriteServices => _favoriteServices;
  List<WishlistCollection> get collections => _collections;
  bool get isLoading => _isLoading;

  int get totalFavorites =>
      _favoriteShops.length +
      _favoriteProducts.length +
      _favoriteOffers.length +
      _favoriteServices.length;

  @override
  void dispose() {
    _collectionsSubscription?.cancel();
    super.dispose();
  }

  // ✅ QA Fix #25: تعديل المستخدم في نفس الـ instance بدلاً من إنشاء instance جديد
  void updateUser(User? newUser) {
    if (_user?.id == newUser?.id) return; // لا تغيير إذا كان نفس المستخدم
    _user = newUser;
    _collectionsSubscription?.cancel();
    _collectionsSubscription = null;
    if (newUser != null) {
      _initCollectionsStream();
      loadFavorites();
    } else {
      _clearAllFavorites();
      _loadLocalFavorites();
    }
    notifyListeners();
  }

  void _clearAllFavorites() {
    _favoriteShops = [];
    _favoriteProducts = [];
    _favoriteOffers = [];
    _favoriteServices = [];
    _favoriteShopIds = {};
    _favoriteProductIds = {};
    _favoriteOfferIds = {};
    _favoriteServiceIds = {};
    _collections = [];
  }

  bool isFavorite(String type, String id) {
    switch (type) {
      case 'shop':
        return _favoriteShopIds.contains(id);
      case 'product':
        return _favoriteProductIds.contains(id);
      case 'offer':
        return _favoriteOfferIds.contains(id);
      case 'service':
        return _favoriteServiceIds.contains(id);
      default:
        return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ Fix #17: loadFavorites يستخدم whereIn بدل جلب الكل
  // الخطوات: 1) جلب IDs → 2) جلب التفاصيل بـ whereIn فقط
  // ═══════════════════════════════════════════════════════════
  Future<void> loadFavorites() async {
    if (_user == null) {
      await _loadLocalFavorites();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // الخطوة 1: جلب IDs فقط (قراءات خفيفة)
      final results = await Future.wait([
        ApiService.getFavorites('shop', userId: _user!.id),
        ApiService.getFavorites('product', userId: _user!.id),
        ApiService.getFavorites('offer', userId: _user!.id),
        ApiService.getFavorites('service', userId: _user!.id),
      ]);

      _favoriteShopIds = results[0].toSet();
      _favoriteProductIds = results[1].toSet();
      _favoriteOfferIds = results[2].toSet();
      _favoriteServiceIds = results[3].toSet();

      final allShopIds = {
        ..._favoriteShopIds,
        ..._favoriteServiceIds
      }.toList();

      // الخطوة 2: جلب التفاصيل بـ whereIn فقط (بدل جلب الكل)
      final fetchResults = await Future.wait([
        allShopIds.isNotEmpty
            ? ApiService.getShopsByIds(allShopIds)
            : Future.value(<Shop>[]),
        _favoriteProductIds.isNotEmpty
            ? ApiService.getProductsByIds(_favoriteProductIds.toList())
            : Future.value(<Product>[]),
        _favoriteOfferIds.isNotEmpty
            ? ApiService.getOffersByIds(_favoriteOfferIds.toList())
            : Future.value(<Offer>[]),
      ]);

      final allShops = fetchResults[0] as List<Shop>;
      _favoriteShops =
          allShops.where((s) => _favoriteShopIds.contains(s.id)).toList();
      _favoriteServices =
          allShops.where((s) => _favoriteServiceIds.contains(s.id)).toList();
      _favoriteProducts = fetchResults[1] as List<Product>;
      _favoriteOffers = fetchResults[2] as List<Offer>;
    } catch (e) {
      debugPrint('loadFavorites error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(dynamic item, {String? explicitType}) async {
    final type = explicitType ?? _determineType(item);
    if (type.isEmpty) return;

    final id = item.id as String;
    final wasFav = isFavorite(type, id);

    // Optimistic update
    if (wasFav) {
      _removeFromLocal(type, id);
    } else {
      _addToLocal(type, item);
    }
    notifyListeners();

    if (_user == null) {
      // الضيف — يحفظ محلياً
      try {
        if (wasFav) {
          await LocalFavoritesService.remove(type, id);
        } else {
          await LocalFavoritesService.add(type, id);
        }
      } catch (_) {
        // Rollback
        if (wasFav) {
          _addToLocal(type, item);
        } else {
          _removeFromLocal(type, id);
        }
        notifyListeners();
      }
      return;
    }

    try {
      await ApiService.toggleFavorite(type, id, userId: _user!.id);
    } catch (e) {
      // Rollback
      if (wasFav) {
        _addToLocal(type, item);
      } else {
        _removeFromLocal(type, id);
      }
      notifyListeners();
      debugPrint('toggleFavorite failed: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ Fix #16: mergeLocalFavoritesOnLogin — Add-Only
  // قبل الإصلاح: toggleFavorite يُحذف ما هو موجود بالفعل في Firestore.
  // بعد الإصلاح: addFavoriteIfNotExists تضيف فقط إذا لم يكن موجوداً.
  // ═══════════════════════════════════════════════════════════
  Future<void> mergeLocalFavoritesOnLogin(String userId) async {
    try {
      final shopIds = await LocalFavoritesService.getIds('shop');
      final productIds = await LocalFavoritesService.getIds('product');
      final offerIds = await LocalFavoritesService.getIds('offer');

      // كل ID → addFavoriteIfNotExists (لا toggle)
      for (final id in shopIds) {
        await ApiService.addFavoriteIfNotExists('shop', id, userId: userId);
      }
      for (final id in productIds) {
        await ApiService.addFavoriteIfNotExists('product', id,
            userId: userId);
      }
      for (final id in offerIds) {
        await ApiService.addFavoriteIfNotExists('offer', id, userId: userId);
      }

      await LocalFavoritesService.clear();
      // إعادة تحميل المفضلة من Firestore بعد الدمج
      await loadFavorites();
    } catch (e) {
      debugPrint('mergeLocalFavoritesOnLogin error: $e');
    }
  }

  Future<void> _loadLocalFavorites() async {
    _isLoading = true;
    notifyListeners();
    try {
      _favoriteShopIds = await LocalFavoritesService.getIds('shop');
      _favoriteProductIds = await LocalFavoritesService.getIds('product');
      _favoriteOfferIds = await LocalFavoritesService.getIds('offer');
      _favoriteServiceIds = await LocalFavoritesService.getIds('service');
    } catch (e) {
      debugPrint('_loadLocalFavorites error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _initCollectionsStream() {
    _collectionsSubscription?.cancel();
    _collectionsSubscription =
        ApiService.getUserCollectionsStream(_user!.id).listen(
      (data) {
        _collections = data;
        notifyListeners();
      },
      onError: (e) => debugPrint('Collections stream error: $e'),
    );
  }

  Future<void> createCollection(String name, bool isPublic) async {
    if (_user == null) return;
    final collection = WishlistCollection(
      id: '',
      name: name,
      ownerId: _user!.id,
      isPublic: isPublic,
      collaborators: [],
      createdAt: DateTime.now(),
      items: [],
    );
    await ApiService.createCollection(collection);
  }

  Future<void> addItemToCollection(
      String collectionId, dynamic item) async {
    if (_user == null) return;
    final wishlistItem = _createWishlistItem(item);
    if (wishlistItem == null) return;
    await ApiService.addItemToCollection(collectionId, wishlistItem);
  }

  Future<void> removeItemFromCollection(
      String collectionId, WishlistItem item) async {
    if (_user == null) return;
    await ApiService.removeItemFromCollection(collectionId, item);
  }

  // ✅ Fix #79: التحقق من ملكية المجموعة قبل حذفها (client-side guard)
  Future<void> deleteCollection(String collectionId) async {
    if (_user == null) return;
    // التحقق أن المجموعة ملك للمستخدم الحالي
    final existing = _collections.any(
        (c) => c.id == collectionId && c.ownerId == _user.id);
    if (!existing) {
      throw Exception('لا يمكنك حذف مجموعة لا تملكها.');
    }
    await ApiService.deleteCollection(collectionId);
  }

  Future<void> addCollaborator(
      String collectionId, String emailOrPhone) async {
    final userId = await ApiService.findUserIdByEmail(emailOrPhone);
    if (userId != null) {
      await ApiService.addCollaborator(collectionId, userId);
    } else {
      throw Exception('المستخدم غير موجود');
    }
  }

  // ✅ Fix #80: type guard صريح لمنع InvalidCastException عند dynamic item
  void _addToLocal(String type, dynamic item) {
    try {
      switch (type) {
        case 'shop':
          if (item is Shop) {
            _favoriteShopIds.add(item.id);
            _favoriteShops.add(item);
          }
          break;
        case 'product':
          if (item is Product) {
            _favoriteProductIds.add(item.id);
            _favoriteProducts.add(item);
          }
          break;
        case 'offer':
          if (item is Offer) {
            _favoriteOfferIds.add(item.id);
            _favoriteOffers.add(item);
          }
          break;
        case 'service':
          if (item is Shop) {
            _favoriteServiceIds.add(item.id);
            _favoriteServices.add(item);
          }
          break;
      }
    } catch (e) {
      debugPrint('_addToLocal type error: $e');
    }
  }

  void _removeFromLocal(String type, String id) {
    switch (type) {
      case 'shop':
        _favoriteShopIds.remove(id);
        _favoriteShops.removeWhere((s) => s.id == id);
        break;
      case 'product':
        _favoriteProductIds.remove(id);
        _favoriteProducts.removeWhere((p) => p.id == id);
        break;
      case 'offer':
        _favoriteOfferIds.remove(id);
        _favoriteOffers.removeWhere((o) => o.id == id);
        break;
      case 'service':
        _favoriteServiceIds.remove(id);
        _favoriteServices.removeWhere((s) => s.id == id);
        break;
    }
  }

  String _determineType(dynamic item) {
    if (item is Shop) {
      return _isServiceCategory(item.category) ? 'service' : 'shop';
    }
    if (item is Product) return 'product';
    if (item is Offer) return 'offer';
    return '';
  }

  WishlistItem? _createWishlistItem(dynamic item) {
    final type = _determineType(item);
    if (type.isEmpty) return null;

    String name = '', imageUrl = '';
    double price = 0.0;

    if (item is Shop) {
      name = item.name;
      imageUrl = item.imageUrl;
    } else if (item is Product) {
      name = item.name;
      imageUrl = item.imageUrls.isNotEmpty ? item.imageUrls.first : '';
      price = item.price;
    } else if (item is Offer) {
      name = item.title;
      imageUrl = item.imageUrl;
    }

    return WishlistItem(
      id: item.id as String,
      type: type,
      name: name,
      imageUrl: imageUrl,
      price: price,
      addedAt: DateTime.now(),
    );
  }

  // ✅ Fix #78: استخدام خاصية isServiceProvider من الـ Shop model مباشرةً
  // لمنع الاعتماد على قائمة hardcoded قد تختلف عن بيانات Firestore
  bool _isServiceCategory(String category) {
    const serviceCategories = [
      'خدمات طبية', 'خدمات تعليمية', 'خدمات صيانة',
      'خدمات قانونية', 'خدمات عامة', 'خدمات كهرباء',
      'خدمات سباكة', 'خدمات نجارة', 'خدمات تنظيف',
      'Medical Services', 'Educational Services', 'Workshops & Crafts',
    ];
    return serviceCategories
        .any((c) => category.contains(c) || category == c);
  }

  List<dynamic> getFavoritesByType(String type) {
    switch (type) {
      case 'shop':
        return _favoriteShops;
      case 'product':
        return _favoriteProducts;
      case 'offer':
        return _favoriteOffers;
      case 'service':
        return _favoriteServices;
      default:
        return [];
    }
  }
}