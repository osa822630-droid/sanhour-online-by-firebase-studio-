// lib/screens/splash_screen.dart
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
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()));
      return;
    }

    // ✅ 1.5 التحقق من التحديث الإجباري
    if (mounted) await ForceUpdateChecker.check(context);
    if (!mounted) return;

    // ✅ 2. بعد الأونبوردينج → الاهتمامات (مرة واحدة فقط)
    if (!interestsDone) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const InterestsScreen()));
      return;
    }

    // ✅ 3. إعلان البداية
    final AdModel? ad = await shopsProvider.getStartupAd();
    if (ad != null && mounted) await _showAdDialog(ad);

    if (!mounted) return;

    // ✅ Fix #93: التعامل مع حالة الخطأ (timeout/uninitialized) بشكل واضح
    if (auth.status == AuthStatus.uninitialized) {
      // انتهت المهلة قبل تحديد حالة المصادقة — إرسال للـ login
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    if (auth.isLoggedIn || auth.isGuest) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ✅ خلفية احتياطية بنفس مزاج ألوان صورة شاشة البداية — تظهر فقط
          // خلف تصميم الـ fallback في حال تعذّر تحميل الصورة، أو في أي هامش
          // نادر ناتج عن اختلاف نسبة الشاشة عن نسبة الصورة
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xFF0D0614), Color(0xFF2A0845)]),
            ),
          ),

          // ✅ صورة شاشة البداية — asset محلي مُضمَّن بالكامل داخل التطبيق
          // (assets/images/splash_background.png) — لا تعتمد على الإنترنت
          // إطلاقاً، تعمل من أول لحظة تشغيل حتى بدون اتصال.
          Image.asset(
            'assets/images/splash_background.png',
            fit: BoxFit.cover,
            // ✅ Fallback: تصميم بسيط (أيقونة + اسم التطبيق) لو الصورة غير
            // موجودة — يحدث هذا فقط إذا نُسي تسجيل مسارها في pubspec.yaml
            errorBuilder: (context, error, stackTrace) =>
                Center(child: _buildFallbackLogo()),
          ),

          // ✅ مؤشر تحميل بسيط في الهامش المظلم أسفل الصورة (تحت الموبايل)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// تصميم fallback بسيط (أيقونة + اسم التطبيق) — يظهر فقط إذا تعذّر تحميل
  /// صورة شاشة البداية من الـ assets (غالباً بسبب نسيان تسجيل المسار في
  /// pubspec.yaml أو حذف الملف بالخطأ من مجلد assets/images/).
  Widget _buildFallbackLogo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: const Icon(Icons.storefront, size: 70, color: Colors.white),
        ),
        const SizedBox(height: 24),
        const Text('سنهور أونلاين',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        const Text('سنهور كلها في جيبك',
            style: TextStyle(fontSize: 14, color: Colors.white70, letterSpacing: 2)),
      ],
    );
  }
}
