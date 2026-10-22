// lib/screens/advanced_search_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/shops_provider.dart';
import '../models/shop.dart';
import '../models/product.dart';
import '../models/offer.dart';
import '../services/analytics_service.dart';
import '../widgets/cached_image.dart';
import 'detail_screen.dart';
import 'shop_detail_screen.dart';

class AdvancedSearchScreen extends StatefulWidget {
  // ✅ Phase 2 Missing Fix #3: معامل اختياري للانتقال المباشر لتبويب الفئات
  final bool initialShowCategories;
  const AdvancedSearchScreen({
    super.key,
    this.initialShowCategories = false,
  });
  @override
  State<AdvancedSearchScreen> createState() => _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends State<AdvancedSearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

  // ✅ Q7-1b: نتائج Firestore keyword search
  List<Product> _firestoreProducts = [];
  List<Shop> _firestoreShops = [];
  bool _isSearching = false;
  Timer? _debounce;
  final FocusNode _focusNode = FocusNode();

  String _selectedCategory = 'كل الفئات';
  String _selectedSort = 'الأكثر صلة';
  RangeValues _priceRange = const RangeValues(0, 5000);
  double _minRating = 0;
  String _selectedRegion = 'الكل';

  final List<String> _sortOptions = [
    'الأكثر صلة',
    'الأحدث',
    'الأكثر زيارة',
    'الأعلى تقييماً',
    'الأقل سعراً',
    'الأعلى سعراً',
  ];

  // ✅ Fix #89: المناطق تُحمَّل من Firestore بدلاً من hardcoding
  List<String> _regions = ['الكل', 'سنهور القبلية', 'سنهور البحرية', 'المنطقة الصناعية'];

  Future<void> _loadRegions() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('locations')
          .get();
      if (doc.exists) {
        final areas = doc.data()?['areas'];
        if (areas is List && areas.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _regions = ['الكل', ...areas.cast<String>()];
          });
        }
      }
    } catch (_) {} // نحتفظ بالقيم الافتراضية عند الفشل
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // ✅ Fix #89: تحميل المناطق من Firestore
    _loadRegions();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      // ✅ QA Fix #04: الانتقال لتبويب الفئات بتأخير بسيط لضمان اكتمال الـ render
      if (widget.initialShowCategories) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted && _tabController.length > 2) {
            _tabController.animateTo(2);
          }
        });
      }
      final provider = context.read<ShopsProvider>();
      if (provider.products.isEmpty) provider.fetchProducts();
      if (provider.allOffers.isEmpty) provider.fetchOffers();
    });
    AnalyticsService().logScreenView('advanced_search');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ✅ فئات من Provider
  List<String> _getCategories(BuildContext context) {
    final provider = context.read<ShopsProvider>();
    return ['كل الفئات', ...provider.categories.map((c) => c.name)];
  }

  List<Shop> _filterShops(ShopsProvider p) {
    // ✅ Q7-1b: دمج نتائج Firestore مع الفلترة المحلية
    final q = _searchCtrl.text.trim().toLowerCase();
    final baseList = (q.length >= 2 && _firestoreShops.isNotEmpty)
        ? _firestoreShops
        : p.shops;

    var list = baseList.where((s) {
      final matchQ = q.isEmpty ||
          s.name.toLowerCase().contains(q) ||
          s.description.toLowerCase().contains(q) ||
          s.category.toLowerCase().contains(q);
      final matchCat = _selectedCategory == 'كل الفئات' || s.category == _selectedCategory;
      final matchRating = s.rating >= _minRating;
      final matchRegion = _selectedRegion == 'الكل' ||
          s.location.contains(_selectedRegion);
      return matchQ && matchCat && matchRating && matchRegion;
    }).toList();

    switch (_selectedSort) {
      case 'الأحدث':
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'الأكثر زيارة':
        list.sort((a, b) => b.views.compareTo(a.views));
        break;
      case 'الأعلى تقييماً':
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      default:
        break;
    }
    return list;
  }

  List<Product> _filterProducts(ShopsProvider p) {
    // ✅ Q7-1b: دمج نتائج Firestore مع الفلترة المحلية
    // إذا كان هناك بحث نصي نستخدم Firestore، وإلا نستخدم الكاش المحلي
    final q = _searchCtrl.text.trim().toLowerCase();
    final baseList = (q.length >= 2 && _firestoreProducts.isNotEmpty)
        ? _firestoreProducts
        : p.products;

    var list = baseList.where((prod) {
      final matchQ = q.isEmpty ||
          prod.name.toLowerCase().contains(q) ||
          prod.description.toLowerCase().contains(q) ||
          (prod.searchKeywords?.any((k) => k.contains(q)) ?? false);
      final matchCat = _selectedCategory == 'كل الفئات' || prod.category == _selectedCategory;
      final matchPrice = prod.price >= _priceRange.start && prod.price <= _priceRange.end;
      final matchRating = prod.rating >= _minRating;
      return matchQ && matchCat && matchPrice && matchRating;
    }).toList();

    switch (_selectedSort) {
      // ✅ QA Fix #30: ترتيب حقيقي بـ createdAt بدلاً من reversed
      case 'الأحدث':
        list.sort((a, b) {
          final ca = a.createdAt;
          final cb = b.createdAt;
          if (ca == null && cb == null) return 0;
          if (ca == null) return 1;
          if (cb == null) return -1;
          return cb.compareTo(ca);
        });
        break;
      case 'الأكثر زيارة':
        list.sort((a, b) => b.views.compareTo(a.views));
        break;
      case 'الأعلى تقييماً':
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'الأقل سعراً':
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'الأعلى سعراً':
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      default:
        break;
    }
    return list;
  }

  List<Offer> _filterOffers(ShopsProvider p) {
    var list = p.allOffers.where((o) {
      final q = _searchCtrl.text.trim().toLowerCase();
      return q.isEmpty ||
          o.title.toLowerCase().contains(q) ||
          o.description.toLowerCase().contains(q);
    }).toList();

    switch (_selectedSort) {
      case 'الأكثر زيارة':
        list.sort((a, b) => b.views.compareTo(a.views));
        break;
      case 'الأعلى تقييماً':
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      default:
        break;
    }
    return list;
  }

  void _onSearch(String q) {
    setState(() {});
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        _firestoreProducts = [];
        _firestoreShops = [];
        _isSearching = false;
      });
      return;
    }
    // ✅ Q7-1b: Debounce 400ms ثم بحث في Firestore بـ searchKeywords
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      AnalyticsService().logSearch(q.trim());
      context.read<ShopsProvider>().search(q.trim());
      await _searchFirestore(q.trim().toLowerCase());
    });
  }

  /// ✅ Fix #87: بحث Firestore — منتجات + محلات + عروض بـ searchKeywords
  /// ✅ Fix #88: guard mounted قبل كل setState
  Future<void> _searchFirestore(String keyword) async {
    try {
      final fs = FirebaseFirestore.instance;
      final futures = await Future.wait([
        fs
            .collection('products')
            .where('isVisible', isEqualTo: true)
            .where('searchKeywords', arrayContains: keyword)
            .limit(30)
            .get(),
        fs
            .collection('shops')
            .where('isSuspended', isEqualTo: false)
            .where('searchKeywords', arrayContains: keyword)
            .limit(20)
            .get(),
        // ✅ Fix #87: إضافة بحث في العروض
        fs
            .collection('offers')
            .where('isActive', isEqualTo: true)
            .where('isShopHidden', isEqualTo: false)
            .where('searchKeywords', arrayContains: keyword)
            .limit(20)
            .get(),
      ]);

      if (!mounted) return;
      setState(() {
        _firestoreProducts = futures[0].docs
            .map((d) => Product.fromMap(d.data(), d.id))
            .toList();
        _firestoreShops = futures[1].docs
            .map((d) => Shop.fromMap(d.data(), d.id))
            .toList();
        // العروض تُعرض ضمن صف المنتجات (أو يمكن إضافة tab لها لاحقاً)
        _isSearching = false;
      });
    } catch (e) {
      // ✅ Fix #88
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShopsProvider>();
    final categories = _getCategories(context);
    final shops = _filterShops(provider);
    final products = _filterProducts(provider);
    final offers = _filterOffers(provider);
    final isLoading = provider.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchCtrl,
          focusNode: _focusNode,
          onChanged: _onSearch,
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          decoration: InputDecoration(
            hintText: 'ابحث عن محل، منتج، أو خدمة...',
            hintStyle: TextStyle(color: Colors.white.withAlpha(178)),
            border: InputBorder.none,
            filled: false,
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {});
                    })
                : null,
          ),
        ),
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: isLoading ? 'محلات ...' : 'محلات (${shops.length})'),
            Tab(text: isLoading ? 'منتجات ...' : 'منتجات (${products.length})'),
            Tab(text: isLoading ? 'عروض ...' : 'عروض (${offers.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_isSearching) const LinearProgressIndicator(minHeight: 2),
          // ─── شريط الفلاتر ─────────────────────────────────────────────
          _buildFiltersBar(categories),
          // ─── النتائج ──────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildShopsList(shops),
                _buildProductsGrid(products),
                _buildOffersList(offers),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersBar(List<String> categories) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // الفئة
            _filterChip(
              label: _selectedCategory,
              icon: Icons.category_outlined,
              onTap: () => _showCategoryPicker(categories),
            ),
            const SizedBox(width: 6),
            // الترتيب
            _filterChip(
              label: _selectedSort,
              icon: Icons.sort_rounded,
              onTap: () => _showSortPicker(),
            ),
            const SizedBox(width: 6),
            // المنطقة
            _filterChip(
              label: _selectedRegion,
              icon: Icons.location_on_outlined,
              onTap: () => _showRegionPicker(),
            ),
            const SizedBox(width: 6),
            // التقييم
            if (_minRating > 0)
              _filterChip(
                label: '${_minRating.toStringAsFixed(0)}+ ⭐',
                icon: Icons.star_outline,
                onTap: () => setState(() => _minRating = 0),
                isActive: true,
              )
            else
              _filterChip(
                label: 'التقييم',
                icon: Icons.star_outline,
                onTap: () => _showRatingPicker(),
              ),
            const SizedBox(width: 6),
            // السعر
            _filterChip(
              label: 'السعر',
              icon: Icons.attach_money_rounded,
              onTap: () => _showPriceRangePicker(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(
      {required String label,
      required IconData icon,
      required VoidCallback onTap,
      bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF5E35B1)
              : const Color(0xFF5E35B1).withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF5E35B1).withAlpha(77)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 14,
              color: isActive ? Colors.white : const Color(0xFF5E35B1)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : const Color(0xFF5E35B1))),
          const SizedBox(width: 2),
          Icon(Icons.arrow_drop_down,
              size: 16,
              color: isActive ? Colors.white : const Color(0xFF5E35B1)),
        ]),
      ),
    );
  }

  // ─── القوائم ──────────────────────────────────────────────────────────────

  Widget _buildShopsList(List<Shop> shops) {
    if (shops.isEmpty) return _buildEmpty('لا توجد محلات مطابقة');
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: shops.length,
      itemBuilder: (_, i) {
        final shop = shops[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            onTap: () {
              if (mounted) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ShopDetailScreen(shop: shop)));
              }
            },
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                  width: 52,
                  height: 52,
                  child:
                      CachedImage(imageUrl: shop.imageUrl, fit: BoxFit.cover)),
            ),
            title: Text(shop.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(shop.category,
                  style:
                      TextStyle(color: Colors.deepPurple[700], fontSize: 11)),
              Row(children: [
                const Icon(Icons.star, color: Colors.amber, size: 13),
                Text(' ${shop.rating.toStringAsFixed(1)} · ${shop.views} مشاهدة',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
            ]),
            trailing:
                const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ),
        );
      },
    );
  }

  Widget _buildProductsGrid(List<Product> products) {
    if (products.isEmpty) return _buildEmpty('لا توجد منتجات مطابقة');
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10),
      itemCount: products.length,
      itemBuilder: (_, i) {
        final p = products[i];
        return GestureDetector(
          onTap: () {
            if (mounted) {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => DetailScreen(item: p)));
            }
          },
          child: Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Stack(children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  child: SizedBox(
                      width: double.infinity,
                      child: CachedImage(
                          imageUrl:
                              p.imageUrls.isNotEmpty ? p.imageUrls.first : '',
                          fit: BoxFit.cover)),
                ),
                if (p.hasDiscount)
                  Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4)),
                        child: Text('-${p.discountPercentage.toInt()}%',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      )),
              ])),
              Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      Row(children: [
                        Text('${p.price.toStringAsFixed(0)} ج',
                            style: const TextStyle(
                                color: Color(0xFF5E35B1),
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        if (p.hasPriceDrop) ...[
                          const SizedBox(width: 4),
                          Text(p.oldPrice.toStringAsFixed(0),
                              style: const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  fontSize: 10,
                                  color: Colors.grey)),
                        ],
                      ]),
                    ],
                  )),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildOffersList(List<Offer> offers) {
    if (offers.isEmpty) return _buildEmpty('لا توجد عروض مطابقة');
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: offers.length,
      itemBuilder: (_, i) {
        final o = offers[i];
        return GestureDetector(
          onTap: () {
            if (mounted) {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => DetailScreen(item: o)));
            }
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(right: Radius.circular(12)),
                child: SizedBox(
                    width: 90,
                    height: 90,
                    child: CachedImage(imageUrl: o.imageUrl, fit: BoxFit.cover)),
              ),
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(o.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(4)),
                            child: Text('خصم ${o.discount}%',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 4),
                          Text('حتى: ${o.validUntil.day}/${o.validUntil.month}',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 11)),
                        ],
                      ))),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildEmpty(String msg) => Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(msg, style: const TextStyle(color: Colors.grey, fontSize: 15)),
        ],
      ));

  // ─── Pickers ──────────────────────────────────────────────────────────────

  void _showCategoryPicker(List<String> cats) {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => RadioGroup<String>(
              groupValue: _selectedCategory,
              onChanged: (v) {
                if (v != null) {
                  setState(() => _selectedCategory = v);
                  if (mounted) Navigator.pop(context);
                }
              },
              child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: cats
                      .map((c) => ListTile(
                            title: Text(c),
                            leading: Radio<String>.adaptive(
                              value: c,
                              activeColor: const Color(0xFF5E35B1),
                            ),
                            onTap: () {
                              setState(() => _selectedCategory = c);
                              if (mounted) Navigator.pop(context);
                            },
                          ))
                      .toList()),
            ));
  }

  void _showSortPicker() {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => RadioGroup<String>(
              groupValue: _selectedSort,
              onChanged: (v) {
                if (v != null) {
                  setState(() => _selectedSort = v);
                  if (mounted) Navigator.pop(context);
                }
              },
              child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: _sortOptions
                      .map((s) => ListTile(
                            title: Text(s),
                            leading: Radio<String>.adaptive(
                              value: s,
                              activeColor: const Color(0xFF5E35B1),
                            ),
                            onTap: () {
                              setState(() => _selectedSort = s);
                              if (mounted) Navigator.pop(context);
                            },
                          ))
                      .toList()),
            ));
  }

  void _showRegionPicker() {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => RadioGroup<String>(
              groupValue: _selectedRegion,
              onChanged: (v) {
                if (v != null) {
                  setState(() => _selectedRegion = v);
                  if (mounted) Navigator.pop(context);
                }
              },
              child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: _regions
                      .map((r) => ListTile(
                            title: Text(r),
                            leading: Radio<String>.adaptive(
                              value: r,
                              activeColor: const Color(0xFF5E35B1),
                            ),
                            onTap: () {
                              setState(() => _selectedRegion = r);
                              if (mounted) Navigator.pop(context);
                            },
                          ))
                      .toList()),
            ));
  }

  void _showRatingPicker() {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setS) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('الحد الأدنى للتقييم',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                            5,
                            (i) => GestureDetector(
                                  onTap: () {
                                    setS(() =>
                                        _minRating = (i + 1).toDouble());
                                    setState(() {});
                                    if (mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
                                  child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Icon(Icons.star,
                                          size: 36,
                                          color: (i + 1) <= _minRating
                                              ? Colors.amber
                                              : Colors.grey[300])),
                                ))),
                  ]),
                )));
  }

  void _showPriceRangePicker() {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setS) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('نطاق السعر (جنيه)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(
                        '${_priceRange.start.toInt()} - ${_priceRange.end.toInt()} جنيه',
                        style: const TextStyle(
                            color: Color(0xFF5E35B1),
                            fontWeight: FontWeight.bold)),
                    RangeSlider(
                      values: _priceRange,
                      min: 0,
                      max: 5000,
                      divisions: 50,
                      activeColor: const Color(0xFF5E35B1),
                      onChanged: (v) {
                        setS(() {
                          _priceRange = v;
                          setState(() {});
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        if (mounted) {
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('تطبيق'),
                    ),
                  ]),
                )));
  }
}
