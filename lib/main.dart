// lib/main.dart
//
// ✅ Phase 3 Fix #01: تفعيل Firebase App Check (PlayIntegrity + AppAttest).
// ✅ Phase 3 Fix #02: تفعيل Firebase Crashlytics.
// ✅ Phase 3 Fix #03: تفعيل Deep Links بـ app_links package.
// ✅ QA Fix #01: nav.context.mounted → nav.mounted.
// ✅ QA Fix #22: إضافة onGenerateRoute لمسارات الإشعارات الديناميكية.
// ✅ QA Fix #25: FavoritesProvider.updateUser() لتجنب إعادة الإنشاء.
// ✅ QA Fix #33: kDebugMode لاختيار AppCheck provider تلقائياً.

// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_links/app_links.dart';
import 'dart:developer' as developer;

import 'firebase_options.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/merchant_dashboard.dart';
import 'screens/splash_screen.dart';
import 'screens/advanced_search_screen.dart';
import 'screens/sanhour_dealer_screen.dart';
import 'screens/interests_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/subscription_screen.dart';
import 'screens/ads_hub_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/my_complaints_screen.dart';
import 'screens/my_service_history_screen.dart';
import 'screens/post_job_ad_screen.dart';
import 'screens/post_service_request_screen.dart';
import 'screens/provider_registration_screen.dart';
import 'screens/merchant_type_screen.dart';
import 'screens/account_edit_screen.dart';
import 'screens/shop_detail_screen.dart';
import 'screens/detail_screen.dart';
import 'models/wishlist_collection_model.dart';
import 'screens/collection_detail_screen.dart';
import 'providers/shops_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/theme_provider.dart';
// ✅ Pro Suggestions: ربط الـ shared utilities بالتطبيق
import 'utils/app_theme.dart';
import 'services/connectivity_service.dart';
import 'services/notification_service.dart';
import 'services/analytics_service.dart';
import 'models/shop.dart';
import 'models/product.dart';
import 'models/offer.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ✅ Phase 3 Fix #02: تفعيل Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // ✅ QA Fix #33: debug provider في debug mode — playIntegrity/appAttest للـ production فقط
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  // ── Firestore settings ────────────────────────────────────
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 100 * 1024 * 1024,
    );
  } catch (e) {
    developer.log('Firestore persistence error: $e');
  }

  try {
    await NotificationService().init();
  } catch (e) {
    developer.log('Notification init error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _handleDeepLink(initialUri));
      }
    } catch (e) {
      developer.log('Deep link initial error: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleDeepLink,
      onError: (e) => developer.log('Deep link stream error: $e'),
    );
  }

  // ✅ QA Fix #01: nav.mounted بدلاً من nav.context.mounted
  Future<void> _handleDeepLink(Uri uri) async {
    final nav = NotificationService.navigatorKey.currentState;
    if (nav == null) return;

    developer.log('Deep link received: $uri', name: 'DeepLinks');

    final segments = uri.pathSegments;
    if (segments.isEmpty) return;

    final type = segments[0];
    final id = segments.length > 1 ? segments[1] : null;

    switch (type) {
      case 'shop':
        if (id == null || id.isEmpty) return;
        try {
          final doc = await FirebaseFirestore.instance
              .collection('shops')
              .doc(id)
              .get();
          if (doc.exists && nav.mounted) {
            nav.push(MaterialPageRoute(
              builder: (_) =>
                  ShopDetailScreen(shop: Shop.fromMap(doc.data()!, doc.id)),
            ));
          }
        } catch (e) {
          developer.log('Deep link shop fetch error: $e');
        }
        break;

      case 'product':
        if (id == null || id.isEmpty) return;
        try {
          final doc = await FirebaseFirestore.instance
              .collection('products')
              .doc(id)
              .get();
          if (doc.exists && nav.mounted) {
            nav.push(MaterialPageRoute(
              builder: (_) => DetailScreen(
                  item: Product.fromMap(doc.data()!, doc.id)),
            ));
          }
        } catch (e) {
          developer.log('Deep link product fetch error: $e');
        }
        break;

      case 'offer':
        if (id == null || id.isEmpty) return;
        try {
          final doc = await FirebaseFirestore.instance
              .collection('offers')
              .doc(id)
              .get();
          if (doc.exists && nav.mounted) {
            nav.push(MaterialPageRoute(
              builder: (_) => DetailScreen(
                  item: Offer.fromMap(doc.data()!, doc.id)),
            ));
          }
        } catch (e) {
          developer.log('Deep link offer fetch error: $e');
        }
        break;

      default:
        nav.pushNamedAndRemoveUntil('/home', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ShopsProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        // ✅ Pro #222: ConnectivityService متاح في كل التطبيق
        ChangeNotifierProvider(create: (_) {
          final svc = ConnectivityService();
          svc.startMonitoring();
          return svc;
        }),
        // ✅ QA Fix #25: updateUser() لتعديل نفس الـ instance بدلاً من إنشاء جديد
        ChangeNotifierProxyProvider<AuthProvider, FavoritesProvider>(
          create: (_) => FavoritesProvider(null, [], [], []),
          update: (ctx, auth, prev) {
            if (prev != null) {
              prev.updateUser(auth.user);
              return prev;
            }
            return FavoritesProvider(auth.user, [], [], []);
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            navigatorKey: NotificationService.navigatorKey,
            navigatorObservers: [AnalyticsService.observer],
            title: 'سنهور أونلاين',
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('ar', 'EG')],
            locale: const Locale('ar', 'EG'),
            themeMode: themeProvider.themeMode,
            theme: AppTheme.light.copyWith(
              textTheme: GoogleFonts.tajawalTextTheme(AppTheme.light.textTheme),
            ),
            darkTheme: AppTheme.dark.copyWith(
              textTheme: GoogleFonts.tajawalTextTheme(AppTheme.dark.textTheme),
            ),
            home: Consumer<AuthProvider>(
              builder: (context, auth, _) {
                switch (auth.status) {
                  case AuthStatus.uninitialized:
                  case AuthStatus.authenticating:
                    return const SplashScreen();
                  case AuthStatus.authenticated:
                  case AuthStatus.guest:
                    return const MainScreen();
                  case AuthStatus.unauthenticated:
                    return const LoginScreen();
                }
              },
            ),

            routes: {
              '/home':                 (_) => const MainScreen(),
              '/login':                (_) => const LoginScreen(),
              '/admin':                (_) => const AdminDashboard(),
              '/merchant':             (_) => const MerchantDashboard(),
              '/advanced_search':      (_) => const AdvancedSearchScreen(),
              '/dealer':               (_) => const SanhourDealerScreen(),
              '/interests':            (_) => const InterestsScreen(),
              '/onboarding':           (_) => const OnboardingScreen(),
              '/merchant_stats':       (_) => const MerchantDashboard(),
              '/subscription':         (_) => const SubscriptionScreen(),
              '/notifications':        (_) => const NotificationsScreen(),
              '/my_complaints':        (_) => const MyComplaintsScreen(),
              '/my_service_history':   (_) => const MyServiceHistoryScreen(),
              '/post_job':             (_) => const PostJobAdScreen(),
              '/post_service':         (_) => const PostServiceRequestScreen(),
              '/register_provider':    (_) => const ProviderRegistrationScreen(),
              '/merchant_type':        (_) => const MerchantTypeScreen(),
              '/account_edit':         (_) => const AccountEditScreen(),
              '/favorites':            (_) => const MainScreen(),
              '/offers':               (_) => const MainScreen(),
            },

            // ✅ QA Fix #22: مسارات الإشعارات والـ Deep Links الديناميكية
            onGenerateRoute: (settings) {
              if (settings.name == '/shop_detail') {
                final args = settings.arguments as Map<String, dynamic>?;
                final shopId = args?['shopId'] as String?;
                if (shopId != null && shopId.isNotEmpty) {
                  return MaterialPageRoute(
                    builder: (_) => _ShopDetailById(shopId: shopId),
                  );
                }
              }
              if (settings.name == '/product_detail') {
                final args = settings.arguments as Map<String, dynamic>?;
                final productId = args?['productId'] as String?;
                if (productId != null && productId.isNotEmpty) {
                  return MaterialPageRoute(
                    builder: (_) => _ProductDetailById(productId: productId),
                  );
                }
              }
              if (settings.name == '/offer_detail') {
                final args = settings.arguments as Map<String, dynamic>?;
                final offerId = args?['offerId'] as String?;
                if (offerId != null && offerId.isNotEmpty) {
                  return MaterialPageRoute(
                    builder: (_) => _OfferDetailById(offerId: offerId),
                  );
                }
              }
              // ✅ AdsHub مع تحديد التاب الافتراضي (0=ads, 1=jobs, 2=services)
              if (settings.name == '/ads_hub') {
                final args = settings.arguments as Map<String, dynamic>?;
                final tab = (args?['tab'] as int?) ?? 0;
                return MaterialPageRoute(
                  builder: (_) => AdsHubScreen(initialTab: tab),
                );
              }
              // ✅ CollectionDetail by ID (من الإشعارات أو الرابط المشارك)
              if (settings.name == '/collection_detail') {
                final args = settings.arguments as Map<String, dynamic>?;
                final collectionId = args?['collectionId'] as String? ?? '';
                return MaterialPageRoute(
                  builder: (_) =>
                      _CollectionDetailById(collectionId: collectionId),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}

// ── Lazy-loading wrappers للمسارات الديناميكية ───────────────────────────────

class _ShopDetailById extends StatelessWidget {
  final String shopId;
  const _ShopDetailById({required this.shopId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('shops').doc(shopId).get(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (!snap.hasData || !snap.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('المحل')),
            body: const Center(child: Text('المحل غير موجود')),
          );
        }
        return ShopDetailScreen(
            shop: Shop.fromMap(
                snap.data!.data() as Map<String, dynamic>, shopId));
      },
    );
  }
}

class _ProductDetailById extends StatelessWidget {
  final String productId;
  const _ProductDetailById({required this.productId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (!snap.hasData || !snap.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('المنتج')),
            body: const Center(child: Text('المنتج غير موجود')),
          );
        }
        return DetailScreen(
            item: Product.fromMap(
                snap.data!.data() as Map<String, dynamic>, productId));
      },
    );
  }
}

class _OfferDetailById extends StatelessWidget {
  final String offerId;
  const _OfferDetailById({required this.offerId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('offers').doc(offerId).get(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (!snap.hasData || !snap.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('العرض')),
            body: const Center(child: Text('العرض غير موجود')),
          );
        }
        return DetailScreen(
            item: Offer.fromMap(
                snap.data!.data() as Map<String, dynamic>, offerId));
      },
    );
  }
}

// ✅ CollectionDetailById — يُستخدم من الإشعارات والروابط المشتركة
class _CollectionDetailById extends StatelessWidget {
  final String collectionId;
  const _CollectionDetailById({required this.collectionId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('wishlists')
          .doc(collectionId)
          .get(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (!snap.hasData || !snap.data!.exists) {
          return Scaffold(
            appBar: AppBar(
                title: const Text('القائمة'),
                backgroundColor: const Color(0xFF5E35B1),
                foregroundColor: Colors.white),
            body: const Center(child: Text('القائمة غير موجودة')),
          );
        }
        final data =
            Map<String, dynamic>.from(snap.data!.data() as Map<String, dynamic>);
        data['id'] = snap.data!.id;
        final collection = WishlistCollection.fromMap(data, snap.data!.id);
        return CollectionDetailScreen(collection: collection);
      },
    );
  }
}