// lib/screens/notifications_screen.dart
import '../utils/date_helper.dart';
// ✅ دعم قبول/رفض دعوات القوائم مباشرة من شاشة الإشعارات
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_footer.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _db = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _sub;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _listen() {
    final auth = context.read<AuthProvider>();
    final userId = auth.user?.id;

    // ✅ Fix #14: الاستعلام موجَّه للمستخدم من الخادم (targetUserId) بدل قراءة
    // آخر 60 إشعاراً لكل المستخدمين ثم الفلترة محلياً — القواعد ترفض أي
    // استعلام غير مقيَّد بصاحب الإشعار (فكانت الشاشة تظهر فارغة)، وكان يهدر
    // قراءات على مستندات ليست لهذا المستخدم. البث العام (all/merchants/
    // customers) أصبح Push فقط عبر notification_queue ولا يمر بهذا الصندوق.
    // (تُستدعى من initState قبل أول build، فلا حاجة لـ setState هنا.)
    if (userId == null || userId.isEmpty) {
      _isLoading = false;
      return;
    }

    _sub = _db
        .collection('notifications')
        .where('targetUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(60)
        .snapshots()
        .listen(
      (snap) {
        if (!mounted) return;
        final all = snap.docs.map((d) {
          final data = Map<String, dynamic>.from(d.data());
          data['id'] = d.id;
          return data;
        }).toList();

        setState(() {
          _notifications = all;
          _isLoading = false;
        });
      },
      onError: (_) {
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  Future<void> _markAllRead() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;

    final unread = _notifications
        .where((n) => n['isRead'] != true)
        .toList();
    if (unread.isEmpty) return;

    // ✅ Fix #68 #183: batch chunked ≤490 + تحديث الـ UI فوراً
    // ✅ Fix #184: setState قبل await لتجنب context غير نشط
    setState(() {
      for (final n in unread) {
        n['isRead'] = true;
      }
    });

    // ✅ Fix #183: تقسيم batch إذا تجاوز 490
    for (int i = 0; i < unread.length; i += 490) {
      final chunk = unread.sublist(
          i, (i + 490).clamp(0, unread.length));
      final batch = _db.batch();
      for (final n in chunk) {
        final id = n['id'] as String?;
        if (id != null && id.isNotEmpty) {
          batch.update(_db.collection('notifications').doc(id), {
            'isRead': true,
          });
        }
      }
      await batch.commit();
    }
  }

  // ── قبول دعوة القائمة ────────────────────────────────────────────
  Future<void> _acceptInvite(Map<String, dynamic> notif) async {
    final data = notif['data'] as Map<String, dynamic>?;
    if (data == null) return;
    final collectionId = data['collectionId'] as String?;
    final inviterId = data['inviterId'] as String?;
    if (collectionId == null) return;

    final auth = context.read<AuthProvider>();
    final userId = auth.user?.id;
    if (userId == null) return;

    try {
      // إضافة المستخدم كمتعاون
      await _db.collection('wishlists').doc(collectionId).update({
        'collaborators': FieldValue.arrayUnion([userId]),
      });

      // تحديث الدعوة
      await _updateInviteStatus(
          collectionId, userId, inviterId, 'accepted');

      // تعليم الإشعار كمقروء
      await _db.collection('notifications').doc(notif['id']).update({
        'isRead': true,
        'inviteStatus': 'accepted',
      });

      // إشعار الإدارة/المرسل بالقبول
      if (inviterId != null) {
        await _db.collection('notifications').add({
          'title': '✅ ${auth.user?.name ?? 'مستخدم'} قبل دعوتك',
          'body':
              'انضم لقائمة "${data['collectionName'] ?? ''}"',
          'type': 'invite_accepted',
          'targetUserId': inviterId,
          'fromUserId': userId,
          'isRead': false,
          'data': {'route': 'collection:$collectionId'},
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تمت إضافتك للقائمة بنجاح ✅'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('حدث خطأ، حاول مرة أخرى'),
        backgroundColor: Colors.red,
      ));
    }
  }

  // ── رفض دعوة القائمة ────────────────────────────────────────────
  Future<void> _rejectInvite(Map<String, dynamic> notif) async {
    final data = notif['data'] as Map<String, dynamic>?;
    if (data == null) return;
    final collectionId = data['collectionId'] as String?;
    final inviterId = data['inviterId'] as String?;

    try {
      final userId = context.read<AuthProvider>().user?.id;
      await _updateInviteStatus(
          collectionId, userId, inviterId, 'rejected');

      await _db.collection('notifications').doc(notif['id']).update({
        'isRead': true,
        'inviteStatus': 'rejected',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم رفض الدعوة'),
        backgroundColor: Colors.grey,
        duration: Duration(seconds: 1),
      ));
    } catch (_) {}
  }

  Future<void> _updateInviteStatus(
    String? collectionId,
    String? userId,
    String? inviterId,
    String status,
  ) async {
    if (collectionId == null || userId == null) return;
    final snap = await _db
        .collection('collection_invites')
        .where('collectionId', isEqualTo: collectionId)
        .where('inviteeId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    for (final d in snap.docs) {
      await d.reference.update({'status': status});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadCount = _notifications.where((n) => n['isRead'] != true).length;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0E0E1A) : const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('الإشعارات',
                style: TextStyle(fontWeight: FontWeight.bold)),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('تحديد الكل',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF5E35B1)))
          : _notifications.isEmpty
              ? _buildEmptyState()
              : ListView(
                  children: [
                    // ✅ Fix #207: تجميع الإشعارات حسب التاريخ (اليوم / أمس / هذا الأسبوع / أقدم)
                    ..._buildGroupedNotifications(isDark),
                    const AppFooter(),
                  ],
                ),
    );
  }

  List<Widget> _buildGroupedNotifications(bool isDark) {
    final groups = <String, List<Map<String, dynamic>>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    for (final n in _notifications) {
      DateTime date = now;
      final createdAt = n['createdAt'];
      if (createdAt is Timestamp) date = createdAt.toDate();
      final d = DateTime(date.year, date.month, date.day);

      final String group;
      if (!d.isBefore(today)) {
        group = 'اليوم';
      } else if (!d.isBefore(yesterday)) {
        group = 'أمس';
      } else if (!d.isBefore(weekAgo)) {
        group = 'هذا الأسبوع';
      } else {
        group = 'أقدم';
      }
      groups.putIfAbsent(group, () => []).add(n);
    }

    const order = ['اليوم', 'أمس', 'هذا الأسبوع', 'أقدم'];
    final widgets = <Widget>[];
    for (final key in order) {
      final items = groups[key];
      if (items == null || items.isEmpty) continue;
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            key,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
      widgets.addAll(items.map((n) => _buildNotifTile(n, isDark)));
    }
    return widgets;
  }

  Widget _buildNotifTile(Map<String, dynamic> n, bool isDark) {
    final title = n['title'] as String? ?? 'إشعار';
    final body = n['body'] as String? ?? '';
    final isRead = n['isRead'] as bool? ?? false;
    final type = n['type'] as String? ?? 'general';
    final inviteStatus = n['inviteStatus'] as String?;
    final createdAt = n['createdAt'];

    DateTime? date;
    if (createdAt is Timestamp) date = createdAt.toDate();

    // أيقونة ولون حسب النوع
    IconData icon;
    Color color;
    switch (type) {
      case 'collection_invite':
        icon = Icons.group_add;
        color = Colors.deepPurple;
        break;
      case 'invite_accepted':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'offer':
        icon = Icons.local_offer;
        color = Colors.orange;
        break;
      case 'system':
        icon = Icons.info;
        color = Colors.blue;
        break;
      case 'price_drop':
        icon = Icons.trending_down;
        color = Colors.red;
        break;
      default:
        icon = Icons.notifications;
        color = const Color(0xFF5E35B1);
    }

    final isPendingInvite =
        type == 'collection_invite' && inviteStatus == null;

    return Container(
      color: isRead
          ? Colors.transparent
          : (isDark
              ? const Color(0xFF1E1040)
              : const Color(0xFFF0EEFF)),
      child: Column(
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            title: Text(title,
                style: TextStyle(
                    fontWeight:
                        isRead ? FontWeight.normal : FontWeight.bold,
                    fontSize: 14)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(body,
                      style: TextStyle(
                          color: isDark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                          fontSize: 12,
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                if (date != null) ...[
                  const SizedBox(height: 3),
                  Text(_formatDate(date),
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 11)),
                ],
              ],
            ),
            trailing: !isRead
                ? Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Color(0xFF5E35B1),
                        shape: BoxShape.circle),
                  )
                : null,
          ),

          // ── أزرار قبول/رفض الدعوة ──────────────────────────────
          if (isPendingInvite)
            Padding(
              padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectInvite(n),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('رفض',
                        style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _acceptInvite(n),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('قبول',
                        style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ]),
            ),

          // حالة الدعوة بعد الرد
          if (type == 'collection_invite' && inviteStatus != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(72, 0, 16, 10),
              child: Row(children: [
                Icon(
                  inviteStatus == 'accepted'
                      ? Icons.check_circle
                      : Icons.cancel,
                  size: 14,
                  color: inviteStatus == 'accepted'
                      ? Colors.green
                      : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  inviteStatus == 'accepted'
                      ? 'قبلت هذه الدعوة'
                      : 'رفضت هذه الدعوة',
                  style: TextStyle(
                    fontSize: 12,
                    color: inviteStatus == 'accepted'
                        ? Colors.green
                        : Colors.grey,
                  ),
                ),
              ]),
            ),

          Divider(height: 1, indent: 72, color: Colors.grey.withValues(alpha: 0.2)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('لا توجد إشعارات حالياً',
              style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          const SizedBox(height: 8),
          Text('ستصل إشعاراتك هنا عند وجودها',
              style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 1) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inDays < 1) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return DateHelper.stamp(d);
  }
}
