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

  // حالة التحميل والبيانات العامة
  bool _isLoadingOverview = true;
  Map<String, dynamic>? _overviewData;

  // متغيرات تبويبات التحليل (المنتجات والعروض)
  String _productsSort = 'views';
  String _offersSort = 'views';
  List<Map<String, dynamic>> _productsList = [];
  List<Map<String, dynamic>> _offersList = [];
  
  int _productsLimit = 10; // نبدأ بـ 10 بس عشان السرعة
  int _offersLimit = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOverviewStats();
    _loadItemsStats('products');
    _loadItemsStats('offers');
  }

  // ✅ Fix #57: dispose TabController لمنع memory leak
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // تحميل النظرة العامة
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

  // تحميل قوائم المنتجات/العروض
  // ✅ QA Fix #11: تفعيل _isLoadingItems فعلياً
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
    return Column(
      children: [
        // التبويبات العلوية
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.deepPurple[900],
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.deepPurple[900],
            tabs: const [
              Tab(text: 'نظرة عامة'),
              Tab(text: 'المنتجات'),
              Tab(text: 'العروض'),
            ],
          ),
        ),

        // المحتوى
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              _buildItemsAnalysisTab(type: 'products'),
              _buildItemsAnalysisTab(type: 'offers'),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // 1. تبويب النظرة العامة (Overview)
  // ==========================================================
  Widget _buildOverviewTab() {
    if (_isLoadingOverview) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_overviewData == null) {
      return const Center(child: Text('لا توجد بيانات متاحة'));
    }

    // تحويل البيانات للرسم البياني
    final List<ChartData> chartData =
        (_overviewData!['weeklyViews'] as List? ?? [])
            .map((e) => ChartData(
                  label: e['day'] ?? '',
                  value: double.parse(e['value'].toString()),
                  color: Colors.deepPurple,
                ))
            .toList();

    // حساب أقصى قيمة للرسم البياني عشان السكيل
    double maxView = 0;
    for (var d in chartData) {
      if (d.value > maxView) {
        maxView = d.value;
      }
    }
    if (maxView == 0) {
      maxView = 10;
    } // Default

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // كروت الأداء الرئيسية
          Row(
            children: [
              _statCard('زيارات المتجر', '${_overviewData!['totalViews']}',
                  Icons.store, Colors.blue),
              _statCard('إجمالي المفضلة', '${_overviewData!['totalFavorites']}',
                  Icons.favorite, Colors.red),
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
          // ✅ قسم 6: إحصائيات التفاعل (هاتف / واتساب / سوشيال)
          Row(
            children: [
              _statCard('ضغطات الهاتف', '${_overviewData!['phoneClicks'] ?? 0}',
                  Icons.phone, Colors.teal),
              _statCard('ضغطات واتساب', '${_overviewData!['whatsappClicks'] ?? 0}',
                  Icons.chat, Colors.green[700]!),
            ],
          ),
          Row(
            children: [
              _statCard('فيسبوك', '${_overviewData!['facebookClicks'] ?? 0}',
                  Icons.facebook, Colors.blue[800]!),
              _statCard('انستجرام', '${_overviewData!['instagramClicks'] ?? 0}',
                  Icons.camera_alt, Colors.purple),
            ],
          ),

          const SizedBox(height: 20),

          // رسالة عن المنافسين
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'أنت تتنافس مع ${_overviewData!['totalCompetitors'] - 1} متاجر أخرى في نفس القسم.',
                    style: TextStyle(color: Colors.deepPurple),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          // الرسم البياني
          const Text('الزيارات اليومية (آخر 7 أيام)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          Container(
            height: 220,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200)),
            child: BarChartWidget(
              // استخدمنا BarChart عشان أوضح للأيام
              data: chartData,
              maxValue: maxView + (maxView * 0.2), // زيادة 20% هامش
              barColor: Colors.blueAccent,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // 2. تبويب تحليل المنتجات/العروض
  // ==========================================================
  Widget _buildItemsAnalysisTab({required String type}) {
    final items = type == 'products' ? _productsList : _offersList;
    String currentSort = type == 'products' ? _productsSort : _offersSort;

    return Column(
      children: [
        // شريط الفرز
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[50],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('أفضل ${type == 'products' ? 'المنتجات' : 'العروض'} أداءً',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: currentSort,
                underline: Container(),
                style: TextStyle(
                    color: Colors.deepPurple[900],
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
                items: [
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
                    _loadItemsStats(type); // إعادة تحميل بالترتيب الجديد
                  }
                },
              ),
            ],
          ),
        ),

        // القائمة
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                      'لا توجد ${type == 'products' ? 'منتجات' : 'عروض'} حتى الآن'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: items.length + 1, // +1 لزر المزيد
                  itemBuilder: (context, index) {
                    if (index == items.length) {
                      // زر عرض المزيد
                      return Padding(
                        padding: const EdgeInsets.all(20),
                        child: OutlinedButton(
                          onPressed: () =>
                              _loadItemsStats(type, loadMore: true),
                          child: const Text('عرض المزيد (Load More)'),
                        ),
                      );
                    }

                    // ✅ QA Fix #10: احسب النسبة الحقيقية من maxViews
                    final maxViews = items.isNotEmpty
                        ? items.map((i) => (i['views'] as num?)?.toInt() ?? 0).reduce((a, b) => a > b ? a : b)
                        : 1;
                    return _buildRankedItemCard(index + 1, items[index], type, maxViews: maxViews);
                  },
                ),
        ),
      ],
    );
  }

  // ==========================================================
  // 3. الودجات المساعدة
  // ==========================================================

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
      int rank, Map<String, dynamic> item, String type, {int maxViews = 1}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            // بادج الترتيب
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
            // شريط بصري للمشاهدات (Visual Indicator)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.visibility, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text('${item['views']} مشاهدة',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[800])),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // ✅ QA Fix #10: نسبة حقيقية من maxViews في القائمة
                  LayoutBuilder(builder: (ctx, constraints) {
                    final views = (item['views'] as num?)?.toInt() ?? 0;
                    final widthFactor = maxViews > 0
                        ? (views / maxViews).clamp(0.0, 1.0)
                        : 0.0;
                    return Container(
                      height: 4,
                      width: constraints.maxWidth,
                      decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(2)),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerRight,
                        widthFactor: widthFactor,
                        child: Container(
                            decoration: BoxDecoration(
                                color: Colors.deepPurple,
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