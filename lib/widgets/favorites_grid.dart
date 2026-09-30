// lib/widgets/favorites_grid.dart
import 'package:flutter/material.dart';
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
                  'Your favorite list is empty',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
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
            childAspectRatio: 0.8,
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
      subtitle = '${item.rating} ★';
      onTap = () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ShopDetailScreen(shop: item)));
    } else if (item is Product) {
      imageUrl = item.imageUrls.isNotEmpty ? item.imageUrls.first : '';
      title = item.name;
      subtitle = '${item.price} EGP';
      onTap = () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => DetailScreen(item: item)));
    } else if (item is Offer) {
      imageUrl = item.imageUrl;
      title = item.title;
      subtitle = '${item.discount}% Off';
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
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 12),
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
                backgroundColor: Colors.white.withValues(alpha: 0.8),
                child: IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.red, size: 20),
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
