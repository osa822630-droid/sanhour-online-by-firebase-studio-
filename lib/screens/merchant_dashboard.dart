// lib/screens/merchant_dashboard.dart
// ✅ Phase 1 Fix #09: إصلاح TabController Mismatch.
// كان _tabController يُبنى بـ length: 5 دائماً في initState،
// بينما TabBar يعرض 4 أو 5 tabs بناءً على canViewShopStats.
// هذا يُسبب Assertion Error فورياً لأي تاجر بصلاحيات محدودة.
//
// الإصلاح: حساب _resolvedTabCount مرة واحدة في initState من نفس منطق
// canViewShopStats، ثم استخدامه في كلٍّ من TabController وبناء الـ tabs.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/shop.dart';
import 'add_product_screen.dart';
import 'add_offer_screen.dart';
import 'merchant/add_shop_screen.dart';
import 'merchant/edit_shop_screen.dart';
import 'merchant/merchant_reviews_screen.dart';
import 'merchant/merchant_marketing_tab.dart';
import 'merchant/merchant_products_tab.dart';
import 'merchant/merchant_offers_tab.dart';
import 'merchant/merchant_stats_tab.dart';
import 'merchant/merchant_services_tab.dart';
import '../widgets/gemini_chat_button.dart';
import 'subscription_screen.dart';
import 'merchant/team_management_screen.dart';

class MerchantDashboard extends StatefulWidget {
  const MerchantDashboard({super.key});
  @override
  State<MerchantDashboard> createState() => _MerchantDashboardState();
}

class _MerchantDashboardState extends State<MerchantDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ✅ Fix #09: الطول المحسوب مرة واحدة في initState — ثابت طوال دورة حياة الـ widget
  late int _resolvedTabCount;

  Shop? _currentShop;
  List<Shop> _myShops = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _resolvedTabCount = auth.canViewShopStats ? 5 : 4;
    _tabController =
        TabController(length: _resolvedTabCount, vsync: this);
    // ✅ Fix #82: تحديث الـ UI + تحميل الإحصائيات عند التبديل للـ stats tab
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      setState(() {});
      // الـ stats tab هو الأخير (4 أو 3 حسب الصلاحيات)
      final statsTabIndex = _resolvedTabCount - 1;
      if (_tabController.index == statsTabIndex) {
        // إعادة تحميل الإحصائيات عند الانتقال للـ tab
        _loadShopData();
      }
    });
    _loadShopData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadShopData() async {
    final user =
        Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;
    try {
      final shops = await ApiService.getMerchantShops(user.id);
      if (mounted) {
        setState(() {
          _myShops = shops;
          if (_myShops.isNotEmpty) {
            _currentShop ??= _myShops.first;
            _currentShop = _myShops.firstWhere(
              (s) => s.id == _currentShop!.id,
              orElse: () => _myShops.first,
            );
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Fix #09: canSeeStats يُقرأ من _resolvedTabCount الثابت — لا إعادة بناء للـ controller
    final canSeeStats = _resolvedTabCount == 5;
    final auth = context.watch<AuthProvider>();
    final canManageSub = auth.canManageSubscription;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('لوحة التاجر',
                style: TextStyle(fontSize: 13, color: Colors.white70)),
            Text(
              _currentShop?.name ?? 'جاري التحميل...',
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (_currentShop != null) ...[
            IconButton(
              tooltip: 'فريق العمل',
              icon: const Icon(Icons.group_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        TeamManagementScreen(shop: _currentShop!)),
              ),
            ),
            if (canManageSub)
              IconButton(
                tooltip: 'تجديد الاشتراك',
                icon: const Icon(Icons.workspace_premium_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          SubscriptionScreen(shopId: _currentShop!.id)),
                ),
              ),
            IconButton(
              tooltip: 'آراء العملاء',
              icon: const Icon(Icons.rate_review_outlined),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          MerchantReviewsScreen(shopId: _currentShop!.id))),
            ),
            IconButton(
              tooltip: 'إعدادات المتجر',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () async {
                final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            EditShopScreen(shop: _currentShop!)));
                if (result == true) _loadShopData();
              },
            ),
          ],
          _buildShopSwitcher(),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          isScrollable: true,
          // ✅ Fix #09: عدد الـ tabs = _resolvedTabCount دائماً
          tabs: [
            const Tab(
                text: 'تسويق',
                icon: Icon(Icons.campaign, size: 18)),
            const Tab(
                text: 'منتجاتي',
                icon: Icon(Icons.shopping_bag, size: 18)),
            const Tab(
                text: 'خدماتي',
                icon: Icon(Icons.miscellaneous_services, size: 18)),
            const Tab(
                text: 'عروضي',
                icon: Icon(Icons.local_offer, size: 18)),
            // يظهر فقط إذا كان _resolvedTabCount == 5
            if (canSeeStats)
              const Tab(
                  text: 'إحصائيات',
                  icon: Icon(Icons.bar_chart, size: 18)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentShop == null
              ? _buildNoShopState()
              : TabBarView(
                  controller: _tabController,
                  // ✅ Fix #09: عدد children = عدد الـ tabs دائماً
                  key: ValueKey('${_currentShop!.id}_$canSeeStats'),
                  children: [
                    MerchantMarketingTab(currentShop: _currentShop!),
                    MerchantProductsTab(currentShop: _currentShop!),
                    MerchantServicesTab(currentShop: _currentShop!),
                    MerchantOffersTab(currentShop: _currentShop!),
                    if (canSeeStats)
                      MerchantStatsTab(shopId: _currentShop!.id),
                  ],
                ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GeminiChatButton(),
          const SizedBox(height: 8),
          if (_currentShop != null) _buildFAB(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildShopSwitcher() {
    return PopupMenuButton<dynamic>(
      icon: const Icon(Icons.store_mall_directory_outlined),
      tooltip: 'تبديل المتجر',
      onSelected: (value) async {
        if (value == 'add_new') {
          final result = await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      const AddShopScreen(activationCode: '')));
          if (result == true) _loadShopData();
        } else if (value is Shop) {
          setState(() => _currentShop = value);
        }
      },
      itemBuilder: (context) => [
        if (_myShops.isNotEmpty) ...[
          const PopupMenuItem(
            enabled: false,
            child: Text('متاجرك:',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ..._myShops.map((shop) => PopupMenuItem(
                value: shop,
                child: Row(children: [
                  Icon(
                    Icons.check,
                    color: _currentShop?.id == shop.id
                        ? Colors.deepPurple
                        : Colors.transparent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(shop.name,
                          overflow: TextOverflow.ellipsis)),
                ]),
              )),
          const PopupMenuDivider(),
        ],
        const PopupMenuItem(
          value: 'add_new',
          child: Row(children: [
            Icon(Icons.add_business, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('تفعيل متجر جديد'),
          ]),
        ),
      ],
    );
  }

  Widget _buildNoShopState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.store_outlined,
                  size: 60, color: Colors.deepPurple),
            ),
            const SizedBox(height: 20),
            const Text('ليس لديك متجر نشط',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'احصل على كود تفعيل من الإدارة وأنشئ متجرك الآن',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_business),
              label: const Text('تفعيل متجر جديد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const AddShopScreen(activationCode: '')));
                if (result == true) _loadShopData();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB() {
    // index 0 = تسويق، index 3 = عروض — بدون FAB
    if (_tabController.index == 0 || _tabController.index == 3) {
      return const SizedBox.shrink();
    }
    return FloatingActionButton.extended(
      onPressed: () async {
        if (_tabController.index == 1) {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => AddProductScreen(
                      shopId: _currentShop!.id,
                      shopCategory: _currentShop!.category)));
        } else if (_tabController.index == 2) {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      AddOfferScreen(shopId: _currentShop!.id)));
        }
        setState(() {});
      },
      label: Text(_tabController.index == 1 ? 'إضافة منتج' : 'إضافة عرض'),
      icon: Icon(_tabController.index == 1
          ? Icons.add_box
          : Icons.local_offer),
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
    );
  }
}