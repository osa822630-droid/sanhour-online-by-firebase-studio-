// lib/screens/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/shops_provider.dart';
import '../models/ad_model.dart';
import '../screens/shop_detail_screen.dart';
import '../screens/detail_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/interests_screen.dart';
import '../widgets/cached_image.dart';
import '../services/api_service.dart';
import '../widgets/force_update_dialog.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startStartupSequence();
  }

  Future<void> _startStartupSequence() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final shopsProvider = Provider.of<ShopsProvider>(context, listen: false);

    // ✅ Fix #91: تشغيل تأخير الـ splash وقراءة الـ prefs بشكل متوازٍ
    final results = await Future.wait([
      Future.delayed(const Duration(seconds: 2)),
      SharedPreferences.getInstance(),
    ]);

    if (!mounted) return;

    final prefs = results[1] as SharedPreferences;
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;
    final interestsDone = prefs.getBool('interests_done') ?? false;

    // ✅ 1. أول تشغيل → الأونبوردينج
    if (!onboardingDone) {
      if (!mounted) return;
      _replaceSelf(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
      return;
    }

    // ✅ 1.5 التحقق من التحديث الإجباري
    // ✅ Item #2: الـ Splash بقت صاحبة التنقل الوحيدة، فمهلة 5 ثواني عشان اتصال
    // بطيء ميعلّقش التطبيق. لو المهلة خلصت بنكمل عادي، والـ Dialog مش هيظهر لو
    // الـ Splash اتشالت (ForceUpdateChecker بيفحص context.mounted قبل العرض).
    if (mounted) {
      await ForceUpdateChecker.check(context)
          .timeout(const Duration(seconds: 5), onTimeout: () {});
    }
    if (!mounted) return;

    // ✅ 2. بعد الأونبوردينج → الاهتمامات (مرة واحدة فقط)
    if (!interestsDone) {
      if (!mounted) return;
      _replaceSelf(MaterialPageRoute(builder: (_) => const InterestsScreen()));
      return;
    }

    // ✅ 3. إعلان البداية
    final AdModel? ad = await shopsProvider.getStartupAd();
    if (ad != null && mounted) await _showAdDialog(ad);

    if (!mounted) return;

    // ✅ Item #2: ننتظر استقرار حالة المصادقة بدل ما نقراها لحظة وصول التسلسل لهنا.
    // (على الشبكات البطيئة كانت لسه "authenticating" فالمستخدم المسجّل كان بيتبعت
    // للـ login بالغلط.)
    await _waitForAuthResolved(auth);
    if (!mounted) return;

    // ✅ Fix #93: التعامل مع حالة الخطأ (timeout/uninitialized) بشكل واضح
    if (auth.status == AuthStatus.uninitialized) {
      // انتهت المهلة قبل تحديد حالة المصادقة — إرسال للـ login
      _replaceSelfNamed('/login');
      return;
    }

    if (auth.isLoggedIn || auth.isGuest) {
      _replaceSelfNamed('/home');
    } else {
      _replaceSelfNamed('/login');
    }
  }

  /// ✅ Item #2: بينتظر لحد ما حالة المصادقة تستقر (مش uninitialized ولا authenticating).
  ///
  /// قبل كده كان الـ Consumer في main.dart هو اللي بيبدّل الشاشة أول ما الحالة
  /// تتغير وبيقطع تسلسل الـ Splash. دلوقتي الـ Splash هي صاحبة قرار التنقل
  /// الوحيدة، فلازم تستنى الحالة بنفسها. AuthProvider عنده timeout 10 ثواني على
  /// جلب المستخدم، فالمهلة هنا (20 ثانية) حماية إضافية بس.
  Future<void> _waitForAuthResolved(AuthProvider auth) async {
    bool isPending() =>
        auth.status == AuthStatus.uninitialized ||
        auth.status == AuthStatus.authenticating;

    if (!isPending()) return;

    final resolved = Completer<void>();
    void listener() {
      if (!isPending() && !resolved.isCompleted) resolved.complete();
    }

    auth.addListener(listener);
    try {
      await resolved.future.timeout(const Duration(seconds: 20), onTimeout: () {});
    } finally {
      auth.removeListener(listener);
    }
  }

  /// ✅ Item #2: بيستبدل شاشة الـ Splash نفسها بـ [newRoute].
  ///
  /// ⚠️ Navigator.pushReplacement بتستبدل "أعلى route" في الـ Navigator مش الـ Splash
  /// بالضرورة. لو اتفتح فوق الـ Splash أي حاجة (Dialog التحديث الإجباري، شاشة من
  /// إعلان البداية، deep link أو إشعار) كانت pushReplacement هتشيلها هي وتسيب
  /// الـ Splash. عشان كده: لو الـ Splash هي الـ route الحالية بنستخدم
  /// pushReplacement (مع الأنيميشن)، ولو لأ بنستبدلها من تحت بـ Navigator.replace
  /// وبنسيب اللي فوقها زي ما هو.
  void _replaceSelf(Route<dynamic> newRoute) {
    final navigator = Navigator.of(context);
    final self = ModalRoute.of(context);
    if (self == null || self.isCurrent) {
      navigator.pushReplacement(newRoute);
    } else {
      navigator.replace(oldRoute: self, newRoute: newRoute);
    }
  }

  /// نفس [_replaceSelf] لمسار مسمّى (/home أو /login). الـ Route بيتبني من جدول
  /// الـ routes في main.dart نفسه (onGenerateRoute) عشان مفيش تكرار للجدول هنا.
  void _replaceSelfNamed(String routeName) {
    final navigator = Navigator.of(context);
    final route = navigator.widget.onGenerateRoute
        ?.call(RouteSettings(name: routeName));
    if (route == null) {
      // احتياط: لو الـ Navigator مالوش onGenerateRoute نرجع للسلوك القديم.
      navigator.pushReplacementNamed(routeName);
      return;
    }
    _replaceSelf(route);
  }

  Future<void> _showAdDialog(AdModel ad) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(alignment: Alignment.center, children: [
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 520),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Expanded(child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: CachedImage(imageUrl: ad.imageUrl, width: double.infinity, fit: BoxFit.cover),
              )),
              if (ad.text.isNotEmpty)
                Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Text(ad.text, textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: Colors.black87))),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () { Navigator.pop(context); _handleAdClick(ad); },
                    child: Text(ad.actionButtonText,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ),
            ]),
          ),
          Positioned(top: 0, right: 0,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                child: const Icon(Icons.close, color: Colors.white, size: 22),
              ),
            )),
        ]),
      ),
    );
  }

  void _handleAdClick(AdModel ad) {
    final provider = Provider.of<ShopsProvider>(context, listen: false);
    ApiService.incrementAdClickCount(ad.id);
    try {
      if (ad.targetType == 'shop') {
        final shop = provider.shops.firstWhere((s) => s.id == ad.targetId);
        Navigator.push(context, MaterialPageRoute(builder: (_) => ShopDetailScreen(shop: shop)));
      } else if (ad.targetType == 'product') {
        final product = provider.products.firstWhere((p) => p.id == ad.targetId);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(item: product)));
      } else if (ad.targetType == 'url' && ad.targetId != null) {
        launchUrl(Uri.parse(ad.targetId!), mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('العرض غير متاح حالياً')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF4527A0), Color(0xFF7B1FA2)]),
        ),
        child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: const Icon(Icons.storefront, size: 70, color: Colors.white),
          ),
          const SizedBox(height: 24),
          const Text('سنهور أونلاين',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          const Text('سنهور كلها في جيبك',
              style: TextStyle(fontSize: 14, color: Colors.white70, letterSpacing: 2)),
          const SizedBox(height: 40),
          const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white), strokeWidth: 2),
        ])),
      ),
    );
  }
}
