// lib/services/shop_service.dart
// ✅ التحقق من كود التفعيل قبل رفع الصور إلى Firebase Storage وتنظيف الصور المرفوعة إذا فشل الـ Transaction
// ✅ استخدام AppConstants.phoneLookupCandidates للبحث بجميع صيغ أرقام الهواتف عند تعيين مالك المحل
import 'dart:developer' as developer;
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sanhour_online/services/product_service.dart';
import '../models/category_model.dart';
import '../models/shop.dart';
import '../utils/constants.dart';
import 'audit_log_service.dart';
import 'media_upload_service.dart';

class ShopService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // =========================================================
  // 1. جلب المحلات
  // =========================================================

  static Future<List<Shop>> getShops({
    String? category,
    String? query,
    int limit = 150,
  }) async {
    try {
      Query q = _firestore
          .collection('shops')
          .where('isSuspended', isEqualTo: false)
          .orderBy('isFeatured', descending: true);

      if (category != null && category != 'الكل') {
        q = q.where('category', isEqualTo: category);
      }

      final snap = await q.limit(limit).get();
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
      developer.log('getShops error: $e',
          name: 'ShopService', error: e, stackTrace: s);
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
      developer.log('getRankedShops error: $e',
          name: 'ShopService', error: e, stackTrace: s);
      return [];
    }
  }

  static Future<List<Shop>> getMerchantShops(String ownerId,
      {String? linkedShopId}) async {
    try {
      final snap = await _firestore
          .collection('shops')
          .where('ownerId', isEqualTo: ownerId)
          .get();
      final shops = snap.docs.map((d) => Shop.fromMap(d.data(), d.id)).toList();

      if (linkedShopId != null &&
          linkedShopId.isNotEmpty &&
          !shops.any((s) => s.id == linkedShopId)) {
        final linkedDoc =
            await _firestore.collection('shops').doc(linkedShopId).get();
        if (linkedDoc.exists && linkedDoc.data() != null) {
          shops.add(Shop.fromMap(linkedDoc.data()!, linkedDoc.id));
        }
      }
      return shops;
    } catch (e) {
      return [];
    }
  }

  // =========================================================
  // 2. التحقق من كود التفعيل
  // =========================================================

  static const String _shopActivationType = 'shop_activation';

  static Future<DocumentReference<Map<String, dynamic>>?>
      _findUnusedActivationCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      return null;
    }
    final directRef = _firestore.collection('activation_codes').doc(normalized);
    final directDoc = await directRef.get();
    if (!directDoc.exists) {
      return null;
    }
    final data = directDoc.data();
    if (data == null ||
        data['isUsed'] == true ||
        data['type'] != _shopActivationType) {
      return null;
    }
    return directRef;
  }

  static Future<void> validateActivationCode(String code) async {
    final codeRef = await _findUnusedActivationCode(code);
    if (codeRef == null) {
      throw Exception('كود التفعيل غير صحيح أو مستخدم مسبقاً.');
    }
  }

  static Future<void> _requireAdmin(String uid) async {
    final snap = await _firestore.collection('users').doc(uid).get();
    final role = snap.data()?['userType'];
    if (role != 'admin' && role != 'super_admin') {
      throw Exception('إنشاء محل بدون كود تفعيل متاح للأدمن فقط.');
    }
  }

  static Future<Map<String, dynamic>> resolveOwnerAssignment(
      String rawIdentifier) async {
    final clean = rawIdentifier.trim().replaceFirst('@', '');
    if (clean.isEmpty || clean == 'بدون') {
      return {'ownerId': '', 'pendingOwnerPhone': null};
    }

    final digits = AppConstants.arabicToEnglishDigits(clean)
        .replaceAll(RegExp(r'[\s\-]'), '');
    final bool looksLikePhone =
        RegExp(r'^(\+?20|0020)?0?1[0-9]{9}$').hasMatch(digits);
    final String normalizedPhone =
        looksLikePhone ? AppConstants.normalizePhoneToE164(digits) : digits;

    QuerySnapshot<Map<String, dynamic>>? userSnap;
    if (looksLikePhone) {
      final candidates = AppConstants.phoneLookupCandidates(digits);
      userSnap = await _firestore
          .collection('users')
          .where('phone', whereIn: candidates)
          .limit(1)
          .get();
    } else {
      userSnap = await _firestore
          .collection('users')
          .where('username', isEqualTo: clean.toLowerCase())
          .limit(1)
          .get();
    }

    if (userSnap.docs.isNotEmpty) {
      final foundDoc = userSnap.docs.first;
      await foundDoc.reference.update({
        'userType': 'merchant',
        'shopRole': 'owner',
      });
      return {'ownerId': foundDoc.id, 'pendingOwnerPhone': null};
    }

    if (looksLikePhone) {
      return {'ownerId': '', 'pendingOwnerPhone': normalizedPhone};
    }

    return {'ownerId': '', 'pendingOwnerPhone': null};
  }

  // =========================================================
  // 3. إنشاء محل بشكل ذري مع تنظيف الصور عند أي فشل
  // =========================================================

  static Future<String> createShop(
    Map<String, dynamic> shopData,
    File? logo,
    File? cover, {
    bool adminBypass = false,
    void Function(double fraction)? onLogoProgress,
    void Function(double fraction)? onCoverProgress,
  }) async {
    final firebaseUser = _auth.currentUser;
    final ownerId = shopData['ownerId'] as String?;
    if (ownerId == null || ownerId.isEmpty) {
      throw Exception('يجب تسجيل الدخول أولاً');
    }
    if (firebaseUser != null &&
        !firebaseUser.isAnonymous &&
        ownerId != firebaseUser.uid) {
      throw Exception('غير مصرح لك بإنشاء هذا المحل');
    }

    final String? activationCode =
        adminBypass ? null : (shopData['activationCode'] as String?);
    DocumentReference<Map<String, dynamic>>? codeRef;

    // ✅ التحقق المسبق من صلاحية الأدمن أو كود التفعيل قبل رفع أي صور إلى Storage
    if (adminBypass) {
      await _requireAdmin(ownerId);
    } else {
      if (activationCode == null || activationCode.trim().isEmpty) {
        throw Exception('كود التفعيل مطلوب لإنشاء المحل.');
      }
      codeRef = await _findUnusedActivationCode(activationCode);
      if (codeRef == null) {
        throw Exception('كود التفعيل غير صحيح أو مستخدم مسبقاً.');
      }
    }

    String? uploadedLogoUrl;
    String? uploadedCoverUrl;

    try {
      if (logo != null) {
        uploadedLogoUrl = await ProductService.uploadImage(
            logo, 'shop_logos',
            onProgress: onLogoProgress);
        shopData['imageUrl'] = uploadedLogoUrl;
      }
      if (cover != null) {
        uploadedCoverUrl = await ProductService.uploadImage(
            cover, 'shop_covers',
            onProgress: onCoverProgress);
        shopData['coverUrl'] = uploadedCoverUrl;
      }

      shopData['isSuspended'] = false;
      shopData['isActive'] = true;
      shopData['rating'] = 0.0;
      shopData['reviewCount'] = 0;
      shopData['views'] = 0;
      shopData['favoriteCount'] = 0;
      shopData['uniqueVisitors'] = 0;
      shopData['createdAt'] = FieldValue.serverTimestamp();

      final name = (shopData['name'] as String? ?? '').toLowerCase();
      final desc = (shopData['description'] as String? ?? '').toLowerCase();
      final cat = (shopData['category'] as String? ?? '').toLowerCase();
      shopData['searchKeywords'] = _generateShopKeywords(name, desc, cat);

      if (adminBypass && shopData.containsKey('targetOwnerIdentifier')) {
        final rawTarget = shopData['targetOwnerIdentifier'] as String? ?? '';
        shopData.remove('targetOwnerIdentifier');
        final assignment = await resolveOwnerAssignment(rawTarget);
        shopData['ownerId'] = assignment['ownerId'];
        shopData['pendingOwnerPhone'] = assignment['pendingOwnerPhone'];
      } else {
        shopData.remove('targetOwnerIdentifier');
      }

      shopData.remove('activationCode');

      final docRef = _firestore.collection('shops').doc();
      final effectiveUsedBy =
          (firebaseUser != null && !firebaseUser.isAnonymous)
              ? firebaseUser.uid
              : ownerId;

      await _firestore.runTransaction((tx) async {
        if (codeRef != null) {
          final freshCode = await tx.get(codeRef);
          final freshData = freshCode.data();
          if (!freshCode.exists ||
              freshData == null ||
              freshData['isUsed'] == true ||
              freshData['type'] != _shopActivationType) {
            throw Exception('كود التفعيل غير صحيح أو مستخدم مسبقاً.');
          }
          final codeExpiresAt = freshData['expiresAt'];
          if (codeExpiresAt is Timestamp &&
              codeExpiresAt.toDate().isBefore(DateTime.now())) {
            throw Exception('انتهت صلاحية كود التفعيل.');
          }

          tx.update(codeRef, {
            'isUsed': true,
            'usedBy': effectiveUsedBy,
            'usedAt': FieldValue.serverTimestamp(),
            'shopId': docRef.id,
          });
        }

        tx.set(docRef, {...shopData, 'id': docRef.id});
      });

      if (adminBypass) {
        await AuditLogService.log(
          action: AuditAction.shopCreated,
          targetId: docRef.id,
          targetType: 'shop',
          targetName: shopData['name'] as String?,
          metadata: {'viaAdminBypass': true},
          adminId: ownerId,
        );
      }

      return docRef.id;
    } catch (e) {
      // ✅ تنظيف الصور المرفوعة في حال فشل إنشاء الوثيقة أو حرق الكود لمنع بقاء ملفات يتيمة في Storage
      if (uploadedLogoUrl != null && uploadedLogoUrl.isNotEmpty) {
        await MediaUploadService.deleteByUrl(uploadedLogoUrl);
      }
      if (uploadedCoverUrl != null && uploadedCoverUrl.isNotEmpty) {
        await MediaUploadService.deleteByUrl(uploadedCoverUrl);
      }
      rethrow;
    }
  }

  static Future<void> updateShop(
    String shopId,
    Map<String, dynamic> data,
    File? newLogo,
    File? newCover, {
    void Function(double fraction)? onLogoProgress,
    void Function(double fraction)? onCoverProgress,
  }) async {
    if (newLogo != null) {
      data['imageUrl'] = await ProductService.uploadImage(newLogo, 'shop_logos',
          onProgress: onLogoProgress);
    }
    if (newCover != null) {
      data['coverUrl'] = await ProductService.uploadImage(
          newCover, 'shop_covers',
          onProgress: onCoverProgress);
    }

    if (data.containsKey('name') ||
        data.containsKey('description') ||
        data.containsKey('category')) {
      final shopDoc = await _firestore.collection('shops').doc(shopId).get();
      final existing = shopDoc.data() ?? {};
      final name = ((data['name'] ?? existing['name']) as String? ?? '')
          .toLowerCase();
      final desc =
          ((data['description'] ?? existing['description']) as String? ?? '')
              .toLowerCase();
      final cat = ((data['category'] ?? existing['category']) as String? ?? '')
          .toLowerCase();
      data['searchKeywords'] = _generateShopKeywords(name, desc, cat);
    }

    if (data.containsKey('targetOwnerIdentifier')) {
      final rawTarget = data['targetOwnerIdentifier'] as String? ?? '';
      data.remove('targetOwnerIdentifier');
      final assignment = await resolveOwnerAssignment(rawTarget);
      data['ownerId'] = assignment['ownerId'];
      data['pendingOwnerPhone'] = assignment['pendingOwnerPhone'];
    }
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('shops').doc(shopId).update(data);
  }

  // =========================================================
  // 3.5. معرض وسائط المحل (صور + فيديوهات)
  // =========================================================

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
    final newImageUrls =
        await Future.wait(List.generate(newImages.length, (i) {
      return MediaUploadService.uploadFile(
        file: newImages[i],
        folder: 'shop_media',
        kind: MediaKind.image,
        onProgress: onImageProgress == null
            ? null
            : (p) => onImageProgress(i, p.fraction),
      );
    }));

    final newVideoUrls =
        await Future.wait(List.generate(newVideos.length, (i) {
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

    for (final url in removedUrls) {
      await MediaUploadService.deleteByUrl(url);
    }
  }

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
      developer.log('getCategories error: $e',
          name: 'ShopService', error: e, stackTrace: s);
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
      if (region != null && region.isNotEmpty && region != 'الكل') {
        q = q.where('location', isEqualTo: region);
      }
      q = q.limit(pageSize);
      final snap = await q.get();
      final shops = snap.docs
          .map((d) => Shop.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
      final filtered = region != null && region.isNotEmpty && region != 'الكل'
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
      if (region != null && region.isNotEmpty && region != 'الكل') {
        q = q.where('location', isEqualTo: region);
      }
      q = q.limit(pageSize);
      final snap = await q.get();
      final shops = snap.docs
          .map((d) => Shop.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
      final filtered = region != null && region.isNotEmpty && region != 'الكل'
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
