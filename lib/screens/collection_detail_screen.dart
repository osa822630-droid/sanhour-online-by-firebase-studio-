// lib/screens/collection_detail_screen.dart
// ✅ إلغاء حوار الهدية/الخصم عند الدعوة
// ✅ دعوة عبر رقم الهاتف (بكل الصيغ) أو اسم المستخدم + فتح العنصر عند النقر
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/wishlist_collection_model.dart';
import '../providers/favorites_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/cached_image.dart';
import '../services/deep_link_service.dart';
import '../utils/constants.dart';

class CollectionDetailScreen extends StatefulWidget {
  final WishlistCollection collection;
  const CollectionDetailScreen({super.key, required this.collection});

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  void _share(WishlistCollection col) {
    DeepLinkService.shareCollection(
      id: col.id,
      name: col.name,
      itemCount: col.items.length,
    );
  }

  Future<void> _showInviteDialog(
      BuildContext context, WishlistCollection col) async {
    final queryCtrl = TextEditingController();
    Map<String, dynamic>? foundUser;
    bool isSearching = false;
    String? searchError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLS) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.person_add_outlined,
                    color: Color(0xFF5E35B1)),
                const SizedBox(width: 10),
                const Text('دعوة شخص للقائمة',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ]),
              const SizedBox(height: 4),
              const Text(
                'ابحث برقم الهاتف أو اسم المستخدم.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),

              Row(children: [
                Expanded(
                  child: TextField(
                    controller: queryCtrl,
                    textDirection: TextDirection.ltr,
                    onChanged: (_) {
                      if (searchError != null) {
                        setLS(() => searchError = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: '01xxxxxxxxx أو @username',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.grey),
                      errorText: searchError,
                    ),
                    keyboardType: TextInputType.text,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E35B1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  onPressed: isSearching
                      ? null
                      : () async {
                          final q = queryCtrl.text.trim();
                          if (q.isEmpty) return;
                          setLS(() {
                            isSearching = true;
                            foundUser = null;
                            searchError = null;
                          });
                          try {
                            final result = await _searchUser(q);
                            setLS(() {
                              foundUser = result;
                              isSearching = false;
                              if (result == null) {
                                searchError =
                                    'لم يُعثر على مستخدم بهذه البيانات';
                              }
                            });
                          } catch (e) {
                            setLS(() {
                              isSearching = false;
                              searchError = 'حدث خطأ، حاول مرة أخرى';
                            });
                          }
                        },
                  child: isSearching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('بحث'),
                ),
              ]),

              const SizedBox(height: 16),

              if (foundUser != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5E35B1).withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            const Color(0xFF5E35B1).withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF5E35B1),
                      child: Text(
                        ((foundUser!['name'] as String? ?? 'م').trim().isNotEmpty
                                ? (foundUser!['name'] as String).trim()[0]
                                : 'م')
                            .toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            foundUser!['name'] as String? ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          if ((foundUser!['username'] as String?)
                                  ?.isNotEmpty ==
                              true)
                            Text(
                              '@${foundUser!['username']}',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _sendInvite(
                          col: col,
                          targetUserId: foundUser!['id'] as String,
                          targetUserName:
                              foundUser!['name'] as String? ?? 'مستخدم',
                        );
                      },
                      child: const Text('دعوة'),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ).whenComplete(() => queryCtrl.dispose());
  }

  // ── البحث عن مستخدم برقم الهاتف (بكل الصيغ) أو اسم المستخدم ─────────
  Future<Map<String, dynamic>?> _searchUser(String query) async {
    final db = FirebaseFirestore.instance;
    QuerySnapshot? snap;

    final cleanQuery = query.replaceFirst('@', '').trim();
    final phoneCandidates = AppConstants.phoneLookupCandidates(cleanQuery);

    if (phoneCandidates.isNotEmpty) {
      snap = await db
          .collection('users')
          .where('phone', whereIn: phoneCandidates)
          .limit(1)
          .get();
    }

    if (snap == null || snap.docs.isEmpty) {
      snap = await db
          .collection('users')
          .where('username', isEqualTo: cleanQuery)
          .limit(1)
          .get();
    }

    if (snap.docs.isEmpty) {
      final usernameDoc = await db
          .collection('usernames')
          .doc(cleanQuery.toLowerCase())
          .get();
      final uid = usernameDoc.data()?['uid'] as String?;
      if (uid != null && uid.isNotEmpty) {
        final userDoc = await db.collection('users').doc(uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          final data = Map<String, dynamic>.from(userDoc.data()!);
          data['id'] = userDoc.id;
          return data;
        }
      }
      return null;
    }

    final data =
        Map<String, dynamic>.from(snap.docs.first.data() as Map<String, dynamic>);
    data['id'] = snap.docs.first.id;
    return data;
  }

  static const int maxCollaborators = 20;

  Future<void> _sendInvite({
    required WishlistCollection col,
    required String targetUserId,
    required String targetUserName,
  }) async {
    if (col.collaborators.length >= maxCollaborators) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('وصلت القائمة للحد الأقصى للمتعاونين (20 عضواً)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final senderName = auth.user?.name ?? 'أحد المستخدمين';

    try {
      await FirebaseFirestore.instance.collection('collection_invites').add({
        'collectionId': col.id,
        'collectionName': col.name,
        'inviterId': auth.user?.id ?? '',
        'inviterName': senderName,
        'inviteeId': targetUserId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('notifications').add({
        'title': 'دعوة لقائمة مشتريات 🛒',
        'body': '$senderName يدعوك للانضمام لقائمة "${col.name}"',
        'type': 'collection_invite',
        'targetUserId': targetUserId,
        'fromUserId': auth.user?.id ?? '',
        'data': {
          'collectionId': col.id,
          'collectionName': col.name,
          'inviterId': auth.user?.id ?? '',
          'inviterName': senderName,
        },
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('notification_queue').add({
        'title': 'دعوة لقائمة مشتريات 🛒',
        'body': '$senderName يدعوك للانضمام لقائمة "${col.name}"',
        'targetUserId': targetUserId,
        'data': {
          'route': 'notifications',
          'channel': 'user_collections',
        },
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إرسال الدعوة لـ $targetUserName ✅'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل إرسال الدعوة. حاول مرة أخرى.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openItem(WishlistItem item) {
    if (item.itemId.isEmpty) return;
    if (item.type == 'shop') {
      Navigator.pushNamed(context, '/shop/${item.itemId}');
    } else if (item.type == 'offer') {
      Navigator.pushNamed(context, '/offer/${item.itemId}');
    } else {
      Navigator.pushNamed(context, '/product/${item.itemId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesProvider>(
      builder: (context, provider, _) {
        final updated = provider.collections.firstWhere(
          (c) => c.id == widget.collection.id,
          orElse: () => widget.collection,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(updated.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: const Color(0xFF5E35B1),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.person_add_outlined),
                tooltip: 'دعوة شخص',
                onPressed: () => _showInviteDialog(context, updated),
              ),
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'مشاركة الرابط',
                onPressed: () => _share(updated),
              ),
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'delete') {
                    _showDeleteDialog(context, provider, updated);
                  } else if (val == 'rename') {
                    _showRenameDialog(context, provider, updated);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(children: [
                      Icon(Icons.edit, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('إعادة التسمية'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('حذف القائمة',
                          style: TextStyle(color: Colors.red)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
          body: updated.items.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      color: const Color(0xFF5E35B1).withValues(alpha: 0.07),
                      child: Row(children: [
                        const Icon(Icons.collections_bookmark,
                            size: 16, color: Color(0xFF5E35B1)),
                        const SizedBox(width: 8),
                        Text(
                          '${updated.items.length} عنصر في القائمة',
                          style: const TextStyle(
                              color: Color(0xFF5E35B1),
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                        const Spacer(),
                        if (updated.collaborators.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.4)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.group,
                                  size: 12, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                'مشتركة (${updated.collaborators.length})',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold),
                              ),
                            ]),
                          ),
                      ]),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: updated.items.length,
                        itemBuilder: (_, i) {
                          final item = updated.items[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              onTap: () => _openItem(item),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                    width: 52,
                                    height: 52,
                                    child: CachedImage(
                                        imageUrl: item.imageUrl)),
                              ),
                              title: Text(item.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: item.price > 0
                                  ? Text(
                                      '${item.price.toStringAsFixed(0)} جنيه',
                                      style: const TextStyle(
                                          color: Color(0xFF5E35B1)))
                                  : null,
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red, size: 20),
                                onPressed: () =>
                                    provider.removeItemFromCollection(
                                        updated.id, item),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_shopping_cart_outlined,
                size: 70, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('القائمة فارغة',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('أضف منتجات وعروض من شاشة التصفح',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );

  void _showRenameDialog(BuildContext context, FavoritesProvider p,
      WishlistCollection col) {
    final ctrl = TextEditingController(text: col.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إعادة التسمية'),
        content: TextField(
            controller: ctrl,
            autofocus: true,
            maxLength: 50,
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'[<>"/\\]')),
            ],
            decoration:
                const InputDecoration(hintText: 'اسم القائمة الجديد')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E35B1),
                foregroundColor: Colors.white),
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                FirebaseFirestore.instance
                    .collection('wishlists')
                    .doc(col.id)
                    .update({'name': name}).then((_) => p.loadFavorites());
                Navigator.pop(ctx);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ).whenComplete(() => ctrl.dispose());
  }

  void _showDeleteDialog(BuildContext context, FavoritesProvider p,
      WishlistCollection col) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف القائمة؟'),
        content: Text('سيتم حذف "${col.name}" نهائياً.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              p.deleteCollection(col.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
