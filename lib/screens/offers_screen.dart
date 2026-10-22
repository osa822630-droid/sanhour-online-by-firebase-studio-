// lib/screens/offers_screen.dart
// ✅ شريط بحث موحّد مع فلاتر الفئة والترتيب والصلاحية
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shops_provider.dart';
import '../models/offer.dart';
import '../widgets/context_search_bar.dart';
import '../widgets/cached_image.dart';
import '../widgets/app_footer.dart';
import 'detail_screen.dart';
import '../services/analytics_service.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  String _searchQuery = '';
  String _selectedSort = 'الأحدث';
  String _selectedExpiry = 'الكل';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShopsProvider>().loadOffers();
    });
    AnalyticsService().logScreenView('offers');
  }

  List<Offer> _filteredOffers(List<Offer> all) {
    var result = List<Offer>.from(all);

    // فلتر نص البحث
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((o) =>
              o.title.toLowerCase().contains(q) ||
              o.description.toLowerCase().contains(q))
          .toList();
    }

    // فلتر الصلاحية
    if (_selectedExpiry == 'ينتهي اليوم') {
      final end = DateTime.now().add(const Duration(hours: 24));
      result = result
          .where((o) => o.validUntil.isBefore(end))
          .toList();
    } else if (_selectedExpiry == 'خلال أسبوع') {
      final end = DateTime.now().add(const Duration(days: 7));
      result = result
          .where((o) => o.validUntil.isBefore(end))
          .toList();
    }

    // ترتيب
    switch (_selectedSort) {
      case '⏳ ينتهي قريباً':
        result.sort((a, b) => a.validUntil.compareTo(b.validUntil));
        break;
      case '👁️ الأكثر زيارة':
        result.sort((a, b) => b.views.compareTo(a.views));
        break;
      case '❤️ الأكثر مفضلة':
        result.sort((a, b) =>
            (b.favoriteCount).compareTo(a.favoriteCount));
        break;
      case '🔥 الخصم الأعلى':
        result.sort((a, b) => b.discount.compareTo(a.discount));
        break;
      default: // الأحدث
        break;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0E0E1A) : const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text('العروض',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Consumer<ShopsProvider>(
        builder: (_, provider, __) {
          final offers = _filteredOffers(provider.offers);

          return Column(
            children: [
              // ✅ شريط بحث "ابحث عن عرض" مع فلاتر
              ContextSearchBar(
                hint: 'ابحث عن عرض...',
                onSearch: (q) => setState(() => _searchQuery = q),
                filters: [
                  SearchFilter(
                    id: 'sort',
                    label: 'الترتيب',
                    options: [
                      'الأحدث',
                      '⏳ ينتهي قريباً',
                      '👁️ الأكثر زيارة',
                      '❤️ الأكثر مفضلة',
                      '🔥 الخصم الأعلى',
                    ],
                    defaultOption: _selectedSort,
                  ),
                  SearchFilter(
                    id: 'expiry',
                    label: 'الصلاحية',
                    options: ['الكل', 'ينتهي اليوم', 'خلال أسبوع'],
                    defaultOption: _selectedExpiry,
                  ),
                ],
                onFilterChanged: (id, val) {
                  setState(() {
                    if (id == 'sort') _selectedSort = val;
                    if (id == 'expiry') _selectedExpiry = val;
                  });
                },
              ),

              // نتائج
              Expanded(
                child: provider.isLoading && offers.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : offers.isEmpty
                        ? _emptyState()
                        : RefreshIndicator(
                            onRefresh: () => provider.fetchOffers(refresh: true),
                            child: ListView(
                              padding: const EdgeInsets.all(12),
                              children: [
                                // إحصائية سريعة
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    '${offers.length} عرض',
                                    style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12),
                                  ),
                                ),
                                ...offers.map(
                                    (o) => _buildOfferCard(o, isDark)),
                                const AppFooter(),
                              ],
                            ),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOfferCard(Offer offer, bool isDark) {
    final daysLeft = offer.validUntil
        .difference(DateTime.now())
        .inDays;
    final isExpiringSoon = daysLeft <= 3;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetailScreen(item: offer)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (offer.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedImage(
                      imageUrl: offer.imageUrl, fit: BoxFit.cover),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '🔥 خصم ${offer.discount}%',
                        style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ),
                    const Spacer(),
                    if (isExpiringSoon)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          daysLeft == 0
                              ? 'ينتهي اليوم!'
                              : 'ينتهي خلال $daysLeft أيام',
                          style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  Text(offer.title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  if (offer.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      offer.description,
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 13, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      'حتى ${offer.validUntil.day}/${offer.validUntil.month}/${offer.validUntil.year}',
                      style: TextStyle(
                          color: Colors.grey[400], fontSize: 12),
                    ),
                    const Spacer(),
                    Icon(Icons.remove_red_eye_outlined,
                        size: 13, color: Colors.grey[400]),
                    const SizedBox(width: 3),
                    Text('${offer.views}',
                        style: TextStyle(
                            color: Colors.grey[400], fontSize: 12)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_offer_outlined,
                size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('لا توجد عروض حالياً',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
}
