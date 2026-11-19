// lib/screens/tabs/admin_content_tab.dart
// ✅ إضافة حد (Pagination limit) للاستماع الحي لكل قسم لتجنب تحميل آلاف الوثائق دفعة واحدة
// ✅ توحيد قراءة حقول مقدمي الخدمات (categories / serviceCategory و isActive / isAvailable)
// ✅ دعم الوضع الليلي (Dark Mode) بالكامل
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/api_service.dart';
import '../../widgets/cached_image.dart';

class AdminContentTab extends StatefulWidget {
  const AdminContentTab({super.key});

  @override
  State<AdminContentTab> createState() => _AdminContentTabState();
}

class _AdminContentTabState extends State<AdminContentTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _reasonController = TextEditingController();

  static const int _pageSize = 50;
  final Map<String, int> _limits = {
    'shops': _pageSize,
    'products': _pageSize,
    'offers': _pageSize,
    'service_providers': _pageSize,
  };

  @override
  void initState() {
    super.initState();
    // 4 أقسام: محلات، منتجات، عروض، صنايعية وخدمات
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // شريط التبويبات الفرعي
        Container(
          color: isDark ? const Color(0xFF1B201E) : Colors.white,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: isDark ? Colors.white : const Color(0xFF3D6B5E),
            unselectedLabelColor: Colors.grey,
            indicatorColor:
                isDark ? const Color(0xFF73A899) : const Color(0xFF3D6B5E),
            tabs: const [
              Tab(text: 'المحلات', icon: Icon(Icons.store)),
              Tab(text: 'المنتجات', icon: Icon(Icons.shopping_bag)),
              Tab(text: 'العروض', icon: Icon(Icons.local_offer)),
              Tab(text: 'الصنايعية', icon: Icon(Icons.handyman)),
            ],
          ),
        ),

        // محتوى التبويبات
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildShopsList(isDark),
              _buildProductsList(isDark),
              _buildOffersList(isDark),
              _buildServiceProvidersList(isDark),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // 1. قائمة المحلات (تعطيل + حذف)
  // ==========================================================
  Widget _buildShopsList(bool isDark) {
    return _buildStreamList(
      collection: 'shops',
      itemBuilder: (data) {
        final bool isSuspended = data['isSuspended'] ?? false;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isSuspended
              ? (isDark ? const Color(0xFF251A1E) : Colors.grey[100])
              : (isDark ? const Color(0xFF1B201E) : Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSuspended
                ? const BorderSide(color: Colors.red, width: 1)
                : BorderSide.none,
          ),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedImage(
                  imageUrl: data['imageUrl'] ?? '',
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover),
            ),
            title: Text(
              data['name'] ?? 'بدون اسم',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: isSuspended ? TextDecoration.lineThrough : null,
                color: isSuspended
                    ? Colors.grey
                    : (isDark ? Colors.white : Colors.black),
              ),
            ),
            subtitle: Text(
              isSuspended ? '⛔ معطل (مخفي)' : '✅ نشط',
              style: TextStyle(
                  color: isSuspended ? Colors.red : Colors.green, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(isSuspended
                      ? Icons.play_circle_fill
                      : Icons.pause_circle_filled),
                  color: isSuspended ? Colors.green : Colors.deepOrangeAccent,
                  tooltip: isSuspended ? 'تفعيل المحل' : 'تعطيل وإخفاء المحل',
                  onPressed: () =>
                      _toggleShop(data['id'], isSuspended, data['name'] ?? ''),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  tooltip: 'حذف نهائي',
                  onPressed: () =>
                      _confirmDeleteShop(data['id'], data['name'] ?? ''),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================================
  // 2. قائمة المنتجات (حذف بسبب)
  // ==========================================================
  Widget _buildProductsList(bool isDark) {
    return _buildStreamList(
      collection: 'products',
      itemBuilder: (data) {
        final rawUrls = data['imageUrls'];
        final int coverIdx = (data['coverImageIndex'] is num)
            ? (data['coverImageIndex'] as num).toInt()
            : 0;
        String imgUrl = '';
        if (rawUrls is List && rawUrls.isNotEmpty) {
          final safeIdx =
              (coverIdx >= 0 && coverIdx < rawUrls.length) ? coverIdx : 0;
          imgUrl = (rawUrls[safeIdx] ?? '').toString();
        }
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: isDark ? const Color(0xFF1B201E) : Colors.white,
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedImage(
                  imageUrl: imgUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover),
            ),
            title: Text(data['name'] ?? 'منتج',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${data['price']} ج.م',
                style: const TextStyle(color: Colors.blue)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'حذف مع إشعار',
              onPressed: () => _showDeleteReasonDialog(
                collection: 'products',
                itemId: data['id'],
                itemName: data['name'] ?? 'منتج',
                shopId: data['shopId'] ?? '',
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================================
  // 3. قائمة العروض (حذف بسبب)
  // ==========================================================
  Widget _buildOffersList(bool isDark) {
    return _buildStreamList(
      collection: 'offers',
      itemBuilder: (data) {
        final rawUrls = data['imageUrls'];
        final int coverIdx = (data['coverImageIndex'] is num)
            ? (data['coverImageIndex'] as num).toInt()
            : 0;
        String imgUrl = (data['imageUrl'] ?? '').toString();
        if (rawUrls is List && rawUrls.isNotEmpty) {
          final safeIdx =
              (coverIdx >= 0 && coverIdx < rawUrls.length) ? coverIdx : 0;
          final candidate = (rawUrls[safeIdx] ?? '').toString();
          if (candidate.isNotEmpty) imgUrl = candidate;
        }
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: isDark ? const Color(0xFF1B201E) : Colors.white,
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedImage(
                  imageUrl: imgUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover),
            ),
            title: Text(data['title'] ?? 'عرض',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('خصم ${data['discount']}%',
                style: const TextStyle(
                    color: Colors.deepOrangeAccent,
                    fontWeight: FontWeight.bold)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'حذف مع إشعار',
              onPressed: () => _showDeleteReasonDialog(
                collection: 'offers',
                itemId: data['id'],
                itemName: data['title'] ?? 'عرض',
                shopId: data['shopId'] ?? '',
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================================
  // 4. قائمة الصنايعية ومقدمي الخدمات (توثيق + تفعيل + حذف)
  // ==========================================================
  Widget _buildServiceProvidersList(bool isDark) {
    return _buildStreamList(
      collection: 'service_providers',
      itemBuilder: (data) {
        final bool isVerified = data['isVerified'] == true;
        // ✅ دعم الحقلين isActive (الجديد) و isAvailable (القديم)
        final bool isAvailable =
            (data['isActive'] as bool?) ?? (data['isAvailable'] as bool?) ?? true;
        final String name = data['name'] ?? 'مقدم خدمة';
        // ✅ دعم الحقلين categories (List) و serviceCategory (String)
        String category = 'خدمات عامة';
        if (data['categories'] is List &&
            (data['categories'] as List).isNotEmpty) {
          category = (data['categories'] as List).join('، ');
        } else if ((data['serviceCategory'] ?? '').toString().isNotEmpty) {
          category = data['serviceCategory'].toString();
        }
        final String phone = data['phone'] ?? '';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: isDark ? const Color(0xFF1B201E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isVerified ? Colors.green.shade300 : Colors.amber.shade400,
              width: 1,
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  isVerified ? Colors.green.shade50 : Colors.amber.shade50,
              child: Icon(
                isVerified ? Icons.verified_user : Icons.pending_actions,
                color: isVerified ? Colors.green : Colors.amber.shade800,
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '$category ${phone.isNotEmpty ? "• $phone" : ""}\n'
              '${isVerified ? "✅ موثق" : "⏳ بانتظار التوثيق"} • ${isAvailable ? "متاح" : "غير متاح"}',
              style: const TextStyle(fontSize: 12),
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    isVerified ? Icons.verified : Icons.check_circle_outline,
                    color: isVerified ? Colors.green : Colors.blueGrey,
                  ),
                  tooltip: isVerified ? 'إلغاء التوثيق' : 'توثيق مقدم الخدمة',
                  onPressed: () =>
                      _toggleProviderVerification(data['id'], isVerified, name),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'حذف مقدم الخدمة',
                  onPressed: () => _deleteServiceProvider(data['id'], name),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleProviderVerification(
      String providerId, bool currentVerified, String name) async {
    try {
      await FirebaseFirestore.instance
          .collection('service_providers')
          .doc(providerId)
          .update({
        'isVerified': !currentVerified,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!currentVerified
                ? 'تم توثيق "$name" بنجاح ✅'
                : 'تم إلغاء توثيق "$name"'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر التحديث: $e')),
        );
      }
    }
  }

  Future<void> _deleteServiceProvider(String providerId, String name) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('حذف مقدم الخدمة'),
            content: Text('هل تريد حذف حساب مقدم الخدمة "$name" نهائياً؟'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حذف'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirm) return;
    await ApiService.deleteContent('service_providers', providerId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف مقدم الخدمة')),
      );
    }
  }

  // --- دوال مساعدة ---

  Widget _buildStreamList({
    required String collection,
    required Widget Function(Map<String, dynamic>) itemBuilder,
  }) {
    final currentLimit = _limits[collection] ?? _pageSize;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .orderBy('createdAt', descending: true)
          .limit(currentLimit)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        // ✅ Fix #105: عرض حالة الخطأ بدلاً من الفشل الصامت
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('تعذّر تحميل البيانات: ${snapshot.error}',
                    textAlign: TextAlign.center),
              ],
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('لا توجد بيانات'));
        }

        final docs = snapshot.data!.docs;
        final hasMore = docs.length >= currentLimit;

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          itemCount: docs.length + (hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == docs.length) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _limits[collection] = currentLimit + _pageSize;
                    });
                  },
                  icon: const Icon(Icons.expand_more),
                  label: const Text('تحميل المزيد'),
                ),
              );
            }
            final data = Map<String, dynamic>.from(
                docs[index].data() as Map<String, dynamic>);
            data['id'] = docs[index].id;
            return itemBuilder(data);
          },
        );
      },
    );
  }

  // --- المنطق (Logic) ---

  // أ) تبديل حالة المحل (تعطيل/تفعيل)
  Future<void> _toggleShop(
      String shopId, bool currentStatus, String name) async {
    bool confirm = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(currentStatus ? 'تفعيل المحل' : 'تعطيل المحل'),
            content: Text(currentStatus
                ? 'سيتم إعادة إظهار المحل "$name" وجميع منتجاته للمستخدمين.'
                : 'سيتم إخفاء المحل "$name" وكل منتجاته وعروضه وإعلاناته فوراً.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: currentStatus ? Colors.green : Colors.red,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(currentStatus ? 'تفعيل' : 'تعطيل وإخفاء'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await ApiService.toggleShopSuspension(shopId, currentStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(currentStatus ? 'تم التفعيل ✅' : 'تم التعطيل ⛔')));
      }
    }
  }

  // ب) حذف المحل نهائياً
  Future<void> _confirmDeleteShop(String shopId, String name) async {
    bool confirm = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('حذف نهائي للمحل'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تحذير: أنت على وشك حذف محل "$name".'),
                const SizedBox(height: 10),
                const Text(
                    '• سيتم حذف جميع المنتجات والعروض والتقييمات المرتبطة به.',
                    style: TextStyle(color: Colors.red, fontSize: 12)),
                const Text('• لا يمكن التراجع عن هذا الإجراء.',
                    style: TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حذف الكل'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await ApiService.deleteShop(shopId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف المحل وجميع بياناته')));
      }
    }
  }

  // ج) حذف عنصر (منتج/عرض) مع ذكر السبب
  Future<void> _showDeleteReasonDialog({
    required String collection,
    required String itemId,
    required String itemName,
    required String shopId,
  }) async {
    _reasonController.clear();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف ${collection == 'products' ? 'المنتج' : 'العرض'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('الرجاء ذكر سبب الحذف لإرسال إشعار للتاجر:',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'سبب المخالفة',
                hintText: 'مثال: صورة غير لائقة، سعر مضلل...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              if (_reasonController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يجب كتابة السبب!')));
                return;
              }
              Navigator.pop(ctx);

              // 1. جلب معرف التاجر (Owner ID) من المحل
              String ownerId = '';
              try {
                if (shopId.isNotEmpty) {
                  final shopDoc = await FirebaseFirestore.instance
                      .collection('shops')
                      .doc(shopId)
                      .get();
                  if (shopDoc.exists) {
                    ownerId = shopDoc.data()?['ownerId'] ?? '';
                  }
                }
              } catch (e) {
                debugPrint('Error getting owner: $e');
              }

              // 2. التنفيذ
              if (ownerId.isNotEmpty) {
                await ApiService.deleteItemWithNotification(
                  collection: collection,
                  itemId: itemId,
                  ownerId: ownerId,
                  itemName: itemName,
                  reason: _reasonController.text,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('تم الحذف وإبلاغ التاجر ✅')));
                }
              } else {
                await ApiService.deleteContent(collection, itemId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                          Text('تم الحذف (لم يتم العثور على التاجر لإبلاغه)')));
                }
              }
            },
            child: const Text('حذف وإبلاغ'),
          ),
        ],
      ),
    );
  }
}
