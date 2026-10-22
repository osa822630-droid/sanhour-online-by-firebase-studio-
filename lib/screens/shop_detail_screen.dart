// lib/screens/shop_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sanhour_online/widgets/shop_media_gallery.dart';
import 'package:sanhour_online/models/shop.dart';
import 'package:sanhour_online/models/product.dart';
import 'package:sanhour_online/models/offer.dart';
import 'package:sanhour_online/providers/favorites_provider.dart';
import 'package:sanhour_online/providers/auth_provider.dart';
import 'package:sanhour_online/services/api_service.dart';
import 'package:sanhour_online/widgets/cached_image.dart';
import 'detail_screen.dart';
import 'review_screen.dart';
import 'login_screen.dart';
import '../services/analytics_service.dart';
import '../services/stats_service.dart';

class ShopDetailScreen extends StatefulWidget {
  final Shop shop;
  const ShopDetailScreen({super.key, required this.shop});

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Product> _products = [];
  List<Offer> _offers = [];
  List<Map<String, dynamic>> _reviews = [];
  List<Map<String, dynamic>> _services = []; // ✅ خدمات المحل
  String _selectedCategory = 'الكل';
  bool _isLoading = true;
  // ✅ Fix #96: تخزين رسالة الخطأ وعرضها بدلاً من الفشل الصامت
  String? _errorMsg;

  int _callClicks = 0;
  int _whatsappClicks = 0;

  @override
  void initState() {
    super.initState();
    // ✅ Phase 1 Fix #10: دائماً 5 tabs ثابتة — تبويب الخدمات يظهر دائماً
    // (يعرض empty state إذا لم توجد خدمات) لتجنب dispose داخل setState.
    _tabController = TabController(length: 5, vsync: this);
    _loadShopData();
    ApiService.logShopVisit(widget.shop.id);
    AnalyticsService().logScreenView('shop_detail');
    AnalyticsService().logViewItem(widget.shop);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadShopData() async {
    try {
      final results = await Future.wait([
        ApiService.getProducts(shopId: widget.shop.id),
        ApiService.getOffers(shopId: widget.shop.id),
        ApiService.getReviews(widget.shop.id),
        ApiService.getServices(shopId: widget.shop.id),
      ]);
      if (mounted) {
        setState(() {
          _products = results[0] as List<Product>;
          _offers = results[1] as List<Offer>;
          _reviews = (results[2] as List).map((r) => {
            'comment': r.comment ?? '',
            'rating': r.rating ?? 0,
            'userName': r.userName ?? 'مستخدم',
            'userImage': r.userImage ?? '',
          }).toList();
          _services = (results[3] as List<Map<String, dynamic>>);
          _isLoading = false;
          _errorMsg = null;
        });
      }
    } catch (e) {
      // ✅ Fix #96: عرض رسالة الخطأ للمستخدم
      if (mounted) setState(() {
        _isLoading = false;
        _errorMsg = 'تعذّر تحميل بيانات المحل. تحقق من اتصالك.';
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() { _isLoading = true; _errorMsg = null; });
    await _loadShopData();
  }

  void _launchURL(String? urlString) async {
    if (urlString == null || urlString.isEmpty) return;
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر فتح الرابط')));
      }
    }
  }

  // ✅ فتح تطبيق الهاتف مع كتابة الرقم على لوحة المفاتيح مباشرة
  void _callShop() {
    setState(() => _callClicks++);
    StatsService.logPhoneClick(widget.shop.id);
    // tel: يفتح لوحة الاتصال مع الرقم مكتوباً جاهزاً للضغط
    _launchURL('tel:${widget.shop.phone}');
  }

  void _whatsappShop() {
    setState(() => _whatsappClicks++);
    StatsService.logWhatsAppClick(widget.shop.id);
    final raw = widget.shop.whatsapp?.isNotEmpty == true
        ? widget.shop.whatsapp!
        : widget.shop.phone;
    // ✅ Fix #170: تطبيع رقم الواتساب للصيغة الدولية (20xxxxxxxxxx)
    final normalized = _normalizeWhatsApp(raw);
    _launchURL('https://wa.me/$normalized');
  }

  static String _normalizeWhatsApp(String phone) {
    String p = phone.replaceAll(RegExp(r'[\s\-\(\)+]'), '');
    if (p.startsWith('0020')) return p.substring(2);
    if (p.startsWith('+20')) return p.substring(1);
    if (p.startsWith('20') && p.length == 12) return p;
    if (p.startsWith('0') && p.length == 11) return '2$p';
    return '20$p';
  }

  // ✅ حماية التقييم من الزوار
  void _openReviewScreen() {
    final auth = context.read<AuthProvider>();
    if (auth.isGuest) {
      _showGuestDialog();
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ReviewScreen(
        itemId: widget.shop.id, itemType: 'shop', itemName: widget.shop.name),
    )).then((_) => _refreshData());
  }

  void _showGuestDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('يلزم تسجيل الدخول'),
        content: const Text('سجّل دخولك لإضافة تقييم أو تفاعل مع المحل.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('لاحقاً')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
            child: const Text('تسجيل الدخول', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ✅ Fix #96: عرض حالة الخطأ الواضحة
    if (_errorMsg != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.shop.name)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.cloud_off_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(_errorMsg!, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _refreshData,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openReviewScreen,
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.rate_review, color: Colors.white),
        label: const Text('أضف تقييم', style: TextStyle(color: Colors.white)),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, scrolled) => [
          _buildSliverAppBar(ctx, scrolled),
          // ✅ Q5-1b: گاليري وسائط المحل — تظهر أسفل معلومات المحل مباشرة
          if (widget.shop.mediaUrls.isNotEmpty)
            SliverToBoxAdapter(
              child: ShopMediaGallery(
                mediaUrls: widget.shop.mediaUrls,
                mediaTypes: widget.shop.mediaTypes,
              ),
            ),
        ],
        body: Column(
          children: [
            // TabBar
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.deepPurple,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.deepPurple,
                isScrollable: true,
                tabs: [
                  const Tab(text: 'نظرة عامة',
                      icon: Icon(Icons.home_outlined, size: 18)),
                  Tab(
                    text: 'منتجات',
                    icon: Badge(
                      // ✅ Fix #165: إزالة الـ escape الزائد \$
                      label: _products.isNotEmpty
                          ? Text('${_products.length}')
                          : null,
                      child: const Icon(Icons.shopping_bag_outlined, size: 18),
                    ),
                  ),
                  Tab(
                    text: 'خدمات',
                    icon: Badge(
                      label: _services.isNotEmpty
                          ? Text('${_services.length}')
                          : null,
                      child: const Icon(Icons.miscellaneous_services_outlined, size: 18),
                    ),
                  ),
                  Tab(
                    text: 'عروض',
                    icon: Badge(
                      label: _offers.isNotEmpty
                          ? Text('${_offers.length}')
                          : null,
                      child: const Icon(Icons.local_offer_outlined, size: 18),
                    ),
                  ),
                  Tab(
                    text: 'تقييمات',
                    icon: Badge(
                      label: _reviews.isNotEmpty
                          ? Text('${_reviews.length}')
                          : null,
                      child: const Icon(Icons.star_outline, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              // ✅ Phase 1 Fix #10: دائماً 5 children — تطابق تام مع الـ controller
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildProductsTab(),
                  _buildServicesTab(), // يعرض empty state إذا كانت _services فارغة
                  _buildOffersTab(),
                  _buildReviewsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, bool scrolled) {
    return SliverAppBar(
      expandedHeight: 260,
      floating: false,
      pinned: true,
      backgroundColor: Colors.deepPurple,
      title: scrolled ? Text(widget.shop.name, style: const TextStyle(fontSize: 17)) : null,
      actions: [
        Consumer<FavoritesProvider>(builder: (ctx, fav, _) {
          final isFav = fav.isFavorite('shop', widget.shop.id);
          return IconButton(
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav ? Colors.red[300] : Colors.white),
            onPressed: () {
              final auth = ctx.read<AuthProvider>();
              if (auth.isGuest) { _showGuestDialog(); return; }
              fav.toggleFavorite(widget.shop);
            },
          );
        }),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedImage(
              imageUrl: widget.shop.coverUrl.isNotEmpty
                  ? widget.shop.coverUrl : widget.shop.imageUrl,
              fit: BoxFit.cover,
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
            Positioned(
              bottom: 16, right: 16, left: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.shop.coverUrl.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      // ✅ QA Fix #27: استبدال NetworkImage المباشر بـ CachedImage مع fallback
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        child: ClipOval(
                          child: widget.shop.imageUrl.isNotEmpty
                              ? CachedImage(
                                  imageUrl: widget.shop.imageUrl,
                                  width: 56, height: 56,
                                  fit: BoxFit.cover,
                                )
                              : const Icon(Icons.storefront,
                                  size: 28, color: Color(0xFF5E35B1)),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.shop.name,
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.star, color: Colors.amber, size: 15),
                          const SizedBox(width: 4),
                          Text('${widget.shop.rating} (${widget.shop.reviewCount} تقييم)',
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(width: 10),
                          const Icon(Icons.location_on, color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Expanded(child: Text(widget.shop.location,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                              overflow: TextOverflow.ellipsis)),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.visibility, color: Colors.white54, size: 13),
                          const SizedBox(width: 4),
                          Text('${widget.shop.views} مشاهدة',
                              style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── تبويب 1: نظرة عامة ──────────────────────────────────────────────────────
  Widget _buildOverviewTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // أزرار التواصل
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: widget.shop.phone.isNotEmpty ? _callShop : null,
                icon: const Icon(Icons.call),
                label: Text(widget.shop.phone.isNotEmpty ? 'اتصال  (${widget.shop.phone})' : 'لا يوجد هاتف'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              )),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(
                onPressed: (widget.shop.whatsapp != null && widget.shop.whatsapp!.isNotEmpty) ||
                    widget.shop.phone.isNotEmpty ? _whatsappShop : null,
                icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 18),
                label: const Text('واتساب'),
              )),
            ]),
            const SizedBox(height: 20),

            // أحدث العروض
            if (_offers.isNotEmpty) ...[
              _sectionHeader('🔥 عروض حصرية'),
              SizedBox(
                height: 130,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _offers.take(5).length,
                  itemBuilder: (_, i) {
                    final offer = _offers[i];
                    return GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => DetailScreen(item: offer))),
                      child: Container(
                        width: 240,
                        margin: const EdgeInsets.only(left: 10),
                        decoration: BoxDecoration(
                          color: Colors.red[50], borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                            child: SizedBox(width: 90, height: 130,
                                child: CachedImage(imageUrl: offer.imageUrl, fit: BoxFit.cover)),
                          ),
                          Expanded(child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(offer.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                                child: Text('خصم ${offer.discount}%',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(height: 4),
                              Text('حتى: ${offer.validUntil.day}/${offer.validUntil.month}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ]),
                          )),
                        ]),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 30),
            ],

            // عن المحل
            _sectionHeader('عن المحل'),
            Text(widget.shop.description.isNotEmpty ? widget.shop.description : 'لا يوجد وصف حتى الآن.',
                style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87)),
            const SizedBox(height: 16),

            // مواعيد العمل
            if (widget.shop.workingHours.isNotEmpty) ...[
              _sectionHeader('مواعيد العمل'),
              Row(children: [
                const Icon(Icons.access_time, color: Colors.deepPurple, size: 20),
                const SizedBox(width: 8),
                Text(widget.shop.workingHours, style: const TextStyle(fontSize: 15)),
              ]),
              const SizedBox(height: 16),
            ],

            // ✅ إحصائيات التواصل (مرئية للتاجر فقط في المستقبل — الآن للعرض)
            if (_callClicks > 0 || _whatsappClicks > 0) ...[
              _sectionHeader('إحصائيات التواصل'),
              Row(children: [
                _statChip(Icons.call, '$_callClicks اتصال', Colors.green),
                const SizedBox(width: 10),
                _statChip(FontAwesomeIcons.whatsapp, '$_whatsappClicks واتساب', Colors.teal),
              ]),
              const SizedBox(height: 16),
            ],

            // التواصل الاجتماعي
            if ([
              widget.shop.facebookUrl,
              widget.shop.instagramUrl,
              widget.shop.tiktokUrl,
              widget.shop.telegramUrl,
            ].any((u) => u != null && u.isNotEmpty)) ...[ 
              _sectionHeader('تابعنا على'),
              Row(children: [
                if (widget.shop.facebookUrl != null && widget.shop.facebookUrl!.isNotEmpty)
                  IconButton(
                    tooltip: 'فيسبوك',
                    icon: const FaIcon(FontAwesomeIcons.facebook, color: Colors.blue, size: 28),
                    onPressed: () {
                      StatsService.logSocialClick(widget.shop.id, 'facebook');
                      _launchURL(widget.shop.facebookUrl);
                    },
                  ),
                if (widget.shop.instagramUrl != null && widget.shop.instagramUrl!.isNotEmpty)
                  IconButton(
                    tooltip: 'انستجرام',
                    icon: const FaIcon(FontAwesomeIcons.instagram, color: Colors.purple, size: 28),
                    onPressed: () {
                      StatsService.logSocialClick(widget.shop.id, 'instagram');
                      _launchURL(widget.shop.instagramUrl);
                    },
                  ),
                if (widget.shop.tiktokUrl != null && widget.shop.tiktokUrl!.isNotEmpty)
                  IconButton(
                    tooltip: 'تيك توك',
                    icon: const FaIcon(FontAwesomeIcons.tiktok, color: Colors.black87, size: 26),
                    onPressed: () {
                      StatsService.logSocialClick(widget.shop.id, 'tiktok');
                      _launchURL(widget.shop.tiktokUrl);
                    },
                  ),
                if (widget.shop.telegramUrl != null && widget.shop.telegramUrl!.isNotEmpty)
                  IconButton(
                    tooltip: 'تيليجرام',
                    icon: const FaIcon(FontAwesomeIcons.telegram, color: Color(0xFF2CA5E0), size: 28),
                    onPressed: () {
                      StatsService.logSocialClick(widget.shop.id, 'telegram');
                      _launchURL(widget.shop.telegramUrl);
                    },
                  ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  // ── تبويب 2: المنتجات ───────────────────────────────────────────────────────
  Widget _buildProductsTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_products.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.shopping_bag_outlined, size: 60, color: Colors.grey),
        SizedBox(height: 10), Text('لم تُضَف منتجات بعد', style: TextStyle(color: Colors.grey)),
      ]));
    }

    final categories = ['الكل', ..._products.map((p) => p.category).toSet()];
    final filtered = _selectedCategory == 'الكل'
        ? _products : _products.where((p) => p.category == _selectedCategory).toList();

    return Column(children: [
      // Category chips
      if (categories.length > 1)
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final cat = categories[i];
              final sel = _selectedCategory == cat;
              return ChoiceChip(
                label: Text(cat),
                selected: sel,
                selectedColor: Colors.deepPurple,
                labelStyle: TextStyle(color: sel ? Colors.white : Colors.black),
                onSelected: (_) => setState(() => _selectedCategory = cat),
              );
            },
          ),
        ),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, childAspectRatio: 0.72,
              crossAxisSpacing: 10, mainAxisSpacing: 10),
          itemCount: filtered.length,
          itemBuilder: (_, i) => _buildProductCard(filtered[i]),
        ),
      ),
    ]);
  }

  Widget _buildProductCard(Product p) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => DetailScreen(item: p))),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Stack(fit: StackFit.expand, children: [
              CachedImage(imageUrl: p.imageUrls.isNotEmpty ? p.imageUrls.first : '', fit: BoxFit.cover),
              if (p.hasDiscount)
                Positioned(top: 6, right: 6, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                  child: Text('-${p.discountPercentage.toInt()}%',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                )),
            ]),
          )),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Row(children: [
                Text('${p.price.toStringAsFixed(0)} جنيه',
                    style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                if (p.hasPriceDrop) ...[
                  const SizedBox(width: 6),
                  Text(p.oldPrice.toStringAsFixed(0),
                      style: const TextStyle(decoration: TextDecoration.lineThrough, fontSize: 11, color: Colors.grey)),
                ],
              ]),
              Row(children: [
                const Icon(Icons.star, color: Colors.amber, size: 13),
                const SizedBox(width: 2),
                Text('${p.rating}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── تبويب 3: العروض ─────────────────────────────────────────────────────────
  Widget _buildOffersTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_offers.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.local_offer_outlined, size: 60, color: Colors.grey),
        SizedBox(height: 10), Text('لا توجد عروض حالياً', style: TextStyle(color: Colors.grey)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _offers.length,
      itemBuilder: (_, i) {
        final offer = _offers[i];
        return GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => DetailScreen(item: offer))),
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                child: SizedBox(width: 100, height: 110,
                    child: CachedImage(imageUrl: offer.imageUrl, fit: BoxFit.cover)),
              ),
              Expanded(child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(offer.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2),
                  const SizedBox(height: 6),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                      child: Text('خصم ${offer.discount}%',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text('ينتهي: ${offer.validUntil.day}/${offer.validUntil.month}/${offer.validUntil.year}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
              )),
            ]),
          ),
        );
      },
    );
  }

  // ── تبويب 4: التقييمات ──────────────────────────────────────────────────────
  // ✅ تبويب الخدمات — يظهر فقط عند وجود خدمات
  // ✅ Phase 1 Fix #10: دائماً موجود — يعرض empty state عند غياب الخدمات
  Widget _buildServicesTab() {
    if (_services.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.miscellaneous_services_outlined,
                size: 60, color: Colors.grey),
            SizedBox(height: 10),
            Text('لا توجد خدمات مضافة بعد',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _services.length,
      itemBuilder: (_, i) {
        final s = _services[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            leading: Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF5E35B1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.miscellaneous_services, color: Color(0xFF5E35B1)),
            ),
            title: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: s['description'] != null && (s['description'] as String).isNotEmpty
                ? Text(s['description'], maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 13))
                : null,
            trailing: s['price'] != null && (s['price'] as num) > 0
                ? Text('${s['price']} ج',
                    style: const TextStyle(color: Color(0xFF5E35B1),
                        fontWeight: FontWeight.bold, fontSize: 15))
                : null,
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab() {
    return Column(children: [
      // خلاصة التقييم
      if (widget.shop.reviewCount > 0)
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Column(children: [
              Text(widget.shop.rating.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              Row(children: List.generate(5, (i) => Icon(
                i < widget.shop.rating.round() ? Icons.star : Icons.star_border,
                color: Colors.amber, size: 16))),
              Text('${widget.shop.reviewCount} تقييم',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
            const SizedBox(width: 20),
            Expanded(child: Column(children: List.generate(5, (i) {
              final star = 5 - i;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Text('$star', style: const TextStyle(fontSize: 12)),
                  const Icon(Icons.star, color: Colors.amber, size: 12),
                  const SizedBox(width: 6),
                  Expanded(child: LinearProgressIndicator(
                    value: widget.shop.reviewCount > 0 ? (0.3 * (star / 5)) : 0,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation(Colors.amber),
                  )),
                ]),
              );
            }))),
          ]),
        ),

      if (_reviews.isEmpty)
        Expanded(child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.rate_review_outlined, size: 60, color: Colors.grey),
            const SizedBox(height: 10),
            const Text('لا توجد تقييمات بعد', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openReviewScreen,
              icon: const Icon(Icons.add_comment),
              label: const Text('أضف أول تقييم'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            ),
          ]),
        ))
      else
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _reviews.length,
          itemBuilder: (_, i) {
            final r = _reviews[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.deepPurple.withValues(alpha: 0.15),
                      child: Text(
                        (r['userName'] as String).isNotEmpty ? (r['userName'] as String)[0] : 'م',
                        style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r['userName'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Row(children: List.generate(5, (j) => Icon(
                        j < (r['rating'] as int) ? Icons.star : Icons.star_border,
                        color: Colors.amber, size: 14))),
                    ]),
                  ]),
                  if ((r['comment'] as String).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(r['comment'] as String, style: const TextStyle(fontSize: 14, height: 1.5)),
                  ],
                ]),
              ),
            );
          },
        )),
    ]);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
  );

  Widget _statChip(dynamic icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
Icon(icon is IconData ? icon : Icons.phone, size: 16, color: color),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    ]),
  );
}
