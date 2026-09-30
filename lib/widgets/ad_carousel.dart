// lib/widgets/ad_carousel.dart
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/shops_provider.dart';
import '../models/ad_model.dart';
import '../models/shop.dart';
import '../models/product.dart';
import '../screens/shop_detail_screen.dart';
import '../screens/detail_screen.dart';
import '../screens/categories_screen.dart';
import '../widgets/sub_category_list.dart';
import '../services/api_service.dart';
import 'cached_image.dart';

class AdCarousel extends StatefulWidget {
  const AdCarousel({super.key});

  @override
  State<AdCarousel> createState() => _AdCarouselState();
}

class _AdCarouselState extends State<AdCarousel> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // ✅ Fix #182: context.select بدلاً من Provider.of — يُعيد البناء فقط عند تغيير ads
    final ads = context.select<ShopsProvider, List<AdModel>>((p) => p.ads);

    if (ads.isEmpty) return const SizedBox.shrink();

    // ✅ Fix #189: ارتفاع تفاعلي بدلاً من قيمة ثابتة
    final screenWidth = MediaQuery.of(context).size.width;
    final carouselHeight = (screenWidth * 9 / 16).clamp(160.0, 220.0);

    return Column(
      children: [
        CarouselSlider(
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
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: CachedImage(
                        imageUrl: ad.imageUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: Container(color: Colors.grey[100]),
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
                  color: Theme.of(context)
                      .primaryColor
                      .withValues(alpha: isSelected ? 0.9 : 0.2),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  void _handleAdTap(BuildContext context, AdModel ad) {
    ApiService.incrementAdClickCount(ad.id);

    final provider = Provider.of<ShopsProvider>(context, listen: false);

    switch (ad.targetType) {
      case 'shop':
        try {
          Shop shop = provider.shops.firstWhere(
            (s) => s.id == ad.targetId,
            orElse: () =>
                throw Exception('عذراً، هذا المتجر لم يعد متاحاً حالياً'),
          );
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => ShopDetailScreen(shop: shop)));
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        break;

      case 'product':
        try {
          Product product = provider.products.firstWhere(
            (p) => p.id == ad.targetId,
            orElse: () =>
                throw Exception('عذراً، هذا المنتج لم يعد متاحاً حالياً'),
          );
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => DetailScreen(item: product)));
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        break;

      case 'screen':
        _handleScreenNavigation(context, ad.targetId);
        break;

      case 'url':
        if (ad.targetId != null) {
          _launchURL(ad.targetId!);
        }
        break;

      default:
        break;
    }
  }

  void _handleScreenNavigation(BuildContext context, String? screenId) {
    if (screenId == 'offers') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('كل العروض')),
            body: SubCategoryList(
              mainCategory: 'الكل',
              subCategory: 'الكل',
              onSubSubCategorySelected: (String val) {},
            ),
          ),
        ),
      );
    } else if (screenId == 'categories') {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const CategoriesScreen(initialCategory: 'الكل')));
    } else if (screenId == 'merchant') {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('سيتم توجيهك للوحة التاجر')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الشاشة المطلوبة غير متوفرة')));
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
