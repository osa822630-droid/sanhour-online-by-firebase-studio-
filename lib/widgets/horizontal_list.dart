// lib/widgets/horizontal_list.dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:provider/provider.dart';
import '../providers/shops_provider.dart';
import '../screens/detail_screen.dart';
import '../screens/shop_detail_screen.dart';
import '../models/shop.dart';
import '../models/product.dart';
import '../models/offer.dart';
import 'cached_image.dart';

class HorizontalList extends StatelessWidget {
  final String title;
  final String type;
  final List<dynamic>? items; // ✅ إضافة دعم لقائمة مخصصة

  const HorizontalList({super.key, required this.title, required this.type, this.items});

  @override
  Widget build(BuildContext context) {
    if (items != null) return _buildList(context, items!); // ✅ استخدام القائمة الممررة مباشرة

    return Selector<ShopsProvider, List<dynamic>>(
      selector: (_, p) {
        switch (type) {
          case 'best_shops': return p.bestShops;
          case 'new_shops': return p.newShops;
          case 'featured_shops': return p.featuredShops;
          case 'best_products': return p.bestProducts;
          case 'new_products': return p.newProducts;
          case 'best_offers':
          case 'featured_offers':
          case 'all_offers': return p.bestOffers;
          case 'ending_offers':
            final now = DateTime.now();
            return p.allOffers
                .where((o) => o.validUntil.difference(now).inDays <= 7 && o.validUntil.isAfter(now))
                .toList();
          default: return [];
        }
      },
      builder: (context, items, _) => _buildList(context, items),
    );
  }

  Widget _buildList(BuildContext context, List<dynamic> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            scrollCacheExtent: const ScrollCacheExtent.pixels(500),
            itemBuilder: (context, i) => _HorizontalCard(item: items[i]),
          ),
        ),
      ],
    );
  }
}

class _HorizontalCard extends StatelessWidget {
  final dynamic item;
  const _HorizontalCard({required this.item});

  @override
  Widget build(BuildContext context) {
    if (item is Shop) return _buildShopCard(context, item as Shop);
    if (item is Product) return _buildProductCard(context, item as Product);
    if (item is Offer) return _buildOfferCard(context, item as Offer);
    return const SizedBox.shrink();
  }

  Widget _buildShopCard(BuildContext context, Shop shop) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ShopDetailScreen(shop: shop))),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: SizedBox(height: 110, width: double.infinity,
                child: CachedImage(imageUrl: shop.imageUrl, fit: BoxFit.cover)),
          ),
          Padding(padding: const EdgeInsets.all(8), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(shop.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            Text(shop.category,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.star, color: Colors.amber, size: 13),
              Text(' ${shop.rating.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              if (shop.isFeatured) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: Colors.amber[100], borderRadius: BorderRadius.circular(4)),
                  child: const Text('مميز', style: TextStyle(fontSize: 9, color: Colors.orange)),
                ),
              ],
            ]),
          ])),
        ]),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => DetailScreen(item: product))),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Stack(children: [
              SizedBox(height: 110, width: double.infinity,
                  child: CachedImage(
                      imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls.first : '',
                      fit: BoxFit.cover)),
              if (product.hasDiscount)
                Positioned(top: 6, right: 6, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                  child: Text('-${product.discountPercentage.toInt()}%',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                )),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(8), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            Text('${product.price.toStringAsFixed(0)} جنيه',
                style: const TextStyle(color: Color(0xFF5E35B1),
                    fontWeight: FontWeight.bold, fontSize: 13)),
            if (product.hasPriceDrop && product.oldPrice > 0)
              Text(product.oldPrice.toStringAsFixed(0),
                  style: const TextStyle(decoration: TextDecoration.lineThrough,
                      fontSize: 10, color: Colors.grey)),
          ])),
        ]),
      ),
    );
  }

  Widget _buildOfferCard(BuildContext context, Offer offer) {
    final isExpiringSoon = offer.isAboutToExpire && !offer.isExpired;
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => DetailScreen(item: offer))),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Stack(children: [
              SizedBox(height: 100, width: double.infinity,
                  child: CachedImage(imageUrl: offer.imageUrl, fit: BoxFit.cover)),
              Positioned(top: 6, right: 6, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                child: Text('${offer.discount}% خصم',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              )),
              if (isExpiringSoon)
                Positioned(bottom: 6, left: 6, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                  child: const Text('ينتهي قريباً', style: TextStyle(color: Colors.white, fontSize: 9)),
                )),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(8), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(offer.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 3),
            Text('حتى: ${offer.validUntil.day}/${offer.validUntil.month}',
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ])),
        ]),
      ),
    );
  }
}
