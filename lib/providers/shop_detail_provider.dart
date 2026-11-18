// lib/providers/shop_detail_provider.dart
// ✅ Fix #145: استخراج منطق shop_detail_screen إلى ChangeNotifier مستقل
// يُقلِّل الـ widget من >700 سطر ويُسهِّل الاختبار
import 'package:flutter/foundation.dart';
import '../models/shop.dart';
import '../models/product.dart';
import '../models/offer.dart';
import '../models/review_model.dart';
import '../services/api_service.dart';
import '../services/stats_service.dart';

class ShopDetailProvider with ChangeNotifier {
  final Shop shop;

  ShopDetailProvider(this.shop) {
    _load();
  }

  // ── State ─────────────────────────────────────────────────────────
  bool _isLoading = true;
  String? _errorMsg;
  List<Product> _products = [];
  List<Offer>   _offers   = [];
  List<Review>  _reviews  = [];
  List<Map<String, dynamic>> _services = [];
  int _callClicks      = 0;
  int _whatsappClicks  = 0;

  // ── Getters ───────────────────────────────────────────────────────
  bool get isLoading      => _isLoading;
  String? get errorMsg    => _errorMsg;
  List<Product> get products  => List.unmodifiable(_products);
  List<String> get productLists => _products
      .map((p) => p.listName)
      .whereType<String>()
      .where((l) => l.trim().isNotEmpty)
      .toSet()
      .toList();
  List<Offer>   get offers    => List.unmodifiable(_offers);
  List<Review>  get reviews   => List.unmodifiable(_reviews);
  List<Map<String, dynamic>> get services => List.unmodifiable(_services);
  int get callClicks     => _callClicks;
  int get whatsappClicks => _whatsappClicks;

  // ── Load ──────────────────────────────────────────────────────────
  Future<void> _load() async {
    _isLoading = true;
    _errorMsg  = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        ApiService.getProducts(shopId: shop.id),
        ApiService.getOffers(shopId: shop.id),
        ApiService.getReviews(shop.id),
        ApiService.getServices(shopId: shop.id),
      ]);
      final loadedProducts = List<Product>.from(results[0] as List<Product>);
      loadedProducts.sort((a, b) {
        final cmp = a.sortOrder.compareTo(b.sortOrder);
        if (cmp != 0) return cmp;
        final aDate = a.createdAt;
        final bDate = b.createdAt;
        if (aDate != null && bDate != null) {
          return bDate.compareTo(aDate);
        }
        return 0;
      });
      _products  = loadedProducts;
      _offers    = results[1] as List<Offer>;
      _reviews   = results[2] as List<Review>;
      _services  = results[3] as List<Map<String, dynamic>>;
      _isLoading = false;
    } catch (e) {
      _isLoading = false;
      _errorMsg  = 'تعذّر تحميل بيانات المحل. تحقق من اتصالك.';
      debugPrint('ShopDetailProvider load error: $e');
    }
    notifyListeners();
  }

  Future<void> refresh() => _load();

  // ── Actions ───────────────────────────────────────────────────────
  void logCall() {
    _callClicks++;
    notifyListeners();
    StatsService.logPhoneClick(shop.id);
  }

  void logWhatsApp() {
    _whatsappClicks++;
    notifyListeners();
    StatsService.logWhatsAppClick(shop.id);
  }

  void logView() {
    StatsService.logShopVisit(shop.id);
  }
}
