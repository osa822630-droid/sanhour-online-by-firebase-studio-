// lib/screens/tabs/admin_content_tab.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/api_service.dart';
import '../../widgets/cached_image.dart'; // تأكد إن الودجت دي موجودة عندك

class AdminContentTab extends StatefulWidget {
  const AdminContentTab({super.key});

  @override
  State<AdminContentTab> createState() => _AdminContentTabState();
}

class _AdminContentTabState extends State<AdminContentTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 3 أقسام: محلات، منتجات، عروض
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // شريط التبويبات الفرعي
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.deepPurple[900],
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.deepPurple[900],
            tabs: const [
              Tab(text: 'المحلات', icon: Icon(Icons.store)),
              Tab(text: 'المنتجات', icon: Icon(Icons.shopping_bag)),
              Tab(text: 'العروض', icon: Icon(Icons.local_offer)),
            ],
          ),
        ),

        // محتوى التبويبات
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildShopsList(),
              _buildProductsList(),
              _buildOffersList(),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // 1. قائمة المحلات (تعطيل + حذف)
  // ==========================================================
  Widget _buildShopsList() {
    return _buildStreamList(
      collection: 'shops',
      itemBuilder: (data) {
        bool isSuspended = data['isSuspended'] ?? false;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          // تمييز المحل المعطل بلون رمادي وإطار أحمر
          color: isSuspended ? Colors.grey[100] : Colors.white,
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
                color: isSuspended ? Colors.grey : Colors.black,
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
                // زر التعطيل/التفعيل
                IconButton(
                  icon: Icon(isSuspended
                      ? Icons.play_circle_fill
                      : Icons.pause_circle_filled),
                  color: isSuspended ? Colors.green : Colors.deepOrangeAccent,
                  tooltip: isSuspended ? 'تفعيل المحل' : 'تعطيل وإخفاء المحل',
                  onPressed: () =>
                      _toggleShop(data['id'], isSuspended, data['name']),
                ),
                // زر الحذف
                IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  tooltip: 'حذف نهائي',
                  onPressed: () => _confirmDeleteShop(data['id'], data['name']),
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
  Widget _buildProductsList() {
    return _buildStreamList(
      collection: 'products',
      itemBuilder: (data) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedImage(
                  imageUrl: (data['imageUrls'] != null &&
                          (data['imageUrls'] as List).isNotEmpty)
                      ? data['imageUrls'][0]
                      : '',
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
                shopId: data['shopId'],
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
  Widget _buildOffersList() {
    return _buildStreamList(
      collection: 'offers',
      itemBuilder: (data) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedImage(
                  imageUrl: data['imageUrl'] ?? '',
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover),
            ),
            title: Text(data['title'] ?? 'عرض',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('خصم ${data['discount']}%',
                style: const TextStyle(
                    color: Colors.deepOrangeAccent, fontWeight: FontWeight.bold)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'حذف مع إشعار',
              onPressed: () => _showDeleteReasonDialog(
                collection: 'offers',
                itemId: data['id'],
                itemName: data['title'] ?? 'عرض',
                shopId: data['shopId'],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- دوال مساعدة ---

  Widget _buildStreamList(
      {required String collection,
      required Widget Function(Map<String, dynamic>) itemBuilder}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .orderBy('createdAt', descending: true)
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
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
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

              // 1. جلب معرف التاجر (Owner ID) من المحل لأن المنتج مفيهوش Owner ID مباشر غالباً
              String ownerId = '';
              try {
                final shopDoc = await FirebaseFirestore.instance
                    .collection('shops')
                    .doc(shopId)
                    .get();
                if (shopDoc.exists) {
                  ownerId = shopDoc.data()?['ownerId'] ?? '';
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
                // لو معرفناش نجيب التاجر، نحذف وخلاص
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
