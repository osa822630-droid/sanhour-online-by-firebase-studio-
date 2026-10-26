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
import '../screens/categories_screen.dart';
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

  // إعدادات الموقع من Firestore
  bool _showLocationFilter = false;
  List<String> _regions = [];

  // ✅ Fix #72: تخزين الـ streams في الـ state لمنع إعادة الاشتراك في كل rebuild
  late final Stream<QuerySnapshot> _jobsStream;
  late final Stream<QuerySnapshot> _servicesStream;

  @override
  void initState() {
    super.initState();
    // ✅ Fix #72: إنشاء الـ streams مرة واحدة في initState
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

  // ── تحميل إعداد الموقع من Firestore ──────────────────────────────
  Future<void> _loadLocationSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('general')
          .get();
      if (!mounted) return;
      final data = doc.data() ?? {};
      final show = data['showLocationFilter'] as bool? ?? false;
      final regions =
          List<String>.from(data['regions'] as List? ?? []);
      setState(() {
        _showLocationFilter = show;
        _regions = regions;
      });
    } catch (_) {}
  }

  // ── التركيز على شريط البحث والتمرير إليه ────────────────────────
  void _focusSearchBar() {
    _scrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  Future<void> _loadInterests() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user_interests');
    if (raw != null && mounted) {
      setState(() => _userInterests = List<String>.from(jsonDecode(raw)));
    }
  }

  // ✅ إصلاح الجليتش: مقارنة بتوقيع فعلي (معرّفات المحلات) بدلاً من العدد
  // فقط — العدد وحده كان يُسبب مشكلتين: (1) إعادة ترتيب متكررة ومزعجة أثناء
  // التحديث كل ما وصلت بيانات جزئية بنفس عدد المحلات القديم تقريباً، و(2)
  // عدم اكتشاف تغيّر المحلات الفعلية لو ظل العدد نفسه صدفة (محل عُلِّق
  // واستُبدل بآخر). الآن يُعاد الترتيب فقط عند تغيّر المحلات فعلياً.
  String? _lastShuffleSignature;

  // ✅ Fix #29: force = true بيعيد الخلط حتى لو المحلات ما اتغيّرتش (زرار «خلّط»).
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
        .where((s) => _userInterests.contains(s.category))
        .toList()
      ..shuffle(rng);
    final rest = provider.shops
        .where((s) => !_userInterests.contains(s.category))
        .toList()
      ..shuffle(rng);
    _shuffledShops = [...interested, ...rest].take(20).toList();
  }

  Future<void> _refreshData() async {
    final provider = context.read<ShopsProvider>();
    // ✅ إصلاح الجليتش: لم نعد نمسح _shuffledShops هنا — كان هذا يُسبب
    // اختفاء/إعادة ترتيب قسم "اخترنا لك" بشكل مزعج أثناء التحديث.
    // _buildShuffleList الجديدة تكتشف التغيّر الفعلي تلقائياً بمجرد وصول
    // بيانات جديدة حقيقية، ومؤشر RefreshIndicator نفسه يكفي كتغذية راجعة
    // بصرية لحالة "جارٍ التحديث".
    await CacheService().clearAllCache();
    await Future.wait([
      // ✅ إصلاح: تمرير الفئة الحالية — كان التحديث يمسح فلتر الفئة
      // المختارة بصمت في كل مرة (لأن عدم تمرير category يُعيد ضبطه لـ null)
      provider.fetchShops(category: provider.selectedCategory, refresh: true),
      provider.fetchProducts(refresh: true),
      provider.fetchOffers(refresh: true),
      provider.fetchCategories(refresh: true),
      provider.fetchAds(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SeasonalOverlay(
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0E0E1A) : const Color(0xFFF8F7FF),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshData,
            color: const Color(0xFF5E35B1),
            child: Consumer<ShopsProvider>(
              builder: (context, provider, _) {
                _buildShuffleList(provider);

                // ✅ Fix #109: عرض حالة الخطأ بدلاً من صفحة فارغة
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
                          ? const Color(0xFF1A1A2E)
                          : const Color(0xFF5E35B1),
                      automaticallyImplyLeading: false,
                      flexibleSpace: FlexibleSpaceBar(
                        collapseMode: CollapseMode.pin,
                        background: Container(
                          color: isDark
                              ? const Color(0xFF1A1A2E)
                              : const Color(0xFF5E35B1),
                        ),
                      ),
                      title: Row(
                        children: [
                          // هامبرغر
                          GestureDetector(
                            onTap: () => MainScreen.scaffoldKey.currentState
                                ?.openDrawer(),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _bar(22),
                                  const SizedBox(height: 4),
                                  _bar(17),
                                  const SizedBox(height: 4),
                                  _bar(13),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // ✅ أيقونة الموقع — تظهر فقط إذا فعّلها الأدمن
                          if (_showLocationFilter)
                            GestureDetector(
                              onTap: _showRegionPicker,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4),
                                child: const Icon(Icons.location_on_outlined,
                                    color: Colors.white70, size: 20),
                              ),
                            ),

                          // اسم التطبيق
                          Expanded(
                            child: Column(
                              children: [
                                const Text(
                                  'سنهور أونلاين',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const Text(
                                  'سنهور كلها في جيبك',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          ),

                          // ✅ أيقونة البحث — تُركّز على الشريط أسفله
                          IconButton(
                            icon: const Icon(Icons.search,
                                color: Colors.white, size: 22),
                            tooltip: 'بحث',
                            onPressed: _focusSearchBar,
                          ),
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
                          // ✅ فلتر مدمج: الفئة
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
                                  ),
                                  SearchFilter(
                                    id: 'type',
                                    label: 'نوع النتيجة',
                                    options: [
                                      'الكل',
                                      'محلات',
                                      'منتجات',
                                      'عروض',
                                      'خدمات',
                                    ],
                                  ),
                                ]
                              : [],
                          onFilterChanged: (id, val) {
                            // تمرير الفلتر للـ provider عبر search
                            if (id == 'category') {
                              if (val != 'الكل') {
                                context.read<ShopsProvider>().search(val);
                              } else {
                                context.read<ShopsProvider>().search('');
                              }
                            }
                          },
                          // ✅ البحث المتقدم من داخل شريط البحث
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
                          if (provider.categories.isNotEmpty) ...[
                            _sectionHeader(
                              'استكشف الفئات',
                              onViewAll: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const CategoriesScreen()),
                              ),
                            ),
                            const CategoryListWidget(),
                            const SizedBox(height: 20),
                          ],

                          // المحلات المميزة
                          if (provider.featuredShops.isNotEmpty) ...[
                            _sectionHeader('⭐ محلات مميزة'),
                            HorizontalList(
                              title: '⭐ محلات مميزة',
                              items: provider.featuredShops,
                              type: 'shop',
                            ),
                            const SizedBox(height: 20),
                          ],

                          // أحدث المنتجات
                          if (provider.products.isNotEmpty) ...[
                            _sectionHeader('🛍️ أحدث المنتجات'),
                            HorizontalList(
                              title: '🛍️ أحدث المنتجات',
                              items: provider.products.take(10).toList(),
                              type: 'product',
                            ),
                            const SizedBox(height: 20),
                          ],

                          // أحدث العروض
                          if (provider.offers.isNotEmpty) ...[
                            _sectionHeader('🏷️ أحدث العروض',
                                onViewAll: () =>
                                    Navigator.pushNamed(context, '/offers')),
                            HorizontalList(
                              title: '🏷️ أحدث العروض',
                              items: provider.offers.take(10).toList(),
                              type: 'offer',
                            ),
                            const SizedBox(height: 20),
                          ],

                          // ✅ إصلاح الكراش: كان هنا SliverToBoxAdapter
                          // متداخل داخل Column عادي — تعارض نوع render
                          // (RenderSliver داخل RenderBox) يُسبب كراش فوري
                          // Flutter عند تحقق هذا الشرط. الحل: عنصر عادي فقط
                          // (بدون غلاف Sliver) لأننا بالفعل داخل Column
                          if (provider.isLoading && provider.shops.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: ShimmerList(count: 4),
                            ),

                          // حالة فارغة
                          if (provider.shops.isEmpty &&
                              provider.products.isEmpty &&
                              !provider.isLoading)
                            _emptyState(context, provider),

                          // ── سنهور ديلر ────────────────────────
                          _buildDealerSection(context),

                          // ── فرص عمل ───────────────────────────
                          _buildJobsPreviewSection(context),

                          // ── طلبات الخدمات ─────────────────────
                          _buildServicesPreviewSection(context),

                          // اخترنا لك
                          if (_shuffledShops.isNotEmpty)
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
            leading:
                const Icon(Icons.clear, color: Colors.grey),
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

  Widget _bar(double w) => Container(
      width: w, height: 2.5, color: Colors.white);

  // ── سنهور ديلر (بيع وشراء المستعمل) ────────────────────────────────
  Widget _buildDealerSection(BuildContext context) {
    return Column(
      children: [
        _sectionHeader(
          '🏷️ سنهور ديلر',
          onViewAll: () => Navigator.pushNamed(context, '/dealer'),
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
                    onPressed: () =>
                        Navigator.pushNamed(context, '/dealer'),
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
            const Icon(Icons.sell_outlined,
                color: Colors.white54, size: 72),
          ]),
        ),
      ],
    );
  }

  // ── فرص عمل ────────────────────────────────────────────────────────
  Widget _buildJobsPreviewSection(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // ✅ Fix #72: استخدام stream محفوظ في state
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
                  Navigator.pushNamed(context, '/ads_hub',
                      arguments: {'tab': 1}),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                itemCount: jobs.length,
                itemBuilder: (_, i) {
                  final data =
                      jobs[i].data() as Map<String, dynamic>;
                  final title = data['title'] as String? ?? '';
                  final category = data['category'] as String? ?? '';
                  final location =
                      data['location'] as String? ?? '';
                  return Container(
                    width: 200,
                    margin: const EdgeInsets.only(left: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.deepPurple
                              .withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(location,
                            style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            category,
                            style: const TextStyle(
                                color: Colors.deepPurple,
                                fontSize: 10),
                          ),
                        ),
                      ],
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
      // ✅ Fix #72: استخدام stream محفوظ في state
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
                  Navigator.pushNamed(context, '/ads_hub',
                      arguments: {'tab': 2}),
            ),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 0),
                itemCount: requests.length,
                itemBuilder: (_, i) {
                  final data = requests[i].data()
                      as Map<String, dynamic>;
                  final title =
                      data['title'] as String? ?? '';
                  // ignore: unused_local_variable
                  final category =
                      data['category'] as String? ?? '';
                  final bidsCount =
                      (data['bidsCount'] as int?) ?? 0;
                  final urgent =
                      data['urgent'] as bool? ?? false;
                  return Container(
                    width: 200,
                    margin:
                        const EdgeInsets.only(left: 12),
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
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        if (urgent)
                          const Padding(
                            padding:
                                EdgeInsets.only(bottom: 4),
                            child: Text('⚡ عاجل',
                                style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 11,
                                    fontWeight:
                                        FontWeight.bold)),
                          ),
                        Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Row(children: [
                          Icon(Icons.people_outline,
                              size: 13,
                              color: Colors.teal),
                          const SizedBox(width: 4),
                          Text(
                            '$bidsCount عرض',
                            style: TextStyle(
                                color: Colors.teal,
                                fontSize: 11),
                          ),
                        ]),
                      ],
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
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          if (onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              child: const Text('عرض الكل',
                  style: TextStyle(
                      color: Color(0xFF5E35B1), fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _forYouSection(BuildContext context, ShopsProvider provider) {
    _buildShuffleList(provider);
    if (_shuffledShops.isEmpty) return const SizedBox.shrink();
    final title = _userInterests.isNotEmpty
        ? '✨ اخترنا لك'
        : '🔀 تصفح عشوائي';
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
                // ✅ Fix #29: كان بيفضّي القائمة (والتوقيع ما اتغيّرش فما كانتش بتتبني
                // تاني) فالقسم كله كان بيختفي. دلوقتي بيعيد الخلط فعلًا.
                onPressed: () => setState(
                    () => _buildShuffleList(provider, force: true)),
                icon: const Icon(Icons.shuffle,
                    size: 16, color: Color(0xFF5E35B1)),
                label: const Text('خلّط',
                    style: TextStyle(
                        color: Color(0xFF5E35B1), fontSize: 13)),
              ),
            ],
          ),
        ),
        HorizontalList(title: '✨ اخترنا لك', items: _shuffledShops, type: 'shop'),
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
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
