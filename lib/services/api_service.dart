
// lib/services/api_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sanhour_online/models/ad_model.dart';
import 'package:sanhour_online/models/category_model.dart';
import 'package:sanhour_online/models/offer.dart';
import 'package:sanhour_online/models/product.dart';
import 'package:sanhour_online/models/review_model.dart';
import 'package:sanhour_online/models/shop.dart';
import 'package:sanhour_online/models/wishlist_collection_model.dart';
import 'package:sanhour_online/services/ad_service.dart';
import 'package:sanhour_online/services/admin_service.dart';
import 'package:sanhour_online/services/auth_service.dart';
import 'package:sanhour_online/services/product_service.dart';
import 'package:sanhour_online/services/review_service.dart';
import 'package:sanhour_online/services/shop_service.dart';
import 'package:sanhour_online/services/stats_service.dart';
import 'package:sanhour_online/services/wishlist_service.dart';



class ApiService {
  
  // ==========================================================
  // 1. المصادقة والمستخدمين (Auth)
  // ==========================================================
  
  static Future<Map<String, dynamic>> login(String email, String password) => 
      AuthService.login(email, password);

  static Future<Map<String, dynamic>> registerUser(Map<String, dynamic> userData) => 
      AuthService.registerUser(userData);

  // ✅ Phase 2 Fix #15: يُمرر uid لـ AuthService.getUserStream بدل تجاهله
  static Stream<DocumentSnapshot> getUserStream(String uid) =>
      AuthService.getUserStream(userId: uid);

  static Future<void> signOut() => 
      AuthService.signOut();

  static Future<List<Map<String, dynamic>>> getAllUsers() => 
      AuthService.getAllUsers();

  static Future<void> toggleUserSuspension(String userId, bool currentStatus) => 
      AuthService.toggleUserSuspension(userId, currentStatus);

  static Future<void> toggleFavorite(String type, String itemId, {String? userId}) => 
      AuthService.toggleFavorite(type, itemId, userId: userId);

  static Future<List<String>> getFavorites(String type, {String? userId}) =>
      AuthService.getFavorites(type, userId: userId);

  // ✅ Phase 2 Fix #16: Add-only favorite — لا toggle (يُستخدم في mergeLocalFavoritesOnLogin)
  static Future<void> addFavoriteIfNotExists(String type, String itemId,
          {required String userId}) =>
      AuthService.addFavoriteIfNotExists(type, itemId, userId: userId);

  // ✅ Phase 2 Fix #17: جلب المحلات/المنتجات/العروض بـ whereIn (بدل جلب الكل وتصفية في Dart)
  static Future<List<Shop>> getShopsByIds(List<String> ids) =>
      ShopService.getShopsByIds(ids);

  static Future<List<Product>> getProductsByIds(List<String> ids) =>
      ProductService.getProductsByIds(ids);

  static Future<List<Offer>> getOffersByIds(List<String> ids) =>
      ProductService.getOffersByIds(ids);

  // static Future<bool> checkUsernameExists(String username) =>
  //     AuthService.checkUsernameExists(username);

  // ==========================================================
  // 2. المحلات والفئات (Shops)
  // ==========================================================
  
  static Future<List<Shop>> getShops({String? category, String? query}) => 
      ShopService.getShops(category: category, query: query);

  static Future<List<Shop>> getRankedShops({String? category}) => 
      ShopService.getRankedShops(category: category);

  static Future<List<Shop>> getMerchantShops(String ownerId) => 
      ShopService.getMerchantShops(ownerId);

  static Future<void> validateActivationCode(String code) => 
      ShopService.validateActivationCode(code);

  static Future<String> createShop(
    Map<String, dynamic> shopData,
    File? logo,
    File? cover, {
    void Function(double fraction)? onLogoProgress,
    void Function(double fraction)? onCoverProgress,
  }) =>
      ShopService.createShop(shopData, logo, cover,
          onLogoProgress: onLogoProgress, onCoverProgress: onCoverProgress);

  static Future<void> updateShop(
    String shopId,
    Map<String, dynamic> data,
    File? newLogo,
    File? newCover, {
    void Function(double fraction)? onLogoProgress,
    void Function(double fraction)? onCoverProgress,
  }) =>
      ShopService.updateShop(shopId, data, newLogo, newCover,
          onLogoProgress: onLogoProgress, onCoverProgress: onCoverProgress);

  static Future<List<CategoryModel>> getCategories() => 
      ShopService.getCategories();

  static Future<void> addCategory(CategoryModel category) => 
      ShopService.addCategory(category);

  static Future<void> updateCategory(CategoryModel category) => 
      ShopService.updateCategory(category);

  static Future<void> deleteCategory(String id) => 
      ShopService.deleteCategory(id);


  // ==========================================================
  // 3. المنتجات والعروض (Products)
  // ==========================================================
  
  static Future<List<Product>> getProducts({String? shopId}) => 
      ProductService.getProducts(shopId: shopId);

  static Future<List<Product>> getTopProducts({String? category}) => 
      ProductService.getTopProducts(category: category);

  static Future<List<Offer>> getTopOffers() => 
      ProductService.getTopOffers();

  static Future<void> addProduct(
    Map<String, dynamic> data,
    List<File> images, {
    void Function(int fileIndex, double fraction)? onImageProgress,
  }) =>
      ProductService.addProduct(data, images, onImageProgress: onImageProgress);

  static Future<void> updateProduct(
    String id,
    Map<String, dynamic> data,
    List<File>? newImages, {
    void Function(int fileIndex, double fraction)? onImageProgress,
  }) =>
      ProductService.updateProduct(id, data, newImages,
          onImageProgress: onImageProgress);

  static Future<void> deleteProduct(String id) => 
      ProductService.deleteProduct(id);

  static Future<List<Offer>> getOffers({String? shopId}) => 
      ProductService.getOffers(shopId: shopId);

  // ✅ Fix #43: إضافة visibleOnly لإتاحة رؤية الخدمات المخفية للتاجر في لوحته
  static Future<List<Map<String, dynamic>>> getServices({
    required String shopId,
    bool visibleOnly = true,
  }) async {
    try {
      Query q = FirebaseFirestore.instance
          .collection('services')
          .where('shopId', isEqualTo: shopId);
      if (visibleOnly) q = q.where('isVisible', isEqualTo: true);
      final snap = await q.get();
      return snap.docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList();
    } catch (_) {
      return [];
    }
  }

  // ✅ Fix #44: إضافة isShopHidden و ownerId لضمان عمل toggleShopSuspension على الخدمات
  static Future<void> addService(Map<String, dynamic> data) async {
    final ref = FirebaseFirestore.instance.collection('services').doc();
    await ref.set({
      'id': ref.id,
      ...data,
      'isVisible': true,
      'isShopHidden': false,
      'ownerId': data['ownerId'] ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateService(String id, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance.collection('services').doc(id).update(data);
  }

  static Future<void> deleteService(String id) async {
    await FirebaseFirestore.instance.collection('services').doc(id).delete();
  }

  // ✅ Fix #42: حُذفت addRating — الوظيفة مُضمَّنة في ReviewService.addReview


  // ✅ تحديث التوقيع لدعم صور متعددة + coverIndex + تتبع تقدم الرفع
  static Future<void> addOffer(
    Map<String, dynamic> data,
    List<File> images, {
    int coverIndex = 0,
    void Function(int fileIndex, double fraction)? onImageProgress,
  }) =>
      ProductService.addOffer(data, images,
          coverIndex: coverIndex, onImageProgress: onImageProgress);

  static Future<void> updateOffer(
    String id,
    Map<String, dynamic> data,
    List<File> newImages, {
    int? coverIndex,
    void Function(int fileIndex, double fraction)? onImageProgress,
  }) =>
      ProductService.updateOffer(id, data, newImages,
          coverIndex: coverIndex, onImageProgress: onImageProgress);

  static Future<void> deleteOffer(String id) => 
      ProductService.deleteOffer(id);

  static Future<String> uploadImage(
    File file,
    String folder, {
    void Function(double fraction)? onProgress,
  }) =>
      ProductService.uploadImage(file, folder, onProgress: onProgress);

  static Future<Map<String, dynamic>> importProductsExcel(String shopId, String filePath) => 
      ProductService.importProductsExcel(shopId, filePath);

  static Future<void> bulkDeleteProducts(List<String> ids) => 
      ProductService.bulkDeleteProducts(ids);

  static Future<void> bulkUpdateProductCategory(List<String> ids, String category) => 
      ProductService.bulkUpdateProductCategory(ids, category);


  // ==========================================================
  // 4. الإحصائيات (Stats)
  // ==========================================================
  
  static Future<void> logShopVisit(String shopId) => 
      StatsService.logShopVisit(shopId);

  static Future<void> logProductVisit(String id) => 
      StatsService.logProductVisit(id);

  static Future<void> logOfferVisit(String id) => 
      StatsService.logOfferVisit(id);

  static Future<Map<String, dynamic>> getMerchantAdvancedStats(String shopId, {DateTime? start, DateTime? end}) => 
      StatsService.getMerchantAdvancedStats(shopId, start: start, end: end);

  static Future<List<Map<String, dynamic>>> getTopItems({
    required String shopId,
    required String type,
    required String sortBy,
    int limit = 100,
  }) => StatsService.getTopItems(shopId: shopId, type: type, sortBy: sortBy, limit: limit);

  static Future<Map<String, int>> getItemRank({
    required String collection,
    required String id,
    required int currentViews,
    String? category,
  }) => StatsService.getItemRank(collection: collection, id: id, currentViews: currentViews, category: category);


  // ==========================================================
  // 5. الإعلانات (Ads)
  // ==========================================================
  
  static Future<List<AdModel>> getActiveAds() => 
      AdService.getActiveAds();

  static Future<void> incrementAdClickCount(String adId) => 
      AdService.incrementAdClickCount(adId);

  // ✅ تحديث التوقيع لدعم صور متعددة + coverIndex + تتبع تقدم الرفع
  static Future<void> createAd({
    required List<File> imageFiles,
    required String targetType,
    required String text,
    String? targetId,
    String? activationCode,
    int durationDays = 7,
    int coverIndex = 0,
    String? shopId,
    List<String> displayLocations = const ['home', 'splash', 'ads_screen'],
    void Function(int fileIndex, double fraction)? onImageProgress,
  }) =>
      AdService.createAd(
        imageFiles: imageFiles,
        targetType: targetType,
        text: text,
        targetId: targetId,
        activationCode: activationCode,
        durationDays: durationDays,
        coverIndex: coverIndex,
        shopId: shopId,
        displayLocations: displayLocations,
        onImageProgress: onImageProgress,
      );

  static Future<String> generateAdCode() => 
      AdService.generateAdCode();


  // ==========================================================
  // 6. الأدمن (Admin)
  // ==========================================================
  
  static Future<List<Map<String, dynamic>>> getAllCodes() => 
      AdminService.getAllCodes();

  static Future<void> generateActivationCode(String adminId) => 
      AdminService.generateActivationCode(adminId);

  static Future<void> submitComplaint(Map<String, dynamic> data) => 
      AdminService.submitComplaint(data);

  static Future<List<Map<String, dynamic>>> getComplaints() => 
      AdminService.getComplaints();

  static Future<void> updateComplaintStatus(String id, String status) => 
      AdminService.updateComplaintStatus(id, status);

  static Future<void> replyToComplaint({
    required String complaintId,
    required String reply,
    required String userId,
  }) => AdminService.replyToComplaint(
    complaintId: complaintId, 
    reply: reply, 
    userId: userId
  );

  static Future<void> deleteContent(String collection, String id) => 
      AdminService.deleteContent(collection, id);
      
  static Future<void> deleteUser(String userId) =>
      AdminService.deleteUser(userId);

  static Future<Map<String, int>> getAppStatistics() => 
      AdminService.getAppStatistics();
      
  static Future<Map<String, dynamic>> getAppSettings() =>
      AdminService.getAppSettings();
      
  static Future<void> updateAppSettings(Map<String, dynamic> data) =>
      AdminService.updateAppSettings(data);

  static Future<void> toggleShopSuspension(String shopId, bool currentStatus) => 
      AdminService.toggleShopSuspension(shopId, currentStatus);

  static Future<void> deleteShop(String shopId) => 
      AdminService.deleteShop(shopId);

  // ✅ QA Fix #08: توحيد التوقيع مع AdminService — docId بدلاً من itemId + معاملات اختيارية
  static Future<void> deleteItemWithNotification({
    required String collection,
    required String itemId,
    String? ownerId,
    String? itemName,
    required String reason,
  }) => AdminService.deleteItemWithNotification(
    collection: collection,
    docId: itemId,
    reason: reason,
    ownerId: ownerId,
    itemName: itemName,
  );

  // ==========================================================
  // 7. المراجعات والتقييمات (Reviews)
  // ==========================================================

  static Future<void> addReview(Review review) => 
      ReviewService.addReview(review);

  static Future<List<Review>> getReviews(String targetId) => 
      ReviewService.getReviews(targetId);

  static Future<void> replyToReview(String reviewId, String reply) => 
      ReviewService.replyToReview(reviewId, reply);

  static Future<void> toggleProductFavorite(String productId, bool isFavorite) async {
    await AuthService.toggleFavorite('product', productId);
  }

  static Future<void> toggleOfferFavorite(String offerId, bool isFavorite) async {
    await AuthService.toggleFavorite('offer', offerId);
  }

  // ==========================================================
  // 8. القوائم والمفضلة (Collections & Wishlist)
  // ==========================================================
  
  static Future<void> createCollection(WishlistCollection collection) =>
      WishlistService.createCollection(collection);

  static Stream<List<WishlistCollection>> getUserCollectionsStream(String userId) =>
      WishlistService.getUserCollectionsStream(userId);

  static Future<void> addItemToCollection(String collectionId, WishlistItem item) =>
      WishlistService.addItemToCollection(collectionId, item);

  static Future<void> removeItemFromCollection(String collectionId, WishlistItem item) =>
      WishlistService.removeItemFromCollection(collectionId, item);

  static Future<void> deleteCollection(String collectionId) =>
      WishlistService.deleteCollection(collectionId);

  static Future<String?> findUserIdByEmail(String email) =>
      WishlistService.findUserIdByEmail(email);

  static Future<void> addCollaborator(String collectionId, String userId) =>
      WishlistService.addCollaborator(collectionId, userId);
}
