// lib/screens/detail_screen.dart
import 'package:material_ui/material_ui.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';
import 'package:sanhour_online/models/product.dart';
import 'package:sanhour_online/models/shop.dart';
import 'package:sanhour_online/models/offer.dart';
import 'package:sanhour_online/models/review_model.dart';
import 'package:sanhour_online/services/review_service.dart';
import 'package:sanhour_online/providers/favorites_provider.dart';
import 'package:sanhour_online/providers/auth_provider.dart';
import 'package:sanhour_online/services/api_service.dart';
import 'package:sanhour_online/widgets/cached_image.dart';
import 'shop_detail_screen.dart';
import 'review_screen.dart';
import 'login_screen.dart';
import '../services/analytics_service.dart';

class DetailScreen extends StatefulWidget {
  final dynamic item;
  const DetailScreen({super.key, required this.item});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  int _currentImageIndex = 0;
  String? _selectedColor;
  String? _selectedSize;
  List<Review> _itemReviews = [];
  bool _loadingReviews = false;

  Future<void> _loadItemReviews() async {
    if (widget.item is Shop) {
      return;
    }
    final String itemId = widget.item is Product
        ? (widget.item as Product).id
        : (widget.item as Offer).id;
    setState(() => _loadingReviews = true);
    final list = await ReviewService.getReviews(itemId);
    if (mounted) {
      setState(() {
        _itemReviews = list;
        _loadingReviews = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // ✅ تسجيل الزيارة عند فتح الشاشة
    if (widget.item is Product) {
      ApiService.logProductVisit((widget.item as Product).id);
    } else if (widget.item is Offer) {
      ApiService.logOfferVisit((widget.item as Offer).id);
    }
    _loadItemReviews();
    // ✅ 4.8: ربط Analytics
    AnalyticsService().logScreenView('detail_screen');
    AnalyticsService().logViewItem(widget.item);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.item is Shop) return ShopDetailScreen(shop: widget.item as Shop);

    final isProduct = widget.item is Product;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String id = widget.item.id;
    final String name = isProduct
        ? (widget.item as Product).name
        : (widget.item as Offer).title;
    final String description = isProduct
        ? (widget.item as Product).description
        : (widget.item as Offer).description;
    final List<String> imageUrls = isProduct
        ? (widget.item as Product).imageUrls
        : ((widget.item as Offer).imageUrls.isNotEmpty
            ? (widget.item as Offer).imageUrls
            : ((widget.item as Offer).imageUrl.isNotEmpty
                ? [(widget.item as Offer).imageUrl]
                : <String>[]));
    final double price = isProduct
        ? (widget.item as Product).price
        : ((widget.item as Offer).newPrice ?? 0.0);
    final double oldPrice = isProduct
        ? (widget.item as Product).oldPrice
        : ((widget.item as Offer).oldPrice ?? 0.0);
    final bool hasPriceDrop = isProduct
        ? (widget.item as Product).hasPriceDrop
        : (oldPrice > 0 && price > 0 && oldPrice > price);
    final String category =
        isProduct ? (widget.item as Product).category : 'عروض خاصة';
    final List<String> colors =
        isProduct ? (widget.item as Product).colors : [];
    final List<String> sizes = isProduct ? (widget.item as Product).sizes : [];
    final double rating = isProduct
        ? (widget.item as Product).rating
        : (widget.item as Offer).rating;
    final int reviewCount = isProduct
        ? (widget.item as Product).reviewCount
        : (widget.item as Offer).reviewCount;

    // Offer specific
    final int discount = isProduct ? 0 : (widget.item as Offer).discount;
    final DateTime? validUntil =
        isProduct ? null : (widget.item as Offer).validUntil;
    final String? giftDescription =
        isProduct ? null : (widget.item as Offer).giftDescription;
    final String? bundleDetails =
        isProduct ? null : (widget.item as Offer).bundleDetails;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121514) : Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                // ─── صور المنتج / العرض ───────────────────────────────────
                SliverAppBar(
                  expandedHeight: 380.0,
                  floating: false,
                  pinned: true,
                  backgroundColor:
                      isDark ? const Color(0xFF1B201E) : Colors.white,
                  leading: IconButton(
                    tooltip: 'رجوع',
                    icon: CircleAvatar(
                      backgroundColor: isDark ? Colors.white12 : Colors.white,
                      child: Icon(Icons.arrow_back,
                          color: isDark ? Colors.white : Colors.black),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    Consumer<FavoritesProvider>(
                      builder: (ctx, fav, _) {
                        final isFav = fav.isFavorite(
                            isProduct ? 'product' : 'offer', id);
                        return IconButton(
                          tooltip: 'المفضلة',
                          icon: CircleAvatar(
                            backgroundColor:
                                isDark ? Colors.white12 : Colors.white,
                            child: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              color: isFav
                                  ? Colors.red
                                  : (isDark ? Colors.white : Colors.black),
                            ),
                          ),
                          onPressed: () {
                            final auth = ctx.read<AuthProvider>();
                            if (auth.isGuest) {
                              _showLoginDialog(context);
                              return;
                            }
                            fav.toggleFavorite(widget.item);
                          },
                        );
                      },
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: imageUrls.isEmpty
                        ? Container(
                            color: isDark
                                ? const Color(0xFF1B201E)
                                : Colors.grey[200],
                            child: const Icon(Icons.image_not_supported,
                                size: 60, color: Colors.grey))
                        : Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              CarouselSlider(
                                options: CarouselOptions(
                                  height: 420,
                                  viewportFraction: 1.0,
                                  enableInfiniteScroll: imageUrls.length > 1,
                                  onPageChanged: (i, _) =>
                                      setState(() => _currentImageIndex = i),
                                ),
                                items: imageUrls
                                    .map((url) => GestureDetector(
                                          onTap: () =>
                                              _openFullScreen(context, url),
                                          child: CachedImage(
                                              imageUrl: url,
                                              fit: BoxFit.cover),
                                        ))
                                    .toList(),
                              ),
                              if (imageUrls.length > 1)
                                Positioned(
                                  bottom: 16,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children:
                                        imageUrls.asMap().entries.map((e) {
                                      return AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 300),
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 3),
                                        width: _currentImageIndex == e.key
                                            ? 20
                                            : 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: _currentImageIndex == e.key
                                              ? const Color(0xFF3D6B5E)
                                              : Colors.white60,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              // بادج الخصم للعروض
                              if (!isProduct && discount > 0)
                                Positioned(
                                  top: 16,
                                  right: 16,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text('خصم $discount%',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),

                // ─── تفاصيل المنتج/العرض ─────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // الفئة
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                Color(0xFF3D6B5E).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(category,
                              style: const TextStyle(
                                  color: Color(0xFF3D6B5E), fontSize: 12)),
                        ),
                        const SizedBox(height: 10),

                        // الاسم
                        Text(name,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),

                        // التقييم
                        if (reviewCount > 0)
                          Row(children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text(
                                '${rating.toStringAsFixed(1)} ($reviewCount تقييم)',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 13)),
                          ]),

                        const SizedBox(height: 12),

                        // السعر (للمنتجات أو العروض التي تحتوي على سعر)
                        if (price > 0) ...[
                          Row(children: [
                            Text('${price.toStringAsFixed(0)} جنيه',
                                style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF3D6B5E))),
                            if (hasPriceDrop && oldPrice > 0) ...[
                              const SizedBox(width: 12),
                              Text('${oldPrice.toStringAsFixed(0)} جنيه',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.grey)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(4)),
                                child: Text(
                                  '${((1 - price / oldPrice) * 100).toInt()}% خصم',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 11),
                                ),
                              ),
                            ],
                          ]),
                          const SizedBox(height: 16),
                        ],

                        // تفاصيل الهدية أو الباقة للعروض
                        if (!isProduct &&
                            giftDescription != null &&
                            giftDescription.trim().isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.purple.withValues(alpha: 0.3)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.card_giftcard,
                                  color: Colors.purple, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'هدية العرض: $giftDescription',
                                  style: const TextStyle(
                                      color: Colors.purple,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (!isProduct &&
                            bundleDetails != null &&
                            bundleDetails.trim().isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.teal.withValues(alpha: 0.3)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.inventory_2_outlined,
                                  color: Colors.teal, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'تفاصيل الباقة: $bundleDetails',
                                  style: const TextStyle(
                                      color: Colors.teal,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // صلاحية العرض
                        if (!isProduct && validUntil != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.3)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.timer,
                                  color: Colors.orange, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'صالح حتى: ${validUntil.day}/${validUntil.month}/${validUntil.year}',
                                style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // الألوان
                        if (colors.isNotEmpty) ...[
                          const Text('اللون:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: colors
                                .map((color) => GestureDetector(
                                      onTap: () => setState(
                                          () => _selectedColor = color),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: _selectedColor == color
                                              ? Color(0xFF3D6B5E)
                                              : Colors.transparent,
                                          border: Border.all(
                                              color: _selectedColor == color
                                                  ? const Color(0xFF3D6B5E)
                                                  : Colors.grey[400]!),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(color,
                                            style: TextStyle(
                                              color: _selectedColor == color
                                                  ? Colors.white
                                                  : null,
                                              fontSize: 13,
                                            )),
                                      ),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // المقاسات
                        if (sizes.isNotEmpty) ...[
                          const Text('المقاس:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: sizes
                                .map((size) => GestureDetector(
                                      onTap: () =>
                                          setState(() => _selectedSize = size),
                                      child: Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          color: _selectedSize == size
                                              ? const Color(0xFF3D6B5E)
                                              : Colors.transparent,
                                          border: Border.all(
                                              color: _selectedSize == size
                                                  ? const Color(0xFF3D6B5E)
                                                  : Colors.grey[400]!),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                            child: Text(size,
                                                style: TextStyle(
                                                  color: _selectedSize == size
                                                      ? Colors.white
                                                      : null,
                                                  fontWeight: FontWeight.bold,
                                                ))),
                                      ),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // الوصف
                        const Text('الوصف:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(
                          description.isNotEmpty
                              ? description
                              : 'لا يوجد وصف متاح',
                          style: const TextStyle(
                              fontSize: 15, height: 1.7, color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              isProduct ? 'تقييمات المنتج' : 'تقييمات العرض',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${_itemReviews.length})',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_loadingReviews)
                          const Center(
                              child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ))
                        else if (_itemReviews.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'لا توجد تقييمات بعد — كن أول من يضيف تقييماً!',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          )
                        else
                          ..._itemReviews.map((r) {
                            final reviewerName =
                                (r.userName != null && r.userName!.trim().isNotEmpty)
                                    ? r.userName!.trim()
                                    : 'مستخدم';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor:
                                              const Color(0xFF3D6B5E)
                                                  .withValues(alpha: 0.12),
                                          child: Text(
                                            reviewerName.isNotEmpty
                                                ? reviewerName[0]
                                                : 'م',
                                            style: const TextStyle(
                                              color: Color(0xFF3D6B5E),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            reviewerName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14),
                                          ),
                                        ),
                                        Row(
                                          children: List.generate(
                                            5,
                                            (i) => Icon(
                                              i < r.rating
                                                  ? Icons.star
                                                  : Icons.star_border,
                                              color: Colors.amber,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (r.comment.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(r.comment,
                                          style: const TextStyle(
                                              fontSize: 13, height: 1.5)),
                                    ],
                                    if (r.reply != null &&
                                        r.reply!.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Color(0xFF3D6B5E)
                                              .withValues(alpha: 0.06),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.reply,
                                                size: 15,
                                                color: Color(0xFF3D6B5E)),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'رد المتجر: ${r.reply}',
                                                style: const TextStyle(
                                                    fontSize: 12),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }),
                        const SizedBox(height: 100), // مسافة للـ FAB
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ─── زرار التقييم ──────────────────────────────────────────────
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton.extended(
                backgroundColor: const Color(0xFF3D6B5E),
                foregroundColor: Colors.white,
                onPressed: () {
                  final auth = context.read<AuthProvider>();
                  if (auth.isGuest) {
                    _showLoginDialog(context);
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReviewScreen(
                        itemId: id,
                        itemType: isProduct ? 'product' : 'offer',
                        itemName: name,
                      ),
                    ),
                  ).then((_) => _loadItemReviews());
                },
                icon: const Icon(Icons.rate_review, size: 20),
                label: const Text('أضف تقييم'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white),
                body: Center(
                    child:
                        InteractiveViewer(child: CachedImage(imageUrl: url))),
              )),
    );
  }

  void _showLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('يلزم تسجيل الدخول'),
        content: const Text('سجّل دخولك للتفاعل مع هذا العنصر.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لاحقاً')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3D6B5E)),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
            child: const Text('دخول', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}