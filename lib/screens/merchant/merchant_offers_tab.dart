// lib/screens/merchant/merchant_offers_tab.dart
import 'package:material_ui/material_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/date_helper.dart';
import '../../services/api_service.dart';
import '../../models/shop.dart';
import '../../models/offer.dart';
import '../../widgets/cached_image.dart';
import '../add_offer_screen.dart';

class MerchantOffersTab extends StatefulWidget {
  final Shop currentShop;

  const MerchantOffersTab({super.key, required this.currentShop});

  @override
  State<MerchantOffersTab> createState() => _MerchantOffersTabState();
}

class _MerchantOffersTabState extends State<MerchantOffersTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Offer>? _allOffers;
  late Future<List<Offer>> _offersFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _offersFuture = ApiService.getOffers(
        shopId: widget.currentShop.id, includeInactive: true);
  }

  void _refreshOffers() {
    setState(() {
      _allOffers = null;
      _offersFuture = ApiService.getOffers(
          shopId: widget.currentShop.id, includeInactive: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Column(
        children: [
          // 1. شريط البحث والتبويبات
          Container(
            color: isDark ? const Color(0xFF1B201E) : Colors.white,
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'بحث في العروض...',
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              })
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 0, horizontal: 15),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF232927)
                          : Colors.grey[100],
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),

                const SizedBox(height: 10),

                TabBar(
                  controller: _tabController,
                  labelColor: isDark
                      ? const Color(0xFFB39DDB)
                      : const Color(0xFF3D6B5E),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: const Color(0xFF3D6B5E),
                  tabs: const [
                    Tab(text: 'نشط 🟢'),
                    Tab(text: 'منتهي / أرشيف 🔴'),
                  ],
                ),
                const Divider(height: 1),
              ],
            ),
          ),

          // 2. المحتوى
          Expanded(
            child: FutureBuilder<List<Offer>>(
              future: _offersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    _allOffers == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError && _allOffers == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        const Text('تعذّر تحميل العروض',
                            style: TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _refreshOffers,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasData) {
                  _allOffers = snapshot.data!;
                }

                if (_allOffers == null || _allOffers!.isEmpty) {
                  return _buildEmptyState();
                }

                final now = DateTime.now();

                final searchResults = _allOffers!
                    .where((o) => o.title
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase()))
                    .toList();

                final activeOffers = searchResults
                    .where((o) => !o.validUntil.isBefore(now))
                    .toList();
                final expiredOffers = searchResults
                    .where((o) => o.validUntil.isBefore(now))
                    .toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOffersList(activeOffers,
                        isActiveTab: true, isDark: isDark),
                    _buildOffersList(expiredOffers,
                        isActiveTab: false, isDark: isDark),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.discount_outlined, size: 60, color: Colors.grey),
          SizedBox(height: 10),
          Text('لا توجد عروض حالياً'),
          SizedBox(height: 5),
          Text('أضف عروض جديدة لجذب العملاء! 🚀',
              style: TextStyle(color: Colors.green)),
        ],
      ),
    );
  }

  Widget _buildOffersList(List<Offer> offers,
      {required bool isActiveTab, required bool isDark}) {
    if (offers.isEmpty) {
      return Center(
        child: Text(
          isActiveTab ? 'لا توجد عروض نشطة' : 'سجل العروض فارغ',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _refreshOffers(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80, top: 10),
        itemCount: offers.length,
        itemBuilder: (context, index) {
          final offer = offers[index];
          return _buildOfferItem(offer, isActiveTab, isDark);
        },
      ),
    );
  }

  Widget _buildOfferItem(Offer offer, bool isActiveTab, bool isDark) {
    final dateStr = DateHelper.day(offer.validUntil);
    final isVisible = offer.isVisible && offer.isActive;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: isVisible
          ? (isDark ? const Color(0xFF1B201E) : Colors.white)
          : (isDark ? const Color(0xFF151522) : Colors.grey[100]),
      elevation: isVisible ? 2 : 0,
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(10),
            leading: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Opacity(
                    opacity: isVisible ? 1 : 0.6,
                    child: CachedImage(
                      imageUrl: offer.displayImageUrl,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      fallbackIcon: Icons.local_offer_outlined,
                    ),
                  ),
                ),
                if (!isVisible)
                  const Positioned.fill(
                    child: Center(
                        child: Icon(Icons.visibility_off,
                            color: Colors.black54)),
                  ),
              ],
            ),
            title: Text(
              offer.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: isVisible ? null : TextDecoration.lineThrough,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                if (offer.discount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text('خصم ${offer.discount}%',
                        style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                const SizedBox(height: 4),
                Text(isActiveTab ? 'ينتهي في: $dateStr' : 'انتهى في: $dateStr',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleAction(value, offer),
              itemBuilder: (context) => [
                if (isActiveTab)
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(isVisible ? Icons.pause : Icons.play_arrow,
                            color: isVisible ? Colors.orange : Colors.green),
                        const SizedBox(width: 8),
                        Text(isVisible ? 'تجميد مؤقت' : 'تفعيل العرض'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('تعديل')
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'duplicate',
                  child: Row(
                    children: [
                      Icon(Icons.copy, color: Colors.purple),
                      SizedBox(width: 8),
                      Text('تكرار العرض')
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('حذف')
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isActiveTab)
            Container(
              width: double.infinity,
              color: Colors.red.withValues(alpha: 0.08),
              child: TextButton.icon(
                icon: const Icon(Icons.refresh, size: 16, color: Colors.red),
                label: const Text('إعادة نشر العرض (تكرار)',
                    style: TextStyle(color: Colors.red)),
                onPressed: () => _handleAction('duplicate', offer),
              ),
            ),
        ],
      ),
    );
  }

  void _handleAction(String action, Offer offer) {
    switch (action) {
      case 'toggle':
        _toggleVisibility(offer);
        break;
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => AddOfferScreen(
                  shopId: widget.currentShop.id,
                  ownerId: widget.currentShop.ownerId,
                  offerToEdit: offer)),
        ).then((_) => _refreshOffers());
        break;
      case 'duplicate':
        final newOffer = offer.copyWith(
          id: '',
          validUntil: DateTime.now().add(const Duration(days: 7)),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddOfferScreen(
              shopId: widget.currentShop.id,
              ownerId: widget.currentShop.ownerId,
              offerToEdit: newOffer,
            ),
          ),
        ).then((_) => _refreshOffers());
        break;
      case 'delete':
        _confirmDelete(offer);
        break;
    }
  }

  Future<void> _toggleVisibility(Offer offer) async {
    final newVisible = !(offer.isVisible && offer.isActive);
    try {
      await FirebaseFirestore.instance
          .collection('offers')
          .doc(offer.id)
          .update({
        'isVisible': newVisible,
        'isActive': newVisible,
      });

      _refreshOffers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newVisible ? 'تم تفعيل العرض ✅' : 'تم تجميد العرض ⏸️'),
          duration: const Duration(seconds: 1),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('حدث خطأ، يُرجى المحاولة مرة أخرى'),
            backgroundColor: Colors.red));
      }
    }
  }

  void _confirmDelete(Offer offer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف العرض'),
        content: const Text('هل أنت متأكد؟ لا يمكن التراجع.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService.deleteOffer(offer.id);
              _refreshOffers();
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('تم الحذف')));
              }
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
