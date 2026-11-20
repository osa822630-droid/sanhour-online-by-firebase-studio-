// lib/screens/merchant_dashboard.dart
// ✅ Phase 1 Fix #09: إصلاح TabController Mismatch.
// ✅ إخفاء أزرار إدارة الفريق وإعدادات المتجر عن أعضاء الفريق غير المالكين
import 'package:material_ui/material_ui.dart';
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
  late int _resolvedTabCount;

  static const int _productsTabIndex = 1;
  static const int _servicesTabIndex = 2;
  static const int _offersTabIndex = 3;

  int _offersRevision = 0;
  int _productsRevision = 0;

  Shop? _currentShop;
  List<Shop> _myShops = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _resolvedTabCount = auth.canViewShopStats ? 5 : 4;
    _tabController = TabController(length: _resolvedTabCount, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      final statsTabIndex = _resolvedTabCount - 1;
      if (_tabController.index == statsTabIndex) {
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
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;
    try {
      final shops = await ApiService.getMerchantShops(user.id,
          linkedShopId: user.linkedShopId);
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
    final canSeeStats = _resolvedTabCount == 5;
    final auth = context.watch<AuthProvider>();
    final canManageSub = auth.canManageSubscription;
    final isOwnerOrAdmin = auth.userRole == UserRole.admin ||
        (_currentShop != null && auth.user?.id == _currentShop!.ownerId);

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
        backgroundColor: Color(0xFF3D6B5E),
        foregroundColor: Colors.white,
        actions: [
          if (_currentShop != null) ...[
            if (isOwnerOrAdmin)
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
            if (isOwnerOrAdmin)
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
          tabAlignment: TabAlignment.start,
          tabs: [
            const Tab(text: 'تسويق', icon: Icon(Icons.campaign, size: 18)),
            const Tab(
                text: 'منتجاتي', icon: Icon(Icons.shopping_bag, size: 18)),
            const Tab(
                text: 'خدماتي',
                icon: Icon(Icons.miscellaneous_services, size: 18)),
            const Tab(text: 'عروضي', icon: Icon(Icons.local_offer, size: 18)),
            if (canSeeStats)
              const Tab(
                  text: 'إحصائيات', icon: Icon(Icons.bar_chart, size: 18)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentShop == null
              ? _buildNoShopState()
              : TabBarView(
                  controller: _tabController,
                  key: ValueKey('${_currentShop!.id}_$canSeeStats'),
                  children: [
                    MerchantMarketingTab(currentShop: _currentShop!),
                    MerchantProductsTab(
                        key: ValueKey('products_$_productsRevision'),
                        currentShop: _currentShop!),
                    MerchantServicesTab(currentShop: _currentShop!),
                    MerchantOffersTab(
                        key: ValueKey('offers_$_offersRevision'),
                        currentShop: _currentShop!),
                    if (canSeeStats)
                      MerchantStatsTab(shopId: _currentShop!.id),
                  ],
                ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabController,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GeminiChatButton(),
            const SizedBox(height: 8),
            if (_currentShop != null) _buildFAB(),
          ],
        ),
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
                  builder: (_) => const AddShopScreen(activationCode: '')));
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
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ..._myShops.map((shop) => PopupMenuItem(
                value: shop,
                child: Row(children: [
                  Icon(
                    Icons.check,
                    color: _currentShop?.id == shop.id
                        ? const Color(0xFF3D6B5E)
                        : Colors.transparent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child:
                          Text(shop.name, overflow: TextOverflow.ellipsis)),
                ]),
              )),
          const PopupMenuDivider(),
        ],
        const PopupMenuItem(
          value: 'add_new',
          child: Row(children: [
            Icon(Icons.add_business, color: Color(0xFF3D6B5E)),
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
                color: const Color(0xFF3D6B5E).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.store_outlined,
                  size: 60, color: Color(0xFF3D6B5E)),
            ),
            const SizedBox(height: 20),
            const Text('ليس لديك متجر نشط',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                backgroundColor: Color(0xFF3D6B5E),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
    final tabIndex = _tabController.index;
    if (tabIndex == _servicesTabIndex) {
      return const SizedBox(width: 56, height: 56);
    }
    if (tabIndex != _productsTabIndex && tabIndex != _offersTabIndex) {
      return const SizedBox.shrink();
    }
    final isProducts = tabIndex == _productsTabIndex;
    return FloatingActionButton.extended(
      onPressed: isProducts ? _addProduct : _addOffer,
      label: Text(isProducts ? 'إضافة منتج' : 'إضافة عرض'),
      icon: Icon(isProducts ? Icons.add_box : Icons.local_offer),
      backgroundColor: const Color(0xFF3D6B5E),
      foregroundColor: Colors.white,
    );
  }

  Future<void> _addProduct() async {
    final shop = _currentShop;
    if (shop == null) return;
    final added = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => AddProductScreen(
                shopId: shop.id, shopCategory: shop.category)));
    if (!mounted) {
      return;
    }
    if (added == true) {
      setState(() => _productsRevision++);
    }
  }

  Future<void> _addOffer() async {
    final shop = _currentShop;
    if (shop == null) return;
    final added = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => AddOfferScreen(
                shopId: shop.id, ownerId: shop.ownerId)));
    if (!mounted) return;
    if (added == true) setState(() => _offersRevision++);
  }
}