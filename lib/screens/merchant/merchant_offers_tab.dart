// lib/screens/merchant/merchant_offers_tab.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // للتحديث المباشر
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
  // ✅ Fix #83: تخزين الـ future في state لمنع re-fetch عند كل rebuild
  late Future<List<Offer>> _offersFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _offersFuture = ApiService.getOffers(shopId: widget.currentShop.id);
  }

  void _refreshOffers() {
    setState(() {
      _allOffers = null;
      _offersFuture = ApiService.getOffers(shopId: widget.currentShop.id);
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
    return Scaffold(
      body: Column(
        children: [
          // 1. شريط البحث والتبويبات
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              children: [
                // البحث
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'بحث في العروض...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
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
                      fillColor: Colors.grey[100],
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),

                const SizedBox(height: 10),

                // التبويبات
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.red[800],
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.red[800],
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
              // ✅ Fix #83: استخدام future محفوظ في state
              future: _offersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    _allOffers == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                // ✅ Fix #101: عرض حالة الخطأ بدلاً من blank screen
                if (snapshot.hasError && _allOffers == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
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

                // تقسيم العروض
                final now = DateTime.now();

                // تطبيق البحث
                final searchResults = _allOffers!
                    .where((o) => o.title
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase()))
                    .toList();

                // فصل النشط عن المنتهي
                final activeOffers = searchResults
                    .where((o) => o.validUntil.isAfter(now))
                    .toList();
                final expiredOffers = searchResults
                    .where((o) => o.validUntil.isBefore(now))
                    .toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOffersList(activeOffers, isActiveTab: true),
                    _buildOffersList(expiredOffers, isActiveTab: false),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Widgets ---

  Widget _buildEmptyState() {
    return Center(
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

  Widget _buildOffersList(List<Offer> offers, {required bool isActiveTab}) {
    if (offers.isEmpty) {
      return Center(
        child: Text(
          isActiveTab ? 'لا توجد عروض نشطة' : 'سجل العروض فارغ',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80, top: 10),
      itemCount: offers.length,
      itemBuilder: (context, index) {
        final offer = offers[index];
        return _buildOfferItem(offer, isActiveTab);
      },
    );
  }

  Widget _buildOfferItem(Offer offer, bool isActiveTab) {
    // ✅ Pro #221: DateHelper بدلاً من DateFormat مباشرة
    final dateStr = DateHelper.day(offer.validUntil);
    final isVisible = offer.isVisible;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: isVisible ? Colors.white : Colors.grey[100],
      elevation: isVisible ? 2 : 0,
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(10),
            // الصورة
            leading: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Opacity(
                    opacity: isVisible ? 1 : 0.6,
                    child: CachedImage(
                      imageUrl: offer.imageUrl,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (!isVisible)
                  const Positioned.fill(
                    child: Center(
                        child:
                            Icon(Icons.visibility_off, color: Colors.black54)),
                  ),
              ],
            ),

            // التفاصيل
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(4)),
                  child: Text('خصم ${offer.discount}%',
                      style: TextStyle(
                          color: Colors.red[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
                const SizedBox(height: 4),
                Text(isActiveTab ? 'ينتهي في: $dateStr' : 'انتهى في: $dateStr',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),

            // القائمة الجانبية (3 نقاط)
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleAction(value, offer),
              itemBuilder: (context) => [
                // 1. تجميد/تفعيل (للعروض النشطة فقط)
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

                // 2. تعديل
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

                // 3. تكرار (مفيد جداً للمنتهية)
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

                // 4. حذف
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

          // زر التكرار السريع للعروض المنتهية
          if (!isActiveTab)
            Container(
              width: double.infinity,
              color: Colors.red[50],
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

  // --- Actions Logic ---

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
                  shopId: widget.currentShop.id, offerToEdit: offer)),
        ).then((_) => _refreshOffers());
        break;
      case 'duplicate':
        // ✅ Fix #84: copyWith بدون id — AddOfferScreen يُنشئ عرضاً جديداً
        // لا نُمرر id: null حتى لا يُعيد تعديل العرض الأصلي
        final newOffer = offer.copyWith(
          id: '',
          validUntil: DateTime.now().add(const Duration(days: 7)),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddOfferScreen(
              shopId: widget.currentShop.id,
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

  // تجميد/تفعيل
  Future<void> _toggleVisibility(Offer offer) async {
    // تحديث فوري (Optimistic)
    setState(() {
      // هنا بنعتمد على إعادة التحميل أو ممكن نحدث الليستة محلياً لو حبينا
    });

    try {
      // استخدام فايرستور مباشرة للتحديث السريع (أو ضيف updateOffer في ApiService)
      await FirebaseFirestore.instance
          .collection('offers')
          .doc(offer.id)
          .update({'isVisible': !offer.isVisible});

      setState(() {}); // إعادة بناء لجلب البيانات الجديدة
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(offer.isVisible ? 'تم تفعيل العرض ✅' : 'تم تجميد العرض ⏸️'),
          duration: const Duration(seconds: 1),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('حدث خطأ، يُرجى المحاولة مرة أخرى'), backgroundColor: Colors.red));
      }
    }
  }

  // تكرار العرض
  void duplicateOffer(Offer offer) {
    final newOffer = offer.copyWith(id: null, validUntil: DateTime.now().add(const Duration(days: 7)));
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddOfferScreen(
          shopId: widget.currentShop.id,
          offerToEdit: newOffer,
        ),
      ),
    ).then((_) => setState(() {}));
  }


  void _confirmDelete(Offer offer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف العرض'),
        content: const Text('هل أنت متأكد؟ لا يمكن التراجع.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService.deleteOffer(offer.id);
              setState(() {});
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
