// lib/screens/all_ads_screen.dart
// ✅ Fix #33: شاشة الإعلانات (واجهة المشتري) = أرشيف الإعلانات من الأحدث للأقدم
//    مع زر عكس الترتيب، وتحميل تدريجي (20 إعلان في كل مرة)، وشريط بحث موحّد.
//    • مفيش تقسيم نشط/منتهي: الإعلان بيفضل ظاهر هنا ٦ شهور من تاريخ إنشائه
//      (AdService.archiveWindow)، وبعدها بيختفي من الشاشة دي بس وبيفضل عند
//      التاجر في "سجل الإعلانات السابقة".
//    • الإعلانات غير النشطة (isActive:false) وعناصر تحكم الأدمن مخفية عن المشتري.
import 'package:cloud_firestore/cloud_firestore.dart' show DocumentSnapshot;
import 'package:flutter/material.dart';
import '../models/ad_model.dart';
import '../services/ad_service.dart';
import '../widgets/app_footer.dart';
import '../widgets/context_search_bar.dart';
// ✅ Fix #141: استخدام AdminAdCard المشترك بدلاً من بطاقة مكررة
import '../screens/tabs/admin_ads_tab.dart' show AdminAdCard;

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
  bool _isLoading = true; // تحميل أول صفحة (سبينر كامل الشاشة)
  bool _isLoadingMore = false; // تحميل الصفحات التالية (سبينر أسفل القايمة)
  bool _hasMore = false;
  bool _loadFailed = false;
  bool _newestFirst = true;
  String _searchQuery = '';
  // رقم الطلب الحالي: أي نتيجة طلب أقدم (بعد عكس الترتيب أو التحديث) بتتجاهل
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

  // تحميل الصفحة التالية تلقائيًا لما المستخدم يقرّب من آخر القايمة
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) _loadMore();
  }

  /// يحمّل أول صفحة. [silent] = true للسحب للتحديث: القايمة الحالية بتفضل
  /// ظاهرة لحد ما توصل النتيجة الجديدة بدل سبينر كامل الشاشة.
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

  /// يحمّل الصفحة التالية. [isRetry] = true لما المستخدم يضغط "تحميل المزيد"
  /// أو "إعادة المحاولة" (التحميل التلقائي بيقف بعد أول فشل عشان مفيش loop).
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

  // عكس الترتيب = استعلام جديد بالاتجاه العكسي (الترتيب من السيرفر عشان
  // التحميل التدريجي يفضل صحيح)، والـ cursor بيتصفّر مع أول صفحة.
  void _toggleSort() {
    setState(() => _newestFirst = !_newestFirst);
    _loadFirstPage();
  }

  // البحث على الإعلانات المحمّلة بس (التحميل تدريجي)
  List<AdModel> get _visibleAds {
    if (_searchQuery.isEmpty) return _ads;
    final query = _searchQuery.toLowerCase();
    return _ads.where((a) => a.text.toLowerCase().contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0E0E1A) : const Color(0xFFF8F7FF),
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
          // ✅ شريط بحث "ابحث عن إعلان" (من غير فلتر حالة — مفيش نشط/منتهي)
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
    // فشل تحميل أول صفحة ومفيش بيانات نعرضها
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
        // البحث على المحمّل بس — نسيب للمستخدم يحمّل الباقي لو لسه في المزيد
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
        // 0: صف الترتيب · 1..n: الإعلانات · n+1: تذييل التحميل + الفوتر
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

  // ✅ زر عكس الترتيب جوه جسم الشاشة: الـ AppBar مخفي لما الشاشة تتعرض
  // جوه AdsHubScreen (showAppBar: false) فزر الـ AppBar القديم مكانش ظاهر.
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

  // ✅ Fix #33: عرض الإعلان لواجهة المشتري بدون عناصر تحكم الأدمن
  // (showAdminControls: false) — الـ callbacks فاضية لأن مفيش تفعيل/حذف هنا.
  Widget _buildCard(AdModel ad, bool isDark) {
    return AdminAdCard(
      ad: ad,
      isDark: isDark,
      showAdminControls: false,
      onToggle: () {},
      onDelete: () {},
    );
  }
}
