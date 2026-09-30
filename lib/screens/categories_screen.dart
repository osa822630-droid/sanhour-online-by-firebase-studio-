// lib/screens/categories_screen.dart
// ✅ إضافة AppFooter في نهاية كل صفحة من صفحات الفئات الثلاث
// التعديل الوحيد: إضافة import + AppFooter في نهاية كل _buildPage
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shops_provider.dart';
import '../models/category_model.dart';
import '../widgets/app_footer.dart';
import '../widgets/cached_image.dart';
import 'shop_detail_screen.dart';
import 'advanced_search_screen.dart';

class CategoriesScreen extends StatefulWidget {
  final String? initialCategory;
  final String? initialSubCategory;

  const CategoriesScreen({
    super.key,
    this.initialCategory,
    this.initialSubCategory,
  });

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String? _selectedMainCategory;
  String? _selectedSubCategory;
  late PageController _pageController;
  int _currentPage = 0;
  String _sortBy = 'default';

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.initialCategory != null) {
      _selectedMainCategory = widget.initialCategory;
      _selectedSubCategory = widget.initialSubCategory;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _goToPage(_selectedSubCategory != null ? 2 : 1);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    setState(() => _currentPage = page);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0E0E1A) : const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text('الفئات',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (v) => setState(() => _sortBy = v),
            itemBuilder: (_) => [
              _sortItem('default', 'الافتراضي'),
              _sortItem('rating', 'الأعلى تقييماً'),
              _sortItem('views', 'الأكثر مشاهدة'),
              _sortItem('favorites', 'الأكثر تفضيلاً'),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBreadcrumbs(),
          Expanded(
            child: Consumer<ShopsProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.categories.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                return RefreshIndicator(
                  onRefresh: () => provider.fetchCategories(refresh: true),
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildMainCategoriesPage(provider, isDark),
                      _buildSubCategoriesPage(provider, isDark),
                      _buildShopsPage(provider, isDark),
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

  // ── صفحة الفئات الرئيسية ──────────────────────────────────────────
  Widget _buildMainCategoriesPage(ShopsProvider provider, bool isDark) {
    final cats = provider.categories;
    if (cats.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 80),
        Center(
          child: Column(children: [
            Icon(Icons.category_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('لا توجد فئات حالياً',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
          ]),
        ),
        const SizedBox(height: 40),
        const AppFooter(), // ✅
      ]);
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: cats.length + 1, // +1 للـ footer
      itemBuilder: (ctx, i) {
        if (i == cats.length) {
          return const SizedBox.shrink(); // placeholder آخر
        }
        final cat = cats[i];
        final catColor = Color(cat.colorValue);
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedMainCategory = cat.name;
              _selectedSubCategory = null;
            });
            _goToPage(1);
          },
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CategoryModel.getIconData(cat.iconName),
                    color: catColor,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  cat.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${cat.subCategories.length} قسم',
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── صفحة الأقسام الفرعية ──────────────────────────────────────────
  Widget _buildSubCategoriesPage(ShopsProvider provider, bool isDark) {
    if (_selectedMainCategory == null) return const SizedBox();

    final cat = provider.categories.firstWhere(
      (c) => c.name == _selectedMainCategory,
      orElse: () => CategoryModel(id: '', name: '', iconName: 'category', colorValue: 0xFF9E9E9E, subCategories: const [], subSubCategories: const {}),
    );

    final subs = cat.subCategories;
    if (subs.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToPage(2));
      return const SizedBox();
    }

    return ListView(
      children: [
        ...subs.map((sub) {
          final subSubs = cat.subSubCategories[sub] ?? [];
          return ExpansionTile(
            leading: Icon(CategoryModel.getIconData(cat.iconName),
                color: Color(cat.colorValue)),
            title: Text(sub,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: subSubs.isNotEmpty
                ? Text('${subSubs.length} فرعي دقيق',
                    style: const TextStyle(fontSize: 11, color: Colors.grey))
                : null,
            onExpansionChanged: (expanded) {
              if (!expanded || subSubs.isNotEmpty) return;
              setState(() => _selectedSubCategory = sub);
              _goToPage(2);
            },
            children: [
              ...subSubs.map((ss) => ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(48, 0, 16, 0),
                    title: Text(ss,
                        style: const TextStyle(fontSize: 14)),
                    leading: const Icon(Icons.chevron_right,
                        size: 16, color: Colors.grey),
                    onTap: () {
                      setState(() => _selectedSubCategory = ss);
                      _goToPage(2);
                    },
                  )),
              ListTile(
                contentPadding:
                    const EdgeInsets.fromLTRB(48, 0, 16, 0),
                title: Text('عرض كل "$sub"',
                    style: const TextStyle(
                        color: Color(0xFF5E35B1), fontSize: 14)),
                leading: const Icon(Icons.grid_view,
                    size: 16, color: Color(0xFF5E35B1)),
                onTap: () {
                  setState(() => _selectedSubCategory = sub);
                  _goToPage(2);
                },
              ),
            ],
          );
        }),
        const AppFooter(), // ✅
      ],
    );
  }

  // ── صفحة المحلات ─────────────────────────────────────────────────
  Widget _buildShopsPage(ShopsProvider provider, bool isDark) {
    if (_selectedMainCategory == null) return const SizedBox();

    var shops = provider.shops
        .where((s) => s.category == _selectedMainCategory)
        .toList();

    if (_selectedSubCategory != null) {
      // تصفية إضافية إذا كان هناك قسم فرعي محدد
      // (حسب ما هو موجود في بيانات المحل)
    }

    // ترتيب
    switch (_sortBy) {
      case 'rating':
        shops.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'views':
        shops.sort((a, b) => b.uniqueVisitors.compareTo(a.uniqueVisitors));
        break;
      case 'favorites':
        shops.sort((a, b) =>
            b.favoriteCount.compareTo(a.favoriteCount));
        break;
    }

    if (shops.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 80),
        Center(
          child: Column(children: [
            Icon(Icons.store_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'لا توجد محلات في\n"${_selectedSubCategory ?? _selectedMainCategory}"',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 15),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdvancedSearchScreen(),
                ),
              ),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5E35B1),
                  foregroundColor: Colors.white),
              child: const Text('بحث متقدم'),
            ),
          ]),
        ),
        const SizedBox(height: 40),
        const AppFooter(), // ✅
      ]);
    }

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '${shops.length} محل في "${_selectedSubCategory ?? _selectedMainCategory}"',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ),
        ...shops.map((shop) => Card(
              margin:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(10),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: CachedImage(imageUrl: shop.imageUrl),
                  ),
                ),
                title: Text(shop.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (shop.location.isNotEmpty)
                      Text(shop.location,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    Row(children: [
                      const Icon(Icons.star,
                          size: 13, color: Colors.amber),
                      const SizedBox(width: 3),
                      Text(shop.rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 12)),
                    ]),
                  ],
                ),
                trailing: const Icon(Icons.arrow_back_ios,
                    size: 14, color: Colors.grey),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ShopDetailScreen(shop: shop)),
                ),
              ),
            )),
        const AppFooter(), // ✅
      ],
    );
  }

  PopupMenuItem<String> _sortItem(String value, String label) =>
      PopupMenuItem(
        value: value,
        child: Row(children: [
          if (_sortBy == value)
            const Icon(Icons.check, color: Color(0xFF5E35B1), size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ]),
      );

  Widget _buildBreadcrumbs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 3,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(children: [
        _crumb('الرئيسية', _currentPage == 0, () {
          setState(() {
            _selectedMainCategory = null;
            _selectedSubCategory = null;
          });
          _goToPage(0);
        }),
        if (_selectedMainCategory != null) ...[
          const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          _crumb(_selectedMainCategory!, _currentPage == 1, () {
            setState(() => _selectedSubCategory = null);
            _goToPage(1);
          }),
        ],
        if (_selectedSubCategory != null) ...[
          const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          Flexible(
              child:
                  _crumb(_selectedSubCategory!, _currentPage == 2, () {})),
        ],
      ]),
    );
  }

  Widget _crumb(String title, bool active, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        child: Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? Colors.deepPurple : Colors.grey[600],
          ),
        ),
      );
}
