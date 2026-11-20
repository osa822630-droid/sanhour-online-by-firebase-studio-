// lib/screens/splash_screen.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/shops_provider.dart';
import '../models/ad_model.dart';
import '../models/shop.dart';
import '../models/product.dart';
import '../models/offer.dart';
import '../screens/shop_detail_screen.dart';
import '../screens/detail_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/interests_screen.dart';
import '../screens/main_screen.dart';
import '../screens/login_screen.dart';
import '../widgets/cached_image.dart';
import '../services/api_service.dart';
import '../widgets/force_update_dialog.dart';
import '../widgets/motion/sanhour_motion_kit.dart';

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
      _replaceSelf(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()));
      return;
    }

    // ✅ 1.5 التحقق من التحديث الإجباري
    if (mounted) {
      final mustUpdate = await ForceUpdateChecker.check(context)
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
      if (mustUpdate) {
        return;
      }
    }
    if (!mounted) return;

    // ✅ 2. بعد الأونبوردينج → الاهتمامات (مرة واحدة فقط)
    if (!interestsDone) {
      if (!mounted) return;
      _replaceSelf(
          MaterialPageRoute(builder: (_) => const InterestsScreen()));
      return;
    }

    // ✅ 3. إعلان البداية
    final AdModel? ad = await shopsProvider.getStartupAd();
    if (ad != null && mounted) await _showAdDialog(ad);

    if (!mounted) return;

    // ✅ ننتظر استقرار حالة المصادقة
    await _waitForAuthResolved(auth);
    if (!mounted) return;

    if (auth.status == AuthStatus.uninitialized) {
      _replaceSelfNamed('/login');
      return;
    }

    if (auth.isLoggedIn || auth.isGuest) {
      _replaceSelfNamed('/home');
    } else {
      _replaceSelfNamed('/login');
    }
  }

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
      await resolved.future
          .timeout(const Duration(seconds: 20), onTimeout: () {});
    } finally {
      auth.removeListener(listener);
    }
  }

  void _replaceSelf(Route<dynamic> newRoute) {
    final navigator = Navigator.of(context);
    final self = ModalRoute.of(context);
    if (self == null || self.isCurrent) {
      navigator.pushReplacement(newRoute);
    } else {
      navigator.replace(oldRoute: self, newRoute: newRoute);
    }
  }

  void _replaceSelfNamed(String routeName) {
    if (routeName == '/home') {
      _replaceSelf(MaterialPageRoute(
        settings: const RouteSettings(name: '/home'),
        builder: (_) => const MainScreen(),
      ));
      return;
    }
    if (routeName == '/login') {
      _replaceSelf(MaterialPageRoute(
        settings: const RouteSettings(name: '/login'),
        builder: (_) => const LoginScreen(),
      ));
      return;
    }
    final navigator = Navigator.of(context);
    final route = navigator.widget.onGenerateRoute
        ?.call(RouteSettings(name: routeName));
    if (route == null) {
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
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Expanded(
                  child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: CachedImage(
                    imageUrl: ad.imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover),
              )),
              if (ad.text.isNotEmpty)
                Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 0),
                    child: Text(ad.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black87))),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3D6B5E),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _handleAdClick(ad);
                    },
                    child: Text(ad.actionButtonText,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                ),
              ),
            ]),
          ),
          Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 4)
                      ]),
                  child:
                      const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              )),
        ]),
      ),
    );
  }

  Future<void> _handleAdClick(AdModel ad) async {
    final provider = Provider.of<ShopsProvider>(context, listen: false);
    ApiService.incrementAdClickCount(ad.id);
    try {
      if (ad.targetType == 'shop' ||
          ad.targetType == 'shop_products' ||
          ad.targetType == 'shop_offers') {
        if (ad.targetId == null || ad.targetId!.isEmpty) return;
        Shop? shop;
        try {
          shop = provider.shops.firstWhere((s) => s.id == ad.targetId);
        } catch (_) {
          final doc = await FirebaseFirestore.instance
              .collection('shops')
              .doc(ad.targetId)
              .get();
          if (doc.exists && doc.data() != null) {
            shop = Shop.fromMap(doc.data()!, doc.id);
          }
        }
        if (shop != null && mounted) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => ShopDetailScreen(shop: shop!)));
        }
      } else if (ad.targetType == 'product') {
        if (ad.targetId == null || ad.targetId!.isEmpty) return;
        Product? product;
        try {
          product = provider.products.firstWhere((p) => p.id == ad.targetId);
        } catch (_) {
          final doc = await FirebaseFirestore.instance
              .collection('products')
              .doc(ad.targetId)
              .get();
          if (doc.exists && doc.data() != null) {
            product = Product.fromMap(doc.data()!, doc.id);
          }
        }
        if (product != null && mounted) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => DetailScreen(item: product)));
        }
      } else if (ad.targetType == 'offer') {
        if (ad.targetId == null || ad.targetId!.isEmpty) return;
        Offer? offer;
        try {
          offer = provider.allOffers.firstWhere((o) => o.id == ad.targetId);
        } catch (_) {
          final doc = await FirebaseFirestore.instance
              .collection('offers')
              .doc(ad.targetId)
              .get();
          if (doc.exists && doc.data() != null) {
            offer = Offer.fromMap(doc.data()!, doc.id);
          }
        }
        if (offer != null && mounted) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => DetailScreen(item: offer)));
        }
      } else if (ad.targetType == 'external' || ad.targetType == 'url') {
        final rawUrl = ad.externalUrl?.isNotEmpty == true
            ? ad.externalUrl!
            : (ad.targetId ?? '');
        if (rawUrl.isNotEmpty) {
          final uri = Uri.tryParse(rawUrl);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
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
      backgroundColor: const Color(0xFF1A332C),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/splash_background.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3D6B5E), Color(0xFF1A332C)],
                ),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: Center(
              child: LogoTraceLoader(
                size: 46,
                color: Color(0xFFE0A865),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
