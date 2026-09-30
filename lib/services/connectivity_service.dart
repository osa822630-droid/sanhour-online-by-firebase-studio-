// lib/services/connectivity_service.dart
// ✅ Pro #222: خدمة مركزية للتحقق من الاتصال
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConnectivityService with ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  bool _isOnline = true;
  Timer? _checkTimer;

  bool get isOnline => _isOnline;

  void startMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
    _check();
  }

  void stopMonitoring() {
    _checkTimer?.cancel();
  }

  Future<void> _check() async {
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('general')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 5));
      if (!_isOnline) {
        _isOnline = true;
        notifyListeners();
      }
    } catch (_) {
      if (_isOnline) {
        _isOnline = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }
}
