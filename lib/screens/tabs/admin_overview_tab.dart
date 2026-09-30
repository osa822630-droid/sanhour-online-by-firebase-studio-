// lib/screens/tabs/admin_overview_tab.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/api_service.dart';
import '../../models/shop.dart';
import '../../models/product.dart';
import '../../models/offer.dart';
import '../../widgets/stat_card.dart';
import '../../models/category_model.dart';
import '../../widgets/cached_image.dart';

class AdminOverviewTab extends StatefulWidget {
  const AdminOverviewTab({super.key});

  @override
  State<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<AdminOverviewTab> {
  bool _isLoading = true;
  // ✅ Fix #103: تخزين رسالة الخطأ وعرضها بدلاً من الفشل الصامت
  String? _errorMsg;

  // 📅 الفلاتر الزمنية
  String _selectedTimeFrame = 'all'; // 'today', 'week', 'month', 'all'
  DateTime _selectedDate = DateTime.now(); // لتحديد الشهر

  // 💰 البيانات المالية والإحصائية
  double _revenue = 0.0;
  double _prevRevenue = 0.0; // للمقارنة
  int _newUsers = 0;
  int _totalUsers = 0;
  int _suspendedUsers = 0;
  int _totalAds = 0;
  int _adClicks = 0;

  // 📊 البيانات الخام (يتم تحميلها وتصفيتها محلياً لتجنب كثرة الطلبات)
  List<Map<String, dynamic>> _allCodes = [];
  List<Map<String, dynamic>> _allUsers = [];
  List<dynamic> _allAds = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // ✅ QA Fix #24: استخدام count() بدلاً من جلب كل المستخدمين
  // ✅ QA Fix #15: دالة مساعدة آمنة لتحويل أي قيمة زمنية لـ DateTime
  DateTime _parseDate(dynamic raw) {
    if (raw == null) return DateTime.now();
    try {
      if (raw.runtimeType.toString().contains('Timestamp')) {
        return (raw as dynamic).toDate() as DateTime;
      }
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      if (raw is int)    return DateTime.fromMillisecondsSinceEpoch(raw);
    } catch (_) {}
    return DateTime.now();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final results = await Future.wait([
        ApiService.getAllCodes(),
        ApiService.getActiveAds(),
        firestore.collection('users').count().get(),
        firestore.collection('users')
            .where('isSuspended', isEqualTo: true)
            .count()
            .get(),
      ]);

      _allCodes = results[0] as List<Map<String, dynamic>>;
      _allAds   = results[1] as List<dynamic>;
      _totalUsers      = (results[2] as AggregateQuerySnapshot).count ?? 0;
      _suspendedUsers  = (results[3] as AggregateQuerySnapshot).count ?? 0;
      // _allUsers ليست ضرورية بعد الآن للعداد — نحتفظ بها فارغة
      _allUsers = [];

      _applyTimeFilter();
    } catch (e) {
      debugPrint('Dashboard Error: $e');
      // ✅ Fix #103: تخزين الخطأ وعرضه للمدير
      if (mounted) setState(() => _errorMsg = 'تعذّر تحميل البيانات: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 📅 منطق الفلترة الزمنية (السبت - الجمعة)
  void _applyTimeFilter() {
    final now = DateTime.now();
    DateTime start, end;

    if (_selectedTimeFrame == 'today') {
      start = DateTime(now.year, now.month, now.day);
      end = start.add(const Duration(days: 1));
    } else if (_selectedTimeFrame == 'week') {
      // الأسبوع يبدأ السبت وينتهي الجمعة
      // weekday: Mon=1 ... Sat=6, Sun=7
      int daysToSubtract =
          (now.weekday == 6) ? 0 : (now.weekday == 7 ? 1 : now.weekday + 1);
      start = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: daysToSubtract));
      end = start.add(const Duration(days: 7));
    } else if (_selectedTimeFrame == 'month') {
      start = DateTime(_selectedDate.year, _selectedDate.month, 1);
      end = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
    } else {
      start = DateTime(2020); // الكل
      end = DateTime(2030);
    }

    // الفترة السابقة للمقارنة (نفس المدة)
    final duration = end.difference(start);
    final prevStart = start.subtract(duration);
    final prevEnd = start;

    // 1. حساب الأرباح (من الأكواد المستخدمة في الفترة)
    _revenue = 0;
    _prevRevenue = 0;

    for (var code in _allCodes) {
      if (code['isUsed'] == true) {
        // نفترض وجود حقل usedAt، لو مش موجود هنستخدم createdAt مؤقتاً
        // في التطبيق الحقيقي لازم تخزن تاريخ الاستخدام 'usedAt'
        // هنا سأستخدم createdAt للتبسيط
        // ✅ QA Fix #15: _parseDate تدعم Timestamp و String و int
        final date = _parseDate(code['createdAt']);

        double val = code['code'].toString().startsWith('SHOP') ? 200 : 50;

        if (date.isAfter(start) && date.isBefore(end)) {
          _revenue += val;
        }
        if (date.isAfter(prevStart) && date.isBefore(prevEnd)) {
          _prevRevenue += val;
        }
      }
    }

    // 2. حساب المستخدمين
    _newUsers = 0;
    _suspendedUsers = 0;
    for (var user in _allUsers) {
      // ✅ QA Fix #15: _parseDate آمنة مع Timestamp
      final date = _parseDate(user['createdAt']);
      if (date.isAfter(start) && date.isBefore(end)) {
        _newUsers++;
      }
      // المحظورين (بغض النظر عن وقت التسجيل، نحسب عدد المحظورين حالياً)
      // أو ممكن نحسب اللي اتحظروا في الفترة دي لو عندنا log
      if (user['isSuspended'] == true) {
        _suspendedUsers++;
      }
    }

    // 3. الإعلانات
    _totalAds = 0;
    _adClicks = 0;
    for (var ad in _allAds) {
      final date =
          DateTime.now();
      if (date.isAfter(start) && date.isBefore(end)) {
        _totalAds++;
        // ✅ QA Fix #16: الحقل الصحيح في AdModel هو clicks وليس clickCount
        _adClicks += ((ad.clicks ?? ad.clickCount ?? 0) as num).toInt();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // ✅ Fix #103: عرض حالة الخطأ بدلاً من صفحة فارغة
    if (_errorMsg != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMsg!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadDashboardData,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. شريط الفلتر الزمني
            _buildTimeFilterBar(),
            const SizedBox(height: 20),

            // 2. كارت الأرباح
            _buildRevenueCard(),
            const SizedBox(height: 20),

            // 3. ملخص المستخدمين والإعلانات
            Row(
              children: [
                _buildStatCard('مستخدم جديد', '+$_newUsers', Icons.person_add,
                    Colors.purple),
                _buildStatCard(
                    'إعلان جديد', '+$_totalAds', Icons.campaign, Colors.deepOrangeAccent),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildStatCard(
                    'حساب محظور', '$_suspendedUsers', Icons.block, Colors.red),
                _buildStatCard(
                    'نقر إعلانات', '$_adClicks', Icons.touch_app, Colors.blue),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildStatCard(
                    'إجمالي المستخدمين', '$_totalUsers', Icons.people, Colors.teal),
                const Spacer(),
              ],
            ),

            const SizedBox(height: 30),
            const Divider(thickness: 2),
            const SizedBox(height: 10),

            // 4. أزرار التقارير التفصيلية 🚀
            const Text('التقارير التفصيلية (Leaderboards)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            _buildReportButton(
              context,
              title: '🏆 ترتيب المحلات',
              subtitle: 'الأكثر مشاهدة، تقييماً، وتفضيلاً',
              icon: Icons.store,
              color: Colors.deepPurple,
              reportType: 'shops',
            ),
            _buildReportButton(
              context,
              title: '📦 ترتيب المنتجات (Top 100)',
              subtitle: 'تحليل أداء المنتجات حسب القسم',
              icon: Icons.shopping_bag,
              color: Colors.green,
              reportType: 'products',
            ),
            _buildReportButton(
              context,
              title: '🏷️ ترتيب العروض (Top 100)',
              subtitle: 'العروض الأكثر جاذبية للعملاء',
              icon: Icons.local_offer,
              color: Colors.deepOrangeAccent,
              reportType: 'offers',
            ),
          ],
        ),
      ),
    );
  }

  // --- Widgets ---

  Widget _buildTimeFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('الفترة:', style: TextStyle(fontWeight: FontWeight.bold)),
          DropdownButton<String>(
            value: _selectedTimeFrame,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'today', child: Text('اليوم')),
              DropdownMenuItem(
                  value: 'week', child: Text('هذا الأسبوع (السبت-الجمعة)')),
              DropdownMenuItem(value: 'month', child: Text('شهر محدد')),
              DropdownMenuItem(value: 'all', child: Text('منذ البداية')),
            ],
            onChanged: (val) async {
              if (val == 'month') {
                final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2023),
                    lastDate: DateTime.now());
                if (picked != null) {
                  setState(() {
                    _selectedDate = picked;
                    _selectedTimeFrame = val!;
                    _applyTimeFilter();
                  });
                }
              } else {
                setState(() {
                  _selectedTimeFrame = val!;
                  _applyTimeFilter();
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueCard() {
    final currencyFormat =
        NumberFormat.currency(locale: 'ar_EG', symbol: 'ج.م');
    bool isUp = _revenue >= _prevRevenue;
    double diff = _prevRevenue == 0
        ? 100
        : ((_revenue - _prevRevenue) / _prevRevenue) * 100;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.green.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          const Text('صافي الأرباح (الفترة المحددة)',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 5),
          Text(
            currencyFormat.format(_revenue),
            style: const TextStyle(
                color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (_selectedTimeFrame != 'all')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${diff.abs().toStringAsFixed(1)}% مقارنة بالسابق',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            )
        ],
      ),
    );
  }

  // ✅ Fix #142: الآن يُستخدم StatCard المشترك بدلاً من دالة محلية
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return StatCard(title: title, value: value, icon: icon, color: color);
  }

  Widget _buildReportButton(BuildContext context,
      {required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required String reportType}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing:
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () {
          // فتح شاشة التقرير التفصيلي
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => DetailedReportScreen(reportType: reportType)),
          );
        },
      ),
    );
  }
}

// =========================================================
// 🚀 شاشة التقارير التفصيلية (Detailed Report Screen)
// =========================================================

class DetailedReportScreen extends StatefulWidget {
  final String reportType; // 'shops', 'products', 'offers'
  const DetailedReportScreen({super.key, required this.reportType});

  @override
  State<DetailedReportScreen> createState() => _DetailedReportScreenState();
}

class _DetailedReportScreenState extends State<DetailedReportScreen> {
  bool _isLoading = true;
  List<dynamic> _items = [];

  // الفلاتر
  List<CategoryModel> _categories = [];
  String _selectedCategory = 'الكل';
  String _sortBy = 'views'; // 'views', 'rating', 'favorites'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. تحميل الأقسام للفلتر
      if (_categories.isEmpty) {
        _categories =
            await ApiService.getCategories(); // لازم تكون في ApiService
      }

      // 2. تحميل البيانات بناءً على النوع والفلتر
      List<dynamic> data = [];
      if (widget.reportType == 'shops') {
        data = await ApiService.getRankedShops(category: _selectedCategory);
      } else if (widget.reportType == 'products') {
        data = await ApiService.getTopProducts(category: _selectedCategory);
      } else if (widget.reportType == 'offers') {
        // للعروض: بنجيب الكل وبعدين نفلتر لو مفيش دالة فلتر مباشرة
        // أو نستخدم دالة TopOffers اللي عملناها
        // لو الـ Offer Model مفيهوش category، الفلتر ده مش هيشتغل كويس إلا لو عدلت الموديل
        data = await ApiService.getTopOffers();
      }

      // 3. الترتيب المحلي (Client-side Sorting) للمرونة
      if (_sortBy == 'views') {
        data.sort((a, b) => (b.views ?? 0).compareTo(a.views ?? 0));
      } else if (_sortBy == 'rating') {
        // تأكد ان الموديلات فيها rating
        data.sort((a, b) {
          double rateA =
              (a is Shop) ? (a.rating) : (a is Product ? a.rating : 0.0);
          double rateB =
              (b is Shop) ? (b.rating) : (b is Product ? b.rating : 0.0);
          return rateB.compareTo(rateA);
        });
      } else if (_sortBy == 'favorites') {
        data.sort(
            (a, b) => (b.favoriteCount ?? 0).compareTo(a.favoriteCount ?? 0));
      }

      if (mounted) {
        setState(() {
          _items = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = widget.reportType == 'shops'
        ? 'تقرير المحلات'
        : (widget.reportType == 'products' ? 'تقرير المنتجات' : 'تقرير العروض');

    return Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: Colors.deepPurple[900]),
      body: Column(
        children: [
          // شريط الفلاتر
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                // فلتر الأقسام
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('الكل'),
                      ..._categories.map((c) => _buildFilterChip(c.name)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // فلتر الترتيب
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ترتيب حسب:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      value: _sortBy,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                            value: 'views', child: Text('👁️ الأكثر مشاهدة')),
                        DropdownMenuItem(
                            value: 'rating', child: Text('⭐ الأعلى تقييماً')),
                        DropdownMenuItem(
                            value: 'favorites',
                            child: Text('❤️ الأكثر تفضيلاً')),
                      ],
                      onChanged: (val) {
                        setState(() => _sortBy = val!);
                        _loadData(); // إعادة الترتيب
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // القائمة
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(child: Text('لا توجد نتائج'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return _buildRankItem(item, index + 1);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    bool isSelected = _selectedCategory == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {
          if (val) {
            setState(() => _selectedCategory = label);
            _loadData();
          }
        },
      ),
    );
  }

  Widget _buildRankItem(dynamic item, int rank) {
    String name = '';
    String sub = '';
    String img = '';
    String metric = '';

    if (item is Shop) {
      name = item.name;
      sub = item.category;
      img = item.imageUrl;
      if (_sortBy == 'rating') {
        metric = '${item.rating} ⭐';
      } else if (_sortBy == 'favorites') {
        metric = '${item.favoriteCount} ❤️';
      } else {
        metric = '${item.views} 👁️';
      }
    } else if (item is Product) {
      name = item.name;
      sub = '${item.price} ج.م';
      img = item.imageUrls.isNotEmpty ? item.imageUrls.first : '';
      if (_sortBy == 'rating') {
        metric = '${item.rating} ⭐';
      } else if (_sortBy == 'favorites') {
        metric = '${item.favoriteCount} ❤️';
      } else {
        metric = '${item.views} 👁️';
      }
    } else if (item is Offer) {
      name = item.title;
      sub = 'خصم ${item.discount}%';
      img = item.imageUrl;
      metric = '${item.views} 👁️';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: SizedBox(
          width: 80,
          child: Row(
            children: [
              Text('#$rank',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: rank <= 3 ? Colors.amber[800] : Colors.grey)),
              const SizedBox(width: 8),
              ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedImage(
                      imageUrl: img, width: 40, height: 40, fit: BoxFit.cover)),
            ],
          ),
        ),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(sub),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
          child: Text(metric,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.blue)),
        ),
      ),
    );
  }
}