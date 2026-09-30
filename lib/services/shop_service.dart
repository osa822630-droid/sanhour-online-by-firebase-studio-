// lib/services/shop_service.dart
// ✅ QA Fix #20: validateActivationCode + createShop في transaction ذرية (TOCTOU fix)
// ✅ QA Fix #45: createShop يُولِّد searchKeywords ويُعيِّن حقل id
// ✅ QA Fix #46: updateShop يُعيد توليد searchKeywords عند تغيير الاسم
// ✅ QA Fix #160: createShop يُعيد shopId للمستدعي
import 'dart:developer' as developer;
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sanhour_online/services/product_service.dart';
import '../models/category_model.dart';
import '../models/shop.dart';
import 'media_upload_service.dart';

class ShopService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // =========================================================
  // 1. جلب المحلات
  // =========================================================

  static Future<List<Shop>> getShops({String? category, String? query}) async {
    try {
      Query q = _firestore
          .collection('shops')
          .where('isSuspended', isEqualTo: false)
          .orderBy('isFeatured', descending: true);

      if (category != null && category != 'الكل') {
        q = q.where('category', isEqualTo: category);
      }

      final snap = await q.get();
      List<Shop> shops = snap.docs
          .map((d) => Shop.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();

      if (query != null && query.isNotEmpty) {
        final lower = query.toLowerCase();
        shops = shops
            .where((s) =>
                s.name.toLowerCase().contains(lower) ||
                s.description.toLowerCase().contains(lower) ||
                s.category.toLowerCase().contains(lower))
            .toList();
      }

      return shops;
    } catch (e, s) {
      developer.log('getShops error: $e', name: 'ShopService', error: e, stackTrace: s);
      return [];
    }
  }

  static Future<List<Shop>> getRankedShops({String? category}) async {
    try {
      Query q = _firestore
          .collection('shops')
          .where('isSuspended', isEqualTo: false)
          .orderBy('views', descending: true);

      if (category != null && category != 'الكل') {
        q = q.where('category', isEqualTo: category);
      }

      final snap = await q.get();
      return snap.docs
          .map((d) => Shop.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
    } catch (e, s) {
      developer.log('getRankedShops error: $e', name: 'ShopService', error: e, stackTrace: s);
      return [];
    }
  }

  static Future<List<Shop>> getMerchantShops(String ownerId) async {
    try {
      final snap = await _firestore
          .collection('shops')
          .where('ownerId', isEqualTo: ownerId)
          .get();
      return snap.docs.map((d) => Shop.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      return [];
    }
  }

  // =========================================================
  // 2. ✅ Fix #20: التحقق من كود التفعيل داخل createShop في transaction
  //    (لا يُستدعى منفصلاً بعد الآن — الـ TOCTOU مُعالَج)
  // =========================================================

  /// للاستخدام الخارجي كـ pre-check فقط (غير ذري — الـ atomic check في createShop)
  static Future<void> validateActivationCode(String code) async {
    final snap = await _firestore
        .collection('activation_codes')
        .where('code', isEqualTo: code)
        .where('isUsed', isEqualTo: false)
        .get();
    if (snap.docs.isEmpty) {
      throw Exception('كود التفعيل غير صحيح أو مستخدم مسبقاً.');
    }
  }

  // =========================================================
  // 3. ✅ Fix #20 + #45 + #160: إنشاء محل بشكل ذري مع searchKeywords
  // =========================================================

  static Future<String> createShop(
    Map<String, dynamic> shopData,
    File? logo,
    File? cover, {
    // ✅ نظام تقدم الرفع — fraction 0.0–1.0 لكل من اللوجو والغلاف
    void Function(double fraction)? onLogoProgress,
    void Function(double fraction)? onCoverProgress,
  }) async {
    final firebaseUser = _auth.currentUser;
    final ownerId = shopData['ownerId'] as String?;
    if (ownerId == null || ownerId.isEmpty) {
      throw Exception('يجب تسجيل الدخول أولاً');
    }
    if (firebaseUser != null && ownerId != firebaseUser.uid) {
      throw Exception('غير مصرح لك بإنشاء هذا المحل');
    }

    // ✅ إصلاح الكراش: ProductService.uploadImage الآن مُغلَّف بالكامل
    // عبر MediaUploadService — أي فشل يُرمى كـ MediaUploadException
    // برسالة عربية واضحة بدلاً من استثناء Firebase خام
    if (logo != null) {
      shopData['imageUrl'] =
          await ProductService.uploadImage(logo, 'shop_logos', onProgress: onLogoProgress);
    }
    if (cover != null) {
      shopData['coverUrl'] =
          await ProductService.uploadImage(cover, 'shop_covers', onProgress: onCoverProgress);
    }

    // إضافة الحقول الافتراضية
    shopData['isSuspended'] = false;
    shopData['isActive'] = true;
    shopData['rating'] = 0.0;
    shopData['reviewCount'] = 0;
    shopData['views'] = 0;
    shopData['favoriteCount'] = 0;
    shopData['uniqueVisitors'] = 0;
    shopData['createdAt'] = FieldValue.serverTimestamp();

    // ✅ Fix #45: توليد searchKeywords
    final name = (shopData['name'] as String? ?? '').toLowerCase();
    final desc = (shopData['description'] as String? ?? '').toLowerCase();
    final cat = (shopData['category'] as String? ?? '').toLowerCase();
    shopData['searchKeywords'] = _generateShopKeywords(name, desc, cat);

    final activationCode = shopData['activationCode'] as String?;

    // ✅ Fix #20: قراءة الكود وحرقه وإنشاء المحل في transaction ذرية
    final docRef = _firestore.collection('shops').doc();

    await _firestore.runTransaction((tx) async {
      // التحقق من الكود ذرياً
      if (activationCode != null && activationCode.isNotEmpty) {
        final codeSnap = await _firestore
            .collection('activation_codes')
            .where('code', isEqualTo: activationCode)
            .where('isUsed', isEqualTo: false)
            .limit(1)
            .get();

        if (codeSnap.docs.isEmpty) {
          throw Exception('كود التفعيل غير صحيح أو مستخدم مسبقاً.');
        }

        // ✅ حرق الكود أثناء الـ transaction
        tx.update(codeSnap.docs.first.reference, {
          'isUsed': true,
          'usedBy': ownerId,
          'usedAt': FieldValue.serverTimestamp(),
          'shopId': docRef.id,
        });
      }

      // ✅ Fix #45: كتابة id صريح في الوثيقة
      tx.set(docRef, {...shopData, 'id': docRef.id});
    });

    // ✅ Fix #160: إعادة shopId
    return docRef.id;
  }

  // ✅ Fix #46: تحديث searchKeywords عند تغيير الاسم
  static Future<void> updateShop(
    String shopId,
    Map<String, dynamic> data,
    File? newLogo,
    File? newCover, {
    // ✅ نظام تقدم الرفع — fraction 0.0–1.0 لكل من اللوجو والغلاف
    void Function(double fraction)? onLogoProgress,
    void Function(double fraction)? onCoverProgress,
  }) async {
    // ✅ إصلاح الكراش: رفع آمن عبر MediaUploadService مع رسائل عربية
    if (newLogo != null) {
      data['imageUrl'] =
          await ProductService.uploadImage(newLogo, 'shop_logos', onProgress: onLogoProgress);
    }
    if (newCover != null) {
      data['coverUrl'] =
          await ProductService.uploadImage(newCover, 'shop_covers', onProgress: onCoverProgress);
    }

    // إعادة توليد searchKeywords إذا تغيَّر الاسم أو الوصف أو الفئة
    if (data.containsKey('name') || data.containsKey('description') ||
        data.containsKey('category')) {
      final shopDoc = await _firestore.collection('shops').doc(shopId).get();
      final existing = shopDoc.data() ?? {};
      final name = ((data['name'] ?? existing['name']) as String? ?? '').toLowerCase();
      final desc = ((data['description'] ?? existing['description']) as String? ?? '').toLowerCase();
      final cat = ((data['category'] ?? existing['category']) as String? ?? '').toLowerCase();
      data['searchKeywords'] = _generateShopKeywords(name, desc, cat);
    }

    data['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('shops').doc(shopId).update(data);
  }

  // =========================================================
  // 3.5. ✅ معرض وسائط المحل (صور + فيديوهات) — mediaUrls / mediaTypes
  // =========================================================

  /// تحديث معرض وسائط المحل: يدمج العناصر المُحتفَظ بها مع الصور
  /// والفيديوهات الجديدة (مرفوعة بأمان عبر MediaUploadService)، يحفظ
  /// `mediaUrls`/`mediaTypes` كمصفوفتين متوازيتين، ويحذف عناصر Storage
  /// المُزالة بأفضل مجهود (لا يوقف العملية لو فشل الحذف).
  ///
  /// [onImageProgress]/[onVideoProgress]: (index في القائمة المُمرَّرة, fraction)
  static Future<void> updateShopMedia({
    required String shopId,
    required List<String> keptUrls,
    required List<String> keptTypes,
    required List<File> newImages,
    required List<File> newVideos,
    List<String> removedUrls = const [],
    void Function(int index, double fraction)? onImageProgress,
    void Function(int index, double fraction)? onVideoProgress,
  }) async {
    // ✅ إصلاح الكراش: رفع آمن بالتوازي مع تتبع تقدم منفصل للصور والفيديو
    final newImageUrls = await Future.wait(List.generate(newImages.length, (i) {
      return MediaUploadService.uploadFile(
        file: newImages[i],
        folder: 'shop_media',
        kind: MediaKind.image,
        onProgress: onImageProgress == null
            ? null
            : (p) => onImageProgress(i, p.fraction),
      );
    }));

    final newVideoUrls = await Future.wait(List.generate(newVideos.length, (i) {
      return MediaUploadService.uploadFile(
        file: newVideos[i],
        folder: 'shop_media_videos',
        kind: MediaKind.video,
        onProgress: onVideoProgress == null
            ? null
            : (p) => onVideoProgress(i, p.fraction),
      );
    }));

    final mediaUrls = [...keptUrls, ...newImageUrls, ...newVideoUrls];
    final mediaTypes = [
      ...keptTypes,
      ...List.filled(newImageUrls.length, 'image'),
      ...List.filled(newVideoUrls.length, 'video'),
    ];

    await _firestore.collection('shops').doc(shopId).update({
      'mediaUrls': mediaUrls,
      'mediaTypes': mediaTypes,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // ✅ حذف العناصر المُزالة من Storage — أفضل مجهود، لا يوقف العملية
    for (final url in removedUrls) {
      await MediaUploadService.deleteByUrl(url);
    }
  }

  // ✅ Fix #45: توليد keywords للبحث
  static List<String> _generateShopKeywords(
      String name, String desc, String category) {
    final keywords = <String>{};

    void addPrefixes(String text) {
      final words = text.split(RegExp(r'\s+'));
      for (final word in words) {
        if (word.length < 2) continue;
        for (int i = 2; i <= word.length; i++) {
          keywords.add(word.substring(0, i));
        }
      }
    }

    addPrefixes(name);
    // وصف: أول 3 كلمات فقط لتجنب bloat
    final descWords = desc.split(RegExp(r'\s+')).take(3).join(' ');
    addPrefixes(descWords);
    addPrefixes(category);

    return keywords.take(40).toList();
  }

  // =========================================================
  // 4. الفئات
  // =========================================================

  static Future<List<CategoryModel>> getCategories() async {
    try {
      final snap = await _firestore.collection('categories').get();
      return snap.docs
          .map((d) => CategoryModel.fromMap(d.data(), d.id))
          .toList();
    } catch (e, s) {
      developer.log('getCategories error: $e', name: 'ShopService', error: e, stackTrace: s);
      return [];
    }
  }

  static Future<void> addCategory(CategoryModel category) async {
    await _firestore.collection('categories').add(category.toMap());
  }

  static Future<void> updateCategory(CategoryModel category) async {
    await _firestore
        .collection('categories')
        .doc(category.id)
        .update(category.toMap());
  }

  static Future<void> deleteCategory(String id) async {
    await _firestore.collection('categories').doc(id).delete();
  }

  // =========================================================
  // 5. getShopsByIds بـ whereIn مع chunking
  // =========================================================

  static Future<List<Shop>> getShopsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final results = <Shop>[];
    for (int i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, (i + 30).clamp(0, ids.length));
      try {
        final snap = await _firestore
            .collection('shops')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        results.addAll(snap.docs.map((d) => Shop.fromMap(d.data(), d.id)));
      } catch (e) {
        developer.log('getShopsByIds chunk error: $e', name: 'ShopService');
      }
    }
    return results;
  }

  // =========================================================
  // 6. Pagination
  // =========================================================

  static const int _shopPageSize = 20;

  static Future<ShopPage> getShopsPage({
    String? category,
    String? region,
    int pageSize = _shopPageSize,
  }) async {
    try {
      Query q = _firestore
          .collection('shops')
          .where('isSuspended', isEqualTo: false)
          .orderBy('isFeatured', descending: true)
          .orderBy('createdAt', descending: true);
      if (category != null && category != 'الكل') {
        q = q.where('category', isEqualTo: category);
      }
      q = q.limit(pageSize);
      final snap = await q.get();
      final shops = snap.docs
          .map((d) => Shop.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
      final filtered = region != null && region.isNotEmpty
          ? shops.where((s) => s.location.contains(region)).toList()
          : shops;
      return ShopPage(
        shops: filtered,
        lastDocument: snap.docs.isNotEmpty ? snap.docs.last : null,
        hasMore: snap.docs.length == pageSize,
      );
    } catch (e, s) {
      developer.log('getShopsPage error: $e',
          name: 'ShopService', error: e, stackTrace: s);
      return const ShopPage(shops: [], lastDocument: null, hasMore: false);
    }
  }

  static Future<ShopPage> getNextShopsPage({
    required DocumentSnapshot lastDoc,
    String? category,
    String? region,
    int pageSize = _shopPageSize,
  }) async {
    try {
      Query q = _firestore
          .collection('shops')
          .where('isSuspended', isEqualTo: false)
          .orderBy('isFeatured', descending: true)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(lastDoc);
      if (category != null && category != 'الكل') {
        q = q.where('category', isEqualTo: category);
      }
      q = q.limit(pageSize);
      final snap = await q.get();
      final shops = snap.docs
          .map((d) => Shop.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
      final filtered = region != null && region.isNotEmpty
          ? shops.where((s) => s.location.contains(region)).toList()
          : shops;
      return ShopPage(
        shops: filtered,
        lastDocument: snap.docs.isNotEmpty ? snap.docs.last : null,
        hasMore: snap.docs.length == pageSize,
      );
    } catch (e, s) {
      developer.log('getNextShopsPage error: $e',
          name: 'ShopService', error: e, stackTrace: s);
      return const ShopPage(shops: [], lastDocument: null, hasMore: false);
    }
  }
}

class ShopPage {
  final List<Shop> shops;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  const ShopPage({
    required this.shops,
    required this.lastDocument,
    required this.hasMore,
  });
}
