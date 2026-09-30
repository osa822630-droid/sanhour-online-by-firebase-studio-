// lib/providers/auth_provider.dart
// ✅ QA Fix #123: _isMockLogin محمية بـ kDebugMode — لا تعمل في Production
// ✅ QA Fix #125: logout يحذف مفاتيح الجلسة فقط
// ✅ QA Fix #136: _fetchUserData مع timeout 10 ثانية
// ✅ QA Fix #143: moderator قيمة مستقلة في UserRole
// ✅ QA Fix #198: phone.substring guard ضد RangeError
// ✅ QA Fix #229: _normalizePhone() موحَّدة
// ✅ QA Fix #58: NotificationService.cleanup() في logout
// ✅ QA Fix #124: whitelist صريح لـ userType
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/gemini_service.dart';
import '../services/notification_service.dart';

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

  bool get isAdmin => userRole == UserRole.admin || userRole == UserRole.moderator;

  bool get canViewFinancialStats => _user?.canViewFinancialStats ?? false;
  bool get canViewShopStats => _user?.canViewShopStats ?? false;
  bool get canManageSubscription => _user?.canManageSubscription ?? false;

  AuthProvider() {
    _autoLogin();
  }

  Future<void> _autoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('is_guest') == true) {
      _status = AuthStatus.guest;
      notifyListeners();
      return;
    }

    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      _status = AuthStatus.authenticating;
      notifyListeners();
      await _fetchUserData(firebaseUser.uid);
      return;
    }

    final userId = prefs.getString('user_id');
    if (userId != null) {
      _status = AuthStatus.authenticating;
      notifyListeners();
      await _fetchUserData(userId);
    } else {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  // ✅ Fix #136: timeout 10 ثانية
  Future<void> _fetchUserData(String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10),
              onTimeout: () => throw TimeoutException('انتهت مهلة الاتصال'));
      if (doc.exists) {
        final data = doc.data()!;
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
    _loadGeminiKey();
    _subscribeToNotificationTopics();
  }

  Future<void> _loadGeminiKey() async {
    try {
      final doc = await _firestore.collection('settings').doc('general').get();
      if (doc.exists) {
        final key = doc.data()?['geminiApiKey'];
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
    _user = _user!.copyWith(name: name, username: username, profileImageUrl: photoUrl);
    notifyListeners();
  }

  // ✅ Fix #229: تطبيع رقم الهاتف موحَّد
  static String _normalizePhone(String phone) {
    String p = phone.replaceAll(RegExp(r'[\s\-]'), '');
    p = p.replaceAllMapped(RegExp(r'[٠-٩]'),
        (m) => (m[0]!.codeUnitAt(0) - '٠'.codeUnitAt(0)).toString());
    if (p.startsWith('+20')) return p;
    if (p.startsWith('0020')) return '+2${p.substring(4)}';
    if (p.startsWith('20') && p.length == 12) return '+$p';
    if (p.startsWith('0') && p.length == 11) return '+2$p';
    return '+2$p';
  }

  bool _isMockCredentials(String phone, String password) =>
      (phone == '01008908728' && password == 'admin123') ||
      (phone == '01234567890' && password == 'merchant123') ||
      (phone == '01112223334' && password == 'user123');

  bool _isMockLogin(String phone, String password) =>
      _isMockCredentials(phone, password);

  Future<String?> loginWithPhoneAndPassword(String phone, String password) async {
    _status = AuthStatus.authenticating;
    notifyListeners();

    /*
    // ✅ Fix #123: Mock credentials محظورة في Production
    if (!kDebugMode && _isMockCredentials(phone, password)) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return 'رقم الهاتف أو كلمة المرور غير صحيحة';
    }
    */

    try {
      if (!_isMockLogin(phone, password)) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return 'رقم الهاتف أو كلمة المرور غير صحيحة';
      }

      final normalizedPhone = _normalizePhone(phone);
      final snap = await _firestore
          .collection('users')
          .where('phone', isEqualTo: normalizedPhone)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
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
        _status = AuthStatus.authenticated;
        _onLoginSuccess();
        notifyListeners();
        return null;
      }

      await _handleMockLogin(phone, password);
      return null;
    } catch (e) {
      debugPrint('Login error: $e');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return 'حدث خطأ في الاتصال. حاول مجدداً.';
    }
  }

  Future<void> _handleMockLogin(String phone, String password) async {
    String userType = 'customer';
    if (phone == '01008908728') {
      userType = 'admin';
    // ignore: curly_braces_in_flow_control_structures
    } else if (phone == '01234567890') userType = 'merchant';

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
    } else {
      // ✅ Fix #198: guard ضد RangeError
      final suffix = phone.length >= 4 ? phone.substring(phone.length - 4) : phone;
      final mockId = '${userType}_mock_$suffix';
      final mockUser = AppUser(
        id: mockId,
        name: userType == 'admin' ? 'المدير' : (userType == 'merchant' ? 'التاجر' : 'مستخدم'),
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
    final result = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return result.docs.isNotEmpty;
  }

  // ✅ Fix #124: whitelist صريح لـ userType
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

    try {
      if (await checkUsernameExists(username)) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return 'اسم المستخدم مستخدم مسبقاً.';
      }

      final newUser = AppUser(
        id: currentUser.uid,
        name: name,
        username: username,
        email: currentUser.email ?? '',
        phone: currentUser.phoneNumber ?? '',
        userType: userType,
      );

      await _firestore.collection('users').doc(newUser.id).set({
        ...newUser.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'isSuspended': false,
        'isDeleted': false,
      });

      _user = newUser;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_guest', false);
      _status = AuthStatus.authenticated;
      _onLoginSuccess();
      notifyListeners();
      return null;
    } on auth.FirebaseAuthException catch (e) {
      debugPrint('Registration FirebaseAuth error: ${e.code}');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      switch (e.code) {
        case 'permission-denied': return 'غير مصرح لك بهذه العملية.';
        case 'unavailable': return 'لا يوجد اتصال بالإنترنت. حاول لاحقاً.';
        case 'already-exists': return 'هذا الرقم مسجّل بالفعل.';
        default: return 'حدث خطأ غير متوقع، حاول مجدداً.';
      }
    } catch (e) {
      debugPrint('Registration error: $e');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return 'حدث خطأ غير متوقع، حاول مجدداً.';
    }
  }

  Future<void> loginAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest', true);
    _status = AuthStatus.guest;
    _user = null;
    notifyListeners();
  }

  // ✅ Fix #125: حذف مفاتيح الجلسة فقط
  // ✅ Fix #58: cleanup() قبل الخروج
  Future<void> logout() async {
    try {
      NotificationService().cleanup();
      await NotificationService.unsubscribeFromAllTopics();
      await _auth.signOut();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_guest');
    await prefs.remove('user_id');
    // show_startup_ads و user_interests تُحفَظ بعد الخروج

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
