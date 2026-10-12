// lib/screens/categories_screen.dart
// ✅ إعادة تصميم كاملة: نظام Chips هرمي بدلاً من الصفحات المنفصلة (PageView)
// — اختيار فئة رئيسية يعرض محتواها كاملاً فوراً + شريط chips للفئات
// الفرعية أعلى القائمة. اختيار فئة فرعية يعرض شريط chips ثانٍ تحته مباشرةً
// للفئات الفرعية الدقيقة (subSubCategories). كل هذا في شاشة واحدة بدون
// تنقّل بين صفحات منفصلة.
import 'package:flutter/material.dart';
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

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  CategoryModel? _selectedCategory;
  // null = شريحة "الكل" مُختارة (لا فلترة إضافية على هذا المستوى)
  String? _selectedSubCategory;
  String? _selectedSubSubCategory;
  String _sortBy = 'default';

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyInitialCategory());
    }
  }

  void _applyInitialCategory() {
    if (!mounted) return;
    final provider = context.read<ShopsProvider>();
    CategoryModel? match;
    for (final c in provider.categories) {
      if (c.name == widget.initialCategory) {
        match = c;
        break;
      }
    }
    if (match == null) return;
    setState(() {
      _selectedCategory = match;
      _selectedSubCategory = widget.initialSubCategory;
    });
  }

  void _resetToGrid() {
    setState(() {
      _selectedCategory = null;
      _selectedSubCategory = null;
      _selectedSubSubCategory = null;
    });
  }

  void _selectSubCategory(String? sub) {
    setState(() {
      // ✅ اختيار "الكل" (sub == null) أو فئة فرعية جديدة يُعيد ضبط المستوى
      // الأعمق (الفئة الفرعية الدقيقة) دائماً — منطقي أن تختفي الخيارات
      // الدقيقة القديمة عند تغيير الفئة الفرعية الأب
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
          isDark ? const Color(0xFF0E0E1A) : const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: Text(_selectedCategory?.name ?? 'الفئات',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
        centerTitle: true,
        // ✅ عند اختيار فئة، السهم يرجع لشبكة الفئات بدلاً من الخروج من الشاشة
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

  // ── شبكة الفئات الرئيسية ──────────────────────────────────────────
  Widget _buildCategoryGrid(ShopsProvider provider, bool isDark) {
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
        const AppFooter(),
      ]);
    }

    return RefreshIndicator(
      onRefresh: () => provider.fetchCategories(refresh: true),
      color: const Color(0xFF5E35B1),
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
            onTap: () => setState(() {
              _selectedCategory = cat;
              _selectedSubCategory = null;
              _selectedSubSubCategory = null;
            }),
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
    );
  }

  // ── محتوى الفئة المختارة: chips هرمية + قائمة المحلات ────────────
  Widget _buildCategoryContent(ShopsProvider provider, bool isDark) {
    final cat = _selectedCategory!;
    final shops = _filterAndSortShops(provider);
    final subSubs = _selectedSubCategory == null
        ? const <String>[]
        : (cat.subSubCategories[_selectedSubCategory] ?? const <String>[]);

    return RefreshIndicator(
      onRefresh: () => provider.fetchShops(
          category: cat.name, refresh: true),
      color: const Color(0xFF5E35B1),
      child: CustomScrollView(
        slivers: [
          // ── شريط الفئات الفرعية (المستوى الأول) ──────────────────
          if (cat.subCategories.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildChipRow(
                options: cat.subCategories,
                selected: _selectedSubCategory,
                onSelect: _selectSubCategory,
                isDark: isDark,
              ),
            ),

          // ── شريط الفئات الفرعية الدقيقة (المستوى الثاني) ──────────
          // ✅ يظهر فقط إذا اختار المستخدم فئة فرعية مُحدَّدة (وليس "الكل")
          // ولها فعلاً فئات دقيقة مُعرَّفة
          // ✅ إصلاح: SliverToBoxAdapter مباشرةً بدون أي غلاف Padding/Box حوله
          // — التباعد يُدار داخل _buildChipRow نفسها عبر isSecondLevel
          if (_selectedSubCategory != null && subSubs.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildChipRow(
                options: subSubs,
                selected: _selectedSubSubCategory,
                onSelect: _selectSubSubCategory,
                isDark: isDark,
                isSecondLevel: true,
              ),
            ),

          // ── عداد النتائج ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                '${shops.length} محل${_activeFilterLabel != null ? ' في "$_activeFilterLabel"' : ''}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ),
          ),

          // ── النتائج أو حالة الفراغ ───────────────────────────────
          if (shops.isEmpty)
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

  /// صف شرائح (chips) قابل للف على أكثر من سطر — دائماً يبدأ بشريحة "الكل"
  Widget _buildChipRow({
    required List<String> options,
    required String? selected,
    required void Function(String?) onSelect,
    required bool isDark,
    bool isSecondLevel = false,
  }) {
    final color = isSecondLevel ? const Color(0xFF00897B) : const Color(0xFF5E35B1);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, isSecondLevel ? 0 : 12, 16, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _chip('الكل', selected == null, color, () => onSelect(null)),
          ...options.map((o) => _chip(o, selected == o, color, () => onSelect(o))),
        ],
      ),
    );
  }

  Widget _chip(String label, bool isSelected, Color color, VoidCallback onTap) {
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
            child: CachedImage(imageUrl: shop.imageUrl),
          ),
        ),
        title: Text(shop.name, style: const TextStyle(fontWeight: FontWeight.bold)),
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
              Text(shop.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12)),
            ]),
          ],
        ),
        trailing: const Icon(Icons.arrow_back_ios, size: 14, color: Colors.grey),
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
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AdvancedSearchScreen())),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E35B1), foregroundColor: Colors.white),
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
                backgroundColor: const Color(0xFF5E35B1), foregroundColor: Colors.white),
          ),
        ]),
      ),
    );
  }

  /// عنوان الفلتر النشط حالياً — لعرضه في العداد وحالة الفراغ
  String? get _activeFilterLabel => _selectedSubSubCategory ?? _selectedSubCategory;

  /// ✅ فلترة تقريبية بالاسم/الوصف للفئة الفرعية والدقيقة — نموذج المحل
  /// الحالي لا يخزّن حقل فئة فرعية منفصلاً، فنعتمد على تطابق النص كأفضل حل
  /// متاح دون تعديل بنية بيانات المحلات. الفلترة الأساسية (الفئة الرئيسية)
  /// دقيقة تماماً لأنها تعتمد على حقل shop.category المخزَّن فعلياً.
  List<Shop> _filterAndSortShops(ShopsProvider provider) {
    var shops = provider.shops
        .where((s) => s.category == _selectedCategory!.name)
        .toList();

    final term = _activeFilterLabel;
    if (term != null) {
      final normalized = term.trim();
      shops = shops.where((s) {
        return s.name.contains(normalized) || s.description.contains(normalized);
      }).toList();
    }

    switch (_sortBy) {
      case 'rating':
        shops.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'views':
        shops.sort((a, b) => b.uniqueVisitors.compareTo(a.uniqueVisitors));
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
            const Icon(Icons.check, color: Color(0xFF5E35B1), size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ]),
      );
}
