// lib/services/product_service.dart
// ✅ دعم includeHidden في getProducts و includeInactive في getOffers للوحة التاجر
// ✅ إزالة محاولة حذف العروض المنتهية من حسابات الزوار والعملاء (التي كانت ترمي permission-denied)
// ✅ استثناء 'الكل' في getTopProducts
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

  static Future<bool> _canManageShop(String shopId, String uid) async {
    final results = await Future.wait([
      _firestore.collection('shops').doc(shopId).get(),
      _firestore.collection('users').doc(uid).get(),
    ]);
    final shopDoc = results[0];
    final userDoc = results[1];
    if (!shopDoc.exists) return false;
    if (shopDoc.data()?['ownerId'] == uid) return true;
    final userData = userDoc.data() ?? {};
    final role = userData['userType'];
    if (role == 'admin' || role == 'super_admin' || role == 'moderator') {
      return true;
    }
    final linkedShopId = userData['linkedShopId'];
    final shopRole = userData['shopRole'];
    return linkedShopId == shopId &&
        ['owner', 'partner', 'worker'].contains(shopRole);
  }

  static Future<List<Product>> getProducts({
    String? shopId,
    bool includeHidden = false,
    int limit = 150,
  }) async {
    try {
      Query q = _firestore.collection('products');
      if (shopId != null) q = q.where('shopId', isEqualTo: shopId);
      if (!includeHidden) {
        q = q
            .where('isVisible', isEqualTo: true)
            .where('isShopHidden', isEqualTo: false);
      }
      q = q.orderBy('createdAt', descending: true);
      final snap = await q.limit(limit).get();
      final products = snap.docs
          .map((d) => Product.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();

      if (shopId != null) {
        products.sort((a, b) {
          final orderA = a.sortOrder;
          final orderB = b.sortOrder;
          if (orderA != null && orderB != null) {
            return orderA.compareTo(orderB);
          }
          if (orderA != null) return -1;
          if (orderB != null) return 1;
          return 0;
        });
      }
      return products;
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
      if (category != null && category.isNotEmpty && category != 'الكل') {
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
    void Function(int fileIndex, double fraction)? onImageProgress,
  }) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser != null && !firebaseUser.isAnonymous) {
      final allowed = await _canManageShop(
          productData['shopId'] as String, firebaseUser.uid);
      if (!allowed) {
        throw Exception('غير مصرح لك بإضافة منتج لهذا المتجر');
      }
    }

    final imageUrls = await _uploadImagesWithProgress(
        images, 'products_images', onImageProgress);

    final int rawCover = (productData['coverImageIndex'] as int? ?? 0);
    final int validCover =
        imageUrls.isEmpty ? 0 : rawCover.clamp(0, imageUrls.length - 1);
    productData.remove('coverImageIndex');

    final prodName = (productData['name'] as String? ?? '').trim();
    final prodDesc = (productData['description'] as String? ?? '').trim();
    final prodCat = (productData['category'] as String? ?? '').trim();
    final keywords = generateSearchKeywords(prodName, prodDesc, prodCat);

    final docRef = _firestore.collection('products').doc();
    await docRef.set({
      'id': docRef.id,
      ...productData,
      'imageUrls': imageUrls,
      'coverImageIndex': validCover,
      'imageUrl': imageUrls.isEmpty ? '' : imageUrls[validCover],
      'searchKeywords': keywords,
      'createdAt': FieldValue.serverTimestamp(),
      'rating': 0.0,
      'reviewCount': 0,
      'views': 0,
      'favoriteCount': 0,
      'isVisible': true,
      'isShopHidden': false,
    });
  }

  static Future<void> updateProduct(
    String productId,
    Map<String, dynamic> data,
    List<File>? newImages, {
    void Function(int fileIndex, double fraction)? onImageProgress,
  }) async {
    List<String> imageUrls =
        List<String>.from(data['existingImages'] ?? []);
    data.remove('existingImages');

    if (newImages != null && newImages.isNotEmpty) {
      final newUrls = await _uploadImagesWithProgress(
          newImages, 'products_images', onImageProgress);
      imageUrls.addAll(newUrls);
    }

    final int rawCover = (data['coverImageIndex'] as int? ?? 0);
    final int validCover =
        imageUrls.isEmpty ? 0 : rawCover.clamp(0, imageUrls.length - 1);

    if (data.containsKey('name') ||
        data.containsKey('description') ||
        data.containsKey('category')) {
      final prodName = (data['name'] as String? ?? '').trim();
      final prodDesc = (data['description'] as String? ?? '').trim();
      final prodCat = (data['category'] as String? ?? '').trim();
      data['searchKeywords'] =
          generateSearchKeywords(prodName, prodDesc, prodCat);
    }
    data['imageUrls'] = imageUrls;
    data['coverImageIndex'] = validCover;
    data['imageUrl'] = imageUrls.isEmpty ? '' : imageUrls[validCover];
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore
        .collection('products')
        .doc(productId)
        .update(data);
  }

  static Future<void> deleteProduct(String productId) async {
    await _firestore.collection('products').doc(productId).delete();
  }

  // ==========================================================
  // 2. العروض
  // ==========================================================

  static Future<List<Offer>> getOffers({
    String? shopId,
    bool includeInactive = false,
    int limit = 150,
  }) async {
    try {
      Query q = _firestore.collection('offers');
      if (shopId != null) {
        q = q.where('shopId', isEqualTo: shopId);
      }
      if (!includeInactive) {
        q = q
            .where('isActive', isEqualTo: true)
            .where('isShopHidden', isEqualTo: false);
      }
      q = q.orderBy('createdAt', descending: true);
      final snap = await q.limit(limit).get();
      final all = snap.docs
          .map((d) =>
              Offer.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();

      final monthAgo = DateTime.now().subtract(const Duration(days: 30));

      // ✅ تنظيف العروض التي مضى على انتهائها أكثر من 30 يوماً فقط عندما يفتح التاجر لوحته الخاصة (includeInactive == true)
      if (shopId != null && includeInactive) {
        final stale = all.where((o) => o.validUntil.isBefore(monthAgo)).toList();
        for (final expiredOffer in stale) {
          deleteOffer(expiredOffer.id).catchError((_) {});
        }
      }

      if (shopId == null && !includeInactive) {
        return all.where((o) => !o.isExpired).toList();
      }
      return all.where((o) => !o.validUntil.isBefore(monthAgo)).toList();
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

  static Future<void> addOffer(
      Map<String, dynamic> offerData,
      List<File> images, {
      int coverIndex = 0,
      void Function(int fileIndex, double fraction)? onImageProgress,
      }) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser != null && !firebaseUser.isAnonymous) {
      final allowed = await _canManageShop(
          offerData['shopId'] as String, firebaseUser.uid);
      if (!allowed) {
        throw Exception('غير مصرح لك بإضافة عرض لهذا المتجر');
      }
    }

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

    offerData.remove('imageUrls');
    offerData.remove('imageUrl');
    offerData.remove('existingImages');

    final docRef = _firestore.collection('offers').doc();

    final offerTitle = (offerData['title'] as String? ?? '').trim();
    final offerDesc = (offerData['description'] as String? ?? '').trim();
    final offerType = (offerData['type'] as String? ?? '').trim();
    final offerKeywords =
        generateSearchKeywords(offerTitle, offerDesc, offerType);

    final offerMap = {
      'id': docRef.id,
      ...offerData,
      'imageUrls': imageUrls,
      'coverImageIndex': validCover,
      'imageUrl': coverUrl,
      'searchKeywords': offerKeywords,
      'createdAt': FieldValue.serverTimestamp(),
      'views': 0,
      'favoriteCount': 0,
      'isActive': offerData['isActive'] ?? true,
      'isVisible': offerData['isVisible'] ?? true,
      'isShopHidden': false,
    };

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

  static Future<void> updateOffer(
      String offerId,
      Map<String, dynamic> data,
      List<File> newImages, {
      int? coverIndex,
      void Function(int fileIndex, double fraction)? onImageProgress,
      }) async {
    final List<String> existingUrls =
        List<String>.from(data['existingImages'] ?? data['imageUrls'] ?? []);
    data.remove('existingImages');
    data.remove('imageUrls');
    data.remove('imageUrl');

    List<String> uploadedUrls = [];
    if (newImages.isNotEmpty) {
      uploadedUrls = await _uploadImagesWithProgress(
          newImages, 'offers_images', onImageProgress);
    }

    final List<String> allUrls = [...existingUrls, ...uploadedUrls];
    final int validCover =
        allUrls.isEmpty ? 0 : (coverIndex ?? 0).clamp(0, allUrls.length - 1);
    final String coverUrl = allUrls.isEmpty ? '' : allUrls[validCover];

    if (data.containsKey('title') ||
        data.containsKey('description') ||
        data.containsKey('type')) {
      final offerTitle = (data['title'] as String? ?? '').trim();
      final offerDesc = (data['description'] as String? ?? '').trim();
      final offerType = (data['type'] as String? ?? '').trim();
      data['searchKeywords'] =
          generateSearchKeywords(offerTitle, offerDesc, offerType);
    }
    data['imageUrls'] = allUrls;
    data['coverImageIndex'] = validCover;
    data['imageUrl'] = coverUrl;
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('offers').doc(offerId).update(data);
  }

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
  // 4. استيراد Excel
  // ==========================================================

  static Future<Map<String, dynamic>> importProductsExcel(
      String shopId, String filePath) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول أولاً');

    if (!user.isAnonymous) {
      final allowed = await _canManageShop(shopId, user.uid);
      if (!allowed) {
        throw Exception('غير مصرح لك باستيراد منتجات لهذا المتجر');
      }
    } else {
      final shopDoc = await _firestore.collection('shops').doc(shopId).get();
      if (!shopDoc.exists) {
        throw Exception('المتجر غير موجود');
      }
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

          final keywords = generateSearchKeywords(name, desc, cat);

          final docRef = _firestore.collection('products').doc();
          batch.set(docRef, {
            'id': docRef.id,
            'shopId': shopId,
            'name': name,
            'price': price,
            'description': desc,
            'category': cat,
            'imageUrls': <String>[],
            'coverImageIndex': 0,
            'rating': 0.0,
            'reviewCount': 0,
            'views': 0,
            'favoriteCount': 0,
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
  // 6. Pagination
  // ==========================================================

  static const int _pageSize = 20;

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

  static List<String> generateSearchKeywords(
      String name, String description, String category) {
    final Set<String> keywords = {};

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
    return keywords.take(40).toList();
  }

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
        developer.log('getProductsByIds chunk error: $e',
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
        developer.log('getOffersByIds chunk error: $e',
            name: 'ProductService');
      }
    }
    return results;
  }
}

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
