// lib/screens/favorites_screen.dart
// ✅ إصلاح مشكلة المساحة الفارغة في TabBar — TabAlignment.fill لملء العرض الكامل
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/search_bar.dart';
import '../widgets/cached_image.dart';
import 'detail_screen.dart';
import 'collection_detail_screen.dart';
import 'login_screen.dart';
import '../services/analytics_service.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isNotificationEnabled = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    AnalyticsService().logScreenView('favorites');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleNotifications() {
    setState(() => _isNotificationEnabled = !_isNotificationEnabled);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        _isNotificationEnabled
            ? 'تم تفعيل التنبيهات 🔔'
            : 'تم تعطيل التنبيهات 🔕',
      ),
      backgroundColor:
          _isNotificationEnabled ? Colors.green : Colors.grey,
      duration: const Duration(seconds: 1),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isGuest) {
      return _buildGuestView(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'المفضلة',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _toggleNotifications,
            icon: Icon(
              _isNotificationEnabled
                  ? Icons.notifications_active
                  : Icons.notifications_off_outlined,
              color: _isNotificationEnabled
                  ? Colors.amber
                  : Colors.white,
            ),
          ),
        ],
        // ✅ إصلاح TabBar: isScrollable: false مع tabAlignment لملء العرض الكامل
        // يمنع المساحة الفارغة ويجعل الأيقونات ثابتة في أماكنها
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: false, // ← الإصلاح الأساسي للمساحة الفارغة
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          tabs: const [
            Tab(text: 'قوائمي', icon: Icon(Icons.collections_bookmark, size: 16)),
            Tab(text: 'محلات',  icon: Icon(Icons.store, size: 16)),
            Tab(text: 'منتجات', icon: Icon(Icons.shopping_bag, size: 16)),
            Tab(text: 'عروض',   icon: Icon(Icons.local_offer, size: 16)),
            Tab(text: 'خدمات',  icon: Icon(Icons.handyman, size: 16)),
          ],
        ),
      ),
      body: Column(
        children: [
          const SearchBarWidget(),
          Expanded(
            child: Consumer<FavoritesProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                return RefreshIndicator(
                  color: const Color(0xFF5E35B1),
                  onRefresh: () => provider.loadFavorites(),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCollectionsGrid(provider),
                      _buildList(provider.favoriteShops,
                          'لا توجد محلات مفضلة', 'shop', provider),
                      _buildList(provider.favoriteProducts,
                          'لا توجد منتجات مفضلة', 'product', provider),
                      _buildList(provider.favoriteOffers,
                          'لا توجد عروض مفضلة', 'offer', provider),
                      _buildList(provider.favoriteServices,
                          'لا توجد خدمات مفضلة', 'service', provider),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── شاشة الزوار ─────────────────────────────────────────────────────
  Widget _buildGuestView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المفضلة',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite_border,
                    size: 48, color: Colors.deepPurple),
              ),
              const SizedBox(height: 24),
              const Text(
                'المفضلة خاصة بالأعضاء',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'سجّل دخولك لحفظ المحلات والمنتجات والعروض في مفضلتك وإنشاء قوائم تسوق مشتركة مع عائلتك.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey, fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  icon: const Icon(Icons.login),
                  label: const Text('تسجيل الدخول',
                      style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildFeatureRow(
                  Icons.collections_bookmark, 'أنشئ قوائم تسوق مشتركة'),
              _buildFeatureRow(
                  Icons.notifications_active, 'تنبيهات عند تغيّر السعر'),
              _buildFeatureRow(
                  Icons.favorite, 'احفظ محلاتك وعروضك المفضلة'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, color: Colors.deepPurple, size: 20),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontSize: 14)),
      ]),
    );
  }

  // ── القوائم (Collections) ────────────────────────────────────────────
  Widget _buildCollectionsGrid(FavoritesProvider provider) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: provider.collections.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return InkWell(
            onTap: () => _showCreateCollectionDialog(context, provider),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.deepPurple.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline,
                      size: 40, color: Colors.deepPurple),
                  SizedBox(height: 10),
                  Text(
                    'قائمة جديدة',
                    style: TextStyle(
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }
        final collection = provider.collections[index - 1];
        final coverImage = collection.items.isNotEmpty
            ? collection.items.last.imageUrl
            : '';
        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CollectionDetailScreen(collection: collection),
            ),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                    image: coverImage.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(coverImage),
                            fit: BoxFit.cover)
                        : null,
                  ),
                  child: coverImage.isEmpty
                      ? const Center(
                          child: Icon(Icons.folder_open,
                              size: 40, color: Colors.grey))
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                collection.name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${collection.items.length} عنصر',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── القوائم العامة ───────────────────────────────────────────────────
  Widget _buildList(
    List<dynamic> items,
    String emptyMsg,
    String type,
    FavoritesProvider provider,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text(emptyMsg, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        String title = '', subtitle = '', imageUrl = '';
        if (type == 'shop' || type == 'service') {
          title = item.name;
          subtitle = item.category;
          imageUrl = item.imageUrl;
        } else if (type == 'product') {
          title = item.name;
          subtitle = '${item.price.toStringAsFixed(0)} جنيه';
          imageUrl =
              item.imageUrls.isNotEmpty ? item.imageUrls.first : '';
        } else if (type == 'offer') {
          title = item.title;
          subtitle = 'خصم ${item.discount}%';
          imageUrl = item.imageUrl;
        }
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                  width: 52,
                  height: 52,
                  child: CachedImage(imageUrl: imageUrl)),
            ),
            title: Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(subtitle),
            trailing: IconButton(
              icon: const Icon(Icons.favorite, color: Colors.red),
              onPressed: () =>
                  provider.toggleFavorite(item, explicitType: type),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
            ),
          ),
        );
      },
    );
  }

  void _showCreateCollectionDialog(
      BuildContext context, FavoritesProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إنشاء قائمة جديدة'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'اسم القائمة (مثلاً: تجهيزات رمضان)',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                provider.createCollection(
                    controller.text.trim(), false);
                Navigator.pop(ctx);
              }
            },
            child: const Text('إنشاء',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    // ✅ Fix #66: dispose controller بعد إغلاق الـ dialog
    ).whenComplete(() => controller.dispose());
  }
}
