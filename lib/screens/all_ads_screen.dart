// lib/screens/all_ads_screen.dart
// ✅ Fix #33: شاشة الإعلانات (واجهة المشتري) = أرشيف الإعلانات من الأحدث للأقدم
//    مع زر عكس الترتيب، وتحميل تدريجي (20 إعلان في كل مرة)، وشريط بحث موحّد،
//    وإمكانية النقر على الإعلان للانتقال المباشر لوجهته أو تشغيل الفيديو.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ad_model.dart';
import '../models/shop.dart';
import '../models/product.dart';
import '../models/offer.dart';
import '../providers/shops_provider.dart';
import '../services/ad_service.dart';
import '../services/api_service.dart';
import '../widgets/app_footer.dart';
import '../widgets/context_search_bar.dart';
import '../widgets/media_preview_dialog.dart';
import '../screens/tabs/admin_ads_tab.dart' show AdminAdCard;
import 'detail_screen.dart';
import 'shop_detail_screen.dart';

class AllAdsScreen extends StatefulWidget {
  final bool showAppBar;
  const AllAdsScreen({super.key, this.showAppBar = true});

  @override
  State<AllAdsScreen> createState() => _AllAdsScreenState();
}

class _AllAdsScreenState extends State<AllAdsScreen> {
  static const Color _brand = Color(0xFF5E35B1);

  final ScrollController _scrollController = ScrollController();
  final List<AdModel> _ads = [];
  DocumentSnapshot? _lastDoc;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool _loadFailed = false;
  bool _newestFirst = true;
  String _searchQuery = '';
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) _loadMore();
  }

  Future<void> _loadFirstPage({bool silent = false}) async {
    final generation = ++_loadGeneration;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _loadFailed = false;
      });
    }
    final page = await AdService.getArchivePage(newestFirst: _newestFirst);
    if (!mounted || generation != _loadGeneration) return;
    final keepOldList = silent && page.failed && _ads.isNotEmpty;
    setState(() {
      if (!keepOldList) {
        _ads
          ..clear()
          ..addAll(page.ads);
        _lastDoc = page.lastDocument;
        _hasMore = page.hasMore;
        _loadFailed = page.failed;
      }
      _isLoading = false;
      _isLoadingMore = false;
    });
    if (keepOldList) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر تحديث الإعلانات، حاول مرة أخرى')),
      );
    }
  }

  Future<void> _loadMore({bool isRetry = false}) async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    final cursor = _lastDoc;
    if (cursor == null || (_loadFailed && !isRetry)) return;
    final generation = _loadGeneration;
    setState(() {
      _isLoadingMore = true;
      _loadFailed = false;
    });
    final page = await AdService.getArchivePage(
      newestFirst: _newestFirst,
      startAfter: cursor,
    );
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _ads.addAll(page.ads);
      if (!page.failed) {
        _lastDoc = page.lastDocument ?? cursor;
        _hasMore = page.hasMore;
      }
      _loadFailed = page.failed;
      _isLoadingMore = false;
    });
  }

  void _toggleSort() {
    setState(() => _newestFirst = !_newestFirst);
    _loadFirstPage();
  }

  List<AdModel> get _visibleAds {
    if (_searchQuery.isEmpty) return _ads;
    final query = _searchQuery.toLowerCase();
    return _ads.where((a) => a.text.toLowerCase().contains(query)).toList();
  }

  Future<void> _handleAdTap(AdModel ad) async {
    ApiService.logAdClick(ad.id);

    if (ad.isVideo &&
        ad.imageUrl.isNotEmpty &&
        (ad.targetType == 'none' ||
            (ad.targetId ?? '').isEmpty &&
                (ad.externalUrl ?? '').isEmpty)) {
      await MediaPreviewDialog.show(
        context,
        items: [MediaItem(url: ad.imageUrl, isVideo: true)],
      );
      return;
    }

    switch (ad.targetType) {
      case 'shop':
      case 'shop_products':
      case 'shop_offers':
        if (ad.targetId == null || ad.targetId!.isEmpty) return;
        final provider = context.read<ShopsProvider>();
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
        break;
      case 'product':
        if (ad.targetId == null || ad.targetId!.isEmpty) return;
        final provider = context.read<ShopsProvider>();
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
        break;
      case 'offer':
        if (ad.targetId == null || ad.targetId!.isEmpty) return;
        final provider = context.read<ShopsProvider>();
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
        break;
      case 'external':
        final url = ad.externalUrl;
        if (url != null && url.isNotEmpty) {
          final uri = Uri.tryParse(url);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
        break;
      default:
        if (ad.imageUrl.isNotEmpty) {
          await MediaPreviewDialog.show(
            context,
            items: [MediaItem(url: ad.imageUrl, isVideo: ad.isVideo)],
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF18162B) : const Color(0xFFF8F7FF),
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text(
                'الإعلانات',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: _brand,
              foregroundColor: Colors.white,
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadFirstPage,
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          ContextSearchBar(
            hint: 'ابحث عن إعلان...',
            onSearch: (q) => setState(() => _searchQuery = q),
            showFilterButton: false,
          ),
          Expanded(child: _buildBody(isDark)),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _brand));
    }
    if (_loadFailed && _ads.isEmpty) {
      return _buildMessage(
        icon: Icons.cloud_off_outlined,
        text: 'تعذّر تحميل الإعلانات',
        actionLabel: 'إعادة المحاولة',
        onAction: _loadFirstPage,
      );
    }
    final ads = _visibleAds;
    if (ads.isEmpty) {
      final searching = _searchQuery.isNotEmpty;
      return _buildMessage(
        icon: Icons.campaign_outlined,
        text: searching ? 'لا توجد نتائج' : 'لا توجد إعلانات',
        actionLabel:
            searching && _hasMore ? 'تحميل المزيد من الإعلانات' : null,
        onAction: () => _loadMore(isRetry: true),
      );
    }
    return RefreshIndicator(
      color: _brand,
      onRefresh: () => _loadFirstPage(silent: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: ads.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) return _buildSortRow();
          if (index <= ads.length) return _buildCard(ads[index - 1], isDark);
          return _buildListFooter();
        },
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String text,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          if (actionLabel != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ],
      ),
    );
  }

  Widget _buildSortRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: TextButton.icon(
          onPressed: _toggleSort,
          icon: const Icon(Icons.swap_vert_rounded, size: 18),
          label: Text(_newestFirst ? 'الأحدث أولًا' : 'الأقدم أولًا'),
        ),
      ),
    );
  }

  Widget _buildListFooter() {
    final Widget status;
    if (_isLoadingMore) {
      status = const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: _brand),
          ),
        ),
      );
    } else if (_loadFailed && _hasMore) {
      status = Center(
        child: TextButton.icon(
          onPressed: () => _loadMore(isRetry: true),
          icon: const Icon(Icons.refresh),
          label: const Text('تعذّر التحميل — إعادة المحاولة'),
        ),
      );
    } else if (_hasMore) {
      status = Center(
        child: TextButton(
          onPressed: () => _loadMore(isRetry: true),
          child: const Text('تحميل المزيد'),
        ),
      );
    } else {
      status = const SizedBox.shrink();
    }
    return Column(children: [status, const AppFooter()]);
  }

  Widget _buildCard(AdModel ad, bool isDark) {
    return GestureDetector(
      onTap: () => _handleAdTap(ad),
      child: AdminAdCard(
        ad: ad,
        isDark: isDark,
        showAdminControls: false,
        onToggle: () {},
        onDelete: () {},
      ),
    );
  }
}
