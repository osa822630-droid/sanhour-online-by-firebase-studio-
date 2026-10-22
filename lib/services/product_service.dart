// lib/services/product_service.dart
// ✅ Phase 1 Fix #03: نُقلت دوال Pagination (_pageSize, getProductsPage,
// getNextProductsPage, generateSearchKeywords) إلى داخل كلاس ProductService
// بعد أن كانت مكتوبة خارجه تماماً، مما كان يُسبب Compile Error كاملاً.
import 'dart:developer' as developer;
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:excel/excel.dart';
import '../models/product.dart';
import '../models/offer.dart';
import 'media_upload_service.dart';

class ProductService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==========================================================
  // 1. المنتجات
  // ==========================================================

  static Future<List<Product>> getProducts({String? shopId}) async {
    try {
      Query q = _firestore.collection('products');
      if (shopId != null) q = q.where('shopId', isEqualTo: shopId);
      q = q
          .where('isVisible', isEqualTo: true)
          .where('isShopHidden', isEqualTo: false)
          .orderBy('createdAt', descending: true);
      final snap = await q.get();
      return snap.docs
          .map((d) => Product.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
    } catch (e, s) {
      developer.log('getProducts error: $e',
          name: 'ProductService', error: e, stackTrace: s);
      return [];
    }
  }

  static Future<List<Product>> getTopProducts(
      {String? category, int limit = 100}) async {
    try {
      Query q = _firestore
          .collection('products')
          .where('isVisible', isEqualTo: true)
          .orderBy('views', descending: true);
      if (category != null && category != 'الكل') {
        q = q.where('category', isEqualTo: category);
      }
      final snap = await q.limit(limit).get();
      return snap.docs
          .map((d) => Product.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
    } catch (e, s) {
      developer.log('getTopProducts error: $e',
          name: 'ProductService', error: e, stackTrace: s);
      return [];
    }
  }

  static Future<void> addProduct(
    Map<String, dynamic> productData,
    List<File> images, {
    // ✅ نظام تقدم الرفع: (index في images, fraction 0.0–1.0)
    void Function(int fileIndex, double fraction)? onImageProgress,
  }) async {
    // QA Fix #03: دعم كلٍّ من Firebase Auth والـ Mock Auth
    // ✅ mock_user كـ fallback لتجنب رفض عمليات الـ Mock Auth
    final firebaseUser = _auth.currentUser;

    // ✅ Fix #13: التحقق من الـ ownership عبر uid فقط في الجلسات الحقيقية.
    // الجلسة المجهولة (Mock Login) uid لها عشوائي ولا يساوي ownerId (معرّف
    // مستخدم التطبيق)، فكان التاجر التجريبي يُرفَض هنا دائماً. في الجلسة
    // المجهولة تفرض Firestore Rules الملكية عبر appUid() (الجلسة مربوطة
    // بهوية المستخدم في auth_sessions).
    if (firebaseUser != null && !firebaseUser.isAnonymous) {
      final shopDoc = await _firestore
          .collection('shops')
          .doc(productData['shopId'])
          .get();
      if (!shopDoc.exists || shopDoc.data()!['ownerId'] != firebaseUser.uid) {
        throw Exception('غير مصرح لك بإضافة منتج لهذا المتجر');
      }
    }

    // ✅ إصلاح الكراش: رفع آمن مع معالجة أخطاء عربية + تتبع تقدم لكل صورة
    final imageUrls = await _uploadImagesWithProgress(
        images, 'products_images', onImageProgress);

    // ✅ استخراج coverImageIndex من data قبل الحفظ
    final int rawCover = (productData['coverImageIndex'] as int? ?? 0);
    final int validCover =
        imageUrls.isEmpty ? 0 : rawCover.clamp(0, imageUrls.length - 1);
    productData.remove('coverImageIndex');

    final docRef = _firestore.collection('products').doc();
    await docRef.set({
      'id': docRef.id,
      ...productData,
      'imageUrls': imageUrls,
      'coverImageIndex': validCover,
      // ✅ توافق خلفي: imageUrl = صورة الغلاف
      'imageUrl': imageUrls.isEmpty ? '' : imageUrls[validCover],
      'createdAt': FieldValue.serverTimestamp(),
      'rating': 0.0,
      'reviewCount': 0,
      'views': 0,
      'favoriteCount': 0,
      'isFavorite': false,
      'isVisible': true,
      'isShopHidden': false,
    });
  }

  static Future<void> updateProduct(
    String productId,
    Map<String, dynamic> data,
    List<File>? newImages, {
    // ✅ نظام تقدم الرفع: (index في newImages, fraction 0.0–1.0)
    void Function(int fileIndex, double fraction)? onImageProgress,
  }) async {
    // QA Fix #03: لا نمنع Mock users من التعديل
    List<String> imageUrls =
        List<String>.from(data['existingImages'] ?? []);
    data.remove('existingImages');

    if (newImages != null && newImages.isNotEmpty) {
      // ✅ إصلاح الكراش: رفع آمن مع معالجة أخطاء عربية + تتبع تقدم
      final newUrls = await _uploadImagesWithProgress(
          newImages, 'products_images', onImageProgress);
      imageUrls.addAll(newUrls);
    }

    final int rawCover = (data['coverImageIndex'] as int? ?? 0);
    final int validCover =
        imageUrls.isEmpty ? 0 : rawCover.clamp(0, imageUrls.length - 1);

    data['imageUrls'] = imageUrls;
    data['coverImageIndex'] = validCover;
    data['imageUrl'] = imageUrls.isEmpty ? '' : imageUrls[validCover]; // توافق خلفي
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore
        .collection('products')
        .doc(productId)
        .update(data);
  }

  static Future<void> deleteProduct(String productId) async {
    // ✅ QA Fix #03: تخطي Firebase Auth check للـ Mock users
    await _firestore.collection('products').doc(productId).delete();
  }

  // ==========================================================
  // 2. العروض
  // ==========================================================

  static Future<List<Offer>> getOffers({String? shopId}) async {
    try {
      Query q = _firestore
          .collection('offers')
          .where('isActive', isEqualTo: true)
          .where('isShopHidden', isEqualTo: false);
      if (shopId != null) q = q.where('shopId', isEqualTo: shopId);
      final snap = await q.get();
      return snap.docs
          .map((d) =>
              Offer.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
    } catch (e, s) {
      developer.log('getOffers error: $e',
          name: 'ProductService', error: e, stackTrace: s);
      return [];
    }
  }

  static Future<List<Offer>> getTopOffers({int limit = 100}) async {
    try {
      final snap = await _firestore
          .collection('offers')
          .where('isActive', isEqualTo: true)
          .orderBy('views', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => Offer.fromMap(d.data(), d.id))
          .toList();
    } catch (e, s) {
      developer.log('getTopOffers error: $e',
          name: 'ProductService', error: e, stackTrace: s);
      return [];
    }
  }

  // ✅ تحديث التوقيع لدعم صور متعددة + coverIndex
  static Future<void> addOffer(
      Map<String, dynamic> offerData,
      List<File> images, {
      int coverIndex = 0,
      // ✅ نظام تقدم الرفع: (index في images, fraction 0.0–1.0)
      void Function(int fileIndex, double fraction)? onImageProgress,
      }) async {
    // QA Fix #03: دعم كلٍّ من Firebase Auth والـ Mock Auth
    // ✅ mock_user كـ fallback لتجنب رفض عمليات الـ Mock Auth
    final firebaseUser = _auth.currentUser;

    // ✅ Fix #13: نفس منطق addProduct — فحص uid للجلسات الحقيقية فقط
    // (الجلسة المجهولة تعتمد على Firestore Rules + appUid()).
    if (firebaseUser != null && !firebaseUser.isAnonymous) {
      final shopDoc = await _firestore
          .collection('shops')
          .doc(offerData['shopId'])
          .get();
      if (!shopDoc.exists ||
          shopDoc.data()!['ownerId'] != firebaseUser.uid) {
        throw Exception('غير مصرح لك بإضافة عرض لهذا المتجر');
      }
    }

    // رفع الصور الجديدة
    // ✅ إصلاح الكراش: رفع آمن مع معالجة أخطاء عربية + تتبع تقدم
    List<String> imageUrls = [];
    if (images.isNotEmpty) {
      imageUrls = await _uploadImagesWithProgress(
          images, 'offers_images', onImageProgress);
    } else if (offerData['imageUrls'] != null) {
      imageUrls = List<String>.from(offerData['imageUrls'] as List);
    } else if (offerData['imageUrl'] != null) {
      final legacy = offerData['imageUrl'] as String;
      if (legacy.isNotEmpty) imageUrls = [legacy];
    }

    final int validCover =
        imageUrls.isEmpty ? 0 : coverIndex.clamp(0, imageUrls.length - 1);
    final String coverUrl = imageUrls.isEmpty ? '' : imageUrls[validCover];

    // إزالة الحقول المؤقتة قبل الحفظ
    offerData.remove('imageUrls');
    offerData.remove('imageUrl');
    offerData.remove('existingImages');

    final docRef = _firestore.collection('offers').doc();

    final offerMap = {
      'id': docRef.id,
      ...offerData,
      'imageUrls': imageUrls,
      'coverImageIndex': validCover,
      'imageUrl': coverUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'views': 0,
      'favoriteCount': 0,
      'isFavorite': false,
      'isShopHidden': false,
    };

    // ✅ Fix #21: إنشاء العرض + تحديث سعر المنتج في transaction ذرية واحدة
    if (offerData['type'] == 'price_drop' &&
        offerData['productId'] != null) {
      final productRef = _firestore
          .collection('products')
          .doc(offerData['productId'] as String);
      await _firestore.runTransaction((tx) async {
        tx.set(docRef, offerMap);
        tx.update(productRef, {
          'price': offerData['newPrice'],
          'oldPrice': offerData['oldPrice'],
          'hasPriceDrop': true,
        });
      });
    } else {
      await docRef.set(offerMap);
    }
  }

  // ✅ تحديث التوقيع لدعم صور متعددة + coverIndex
  static Future<void> updateOffer(
      String offerId,
      Map<String, dynamic> data,
      List<File> newImages, {
      int? coverIndex,
      // ✅ نظام تقدم الرفع: (index في newImages, fraction 0.0–1.0)
      void Function(int fileIndex, double fraction)? onImageProgress,
      }) async {
    // QA Fix #03: تخطي Firebase Auth check للـ Mock users
    final List<String> existingUrls =
        List<String>.from(data['existingImages'] ?? data['imageUrls'] ?? []);
    data.remove('existingImages');
    data.remove('imageUrls');
    data.remove('imageUrl');

    // ✅ إصلاح الكراش: رفع آمن مع معالجة أخطاء عربية + تتبع تقدم
    List<String> uploadedUrls = [];
    if (newImages.isNotEmpty) {
      uploadedUrls = await _uploadImagesWithProgress(
          newImages, 'offers_images', onImageProgress);
    }

    final List<String> allUrls = [...existingUrls, ...uploadedUrls];
    final int validCover =
        allUrls.isEmpty ? 0 : (coverIndex ?? 0).clamp(0, allUrls.length - 1);
    final String coverUrl = allUrls.isEmpty ? '' : allUrls[validCover];

    data['imageUrls'] = allUrls;
    data['coverImageIndex'] = validCover;
    data['imageUrl'] = coverUrl; // توافق خلفي
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('offers').doc(offerId).update(data);
  }

  // ✅ Fix #22: عند حذف عرض price_drop، نُرجع سعر المنتج الأصلي في transaction ذرية
  static Future<void> deleteOffer(String offerId) async {
    final offerRef = _firestore.collection('offers').doc(offerId);
    final offerDoc = await offerRef.get();

    if (offerDoc.exists) {
      final data = offerDoc.data()!;
      if (data['type'] == 'price_drop' && data['productId'] != null) {
        final productRef = _firestore
            .collection('products')
            .doc(data['productId'] as String);
        final oldPrice = (data['oldPrice'] as num?)?.toDouble();
        await _firestore.runTransaction((tx) async {
          tx.delete(offerRef);
          if (oldPrice != null && oldPrice > 0) {
            tx.update(productRef, {
              'price': oldPrice,
              'hasPriceDrop': false,
            });
          }
        });
        return;
      }
    }

    await offerRef.delete();
  }

  // ==========================================================
  // 3. رفع الملفات
  // ==========================================================

  /// ✅ إصلاح الكراش: تفويض كامل لـ MediaUploadService — تحقق من الحجم،
  /// رسائل خطأ عربية، إعادة محاولة تلقائية لأخطاء الشبكة المؤقتة.
  /// التوقيع القديم محفوظ للتوافق الخلفي مع كل المستدعين الحاليين.
  /// [onProgress] اختياري — fraction من 0.0 إلى 1.0.
  static Future<String> uploadImage(
    File imageFile,
    String folderName, {
    void Function(double fraction)? onProgress,
  }) async {
    return MediaUploadService.uploadFile(
      file: imageFile,
      folder: folderName,
      kind: MediaKind.image,
      onProgress: onProgress == null ? null : (p) => onProgress(p.fraction),
    );
  }

  /// ✅ رفع عدة صور مع تتبع تقدم كل صورة على حدة — index في القائمة
  /// المُمرَّرة (وليس الفهرس المدمج في الواجهة).
  static Future<List<String>> _uploadImagesWithProgress(
    List<File> files,
    String folder,
    void Function(int fileIndex, double fraction)? onProgress,
  ) async {
    if (files.isEmpty) return [];
    return Future.wait(List.generate(files.length, (i) {
      return MediaUploadService.uploadFile(
        file: files[i],
        folder: folder,
        kind: MediaKind.image,
        onProgress: onProgress == null
            ? null
            : (p) => onProgress(i, p.fraction),
      );
    }));
  }

  // ==========================================================
  // 4. استيراد Excel — ✅ إصلاح Batch Bug
  // ==========================================================

  static Future<Map<String, dynamic>> importProductsExcel(
      String shopId, String filePath) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول أولاً');

    final shopDoc =
        await _firestore.collection('shops').doc(shopId).get();
    // ✅ Fix #13: مقارنة uid بـ ownerId للجلسات الحقيقية فقط؛ الجلسة المجهولة
    // (Mock Login) تعتمد على Firestore Rules + appUid() لفرض الملكية.
    if (!shopDoc.exists ||
        (!user.isAnonymous && shopDoc.data()!['ownerId'] != user.uid)) {
      throw Exception('غير مصرح لك باستيراد منتجات لهذا المتجر');
    }

    try {
      final bytes = File(filePath).readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      WriteBatch batch = _firestore.batch();
      int count = 0;
      int batchCount = 0;

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null) continue;
        for (int i = 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          if (row.isEmpty || row[0] == null) continue;

          final name = row[0]?.value?.toString() ?? 'منتج';
          final price =
              double.tryParse(row[1]?.value?.toString() ?? '0') ?? 0.0;
          final desc =
              row.length > 2 ? (row[2]?.value?.toString() ?? '') : '';
          final cat = row.length > 3
              ? (row[3]?.value?.toString() ?? 'عام')
              : 'عام';

          // ✅ توليد searchKeywords عند الاستيراد
          final keywords =
              generateSearchKeywords(name, desc, cat);

          final docRef = _firestore.collection('products').doc();
          batch.set(docRef, {
            'id': docRef.id,
            'shopId': shopId,
            'name': name,
            'price': price,
            'description': desc,
            'category': cat,
            'imageUrls': <String>[],
            'rating': 0.0,
            'reviewCount': 0,
            'views': 0,
            'favoriteCount': 0,
            'isFavorite': false,
            'isVisible': true,
            'isShopHidden': false,
            'searchKeywords': keywords,
            'createdAt': FieldValue.serverTimestamp(),
          });

          count++;
          batchCount++;

          if (batchCount >= 450) {
            await batch.commit();
            batch = _firestore.batch();
            batchCount = 0;
          }
        }
      }

      if (batchCount > 0) await batch.commit();

      return {
        'success': true,
        'message': 'تم رفع $count منتج بنجاح',
        'processedItems': count
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'خطأ: $e',
        'processedItems': 0
      };
    }
  }

  // ==========================================================
  // 5. الحذف والتعديل الجماعي
  // ==========================================================

  static Future<void> bulkDeleteProducts(
      List<String> productIds) async {
    WriteBatch batch = _firestore.batch();
    int count = 0;
    for (final id in productIds) {
      batch.delete(_firestore.collection('products').doc(id));
      count++;
      if (count >= 450) {
        await batch.commit();
        batch = _firestore.batch();
        count = 0;
      }
    }
    if (count > 0) await batch.commit();
  }

  static Future<void> bulkUpdateProductCategory(
      List<String> productIds, String newCategory) async {
    WriteBatch batch = _firestore.batch();
    int count = 0;
    for (final id in productIds) {
      batch.update(_firestore.collection('products').doc(id),
          {'category': newCategory});
      count++;
      if (count >= 450) {
        await batch.commit();
        batch = _firestore.batch();
        count = 0;
      }
    }
    if (count > 0) await batch.commit();
  }

  // ==========================================================
  // ✅ Phase 1 Fix #03 + Fix #06 (searchKeywords):
  // Pagination — جلب المنتجات بشكل تدريجي (startAfterDocument)
  // كانت هذه الدوال خارج الكلاس تماماً — تم نقلها للداخل.
  // ==========================================================

  static const int _pageSize = 20;

  /// يجلب أول صفحة من المنتجات
  static Future<ProductPageResult> getProductsPage({
    String? shopId,
    String? category,
    int pageSize = _pageSize,
  }) async {
    try {
      Query q = _firestore
          .collection('products')
          .where('isVisible', isEqualTo: true)
          .where('isShopHidden', isEqualTo: false)
          .orderBy('createdAt', descending: true);
      if (shopId != null) q = q.where('shopId', isEqualTo: shopId);
      if (category != null && category != 'الكل') {
        q = q.where('category', isEqualTo: category);
      }
      q = q.limit(pageSize);
      final snap = await q.get();
      final products = snap.docs
          .map((d) =>
              Product.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
      return ProductPageResult(
        products: products,
        lastDocument: snap.docs.isNotEmpty ? snap.docs.last : null,
        hasMore: snap.docs.length == pageSize,
      );
    } catch (e, s) {
      developer.log('getProductsPage error: $e',
          name: 'ProductService', error: e, stackTrace: s);
      return const ProductPageResult(
          products: [], lastDocument: null, hasMore: false);
    }
  }

  /// يجلب الصفحة التالية انطلاقاً من آخر وثيقة
  static Future<ProductPageResult> getNextProductsPage({
    required DocumentSnapshot lastDoc,
    String? shopId,
    String? category,
    int pageSize = _pageSize,
  }) async {
    try {
      Query q = _firestore
          .collection('products')
          .where('isVisible', isEqualTo: true)
          .where('isShopHidden', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(lastDoc);
      if (shopId != null) q = q.where('shopId', isEqualTo: shopId);
      if (category != null && category != 'الكل') {
        q = q.where('category', isEqualTo: category);
      }
      q = q.limit(pageSize);
      final snap = await q.get();
      final products = snap.docs
          .map((d) =>
              Product.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
      return ProductPageResult(
        products: products,
        lastDocument: snap.docs.isNotEmpty ? snap.docs.last : null,
        hasMore: snap.docs.length == pageSize,
      );
    } catch (e, s) {
      developer.log('getNextProductsPage error: $e',
          name: 'ProductService', error: e, stackTrace: s);
      return const ProductPageResult(
          products: [], lastDocument: null, hasMore: false);
    }
  }

  /// ✅ توليد searchKeywords — Fix #52: حد أقصى 40 keyword لتجنب تضخم الوثيقة
  static List<String> generateSearchKeywords(
      String name, String description, String category) {
    final Set<String> keywords = {};

    // أول 3 كلمات من الوصف فقط لتجنب bloat
    final descWords = description
        .split(RegExp(r'\s+'))
        .take(3)
        .join(' ');

    final words = '$name $descWords $category'
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 1);
    keywords.addAll(words);
    for (final word in words) {
      for (int i = 2; i <= word.length; i++) {
        keywords.add(word.substring(0, i));
      }
    }
    // ✅ Fix #52: حد أقصى 40 keyword
    return keywords.take(40).toList();
  }

  // =========================================================
  // ✅ Phase 2 Fix #17b: جلب منتجات/عروض بـ whereIn — بدل جلب الكل
  // =========================================================

  static Future<List<Product>> getProductsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final results = <Product>[];
    for (int i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, (i + 30).clamp(0, ids.length));
      try {
        final snap = await _firestore
            .collection('products')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        results.addAll(snap.docs.map(
            (d) => Product.fromMap(d.data(), d.id)));
      } catch (e) {
        developer.log('getProductsByIds chunk error: \$e',
            name: 'ProductService');
      }
    }
    return results;
  }

  static Future<List<Offer>> getOffersByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final results = <Offer>[];
    for (int i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, (i + 30).clamp(0, ids.length));
      try {
        final snap = await _firestore
            .collection('offers')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        results.addAll(snap.docs
            .map((d) => Offer.fromMap(d.data(), d.id)));
      } catch (e) {
        developer.log('getOffersByIds chunk error: \$e',
            name: 'ProductService');
      }
    }
    return results;
  }

} // ← القفل الصحيح الوحيد لكلاس ProductService

/// ✅ يمثّل نتيجة صفحة من المنتجات مع مؤشر التنقل للصفحة التالية
class ProductPageResult {
  final List<Product> products;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  const ProductPageResult({
    required this.products,
    required this.lastDocument,
    required this.hasMore,
  });
}
