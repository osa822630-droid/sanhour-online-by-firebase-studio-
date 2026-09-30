import 'dart:async';
// lib/services/auth_service.dart
// ✅ Phase 2 Fix #15: إصلاح getUserStream ليقبل uid صريح.
// قبل هذا الإصلاح: ApiService.getUserStream(uid) تُمرر uid لكن الدالة تتجاهله
// وتستخدم _auth.currentUser?.uid — وفي حالة المستخدمين الـ Mock لا يوجد
// currentUser في Firebase Auth، فيرجع Stream.empty()، وتنكسر ميزة الطرد الفوري.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==========================================================
  // 1. تسجيل الدخول
  // ==========================================================
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);

      final userDoc = await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .get();

      final userData =
          Map<String, dynamic>.from(userDoc.data() as Map? ?? {});

      if (userData['isSuspended'] == true) {
        await _auth.signOut();
        // ✅ رسالة خطأ user-friendly — لا raw exception
        throw Exception('عذراً، تم تعليق حسابك من قبل الإدارة.');
      }

      userData['id'] = credential.user!.uid;
      userData['email'] = credential.user!.email;

      return {
        'token': await credential.user!.getIdToken(),
        'user': userData
      };
    } on FirebaseAuthException catch (e) {
      // ✅ Fix: ترجمة FirebaseAuthException لرسائل عربية — لا كود تقني للمستخدم
      throw Exception(_mapAuthError(e.code));
    } catch (e) {
      if (e.toString().contains('تم تعليق حسابك')) rethrow;
      throw Exception('بيانات الدخول غير صحيحة أو يوجد مشكلة في الاتصال.');
    }
  }

  // ==========================================================
  // 2. التسجيل
  // ==========================================================
  static Future<Map<String, dynamic>> registerUser(
      Map<String, dynamic> userData) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
          email: userData['email'], password: userData['password']);

      final uid = credential.user!.uid;
      final dataToSave = {
        'name': userData['name'],
        'phone': userData['phone'],
        'username': userData['username'],
        'userType': userData['userType'] ?? 'customer',
        'createdAt': FieldValue.serverTimestamp(),
        'email': userData['email'],
        'isSuspended': false,
        // ✅ لا حقل 'password' يُحفظ في Firestore مطلقاً
      };

      await _firestore.collection('users').doc(uid).set(dataToSave);

      dataToSave['id'] = uid;
      dataToSave['createdAt'] = DateTime.now().toIso8601String();

      return {
        'token': await credential.user!.getIdToken(),
        'user': dataToSave
      };
    } on FirebaseAuthException catch (e) {
      // ✅ لا raw exception للمستخدم
      throw Exception(_mapAuthError(e.code));
    } catch (e) {
      throw Exception('حدث خطأ غير متوقع. حاول مجدداً.');
    }
  }

  // ==========================================================
  // 3. مراقبة المستخدم (Suspension Detection)
  // ==========================================================

  /// ✅ Phase 2 Fix #15: يقبل الآن [userId] صريحاً كمعامل أول.
  /// هذا يُتيح مراقبة مستخدمي الـ Mock الذين ليس لهم Firebase Auth session.
  static Stream<DocumentSnapshot> getUserStream({String? userId}) {
    // استخدم userId الصريح أولاً، ثم currentUser كـ fallback
    final uid = userId ?? _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _firestore.collection('users').doc(uid).snapshots();
  }

  static Future<void> signOut() async => _auth.signOut();

  // ==========================================================
  // 4. إدارة المستخدمين (Admin)
  // ==========================================================
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    final snapshot = await _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  static Future<void> toggleUserSuspension(
      String userId, bool currentStatus) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .update({'isSuspended': !currentStatus});
  }

  // ==========================================================
  // ✅ Fix #24: toggleFavorite في transaction ذرية لمنع race condition
  static Future<void> toggleFavorite(String type, String itemId,
      {String? userId}) async {
    final uid = userId ?? _auth.currentUser?.uid;
    if (uid == null) return;
    final favRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc('${type}_$itemId');

    bool wasAdded = false;
    await _firestore.runTransaction((tx) async {
      final doc = await tx.get(favRef);
      if (doc.exists) {
        tx.delete(favRef);
        wasAdded = false;
      } else {
        tx.set(favRef, {
          'itemId': itemId,
          'type': type,
          'createdAt': FieldValue.serverTimestamp(),
        });
        wasAdded = true;
      }
    });

    unawaited(_updateItemFavoriteCount(type, itemId, wasAdded ? 1 : -1));
  }

  /// ✅ Add-only favorite (لـ mergeLocalFavoritesOnLogin — لا toggle)
  static Future<void> addFavoriteIfNotExists(String type, String itemId,
      {required String userId}) async {
    final favRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc('${type}_$itemId');
    final doc = await favRef.get();
    if (!doc.exists) {
      await favRef.set({
        'itemId': itemId,
        'type': type,
        'createdAt': FieldValue.serverTimestamp()
      });
      // ✅ QA Fix #P8: unawaited() صريحة — تحديث العداد لا يُعيق العملية الرئيسية
      unawaited(_updateItemFavoriteCount(type, itemId, 1));
    }
  }

  static Future<List<String>> getFavorites(String type,
      {String? userId}) async {
    final uid = userId ?? _auth.currentUser?.uid;
    if (uid == null) return [];
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .where('type', isEqualTo: type)
        .get();
    return snapshot.docs
        .map((doc) => doc['itemId'] as String)
        .toList();
  }

  static Future<void> _updateItemFavoriteCount(
      String type, String itemId, int change) async {
    final collection = type == 'shop'
        ? 'shops'
        : (type == 'product' ? 'products' : 'offers');
    try {
      await _firestore
          .collection(collection)
          .doc(itemId)
          .update({'favoriteCount': FieldValue.increment(change)});
    } catch (_) {} // لا نكسر التطبيق لو فشل تحديث العداد
  }

  // ==========================================================
  // 6. Helper — ترجمة Firebase Auth Codes
  // ==========================================================
  static String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'رقم الهاتف أو كلمة المرور غير صحيحة.';
      case 'user-disabled':
        return 'هذا الحساب موقوف. تواصل مع الإدارة.';
      case 'too-many-requests':
        return 'عدد محاولات كثيرة. انتظر قليلاً ثم أعد المحاولة.';
      case 'email-already-in-use':
        return 'هذا البريد الإلكتروني مُسجَّل مسبقاً.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة. استخدم 8 أحرف على الأقل.';
      case 'network-request-failed':
        return 'تعذّر الاتصال بالإنترنت. تحقق من اتصالك.';
      default:
        return 'حدث خطأ غير متوقع. حاول مجدداً.';
    }
  }
}
