// lib/screens/merchant/merchant_stats_tab.dart
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/analytics_charts.dart';
import '../../widgets/cached_image.dart';

class MerchantStatsTab extends StatefulWidget {
  final String shopId;
  const MerchantStatsTab({super.key, required this.shopId});

  @override
  State<MerchantStatsTab> createState() => _MerchantStatsTabState();
}

class _MerchantStatsTabState extends State<MerchantStatsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoadingOverview = true;
  Map<String, dynamic>? _overviewData;

  String _productsSort = 'views';
  String _offersSort = 'views';
  List<Map<String, dynamic>> _productsList = [];
  List<Map<String, dynamic>> _offersList = [];

  int _productsLimit = 10;
  int _offersLimit = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOverviewStats();
    _loadItemsStats('products');
    _loadItemsStats('offers');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOverviewStats() async {
    try {
      final data = await ApiService.getMerchantAdvancedStats(widget.shopId);
      if (mounted) {
        setState(() {
          _overviewData = data;
          _isLoadingOverview = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
      if (mounted) {
        setState(() => _isLoadingOverview = false);
      }
    }
  }

  Future<void> _loadItemsStats(String type, {bool loadMore = false}) async {
    if (loadMore) {
      setState(() {
        if (type == 'products') {
          _productsLimit += 20;
        } else {
          _offersLimit += 20;
        }
      });
    }
    if (!mounted) return;

    try {
      final data = await ApiService.getTopItems(
        shopId: widget.shopId,
        type: type,
        sortBy: type == 'products' ? _productsSort : _offersSort,
        limit: type == 'products' ? _productsLimit : _offersLimit,
      );
      if (mounted) {
        setState(() {
          if (type == 'products') {
            _productsList = data;
          } else {
            _offersList = data;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading items stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: isDark
                ? const Color(0xFFB39DDB)
                : const Color(0xFF5E35B1),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF5E35B1),
            tabs: const [
              Tab(text: 'نظرة عامة'),
              Tab(text: 'المنتجات'),
              Tab(text: 'العروض'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(isDark),
              _buildItemsAnalysisTab(type: 'products', isDark: isDark),
              _buildItemsAnalysisTab(type: 'offers', isDark: isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab(bool isDark) {
    if (_isLoadingOverview) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_overviewData == null) {
      return const Center(child: Text('لا توجد بيانات متاحة'));
    }

    final List<ChartData> chartData =
        (_overviewData!['weeklyViews'] as List? ?? [])
            .map((e) => ChartData(
                  label: e['day'] ?? '',
                  value: double.parse(e['value'].toString()),
                  color: const Color(0xFF5E35B1),
                ))
            .toList();

    double maxView = 0;
    for (var d in chartData) {
      if (d.value > maxView) {
        maxView = d.value;
      }
    }
    if (maxView == 0) {
      maxView = 10;
    }

    final totalCompetitors =
        ((_overviewData!['totalCompetitors'] as num?)?.toInt() ?? 1)
            .clamp(1, 999999);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statCard('زيارات المتجر', '${_overviewData!['totalViews']}',
                  Icons.store, Colors.blue),
              _statCard('إجمالي المفضلة',
                  '${_overviewData!['totalFavorites']}', Icons.favorite,
                  Colors.red),
            ],
          ),
          Row(
            children: [
              _statCard('التقييم العام', '${_overviewData!['avgRating']} ⭐',
                  Icons.star, Colors.amber),
              _statCard('ترتيبك في القسم', '#${_overviewData!['rank']}',
                  Icons.leaderboard, Colors.green),
            ],
          ),
          Row(
            children: [
              _statCard('ضغطات الهاتف',
                  '${_overviewData!['phoneClicks'] ?? 0}', Icons.phone,
                  Colors.teal),
              _statCard('ضغطات واتساب',
                  '${_overviewData!['whatsappClicks'] ?? 0}', Icons.chat,
                  Colors.green[700]!),
            ],
          ),
          Row(
            children: [
              _statCard('فيسبوك', '${_overviewData!['facebookClicks'] ?? 0}',
                  Icons.facebook, Colors.blue[800]!),
              _statCard('انستجرام',
                  '${_overviewData!['instagramClicks'] ?? 0}',
                  Icons.camera_alt, Colors.purple),
            ],
          ),
          Row(
            children: [
              _statCard('تيك توك', '${_overviewData!['tiktokClicks'] ?? 0}',
                  Icons.video_collection, Colors.pink),
              _statCard('تيليجرام', '${_overviewData!['telegramClicks'] ?? 0}',
                  Icons.send, const Color(0xFF2CA5E0)),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'أنت تتنافس مع ${totalCompetitors - 1} متاجر أخرى في نفس القسم.',
                    style: TextStyle(
                        color: isDark
                            ? Colors.green[300]
                            : const Color(0xFF5E35B1)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          const Text('الزيارات اليومية (آخر 7 أيام)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          Container(
            height: 220,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade200)),
            child: BarChartWidget(
              data: chartData,
              maxValue: maxView + (maxView * 0.2),
              barColor: Colors.blueAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsAnalysisTab({required String type, required bool isDark}) {
    final items = type == 'products' ? _productsList : _offersList;
    String currentSort = type == 'products' ? _productsSort : _offersSort;
    final maxViews = items.isNotEmpty
        ? items
            .map((i) => (i['views'] as num?)?.toInt() ?? 0)
            .reduce((a, b) => a > b ? a : b)
        : 1;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[50],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('أفضل ${type == 'products' ? 'المنتجات' : 'العروض'} أداءً',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: currentSort,
                underline: Container(),
                style: TextStyle(
                    color: isDark
                        ? const Color(0xFFB39DDB)
                        : const Color(0xFF5E35B1),
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
                items: const [
                  DropdownMenuItem(
                      value: 'views', child: Text('الأعلى مشاهدة 🔥')),
                  DropdownMenuItem(
                      value: 'rating', child: Text('الأعلى تقييماً ⭐')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      if (type == 'products') {
                        _productsSort = val;
                      } else {
                        _offersSort = val;
                      }
                    });
                    _loadItemsStats(type);
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                      'لا توجد ${type == 'products' ? 'منتجات' : 'عروض'} حتى الآن'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: items.length + 1,
                  itemBuilder: (context, index) {
                    if (index == items.length) {
                      return Padding(
                        padding: const EdgeInsets.all(20),
                        child: OutlinedButton(
                          onPressed: () =>
                              _loadItemsStats(type, loadMore: true),
                          child: const Text('عرض المزيد'),
                        ),
                      );
                    }
                    return _buildRankedItemCard(
                        index + 1, items[index], type, isDark,
                        maxViews: maxViews);
                  },
                ),
        ),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 10),
              Text(value,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text(title,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankedItemCard(
      int rank, Map<String, dynamic> item, String type, bool isDark,
      {int maxViews = 1}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          alignment: Alignment.topLeft,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedImage(
                imageUrl: item['image'],
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: rank <= 3 ? Colors.amber : Colors.grey,
                shape: BoxShape.circle,
              ),
              child: Text('$rank',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        title: Text(item['name'] ?? '---',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.visibility,
                          size: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text('${item['views']} مشاهدة',
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey[300]
                                  : Colors.grey[800])),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LayoutBuilder(builder: (ctx, constraints) {
                    final views = (item['views'] as num?)?.toInt() ?? 0;
                    final widthFactor = maxViews > 0
                        ? (views / maxViews).clamp(0.0, 1.0)
                        : 0.0;
                    return Container(
                      height: 4,
                      width: constraints.maxWidth,
                      decoration: BoxDecoration(
                          color: isDark ? Colors.white12 : Colors.blue[100],
                          borderRadius: BorderRadius.circular(2)),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerRight,
                        widthFactor: widthFactor,
                        child: Container(
                            decoration: BoxDecoration(
                                color: const Color(0xFF5E35B1),
                                borderRadius: BorderRadius.circular(2))),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star, size: 16, color: Colors.amber),
            Text('${item['rating']}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}