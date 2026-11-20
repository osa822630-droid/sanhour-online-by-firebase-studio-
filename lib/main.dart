// lib/main.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:material_ui/material_ui.dart';
import 'package:intl/date_symbol_data_local.dart';
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
import 'screens/complete_profile_screen.dart';
import 'screens/shop_detail_screen.dart';
import 'screens/detail_screen.dart';
import 'screens/seeder_screen.dart';
import 'models/wishlist_collection_model.dart';
import 'screens/collection_detail_screen.dart';
import 'providers/shops_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/theme_provider.dart';
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
  await initializeDateFormatting('ar');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestProvider(),
    );
  } catch (e) {
    developer.log('AppCheck activate skipped: $e', name: 'AppCheck');
  }

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
        nav.pushNamed('/shop/$id');
        break;

      case 'product':
        if (id == null || id.isEmpty) return;
        nav.pushNamed('/product/$id');
        break;

      case 'offer':
        if (id == null || id.isEmpty) return;
        nav.pushNamed('/offer/$id');
        break;

      case 'service':
        nav.pushNamed('/ads_hub', arguments: {'tab': 2});
        break;

      case 'job':
        nav.pushNamed('/ads_hub', arguments: {'tab': 1});
        break;

      case 'ad':
        nav.pushNamed('/ads_hub', arguments: {'tab': 0});
        break;

      case 'collection':
        if (id != null && id.isNotEmpty) {
          nav.pushNamed('/collection/$id');
        } else {
          nav.pushNamed('/favorites');
        }
        break;

      case 'category':
        nav.pushNamed('/categories');
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
        ChangeNotifierProvider(create: (_) {
          final svc = ConnectivityService();
          svc.startMonitoring();
          return svc;
        }),
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
          final lightBase = AppTheme.light;
          final darkBase = AppTheme.dark;
          return MaterialApp(
            navigatorKey: NotificationService.navigatorKey,
            navigatorObservers: [AnalyticsService.observer],
            title: 'سنهور أونلاين',
            debugShowCheckedModeBanner: false,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) =>
                // ignore: deprecated_member_use
                MaterialUiCompatibilityBridge(child: child!),
            supportedLocales: const [Locale('ar', 'EG')],
            locale: const Locale('ar', 'EG'),
            themeMode: themeProvider.themeMode,
            theme: lightBase,
            darkTheme: darkBase,
            home: const SplashScreen(),
            routes: {
              '/home':               (_) => const MainScreen(),
              '/login':              (_) => const LoginScreen(),
              '/admin':              (_) => const AdminDashboard(),
              '/merchant':           (_) => const MerchantDashboard(),
              '/advanced_search':    (_) => const AdvancedSearchScreen(),
              '/dealer':             (_) => const MainScreen(initialIndex: MainScreen.dealerTab),
              '/interests':          (_) => const InterestsScreen(),
              '/onboarding':         (_) => const OnboardingScreen(),
              '/merchant_stats':     (_) => const MerchantDashboard(),
              '/subscription':       (_) => const SubscriptionScreen(),
              '/all_ads':            (_) => const MainScreen(initialIndex: MainScreen.adsHubTab),
              '/ads_hub':            (_) => const MainScreen(initialIndex: MainScreen.adsHubTab),
              '/notifications':      (_) => const NotificationsScreen(),
              '/my_complaints':      (_) => const MyComplaintsScreen(),
              '/user_complaints':    (_) => const MyComplaintsScreen(),
              '/my_service_history': (_) => const MyServiceHistoryScreen(),
              '/post_job':           (_) => const PostJobAdScreen(),
              '/post_service':       (_) => const PostServiceRequestScreen(),
              '/register_provider':  (_) => const ProviderRegistrationScreen(),
              '/merchant_type':      (_) => const MerchantTypeScreen(),
              '/account_edit':       (_) => const AccountEditScreen(),
              '/complete_profile':   (_) => const CompleteProfileScreen(),
              '/categories':         (_) => const MainScreen(initialIndex: MainScreen.categoriesTab),
              '/seeder':             (_) => const SeederScreen(),
              '/favorites':          (_) => const MainScreen(initialIndex: MainScreen.favoritesTab),
              '/offers':             (_) => const MainScreen(initialIndex: MainScreen.offersTab),
              '/job_ads':            (_) => const AdsHubScreen(initialTab: 1),
              '/service_requests':   (_) => const AdsHubScreen(initialTab: 2),
            },
            onGenerateRoute: _onGenerateRoute,
          );
        },
      ),
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final rawName = settings.name ?? '';
    final args = settings.arguments is Map<String, dynamic>
        ? settings.arguments as Map<String, dynamic>
        : null;

    // 1. دعم المسارات النصية المدمجة بالمعرّف (/shop/:id, /product/:id, /offer/:id, /collection/:id)
    if (rawName.startsWith('/shop/')) {
      final shopId = rawName.substring('/shop/'.length).trim();
      if (shopId.isNotEmpty) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => _ShopDetailById(shopId: shopId),
        );
      }
    }
    if (rawName.startsWith('/product/')) {
      final productId = rawName.substring('/product/'.length).trim();
      if (productId.isNotEmpty) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => _ProductDetailById(productId: productId),
        );
      }
    }
    if (rawName.startsWith('/offer/')) {
      final offerId = rawName.substring('/offer/'.length).trim();
      if (offerId.isNotEmpty) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => _OfferDetailById(offerId: offerId),
        );
      }
    }
    if (rawName.startsWith('/collection/')) {
      final colId = rawName.substring('/collection/'.length).trim();
      if (colId.isNotEmpty) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => _CollectionDetailById(collectionId: colId),
        );
      }
    }
    if (rawName.startsWith('/service_request/') ||
        rawName.startsWith('service_request:')) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const MyServiceHistoryScreen(),
      );
    }

    // 2. دعم المسارات المعتمدة على arguments Map
    if (rawName == '/shop_detail' || rawName == 'shop_details' || rawName == 'shop') {
      final shopObj = args?['shop'];
      if (shopObj is Shop) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ShopDetailScreen(shop: shopObj),
        );
      }
      final shopId = (args?['shopId'] ?? args?['targetId'])?.toString();
      if (shopId != null && shopId.isNotEmpty) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => _ShopDetailById(shopId: shopId),
        );
      }
    }

    if (rawName == '/product_detail' || rawName == 'product_details' || rawName == 'product') {
      final productObj = args?['product'];
      if (productObj is Product) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => DetailScreen(item: productObj),
        );
      }
      final productId = (args?['productId'] ?? args?['targetId'])?.toString();
      if (productId != null && productId.isNotEmpty) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => _ProductDetailById(productId: productId),
        );
      }
    }

    if (rawName == '/offer_detail' || rawName == 'offer_details' || rawName == 'offer') {
      final offerObj = args?['offer'];
      if (offerObj is Offer) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => DetailScreen(item: offerObj),
        );
      }
      final offerId = (args?['offerId'] ?? args?['targetId'])?.toString();
      if (offerId != null && offerId.isNotEmpty) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => _OfferDetailById(offerId: offerId),
        );
      }
    }

    if (rawName == '/ads_hub' || rawName == 'ads_hub') {
      final tab = (args?['tab'] as num?)?.toInt() ?? 0;
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => AdsHubScreen(initialTab: tab),
      );
    }

    if (rawName == 'job_ads') {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const AdsHubScreen(initialTab: 1),
      );
    }

    if (rawName == 'service_requests') {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const AdsHubScreen(initialTab: 2),
      );
    }

    if (rawName == 'merchant') {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const MerchantDashboard(),
      );
    }

    if (rawName == 'user_complaints') {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const MyComplaintsScreen(),
      );
    }

    if (rawName == '/collection_detail' || rawName == 'collection_detail') {
      final colObj = args?['collection'];
      if (colObj is WishlistCollection) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => CollectionDetailScreen(collection: colObj),
        );
      }
      final collectionId =
          (args?['collectionId'] ?? args?['targetId'])?.toString() ?? '';
      if (collectionId.isNotEmpty) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => _CollectionDetailById(collectionId: collectionId),
        );
      }
    }

    return null;
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
            body: const Center(child: Text('عذراً، هذا المحل لم يعد متاحاً حالياً')),
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
            body: const Center(child: Text('عذراً، هذا المنتج لم يعد متاحاً حالياً')),
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
            body: const Center(child: Text('عذراً، هذا العرض انتهى أو لم يعد متاحاً')),
          );
        }
        return DetailScreen(
            item: Offer.fromMap(
                snap.data!.data() as Map<String, dynamic>, offerId));
      },
    );
  }
}

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
            body: const Center(child: Text('عذراً، هذه القائمة غير موجودة أو حُذفت')),
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