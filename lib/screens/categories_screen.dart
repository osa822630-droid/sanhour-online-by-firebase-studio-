// lib/screens/categories_screen.dart
// ✅ إعادة تصميم كاملة: نظام Chips هرمي بدلاً من الصفحات المنفصلة (PageView)
// — اختيار فئة رئيسية يعرض محتواها كاملاً فوراً من السيرفر + شريط chips للفئات
// الفرعية أعلى القائمة. اختيار فئة فرعية يعرض شريط chips ثانٍ تحته مباشرةً
// للفئات الفرعية الدقيقة (subSubCategories).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../providers/shops_provider.dart';
import '../models/category_model.dart';
import '../models/shop.dart';
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

  /// يسمح بالتبديل البرمجي لفئة محددة مع إبقاء الشريط السفلي ظاهراً
  static final ValueNotifier<String?> categoryRequest =
      ValueNotifier<String?>(null);

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  CategoryModel? _selectedCategory;
  String? _selectedSubCategory;
  String? _selectedSubSubCategory;
  String _sortBy = 'default';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<Shop> _categoryShops = [];
  bool _loadingCategoryShops = false;

  @override
  void initState() {
    super.initState();
    CategoriesScreen.categoryRequest.addListener(_onCategoryRequested);
    final req = CategoriesScreen.categoryRequest.value ?? widget.initialCategory;
    if (req != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _applyCategoryByName(req));
    }
  }

  @override
  void dispose() {
    CategoriesScreen.categoryRequest.removeListener(_onCategoryRequested);
    _searchController.dispose();
    super.dispose();
  }

  void _onCategoryRequested() {
    final req = CategoriesScreen.categoryRequest.value;
    if (req != null && mounted) {
      CategoriesScreen.categoryRequest.value = null;
      _applyCategoryByName(req);
    }
  }

  void _applyCategoryByName(String categoryName) {
    if (!mounted) return;
    final provider = context.read<ShopsProvider>();
    CategoryModel? match;
    for (final c in provider.categories) {
      if (c.name == categoryName) {
        match = c;
        break;
      }
    }
    if (match == null) return;
    _selectCategory(match, subCategory: widget.initialSubCategory);
  }

  Future<void> _selectCategory(CategoryModel cat,
      {String? subCategory, bool forceRefresh = false}) async {
    setState(() {
      _selectedCategory = cat;
      _selectedSubCategory = subCategory;
      _selectedSubSubCategory = null;
      _searchQuery = '';
      _searchController.clear();
      _loadingCategoryShops = true;
    });

    try {
      final snap = await FirebaseFirestore.instance
          .collection('shops')
          .where('isSuspended', isEqualTo: false)
          .where('category', isEqualTo: cat.name)
          .limit(100)
          .get();
      if (!mounted) return;
      final fetched =
          snap.docs.map((d) => Shop.fromMap(d.data(), d.id)).toList();
      setState(() {
        _categoryShops = fetched;
        _loadingCategoryShops = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingCategoryShops = false;
      });
    }
  }

  void _resetToGrid() {
    setState(() {
      _selectedCategory = null;
      _selectedSubCategory = null;
      _selectedSubSubCategory = null;
      _categoryShops = [];
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _selectSubCategory(String? sub) {
    setState(() {
      _selectedSubCategory = sub;
      _selectedSubSubCategory = null;
    });
  }

  void _selectSubSubCategory(String? subSub) {
    setState(() => _selectedSubSubCategory = subSub);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121514) : const Color(0xFFF7F7F5),
      appBar: AppBar(
        title: Text(_selectedCategory?.name ?? 'الفئات',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF3D6B5E),
        foregroundColor: Colors.white,
        centerTitle: true,
        leading: _selectedCategory != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _resetToGrid,
              )
            : null,
        actions: _selectedCategory == null
            ? null
            : [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.swap_vert_rounded),
                  tooltip: 'ترتيب النتائج',
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
      body: Consumer<ShopsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.categories.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null && provider.categories.isEmpty) {
            return _buildErrorState(provider);
          }
          return _selectedCategory == null
              ? _buildCategoryGrid(provider, isDark)
              : _buildCategoryContent(provider, isDark);
        },
      ),
    );
  }

  Widget _buildSearchField(bool isDark, String hint) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded, size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: isDark ? const Color(0xFF1B201E) : Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF3A3461) : Colors.grey.shade300,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF3A3461) : Colors.grey.shade300,
            ),
          ),
        ),
      ),
    );
  }

  // ── شبكة الفئات الرئيسية (إخفاء الفئات الفارغة + بحث مدمج) ───────────
  Widget _buildCategoryGrid(ShopsProvider provider, bool isDark) {
    final activeCatNames =
        provider.shops.map((s) => s.category.trim()).toSet();
    final cats = provider.categories.where((c) {
      if (!activeCatNames.contains(c.name.trim())) return false;
      if (_searchQuery.isNotEmpty) {
        return c.name.toLowerCase().contains(_searchQuery);
      }
      return true;
    }).toList();
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
        const AppFooter(),
      ]);
    }

    return Column(
      children: [
        _buildSearchField(isDark, 'ابحث في الفئات...'),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                provider.fetchCategories(refresh: true),
                provider.fetchShops(refresh: true),
              ]);
            },
            color: const Color(0xFF3D6B5E),
            child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: cats.length,
        itemBuilder: (ctx, i) {
          final cat = cats[i];
          final catColor = Color(cat.colorValue);
          return GestureDetector(
            onTap: () => _selectCategory(cat),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B201E) : Colors.white,
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
                    child: Icon(CategoryModel.getIconData(cat.iconName),
                        color: catColor, size: 28),
                  ),
                  const SizedBox(height: 10),
                  Text(cat.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('${cat.subCategories.length} قسم',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                ],
              ),
            ),
          );
        },
            ),
          ),
        ),
      ],
    );
  }

  // ── محتوى الفئة المختارة: chips هرمية + قائمة المحلات ────────────
  Widget _buildCategoryContent(ShopsProvider provider, bool isDark) {
    final cat = _selectedCategory!;
    final allCatShops = _categoryShops.isNotEmpty
        ? _categoryShops
        : provider.shops
            .where((s) => s.category.trim() == cat.name.trim())
            .toList();

    // ✅ إخفاء الفئات الفرعية الفارغة
    final nonEmptySubs = cat.subCategories.where((sub) {
      final subNorm = sub.trim();
      return allCatShops.any((s) =>
          s.name.contains(subNorm) ||
          s.description.contains(subNorm) ||
          (s.searchKeywords?.any((k) => k.contains(subNorm)) ?? false));
    }).toList();

    // ✅ إخفاء الفئات الدقيقة الفارغة
    final rawSubSubs = _selectedSubCategory == null
        ? const <String>[]
        : (cat.subSubCategories[_selectedSubCategory] ?? const <String>[]);
    final nonEmptySubSubs = rawSubSubs.where((ss) {
      final ssNorm = ss.trim();
      return allCatShops.any((s) =>
          s.name.contains(ssNorm) ||
          s.description.contains(ssNorm) ||
          (s.searchKeywords?.any((k) => k.contains(ssNorm)) ?? false));
    }).toList();

    var shops = _filterAndSortShops(provider);
    if (_searchQuery.isNotEmpty) {
      shops = shops
          .where((s) =>
              s.name.toLowerCase().contains(_searchQuery) ||
              s.description.toLowerCase().contains(_searchQuery) ||
              s.location.toLowerCase().contains(_searchQuery))
          .toList();
    }

    return RefreshIndicator(
      onRefresh: () => _selectCategory(cat,
          subCategory: _selectedSubCategory, forceRefresh: true),
      color: const Color(0xFF3D6B5E),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _buildSearchField(isDark, 'ابحث داخل ${cat.name}...'),
          ),
          if (nonEmptySubs.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildChipRow(
                options: nonEmptySubs,
                selected: _selectedSubCategory,
                onSelect: _selectSubCategory,
                isDark: isDark,
              ),
            ),

          if (_selectedSubCategory != null && nonEmptySubSubs.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildChipRow(
                options: nonEmptySubSubs,
                selected: _selectedSubSubCategory,
                onSelect: _selectSubSubCategory,
                isDark: isDark,
                isSecondLevel: true,
              ),
            ),

          if (_loadingCategoryShops)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                '${shops.length} محل${_activeFilterLabel != null ? ' في "$_activeFilterLabel"' : ''}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ),
          ),

          if (shops.isEmpty && !_loadingCategoryShops)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyShops(),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _buildShopCard(shops[i]),
                childCount: shops.length,
              ),
            ),

          const SliverToBoxAdapter(child: AppFooter()),
        ],
      ),
    );
  }

  Widget _buildChipRow({
    required List<String> options,
    required String? selected,
    required void Function(String?) onSelect,
    required bool isDark,
    bool isSecondLevel = false,
  }) {
    final color =
        isSecondLevel ? const Color(0xFF00897B) : const Color(0xFF3D6B5E);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, isSecondLevel ? 0 : 12, 16, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _chip('الكل', selected == null, color, () => onSelect(null)),
          ...options
              .map((o) => _chip(o, selected == o, color, () => onSelect(o))),
        ],
      ),
    );
  }

  Widget _chip(
      String label, bool isSelected, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildShopCard(Shop shop) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 56,
            height: 56,
            child: CachedImage(
              imageUrl: shop.imageUrl,
              fallbackIcon: Icons.storefront_outlined,
            ),
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
              const Icon(Icons.star, size: 13, color: Colors.amber),
              const SizedBox(width: 3),
              Text(shop.rating.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 12)),
            ]),
          ],
        ),
        trailing:
            const Icon(Icons.arrow_back_ios, size: 14, color: Colors.grey),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ShopDetailScreen(shop: shop)),
        ),
      ),
    );
  }

  Widget _buildEmptyShops() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.store_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'لا توجد محلات في\n"${_activeFilterLabel ?? _selectedCategory!.name}"',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 15),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdvancedSearchScreen())),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3D6B5E),
                foregroundColor: Colors.white),
            child: const Text('بحث متقدم'),
          ),
        ]),
      ),
    );
  }

  Widget _buildErrorState(ShopsProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.cloud_off_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('تعذّر تحميل الفئات. تحقق من اتصالك.',
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => provider.fetchCategories(refresh: true),
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF3D6B5E),
                foregroundColor: Colors.white),
          ),
        ]),
      ),
    );
  }

  String? get _activeFilterLabel =>
      _selectedSubSubCategory ?? _selectedSubCategory;

  List<Shop> _filterAndSortShops(ShopsProvider provider) {
    // دمج المحلات التي تم جلبها للفئة مع المحلات الموجودة في المزود دون تكرار
    final seen = <String>{};
    final combined = <Shop>[];
    for (final s in [
      ..._categoryShops,
      ...provider.shops.where((s) => s.category == _selectedCategory!.name)
    ]) {
      if (seen.add(s.id)) combined.add(s);
    }

    var shops = combined;
    final term = _activeFilterLabel;
    if (term != null) {
      final normalized = term.trim();
      shops = shops.where((s) {
        return s.name.contains(normalized) ||
            s.description.contains(normalized) ||
            (s.searchKeywords?.any((k) => k.contains(normalized)) ?? false);
      }).toList();
    }

    switch (_sortBy) {
      case 'rating':
        shops.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'views':
        shops.sort((a, b) {
          final va = a.uniqueVisitors > 0 ? a.uniqueVisitors : a.views;
          final vb = b.uniqueVisitors > 0 ? b.uniqueVisitors : b.views;
          return vb.compareTo(va);
        });
        break;
      case 'favorites':
        shops.sort((a, b) => b.favoriteCount.compareTo(a.favoriteCount));
        break;
    }
    return shops;
  }

  PopupMenuItem<String> _sortItem(String value, String label) => PopupMenuItem(
        value: value,
        child: Row(children: [
          if (_sortBy == value)
            const Icon(Icons.check, color: Color(0xFF3D6B5E), size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ]),
      );
}
