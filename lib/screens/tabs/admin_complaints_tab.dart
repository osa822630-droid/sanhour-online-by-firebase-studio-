// lib/screens/tabs/admin_complaints_tab.dart
// ✅ إصلاح: الرد يكتب حقل 'reply' (بدلاً من 'adminReply') ليتوافق مع my_complaints_screen
// ✅ إضافة: الرد يُنشئ إشعاراً في notifications collection ليظهر للمستخدم فوراً
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/api_service.dart';

class AdminComplaintsTab extends StatefulWidget {
  const AdminComplaintsTab({super.key});

  @override
  State<AdminComplaintsTab> createState() => _AdminComplaintsTabState();
}

class _AdminComplaintsTabState extends State<AdminComplaintsTab>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  // ✅ Fix #104/#106/#107: تخزين رسالة الخطأ
  // ignore: unused_field
  // ignore: unused_field
  String? _errorMsg;
  List<Map<String, dynamic>> _allComplaints = [];
  List<Map<String, dynamic>> _filteredComplaints = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_applyFilter);
    _loadComplaints();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadComplaints() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getComplaints();
      if (mounted) {
        setState(() {
          _allComplaints = data;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("load error: $e");
      if (mounted) setState(() { _isLoading = false; _errorMsg = "تعذّر تحميل البيانات. اضغط للمحاولة."; });
    }
  }

  void _applyFilter() {
    final index = _tabController.index;
    setState(() {
      if (index == 0) {
        _filteredComplaints = _allComplaints
            .where((c) =>
                c['status'] == 'pending' ||
                c['status'] == null ||
                c['status'] == '')
            .toList();
      } else if (index == 1) {
        _filteredComplaints = _allComplaints
            .where((c) =>
                c['status'] == 'replied' ||
                c['status'] == 'in_progress')
            .toList();
      } else {
        _filteredComplaints = List.from(_allComplaints);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E0E1A) : Colors.grey[100],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor:
            isDark ? const Color(0xFF1A1A2E) : Colors.deepPurple[900],
        foregroundColor: Colors.white,
        title: Text(
          'الشكاوي والمقترحات (${_allComplaints.length})',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadComplaints,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
                text:
                    'جديدة (${_allComplaints.where((c) => c['status'] == 'pending' || c['status'] == null || c['status'] == '').length})'),
            Tab(
                text:
                    'مردودة (${_allComplaints.where((c) => c['status'] == 'replied' || c['status'] == 'in_progress').length})'),
            Tab(text: 'الكل (${_allComplaints.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredComplaints.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text('لا توجد رسائل',
                          style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadComplaints,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filteredComplaints.length,
                    itemBuilder: (_, i) =>
                        _buildCard(_filteredComplaints[i], isDark),
                  ),
                ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item, bool isDark) {
    final String? replyText = (item['reply'] as String?)?.isNotEmpty == true
        ? item['reply'] as String
        : (item['adminReply'] as String?); // backward compat

    final hasReply = replyText != null && replyText.isNotEmpty;
    // ignore: unused_local_variable
    final status = item['status'] as String? ?? 'pending';
    final type = item['type'] as String? ?? 'شكوى';
    final repliedAt = item['repliedAt'];
    String repliedAtStr = '';
    if (repliedAt != null) {
      try {
        final dt = (repliedAt as dynamic).toDate() as DateTime;
        repliedAtStr = DateFormat('dd/MM/yyyy HH:mm').format(dt);
      } catch (_) {}
    }

    Color typeColor;
    switch (type) {
      case 'شكوى': typeColor = Colors.red; break;
      case 'اقتراح': typeColor = Colors.blue; break;
      case 'إبلاغ عن تاجر': typeColor = Colors.orange; break;
      default: typeColor = Colors.purple;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── معلومات المُرسِل ──────────────────────────────
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(type,
                    style: TextStyle(
                        color: typeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (hasReply ? Colors.green : Colors.grey)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  hasReply ? '✅ تم الرد' : '⏳ لم يُرَد بعد',
                  style: TextStyle(
                    color: hasReply ? Colors.green : Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 10),

            // اسم المستخدم
            Row(children: [
              const Icon(Icons.person_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                item['userName'] as String? ?? 'مجهول',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => Clipboard.setData(
                  ClipboardData(text: item['userPhone'] as String? ?? ''),
                ),
                child: Row(children: [
                  const Icon(Icons.phone, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    item['userPhone'] as String? ?? '',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ]),
              ),
            ]),

            const SizedBox(height: 8),

            // العنوان
            Text(
              item['title'] as String? ?? '',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15),
            ),

            // التفاصيل
            if ((item['details'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(
                item['details'] as String,
                style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.5),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // الرد الموجود
            if (hasReply) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.reply, color: Colors.green, size: 16),
                      SizedBox(width: 6),
                      Text('رد الإدارة:',
                          style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ]),
                    const SizedBox(height: 6),
                    Text(replyText,
                        style: const TextStyle(fontSize: 13, height: 1.4)),
                    if (repliedAtStr.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(repliedAtStr,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11)),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showReplyDialog(item),
                  icon: Icon(hasReply ? Icons.edit : Icons.reply, size: 16),
                  label: Text(hasReply ? 'تعديل الرد' : 'إرسال رد'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        hasReply ? Colors.blue : const Color(0xFF5E35B1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _confirmDelete(item['id'] as String),
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                label: const Text('حذف', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ── ديالوج الرد ─────────────────────────────────────────────────────
  void _showReplyDialog(Map<String, dynamic> item) {
    final existingReply = (item['reply'] as String?)?.isNotEmpty == true
        ? item['reply'] as String
        : (item['adminReply'] as String? ?? '');
    final replyCtrl = TextEditingController(text: existingReply);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          existingReply.isEmpty ? 'إرسال رد' : 'تعديل الرد',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'على: "${item['title'] ?? ''}"',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: replyCtrl,
              maxLines: 4,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'اكتب ردك هنا...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E35B1),
                foregroundColor: Colors.white),
            onPressed: () async {
              if (replyCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await _submitReply(item, replyCtrl.text.trim());
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReply(
      Map<String, dynamic> item, String replyText) async {
    final complaintId = item['id'] as String;
    final userId = item['userId'] as String? ?? '';
    final title = item['title'] as String? ?? 'شكوى';

    try {
      // ✅ كتابة 'reply' (متوافق مع my_complaints_screen) + 'adminReply' للـ backward compat
      await FirebaseFirestore.instance
          .collection('complaints')
          .doc(complaintId)
          .update({
        'reply': replyText,
        'adminReply': replyText, // backward compat
        'status': 'replied',
        'repliedAt': FieldValue.serverTimestamp(),
      });

      // ✅ إشعار فوري للمستخدم
      if (userId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'title': '💬 رد على "${title.length > 30 ? '${title.substring(0, 30)}...' : title}"',
          'body': replyText.length > 80
              ? '${replyText.substring(0, 80)}...'
              : replyText,
          'type': 'complaint_reply',
          'targetUserId': userId,
          'data': {
            'route': 'user_complaints',
            'channel': 'user_support',
            'complaintId': complaintId,
          },
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // FCM عبر notification_queue
        await FirebaseFirestore.instance
            .collection('notification_queue')
            .add({
          'title': '💬 رد جديد على شكواك',
          'body': replyText.length > 80
              ? '${replyText.substring(0, 80)}...'
              : replyText,
          'targetUserId': userId,
          'data': {
            'route': 'user_complaints',
            'channel': 'user_support',
          },
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      _loadComplaints();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم إرسال الرد بنجاح ✅'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('فشل الإرسال: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _confirmDelete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الرسالة؟'),
        content: const Text('سيتم حذف الرسالة نهائياً.'),
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
    );
    if (ok == true) {
      await ApiService.deleteContent('complaints', id);
      _loadComplaints();
    }
  }
}
