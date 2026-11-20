// lib/widgets/favorites_grid.dart
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sanhour_online/providers/favorites_provider.dart';
import 'package:sanhour_online/models/product.dart';
import 'package:sanhour_online/models/shop.dart';
import 'package:sanhour_online/models/offer.dart';
import 'package:sanhour_online/screens/detail_screen.dart';
import 'package:sanhour_online/screens/shop_detail_screen.dart';
import 'package:sanhour_online/widgets/cached_image.dart';

class FavoritesGrid extends StatelessWidget {
  final String type; // 'shop', 'product', or 'offer'

  const FavoritesGrid({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesProvider>(
      builder: (context, favoritesProvider, child) {
        final items = favoritesProvider.getFavoritesByType(type);

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'قائمة المفضلة فارغة حالياً',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.72,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildFavoriteItem(context, item, favoritesProvider);
          },
        );
      },
    );
  }

  Widget _buildFavoriteItem(
      BuildContext context, dynamic item, FavoritesProvider provider) {
    String imageUrl = '';
    String title = '';
    String subtitle = '';
    VoidCallback onTap = () {};

    if (item is Shop) {
      imageUrl = item.imageUrl;
      title = item.name;
      subtitle = '⭐ ${item.rating.toStringAsFixed(1)}';
      onTap = () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ShopDetailScreen(shop: item)));
    } else if (item is Product) {
      imageUrl = item.displayImageUrl;
      title = item.name;
      subtitle = '${item.price.toStringAsFixed(0)} ج.م';
      onTap = () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => DetailScreen(item: item)));
    } else if (item is Offer) {
      imageUrl = item.imageUrl;
      title = item.title;
      subtitle = 'خصم ${item.discount}%';
      onTap = () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => DetailScreen(item: item)));
    }

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: CachedImage(imageUrl: imageUrl, fit: BoxFit.cover),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF3D6B5E),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.black.withValues(alpha: 0.45),
                child: IconButton(
                  tooltip: 'إضافة',
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.favorite, color: Colors.red, size: 18),
                  onPressed: () => provider.toggleFavorite(item),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
