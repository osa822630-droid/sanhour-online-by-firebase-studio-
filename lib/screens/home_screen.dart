// lib/screens/home_screen.dart
// ✅ شريط بحث موحّد — أيقونة البحث في AppBar تُركّز على الشريط أسفله مباشرة
// ✅ أيقونة الموقع تُخفى/تُظهَر بناءً على إعداد الأدمن من Firestore
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/shops_provider.dart';
import '../widgets/horizontal_list.dart';
import '../widgets/ad_carousel.dart';
import '../widgets/app_footer.dart';
import '../widgets/seasonal_overlay.dart';
import '../widgets/context_search_bar.dart';
import '../screens/main_screen.dart';
import '../screens/advanced_search_screen.dart';
import '../services/cache_service.dart';
import '../services/analytics_service.dart';
import '../widgets/category_list.dart';
// ✅ Pro #214: Shimmer loading
import '../widgets/shimmer_loader.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── FocusNode مشترك بين الـ AppBar icon والـ SearchBar ─────────────
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();

  List<String> _userInterests = [];
  List<dynamic> _shuffledShops = [];
  bool _dataLoaded = false;

  static const String _typeAll = 'الكل';
  static const String _typeShops = 'محلات';
  static const String _typeProducts = 'منتجات';
  static const String _typeOffers = 'عروض';
  static const String _typeServices = 'خدمات';
  String _resultType = _typeAll;

  bool _showType(String type) => _resultType == _typeAll || _resultType == type;

  // إعدادات الموقع من Firestore
  bool _showLocationFilter = false;
  List<String> _regions = [];

  // ✅ Fix #72: تخزين الـ streams في الـ state لمنع إعادة الاشتراك في كل rebuild
  late final Stream<QuerySnapshot> _jobsStream;
  late final Stream<QuerySnapshot> _servicesStream;

  @override
  void initState() {
    super.initState();
    _jobsStream = FirebaseFirestore.instance
        .collection('job_ads')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(3)
        .snapshots();
    _servicesStream = FirebaseFirestore.instance
        .collection('service_requests')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .limit(3)
        .snapshots();
    _loadInterests();
    _loadLocationSettings();
    AnalyticsService().logScreenView('home');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_dataLoaded && mounted) {
        context.read<ShopsProvider>().fetchAds();
        _dataLoaded = true;
      }
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── تحميل إعداد الموقع من Firestore (general + locations) ────────────
  Future<void> _loadLocationSettings() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('settings').doc('general').get(),
        FirebaseFirestore.instance
            .collection('settings')
            .doc('locations')
            .get(),
      ]);
      if (!mounted) return;
      final genData = results[0].data() ?? {};
      final locData = results[1].data() ?? {};
      final show = (genData['showLocationFilter'] as bool?) ??
          (locData['showLocationFilter'] as bool?) ??
          false;
      final rawAreas =
          locData['areas'] ?? locData['regions'] ?? genData['regions'];
      final regions = rawAreas is List
          ? rawAreas.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
          : <String>[];
      setState(() {
        _showLocationFilter = show;
        _regions = regions;
      });
    } catch (_) {}
  }

  Future<void> _loadInterests() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user_interests');
    if (raw != null && mounted) {
      setState(() => _userInterests = List<String>.from(jsonDecode(raw)));
    }
  }

  String? _lastShuffleSignature;

  bool _matchesUserInterests(String shopCategory) {
    if (_userInterests.isEmpty || shopCategory.isEmpty) {
      return false;
    }
    if (_userInterests.contains(shopCategory)) {
      return true;
    }
    final catWords =
        shopCategory.split(RegExp(r'\s+')).where((w) => w.length >= 3);
    for (final interest in _userInterests) {
      if (interest.contains(shopCategory) || shopCategory.contains(interest)) {
        return true;
      }
      for (final word in catWords) {
        if (interest.contains(word)) {
          return true;
        }
      }
    }
    return false;
  }

  void _buildShuffleList(ShopsProvider provider, {bool force = false}) {
    if (provider.shops.isEmpty) {
      _shuffledShops = [];
      _lastShuffleSignature = null;
      return;
    }
    final signature = provider.shops.map((s) => s.id).join(',');
    if (!force && signature == _lastShuffleSignature) return;
    _lastShuffleSignature = signature;

    final rng = Random();
    final interested = provider.shops
        .where((s) => _matchesUserInterests(s.category))
        .toList()
      ..shuffle(rng);
    final rest = provider.shops
        .where((s) => !_matchesUserInterests(s.category))
        .toList()
      ..shuffle(rng);
    _shuffledShops = [...interested, ...rest].take(20).toList();
  }

  Future<void> _refreshData() async {
    final provider = context.read<ShopsProvider>();
    await _loadInterests();
    await _loadLocationSettings();
    await CacheService().clearAllCache();
    await Future.wait([
      provider.fetchShops(category: provider.selectedCategory, refresh: true),
      provider.fetchProducts(refresh: true),
      provider.fetchOffers(refresh: true),
      provider.fetchCategories(refresh: true),
      provider.fetchAds(),
    ]);
    if (mounted) {
      setState(() {
        _buildShuffleList(provider, force: true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SeasonalOverlay(
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF18162B) : const Color(0xFFF8F7FF),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshData,
            color: const Color(0xFF5E35B1),
            child: Consumer<ShopsProvider>(
              builder: (context, provider, _) {
                _buildShuffleList(provider);

                if (provider.error != null && provider.shops.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_off_outlined,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'تعذّر تحميل البيانات',
                            style: TextStyle(
                                fontSize: 18, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            provider.error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _refreshData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return CustomScrollView(
                  controller: _scrollCtrl,
                  slivers: [
                    // ── AppBar ────────────────────────────────────
                    SliverAppBar(
                      pinned: true,
                      floating: false,
                      expandedHeight: 110,
                      backgroundColor: isDark
                          ? const Color(0xFF211E3A)
                          : const Color(0xFF5E35B1),
                      automaticallyImplyLeading: false,
                      flexibleSpace: FlexibleSpaceBar(
                        collapseMode: CollapseMode.pin,
                        background: Container(
                          color: isDark
                              ? const Color(0xFF211E3A)
                              : const Color(0xFF5E35B1),
                        ),
                      ),
                      title: Row(
                        children: [
                          // ✅ زر القائمة الجانبية بمساحة لمس قياسية 48×48 سهل الفتح
                          IconButton(
                            onPressed: () => MainScreen.openDrawer(),
                            tooltip: 'القائمة',
                            icon: const Icon(Icons.menu_rounded,
                                color: Colors.white, size: 26),
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(width: 6),

                          // ✅ أيقونة الموقع — تظهر فقط إذا فعّلها الأدمن
                          if (_showLocationFilter)
                            GestureDetector(
                              onTap: _showRegionPicker,
                              child: const Padding(
                                padding:
                                    EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(Icons.location_on_outlined,
                                    color: Colors.white70, size: 20),
                              ),
                            ),

                          // اسم التطبيق
                          const Expanded(
                            child: Column(
                              children: [
                                Text(
                                  'سنهور أونلاين',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  'سنهور كلها في جيبك',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 44),
                        ],
                      ),
                    ),

                    // ── شريط البحث الموحّد ────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ContextSearchBar(
                          hint: 'ابحث عن محل، منتج، أو خدمة...',
                          focusNode: _searchFocusNode,
                          onSearch: (q) =>
                              context.read<ShopsProvider>().search(q),
                          filters: provider.categories.isNotEmpty
                              ? [
                                  SearchFilter(
                                    id: 'category',
                                    label: 'الفئة',
                                    options: [
                                      'الكل',
                                      ...provider.categories
                                          .map((c) => c.name),
                                    ],
                                    defaultOption:
                                        provider.selectedCategory ?? 'الكل',
                                  ),
                                  SearchFilter(
                                    id: 'type',
                                    label: 'نوع النتيجة',
                                    options: [
                                      _typeAll,
                                      _typeShops,
                                      _typeProducts,
                                      _typeOffers,
                                      _typeServices,
                                    ],
                                    defaultOption: _resultType,
                                  ),
                                ]
                              : [],
                          onFilterChanged: (id, val) {
                            if (id == 'category') {
                              context.read<ShopsProvider>().fetchShops(
                                  category: val == 'الكل' ? null : val);
                            } else if (id == 'type') {
                              setState(() => _resultType = val);
                            }
                          },
                          onAdvancedSearch: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdvancedSearchScreen(),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── محتوى الشاشة ──────────────────────────────
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const SizedBox(height: 8),

                          // الإعلانات
                          if (provider.ads.isNotEmpty) ...[
                            const AdCarousel(),
                            const SizedBox(height: 20),
                          ],

                          // الفئات
                          if (provider.categories.any((c) => provider.shops.any((s) => s.category.trim() == c.name.trim()))) ...[
                            _sectionHeader(
                              'استكشف الفئات',
                              onViewAll: () =>
                                  MainScreen.switchTab(MainScreen.categoriesTab),
                            ),
                            const CategoryListWidget(),
                            const SizedBox(height: 20),
                          ],

                          // المحلات المميزة
                          if (_showType(_typeShops) &&
                              provider.featuredShops.isNotEmpty) ...[
                            _sectionHeader('⭐ محلات مميزة'),
                            HorizontalList(
                              title: '⭐ محلات مميزة',
                              items: provider.featuredShops,
                              type: 'shop',
                            ),
                            const SizedBox(height: 20),
                          ],

                          // أحدث المنتجات
                          if (_showType(_typeProducts) &&
                              provider.products.isNotEmpty) ...[
                            _sectionHeader('🛍️ أحدث المنتجات'),
                            HorizontalList(
                              title: '🛍️ أحدث المنتجات',
                              items: provider.products.take(10).toList(),
                              type: 'product',
                            ),
                            const SizedBox(height: 20),
                          ],

                          // أحدث العروض
                          if (_showType(_typeOffers) &&
                              provider.offers.isNotEmpty) ...[
                            _sectionHeader('🏷️ أحدث العروض',
                                onViewAll: () =>
                                    MainScreen.switchTab(MainScreen.offersTab)),
                            HorizontalList(
                              title: '🏷️ أحدث العروض',
                              items: provider.offers.take(10).toList(),
                              type: 'offer',
                            ),
                            const SizedBox(height: 20),
                          ],

                          if (provider.isLoading && provider.shops.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: ShimmerList(count: 4),
                            ),

                          // حالة فارغة
                          if (provider.shops.isEmpty &&
                              provider.products.isEmpty &&
                              !provider.isLoading)
                            _emptyState(context, provider),

                          // ── ديلز ────────────────────────
                          if (_resultType == _typeAll)
                            _buildDealerSection(context),

                          // ── فرص عمل ───────────────────────────
                          if (_resultType == _typeAll)
                            _buildJobsPreviewSection(context),

                          // ── طلبات الخدمات ─────────────────────
                          if (_showType(_typeServices))
                            _buildServicesPreviewSection(context),

                          // اخترنا لك
                          if (_showType(_typeShops) &&
                              _shuffledShops.isNotEmpty)
                            _forYouSection(context, provider),

                          const AppFooter(),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── اختيار المنطقة ────────────────────────────────────────────────
  void _showRegionPicker() {
    if (_regions.isEmpty) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ListView(
        padding: const EdgeInsets.all(20),
        shrinkWrap: true,
        children: [
          const Text('اختر منطقتك',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ..._regions.map((r) => ListTile(
                title: Text(r),
                leading: const Icon(Icons.location_on_outlined,
                    color: Color(0xFF5E35B1)),
                onTap: () {
                  Navigator.pop(context);
                  context.read<ShopsProvider>().filterByRegion(r);
                },
              )),
          ListTile(
            title: const Text('كل المناطق'),
            leading: const Icon(Icons.clear, color: Colors.grey),
            onTap: () {
              Navigator.pop(context);
              context.read<ShopsProvider>().filterByRegion(null);
            },
          ),
        ],
      ),
    );
  }

  // ── مساعدات UI ────────────────────────────────────────────────────

  // ── ديلز (بيع وشراء المستعمل) ────────────────────────────────
  Widget _buildDealerSection(BuildContext context) {
    return Column(
      children: [
        _sectionHeader(
          '🏷️ ديلز',
          onViewAll: () => MainScreen.switchTab(MainScreen.dealerTab),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5E35B1), Color(0xFF3949AB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'بيع وشراء المستعمل',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'ملابس · إلكترونيات · أثاث\nعربيات · كتب وأكثر!',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 12, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () => MainScreen.switchTab(MainScreen.dealerTab),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF5E35B1),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    child: const Text('تصفح الإعلانات',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.sell_outlined, color: Colors.white54, size: 72),
          ]),
        ),
      ],
    );
  }

  // ── فرص عمل ────────────────────────────────────────────────────────
  Widget _buildJobsPreviewSection(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _jobsStream,
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final jobs = snap.data!.docs;
        return Column(
          children: [
            _sectionHeader(
              '💼 فرص عمل متاحة',
              onViewAll: () =>
                  MainScreen.switchTab(MainScreen.adsHubTab, adsSubTab: 1),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                itemCount: jobs.length,
                itemBuilder: (_, i) {
                  final data = jobs[i].data() as Map<String, dynamic>;
                  final title = data['title'] as String? ?? '';
                  final category = data['category'] as String? ?? '';
                  final location = data['location'] as String? ?? '';
                  return GestureDetector(
                    onTap: () =>
                        MainScreen.switchTab(MainScreen.adsHubTab, adsSubTab: 1),
                    child: Container(
                      width: 200,
                      margin: const EdgeInsets.only(left: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.deepPurple.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(location,
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  Colors.deepPurple.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              category,
                              style: const TextStyle(
                                  color: Colors.deepPurple, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  // ── طلبات الخدمات ──────────────────────────────────────────────────
  Widget _buildServicesPreviewSection(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _servicesStream,
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final requests = snap.data!.docs;
        return Column(
          children: [
            _sectionHeader(
              '🔧 محتاج حاجة تتعمل؟',
              onViewAll: () =>
                  MainScreen.switchTab(MainScreen.adsHubTab, adsSubTab: 2),
            ),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                itemCount: requests.length,
                itemBuilder: (_, i) {
                  final data = requests[i].data() as Map<String, dynamic>;
                  final title = data['title'] as String? ?? '';
                  final bidsCount = (data['bidsCount'] as int?) ?? 0;
                  final urgent = data['urgent'] as bool? ?? false;
                  return GestureDetector(
                    onTap: () =>
                        MainScreen.switchTab(MainScreen.adsHubTab, adsSubTab: 2),
                    child: Container(
                      width: 200,
                      margin: const EdgeInsets.only(left: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: urgent
                            ? Colors.red.withValues(alpha: 0.06)
                            : Colors.teal.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: (urgent ? Colors.red : Colors.teal)
                                .withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (urgent)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Text('⚡ عاجل',
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                          Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Row(children: [
                            const Icon(Icons.people_outline,
                                size: 13, color: Colors.teal),
                            const SizedBox(width: 4),
                            Text(
                              '$bidsCount عرض',
                              style: const TextStyle(
                                  color: Colors.teal, fontSize: 11),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _sectionHeader(String title, {VoidCallback? onViewAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              child: const Text('عرض الكل',
                  style: TextStyle(color: Color(0xFF5E35B1), fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _forYouSection(BuildContext context, ShopsProvider provider) {
    _buildShuffleList(provider);
    if (_shuffledShops.isEmpty) return const SizedBox.shrink();
    final title =
        _userInterests.isNotEmpty ? '✨ اخترنا لك' : '🔀 تصفح عشوائي';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () =>
                    setState(() => _buildShuffleList(provider, force: true)),
                icon: const Icon(Icons.shuffle,
                    size: 16, color: Color(0xFF5E35B1)),
                label: const Text('خلّط',
                    style:
                        TextStyle(color: Color(0xFF5E35B1), fontSize: 13)),
              ),
            ],
          ),
        ),
        HorizontalList(
            title: '✨ اخترنا لك', items: _shuffledShops, type: 'shop'),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _emptyState(BuildContext context, ShopsProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.storefront_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('لا توجد بيانات حالياً',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('سيتم إضافة المحلات والخدمات قريباً',
              style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            label: const Text('تحديث'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5E35B1),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
