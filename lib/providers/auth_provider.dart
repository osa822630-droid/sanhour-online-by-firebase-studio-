// lib/providers/auth_provider.dart
// ✅ إزالة سحب مفتاح Gemini السري لأجهزة المستخدمين العاديين (يُعالج عبر Cloud Function askGemini)
// ✅ استخدام AppConstants.phoneLookupCandidates عند المطالبة التلقائية بالمحلات المعلقة (pendingOwnerPhone)
// ✅ حجز اسم المستخدم في usernames/{username} وتوليد referralCode تلقائياً عند التسجيل
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/gemini_service.dart';
import '../services/notification_service.dart';
import '../services/referral_service.dart';
import '../utils/constants.dart';

enum AuthStatus {
  uninitialized,
  authenticated,
  authenticating,
  unauthenticated,
  guest
}

enum UserRole { admin, moderator, merchant, customer, user, guest }

class AuthProvider with ChangeNotifier {
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthStatus _status = AuthStatus.uninitialized;
  AppUser? _user;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  bool get isLoggedIn => _status == AuthStatus.authenticated;
  bool get isGuest => _status == AuthStatus.guest;

  UserRole get userRole {
    if (isGuest || _user == null) return UserRole.guest;
    switch (_user!.userType) {
      case 'admin':
      case 'super_admin':
        return UserRole.admin;
      case 'moderator':
        return UserRole.moderator;
      case 'merchant':
        return UserRole.merchant;
      default:
        return UserRole.customer;
    }
  }

  bool get isAdmin =>
      userRole == UserRole.admin || userRole == UserRole.moderator;

  bool get canViewFinancialStats => _user?.canViewFinancialStats ?? false;
  bool get canViewShopStats => _user?.canViewShopStats ?? false;
  bool get canManageSubscription => _user?.canManageSubscription ?? false;

  AuthProvider() {
    _autoLogin();
  }

  Future<void> _autoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('is_guest') == true) {
      await _ensureAnonymousSession();
      _status = AuthStatus.guest;
      notifyListeners();
      return;
    }

    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null && !firebaseUser.isAnonymous) {
      _status = AuthStatus.authenticating;
      notifyListeners();
      await _fetchUserData(firebaseUser.uid);
      return;
    }

    final userId = prefs.getString('user_id');
    if (userId != null) {
      _status = AuthStatus.authenticating;
      notifyListeners();
      await _ensureAnonymousSession();
      if (BuildFlags.mockModeEnabled) {
        await _bindMockSession(userId);
      }
      await _fetchUserData(userId);
    } else {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<void> _ensureAnonymousSession() async {
    try {
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }
    } catch (e) {
      debugPrint('Anonymous auth session error (non-fatal): $e');
    }
  }

  Future<void> _bindMockSession(String appUserId) async {
    if (!BuildFlags.mockModeEnabled) return;
    try {
      final session = _auth.currentUser;
      if (session == null || !session.isAnonymous) return;
      await _firestore.collection('auth_sessions').doc(session.uid).set({
        'appUserId': appUserId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Mock session binding error (non-fatal): $e');
    }
  }

  Future<void> _unbindMockSession() async {
    try {
      final session = _auth.currentUser;
      if (session == null || !session.isAnonymous) return;
      await _firestore.collection('auth_sessions').doc(session.uid).delete();
    } catch (e) {
      debugPrint('Mock session unbinding error (non-fatal): $e');
    }
  }

  Future<void> _fetchUserData(String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10),
              onTimeout: () => throw TimeoutException('انتهت مهلة الاتصال'));
      if (doc.exists) {
        final data = Map<String, dynamic>.from(doc.data()!);
        if (data['isDeleted'] == true) {
          _status = AuthStatus.unauthenticated;
        } else if (data['isSuspended'] == true) {
          await _auth.signOut();
          _status = AuthStatus.unauthenticated;
        } else {
          data['id'] = doc.id;
          _user = AppUser.fromMap(data);
          _status = AuthStatus.authenticated;
          _onLoginSuccess();
        }
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } on TimeoutException {
      debugPrint('_fetchUserData timeout');
      _status = AuthStatus.unauthenticated;
    } catch (e) {
      debugPrint('fetchUserData error: $e');
      _status = AuthStatus.unauthenticated;
    } finally {
      notifyListeners();
    }
  }

  void _onLoginSuccess() {
    if (_user?.isAnyAdmin == true) {
      _loadGeminiKeyForAdmin();
    }
    _subscribeToNotificationTopics();
    _claimPendingShopsByPhone();
    _ensureReferralCode();
  }

  Future<void> _ensureReferralCode() async {
    final u = _user;
    if (u == null || (u.referralCode != null && u.referralCode!.isNotEmpty)) {
      return;
    }
    try {
      final code = await ReferralService.generateReferralCode(u.id);
      if (_user != null && _user!.id == u.id) {
        _user = _user!.copyWith(referralCode: code);
        notifyListeners();
      }
    } catch (_) {}
  }

  /// ✅ ربط أي محل أضافه الأدمن برقم هاتف هذا المستخدم قبل تسجيله في التطبيق (بجميع صيغ الرقم)
  Future<void> _claimPendingShopsByPhone() async {
    final user = _user;
    if (user == null || user.phone.trim().isEmpty) {
      return;
    }
    try {
      final candidates = AppConstants.phoneLookupCandidates(user.phone.trim());
      if (candidates.isEmpty) return;

      final snap = await _firestore
          .collection('shops')
          .where('pendingOwnerPhone', whereIn: candidates)
          .get();
      if (snap.docs.isEmpty) {
        return;
      }
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {
          'ownerId': user.id,
          'pendingOwnerPhone': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      if (user.userType == 'customer') {
        batch.update(_firestore.collection('users').doc(user.id), {
          'userType': 'merchant',
          'shopRole': 'owner',
        });
      }
      await batch.commit();
      if (user.userType == 'customer') {
        _user = user.copyWith(userType: 'merchant', shopRole: 'owner');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('_claimPendingShopsByPhone error: $e');
    }
  }

  /// ✅ يُستدعى للمشرفين فقط (لأن قراءة settings_private مقصورة على المشرفين في firestore.rules)
  Future<void> _loadGeminiKeyForAdmin() async {
    try {
      final doc =
          await _firestore.collection('settings_private').doc('gemini').get();
      if (doc.exists) {
        final key = doc.data()?['apiKey'];
        if (key != null && key.toString().isNotEmpty) {
          GeminiService().setApiKey(key.toString());
        }
      }
    } catch (_) {}
  }

  Future<void> _subscribeToNotificationTopics() async {
    if (_user == null) return;
    await NotificationService.subscribeToUserTopics(_user!.userType);
    final token = await NotificationService.getToken();
    if (token != null) {
      _firestore
          .collection('users')
          .doc(_user!.id)
          .update({'fcmToken': token}).catchError((_) {});
    }
  }

  void updateUserLocally({String? name, String? username, String? photoUrl}) {
    if (_user == null) return;
    _user = _user!.copyWith(
        name: name, username: username, profileImageUrl: photoUrl);
    notifyListeners();
  }

  static String _normalizePhone(String phone) =>
      AppConstants.normalizePhoneToE164(phone);

  static String _phoneToAuthEmail(String normalizedPhone) {
    final digits = normalizedPhone.replaceAll(RegExp(r'[^0-9]'), '');
    return 'u$digits@users.sanhour.online';
  }

  bool _isMockCredentials(String phone, String password) =>
      (phone == '01008908728' && password == 'admin123') ||
      (phone == '01234567890' && password == 'merchant123') ||
      (phone == '01112223334' && password == 'user123');

  Future<String?> loginWithPhoneAndPassword(
      String phone, String password) async {
    _status = AuthStatus.authenticating;
    notifyListeners();

    if (!BuildFlags.mockModeEnabled && _isMockCredentials(phone, password)) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return 'رقم الهاتف أو كلمة المرور غير صحيحة';
    }

    final normalizedPhone = _normalizePhone(phone);
    final phoneCandidates = AppConstants.phoneLookupCandidates(phone);

    try {
      if (BuildFlags.mockModeEnabled && _isMockCredentials(phone, password)) {
        await _ensureAnonymousSession();
        final snap = await _firestore
            .collection('users')
            .where('phone', whereIn: phoneCandidates)
            .limit(1)
            .get();

        if (snap.docs.isNotEmpty) {
          final data = Map<String, dynamic>.from(snap.docs.first.data());
          if (data['isSuspended'] == true) {
            _status = AuthStatus.unauthenticated;
            notifyListeners();
            return 'تم تعليق حسابك. تواصل مع الإدارة.';
          }
          data['id'] = snap.docs.first.id;
          _user = AppUser.fromMap(data);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_guest', false);
          await prefs.setString('user_id', _user!.id);
          await _bindMockSession(_user!.id);
          _status = AuthStatus.authenticated;
          _onLoginSuccess();
          notifyListeners();
          return null;
        }

        await _handleMockLogin(phone, password);
        return null;
      }

      final syntheticEmail = _phoneToAuthEmail(normalizedPhone);
      try {
        final credential = await _auth.signInWithEmailAndPassword(
          email: syntheticEmail,
          password: password,
        );
        final uid = credential.user!.uid;
        var doc = await _firestore.collection('users').doc(uid).get();

        Map<String, dynamic>? userData;
        String resolvedId = uid;

        if (doc.exists && doc.data() != null) {
          userData = Map<String, dynamic>.from(doc.data()!);
          resolvedId = doc.id;
        } else {
          final snap = await _firestore
              .collection('users')
              .where('phone', whereIn: phoneCandidates)
              .limit(1)
              .get();
          if (snap.docs.isNotEmpty) {
            userData = Map<String, dynamic>.from(snap.docs.first.data());
            resolvedId = snap.docs.first.id;
          }
        }

        if (userData == null) {
          await _auth.signOut();
          _status = AuthStatus.unauthenticated;
          notifyListeners();
          return 'لم يتم العثور على بيانات الحساب. يرجى إنشاء حساب جديد.';
        }

        if (userData['isSuspended'] == true) {
          await _auth.signOut();
          _status = AuthStatus.unauthenticated;
          notifyListeners();
          return 'تم تعليق حسابك. تواصل مع الإدارة.';
        }

        if (userData['isDeleted'] == true) {
          await _auth.signOut();
          _status = AuthStatus.unauthenticated;
          notifyListeners();
          return 'هذا الحساب محذوف.';
        }

        userData['id'] = resolvedId;
        _user = AppUser.fromMap(userData);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_guest', false);
        await prefs.setString('user_id', _user!.id);
        _status = AuthStatus.authenticated;
        _onLoginSuccess();
        notifyListeners();
        return null;
      } on auth.FirebaseAuthException catch (authErr) {
        if (BuildFlags.mockModeEnabled &&
            (authErr.code == 'user-not-found' ||
                authErr.code == 'invalid-credential')) {
          await _ensureAnonymousSession();
          final snap = await _firestore
              .collection('users')
              .where('phone', whereIn: phoneCandidates)
              .limit(1)
              .get();
          if (snap.docs.isNotEmpty) {
            final data = Map<String, dynamic>.from(snap.docs.first.data());
            if (data['isSuspended'] == true) {
              _status = AuthStatus.unauthenticated;
              notifyListeners();
              return 'تم تعليق حسابك. تواصل مع الإدارة.';
            }
            data['id'] = snap.docs.first.id;
            _user = AppUser.fromMap(data);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('is_guest', false);
            await prefs.setString('user_id', _user!.id);
            await _bindMockSession(_user!.id);
            _status = AuthStatus.authenticated;
            _onLoginSuccess();
            notifyListeners();
            return null;
          }
        }

        _status = AuthStatus.unauthenticated;
        notifyListeners();
        switch (authErr.code) {
          case 'user-not-found':
          case 'wrong-password':
          case 'invalid-credential':
            return 'رقم الهاتف أو كلمة المرور غير صحيحة';
          case 'user-disabled':
            return 'تم تعليق حسابك. تواصل مع الإدارة.';
          case 'too-many-requests':
            return 'محاولات كثيرة جداً. يرجى الانتظار قليلاً ثم المحاولة.';
          case 'network-request-failed':
            return 'تعذّر الاتصال بالإنترنت. تحقق من اتصالك.';
          default:
            return 'تعذّر تسجيل الدخول (${authErr.code}).';
        }
      }
    } catch (e) {
      debugPrint('Login error: $e');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return 'حدث خطأ في الاتصال. حاول مجدداً.';
    }
  }

  /// إنشاء حساب جديد فعلي برقم الهاتف وكلمة المرور
  Future<String?> registerWithPhoneAndPassword({
    required String name,
    required String username,
    required String phone,
    required String password,
    required String userType,
  }) async {
    const allowedTypes = ['customer', 'merchant'];
    if (!allowedTypes.contains(userType)) {
      return 'نوع المستخدم غير مسموح به.';
    }

    _status = AuthStatus.authenticating;
    notifyListeners();

    final normalizedPhone = _normalizePhone(phone);
    final phoneCandidates = AppConstants.phoneLookupCandidates(phone);
    final syntheticEmail = _phoneToAuthEmail(normalizedPhone);
    final cleanUsername = username.trim().toLowerCase();

    try {
      await _ensureAnonymousSession();

      if (await checkUsernameExists(cleanUsername)) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return 'اسم المستخدم مستخدم مسبقاً.';
      }

      final phoneSnap = await _firestore
          .collection('users')
          .where('phone', whereIn: phoneCandidates)
          .limit(1)
          .get();
      if (phoneSnap.docs.isNotEmpty) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return 'رقم الهاتف مسجّل بالفعل.';
      }

      if (_auth.currentUser != null && _auth.currentUser!.isAnonymous) {
        await _unbindMockSession();
        await _auth.signOut();
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: syntheticEmail,
        password: password,
      );
      final uid = credential.user!.uid;

      final newUser = AppUser(
        id: uid,
        name: name.trim(),
        username: cleanUsername,
        email: syntheticEmail,
        phone: normalizedPhone,
        userType: userType,
      );

      final batch = _firestore.batch();
      batch.set(_firestore.collection('users').doc(uid), {
        ...newUser.toMap(),
        'id': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'isSuspended': false,
        'isDeleted': false,
      });
      batch.set(_firestore.collection('usernames').doc(cleanUsername), {
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();

      _user = newUser;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_guest', false);
      await prefs.setString('user_id', uid);
      _status = AuthStatus.authenticated;
      _onLoginSuccess();
      notifyListeners();
      return null;
    } on auth.FirebaseAuthException catch (e) {
      debugPrint('registerWithPhoneAndPassword error: ${e.code}');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      switch (e.code) {
        case 'email-already-in-use':
          return 'رقم الهاتف مسجّل بالفعل.';
        case 'weak-password':
          return 'كلمة المرور ضعيفة (يجب أن تكون 6 أحرف على الأقل).';
        case 'network-request-failed':
          return 'لا يوجد اتصال بالإنترنت. حاول لاحقاً.';
        default:
          return 'تعذّر إنشاء الحساب (${e.code}).';
      }
    } catch (e) {
      debugPrint('registerWithPhoneAndPassword unexpected error: $e');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return 'حدث خطأ غير متوقع، حاول مجدداً.';
    }
  }

  Future<void> _handleMockLogin(String phone, String password) async {
    String userType = 'customer';
    if (phone == '01008908728') {
      userType = 'admin';
    } else if (phone == '01234567890') {
      userType = 'merchant';
    }

    final normalizedPhone = _normalizePhone(phone);
    final snap = await _firestore
        .collection('users')
        .where('phone', isEqualTo: normalizedPhone)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      final data = Map<String, dynamic>.from(snap.docs.first.data());
      data['id'] = snap.docs.first.id;
      _user = AppUser.fromMap(data);
      await _bindMockSession(_user!.id);
    } else {
      final suffix =
          phone.length >= 4 ? phone.substring(phone.length - 4) : phone;
      final mockId = '${userType}_mock_$suffix';
      await _bindMockSession(mockId);
      final mockUser = AppUser(
        id: mockId,
        name: userType == 'admin'
            ? 'المدير'
            : (userType == 'merchant' ? 'التاجر' : 'مستخدم'),
        username: userType,
        email: '$userType@sanhour.com',
        phone: normalizedPhone,
        userType: userType,
      );

      try {
        await _firestore.collection('users').doc(mockId).set({
          ...mockUser.toMap(),
          'id': mockId,
          'createdAt': FieldValue.serverTimestamp(),
          'isSuspended': false,
          'isDeleted': false,
          'isMockUser': true,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Could not persist mock user: $e');
      }

      _user = mockUser;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest', false);
    await prefs.setString('user_id', _user!.id);
    _status = AuthStatus.authenticated;
    _onLoginSuccess();
    notifyListeners();
  }

  Future<bool> checkUsernameExists(String username) async {
    final clean = username.trim().toLowerCase();
    final reservedDoc =
        await _firestore.collection('usernames').doc(clean).get();
    if (reservedDoc.exists) return true;

    final result = await _firestore
        .collection('users')
        .where('username', isEqualTo: clean)
        .limit(1)
        .get();
    return result.docs.isNotEmpty;
  }

  Future<String?> completeRegistration(
      String name, String username, String userType) async {
    const allowedTypes = ['customer', 'merchant'];
    if (!allowedTypes.contains(userType)) {
      return 'نوع المستخدم غير مسموح به.';
    }

    _status = AuthStatus.authenticating;
    notifyListeners();

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return 'لم يتم العثور على جلسة نشطة.';
    }

    final cleanUsername = username.trim().toLowerCase();

    try {
      if (await checkUsernameExists(cleanUsername)) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return 'اسم المستخدم مستخدم مسبقاً.';
      }

      final newUser = AppUser(
        id: currentUser.uid,
        name: name.trim(),
        username: cleanUsername,
        email: currentUser.email ?? '',
        phone: currentUser.phoneNumber ?? '',
        userType: userType,
      );

      final batch = _firestore.batch();
      batch.set(_firestore.collection('users').doc(newUser.id), {
        ...newUser.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'isSuspended': false,
        'isDeleted': false,
      });
      batch.set(_firestore.collection('usernames').doc(cleanUsername), {
        'uid': newUser.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();

      _user = newUser;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_guest', false);
      await prefs.setString('user_id', newUser.id);
      _status = AuthStatus.authenticated;
      _onLoginSuccess();
      notifyListeners();
      return null;
    } on auth.FirebaseAuthException catch (e) {
      debugPrint('Registration FirebaseAuth error: ${e.code}');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      switch (e.code) {
        case 'permission-denied':
          return 'غير مصرح لك بهذه العملية.';
        case 'unavailable':
          return 'لا يوجد اتصال بالإنترنت. حاول لاحقاً.';
        case 'already-exists':
          return 'هذا الرقم مسجّل بالفعل.';
        default:
          return 'حدث خطأ غير متوقع، حاول مجدداً.';
      }
    } catch (e) {
      debugPrint('Registration error: $e');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return 'حدث خطأ غير متوقع، حاول مجدداً.';
    }
  }

  Future<void> loginAsGuest() async {
    await _ensureAnonymousSession();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest', true);
    _status = AuthStatus.guest;
    _user = null;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      NotificationService().cleanup();
      await NotificationService.unsubscribeFromAllTopics();
      await _unbindMockSession();
      await _auth.signOut();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_guest');
    await prefs.remove('user_id');

    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<String?> restoreDeletedAccount() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return 'لا يوجد مستخدم مسجل.';

    _status = AuthStatus.authenticating;
    notifyListeners();

    try {
      await _firestore.collection('users').doc(currentUser.uid).update({
        'isDeleted': false,
        'isActive': true,
        'scheduledForDeletionAt': FieldValue.delete(),
      });
      await _fetchUserData(currentUser.uid);
      return null;
    } catch (e) {
      debugPrint('restoreDeletedAccount error: $e');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return 'حدث خطأ غير متوقع، حاول مجدداً.';
    }
  }
}
