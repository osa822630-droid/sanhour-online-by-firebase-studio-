// lib/widgets/ad_carousel.dart
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/shops_provider.dart';
import '../models/ad_model.dart';
import '../models/shop.dart';
import '../models/product.dart';
import '../models/offer.dart';
import '../screens/shop_detail_screen.dart';
import '../screens/detail_screen.dart';
import '../screens/categories_screen.dart';
import '../screens/offers_screen.dart';
import '../services/api_service.dart';
import 'cached_image.dart';
import 'media_preview_dialog.dart';

class AdCarousel extends StatefulWidget {
  const AdCarousel({super.key});

  @override
  State<AdCarousel> createState() => _AdCarouselState();
}

class _AdCarouselState extends State<AdCarousel> {
  int _currentIndex = 0;
  String? _lastAdsSignature;

  @override
  Widget build(BuildContext context) {
    final ads = context.select<ShopsProvider, List<AdModel>>((p) => p.ads);

    if (ads.isEmpty) return const SizedBox.shrink();

    final adsSignature = ads.map((a) => a.id).join(',');
    if (adsSignature != _lastAdsSignature) {
      _lastAdsSignature = adsSignature;
      _currentIndex = 0;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final carouselHeight = (screenWidth * 9 / 16).clamp(160.0, 220.0);

    return Column(
      children: [
        CarouselSlider(
          key: ValueKey('ad_carousel_$adsSignature'),
          options: CarouselOptions(
            height: carouselHeight,
            autoPlay: true,
            enlargeCenterPage: true,
            aspectRatio: 16 / 9,
            autoPlayCurve: Curves.fastOutSlowIn,
            enableInfiniteScroll: ads.length > 1,
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
            viewportFraction: 0.9,
            onPageChanged: (index, reason) {
              if (!mounted) return;
              setState(() {
                _currentIndex = index;
              });
            },
          ),
          items: ads.map((ad) {
            return GestureDetector(
              onTap: () => _handleAdTap(context, ad),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 5.0),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: ad.imageUrl.isNotEmpty
                          ? CachedImage(
                              imageUrl: ad.imageUrl,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: const Color(0xFF1A0030),
                              child: const Center(
                                child: Icon(
                                  Icons.videocam_rounded,
                                  color: Colors.white54,
                                  size: 48,
                                ),
                              ),
                            ),
                    ),
                    if (ad.isVideo)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    if (ad.text.isNotEmpty)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(12)),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.8),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                          child: Text(
                            ad.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              shadows: [
                                Shadow(
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                    color: Colors.black),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        if (ads.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: ads.asMap().entries.map((entry) {
              final isSelected = _currentIndex == entry.key;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isSelected ? 20.0 : 8.0,
                height: 8.0,
                margin:
                    const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: const Color(0xFF3D6B5E)
                      .withValues(alpha: isSelected ? 0.9 : 0.25),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Future<void> _handleAdTap(BuildContext context, AdModel ad) async {
    ApiService.incrementAdClickCount(ad.id);

    // إذا كان إعلان فيديو بدون هدف محدد، نشغّل الفيديو في المعاينة الكاملة
    if (ad.isVideo &&
        ad.videoUrl != null &&
        ad.videoUrl!.isNotEmpty &&
        (ad.targetType == 'none' || (ad.targetId ?? '').isEmpty)) {
      await MediaPreviewDialog.show(context, url: ad.videoUrl, isVideo: true);
      return;
    }

    final provider = Provider.of<ShopsProvider>(context, listen: false);
    final targetId = (ad.targetId ?? '').trim().isNotEmpty
        ? ad.targetId!.trim()
        : (ad.shopId ?? '').trim();

    switch (ad.targetType) {
      case 'shop':
      case 'shop_products':
      case 'shop_offers':
        if (targetId.isEmpty) return;
        final cachedShop =
            provider.shops.where((s) => s.id == targetId).firstOrNull;
        if (cachedShop != null) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ShopDetailScreen(shop: cachedShop)));
          return;
        }
        try {
          final doc = await FirebaseFirestore.instance
              .collection('shops')
              .doc(targetId)
              .get();
          if (!context.mounted) return;
          if (doc.exists && doc.data() != null) {
            final shop = Shop.fromMap(doc.data()!, doc.id);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => ShopDetailScreen(shop: shop)));
          } else {
            _showNotAvailable(context, 'عذراً، هذا المتجر لم يعد متاحاً حالياً');
          }
        } catch (_) {
          if (context.mounted) {
            _showNotAvailable(context, 'تعذّر فتح المتجر حالياً');
          }
        }
        break;

      case 'product':
        if (targetId.isEmpty) return;
        final cachedProduct =
            provider.products.where((p) => p.id == targetId).firstOrNull;
        if (cachedProduct != null) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => DetailScreen(item: cachedProduct)));
          return;
        }
        try {
          final doc = await FirebaseFirestore.instance
              .collection('products')
              .doc(targetId)
              .get();
          if (!context.mounted) return;
          if (doc.exists && doc.data() != null) {
            final product = Product.fromMap(doc.data()!, doc.id);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => DetailScreen(item: product)));
          } else {
            _showNotAvailable(context, 'عذراً، هذا المنتج لم يعد متاحاً حالياً');
          }
        } catch (_) {
          if (context.mounted) {
            _showNotAvailable(context, 'تعذّر فتح المنتج حالياً');
          }
        }
        break;

      case 'offer':
        if (targetId.isEmpty) return;
        final cachedOffer =
            provider.offers.where((o) => o.id == targetId).firstOrNull;
        if (cachedOffer != null) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => DetailScreen(item: cachedOffer)));
          return;
        }
        try {
          final doc = await FirebaseFirestore.instance
              .collection('offers')
              .doc(targetId)
              .get();
          if (!context.mounted) return;
          if (doc.exists && doc.data() != null) {
            final offer = Offer.fromMap(doc.data()!, doc.id);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => DetailScreen(item: offer)));
          } else {
            _showNotAvailable(context, 'عذراً، هذا العرض لم يعد متاحاً حالياً');
          }
        } catch (_) {
          if (context.mounted) {
            _showNotAvailable(context, 'تعذّر فتح العرض حالياً');
          }
        }
        break;

      case 'screen':
        _handleScreenNavigation(context, ad.targetId);
        break;

      case 'url':
        if (ad.targetId != null && ad.targetId!.isNotEmpty) {
          _launchURL(ad.targetId!);
        }
        break;

      default:
        if (ad.isVideo && ad.videoUrl != null && ad.videoUrl!.isNotEmpty) {
          await MediaPreviewDialog.show(context, url: ad.videoUrl, isVideo: true);
        }
        break;
    }
  }

  void _showNotAvailable(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleScreenNavigation(BuildContext context, String? screenId) {
    if (screenId == 'offers') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OffersScreen()),
      );
    } else if (screenId == 'categories') {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const CategoriesScreen(initialCategory: 'الكل')),
      );
    } else if (screenId == 'favorites') {
      Navigator.pushNamed(context, '/favorites');
    } else if (screenId == 'merchant') {
      Navigator.pushNamed(context, '/merchant');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الشاشة المطلوبة غير متوفرة')),
      );
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
