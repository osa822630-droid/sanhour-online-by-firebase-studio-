// lib_widgets_category_list.dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:provider/provider.dart';
import '../providers/shops_provider.dart';
import '../models/category_model.dart';
import '../screens/categories_screen.dart';

class CategoryListWidget extends StatelessWidget {
  const CategoryListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<ShopsProvider, List<CategoryModel>>(
      selector: (_, provider) => provider.categories,
      builder: (context, categories, child) {
        if (categories.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Provider.of<ShopsProvider>(context, listen: false)
                .fetchCategories();
          });
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'استكشف الفئات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  itemCount: categories.length,
                  scrollCacheExtent: const ScrollCacheExtent.pixels(500),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return _buildCategoryItem(
                      context,
                      cat.name,
                      CategoryModel.getIconData(cat.iconName),
                      Color(cat.colorValue),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryItem(
      BuildContext context, String categoryName, IconData icon, Color color) {
    return Container(
      width: 85,
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _navigateToCategory(context, categoryName),
              borderRadius: BorderRadius.circular(50),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: color.withValues(alpha: 0.2), width: 1),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            categoryName,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _navigateToCategory(BuildContext context, String categoryName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoriesScreen(initialCategory: categoryName),
      ),
    );
  }
}
