// lib/widgets/category_list.dart
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../providers/shops_provider.dart';
import '../models/category_model.dart';
import '../screens/main_screen.dart';

class CategoryListWidget extends StatelessWidget {
  const CategoryListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<ShopsProvider>(
      builder: (context, provider, child) {
        if (provider.categories.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Provider.of<ShopsProvider>(context, listen: false)
                .fetchCategories();
          });
          return const SizedBox.shrink();
        }

        // ✅ إخفاء الفئات الفارغة التي لا تحتوي على أي محل نشط
        final activeCatNames =
            provider.shops.map((s) => s.category.trim()).toSet();
        final visibleCategories = activeCatNames.isEmpty
            ? const <CategoryModel>[]
            : provider.categories
                .where((c) => activeCatNames.contains(c.name.trim()))
                .toList();

        if (visibleCategories.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 108,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: visibleCategories.length,
            scrollCacheExtent: const ScrollCacheExtent.pixels(500),
            itemBuilder: (context, index) {
              final cat = visibleCategories[index];
              return _buildCategoryItem(
                context,
                cat.name,
                CategoryModel.getIconData(cat.iconName),
                Color(cat.colorValue),
                isDark,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCategoryItem(
    BuildContext context,
    String categoryName,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      width: 84,
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _navigateToCategory(context, categoryName),
              borderRadius: BorderRadius.circular(50),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.22 : 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: isDark ? 0.45 : 0.25),
                    width: 1.2,
                  ),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            categoryName,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1F1C36),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _navigateToCategory(BuildContext context, String categoryName) {
    // ✅ التبديل إلى تبويب الفئات داخل MainScreen مع إبقاء الشريط السفلي ظاهراً
    MainScreen.switchTab(MainScreen.categoriesTab, categoryName: categoryName);
  }
}
