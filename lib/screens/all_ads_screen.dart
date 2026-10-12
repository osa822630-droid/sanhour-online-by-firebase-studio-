// lib/screens/all_ads_screen.dart
// ✅ شريط بحث موحّد "ابحث عن إعلان" مع فلتر الحالة (نشط / منتهي / الكل)
import 'package:flutter/material.dart';
import '../models/ad_model.dart';
import '../services/ad_service.dart';
import '../widgets/cached_image.dart';
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
  List<AdModel> _allAds = [];
  bool _isLoading = true;
  bool _newestFirst = true;
  String _searchQuery = '';
  String _statusFilter = 'الكل'; // الكل / نشط / منتهي

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  Future<void> _loadAds() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final ads = await AdService.getAllAds();
      if (!mounted) return;
      setState(() {
        _allAds = ads;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<AdModel> get _filtered {
    final now = DateTime.now();
    var result = List<AdModel>.from(_allAds);

    // فلتر الحالة
    if (_statusFilter == 'نشط') {
      result = result.where((a) {
        final expired = a.expiresAt != null && a.expiresAt!.isBefore(now);
        return a.isActive && !expired;
      }).toList();
    } else if (_statusFilter == 'منتهي') {
      result = result.where((a) {
        final expired = a.expiresAt != null && a.expiresAt!.isBefore(now);
        return !a.isActive || expired;
      }).toList();
    }

    // فلتر نص البحث
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((a) => a.text.toLowerCase().contains(q))
          .toList();
    }

    // الترتيب — AdModel لا يحتوي على createdAt، نستخدم expiresAt كمرجع
    result.sort((a, b) {
      final da = a.expiresAt ?? DateTime(2100);
      final db = b.expiresAt ?? DateTime(2100);
      return _newestFirst ? db.compareTo(da) : da.compareTo(db);
    });

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ads = _filtered;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0E0E1A) : const Color(0xFFF8F7FF),
      appBar: widget.showAppBar ? AppBar(
        title: Text(
          'الإعلانات (${_allAds.length})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          Tooltip(
            message: _newestFirst ? 'الأقدم أولاً' : 'الأحدث أولاً',
            child: IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _newestFirst
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  key: ValueKey(_newestFirst),
                ),
              ),
              onPressed: () =>
                  setState(() => _newestFirst = !_newestFirst),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAds,
          ),
        ],
      ) : null,
      body: Column(
        children: [
          // ✅ شريط بحث "ابحث عن إعلان" مع فلتر الحالة
          ContextSearchBar(
            hint: 'ابحث عن إعلان...',
            onSearch: (q) => setState(() => _searchQuery = q),
            filters: [
              SearchFilter(
                id: 'status',
                label: 'الحالة',
                options: ['الكل', 'نشط', 'منتهي'],
                defaultOption: _statusFilter,
              ),
            ],
            onFilterChanged: (id, val) {
              if (id == 'status') setState(() => _statusFilter = val);
            },
            showFilterButton: true,
          ),

          // نتائج
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF5E35B1)))
                : ads.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        color: const Color(0xFF5E35B1),
                        onRefresh: _loadAds,
                        child: ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text('${ads.length} إعلان',
                                  style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12)),
                            ),
                            ...ads.map((a) => _buildCard(a, isDark)),
                            const AppFooter(),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty || _statusFilter != 'الكل'
                  ? 'لا توجد نتائج'
                  : 'لا توجد إعلانات',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );

  // ✅ Fix #141: تفويض العرض لـ AdminAdCard المشترك — لا تكرار
  Widget _buildCard(AdModel ad, bool isDark) {
    return AdminAdCard(
      ad: ad,
      isDark: isDark,
      onToggle: () {},  // all_ads_screen view-only — no toggle
      onDelete: () {}, // view-only
    );
  }
}
