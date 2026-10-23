// lib/screens/my_complaints_screen.dart
import '../utils/date_helper.dart';
// شاشة شكاواي واقتراحاتي — تتبع حالة كل رسالة والرد عليها
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'report_problem_screen.dart';
import '../widgets/app_footer.dart';

class MyComplaintsScreen extends StatefulWidget {
  const MyComplaintsScreen({super.key});

  @override
  State<MyComplaintsScreen> createState() => _MyComplaintsScreenState();
}

class _MyComplaintsScreenState extends State<MyComplaintsScreen> {
  StreamSubscription<QuerySnapshot>? _sub;
  List<Map<String, dynamic>> _complaints = [];
  bool _isLoading = true;
  // ✅ Fix #193: تخزين رسالة الخطأ وإتاحة إعادة المحاولة
  String? _errorMsg;

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
    // ✅ Fix #193: إعادة تهيئة الـ state عند إعادة الاستماع
    if (mounted) setState(() { _isLoading = true; _errorMsg = null; });

    final uid = context.read<AuthProvider>().user?.id;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    _sub?.cancel();
    _sub = FirebaseFirestore.instance
        .collection('complaints')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
      (snap) {
        if (!mounted) return;
        setState(() {
          _complaints = snap.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList();
          _isLoading = false;
          _errorMsg = null;
        });
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMsg = 'تعذّر تحميل الشكاوى. اضغط للمحاولة مجدداً.';
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();

    if (auth.isGuest) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(child: Text('يجب تسجيل الدخول لعرض شكاواك')),
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0E0E1A) : const Color(0xFFF8F7FF),
      appBar: _buildAppBar(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReportProblemScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('رسالة جديدة'),
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
      ),
      // ✅ Fix #193: RefreshIndicator + error state
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF5E35B1)))
          : _errorMsg != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 56, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_errorMsg!, textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _listen,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => _listen(),
                  color: const Color(0xFF5E35B1),
                  child: _complaints.isEmpty
                      ? _buildEmptyState()
                      : ListView(
                          children: [
                            ..._complaints
                                .map((c) => _buildComplaintCard(c, isDark)),
                            const AppFooter(),
                            const SizedBox(height: 80),
                          ],
                        ),
                ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('شكاواي واقتراحاتي',
          style: TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: const Color(0xFF5E35B1),
      foregroundColor: Colors.white,
      centerTitle: true,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('لا توجد رسائل بعد',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'لو واجهت مشكلة أو عندك اقتراح، ابعتلنا رسالة.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ReportProblemScreen()),
              ),
              icon: const Icon(Icons.send),
              label: const Text('إرسال رسالة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E35B1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplaintCard(Map<String, dynamic> c, bool isDark) {
    final status = c['status'] as String? ?? 'pending';
    final hasReply =
        (c['reply'] as String?)?.isNotEmpty == true;
    final type = c['type'] as String? ?? 'شكوى';
    final title = c['title'] as String? ?? '';
    final details = c['details'] as String? ?? '';
    final reply = c['reply'] as String? ?? '';
    final repliedAt = c['repliedAt'];
    final createdAt = c['createdAt'];

    DateTime? createdDate;
    if (createdAt is Timestamp) createdDate = createdAt.toDate();

    DateTime? replyDate;
    if (repliedAt is Timestamp) replyDate = repliedAt.toDate();

    // ألوان الحالة
    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (status) {
      case 'replied':
      case 'closed':
        statusColor = Colors.green;
        statusLabel = 'تم الرد';
        statusIcon = Icons.check_circle;
        break;
      case 'in_progress':
        statusColor = Colors.orange;
        statusLabel = 'قيد المراجعة';
        statusIcon = Icons.hourglass_top;
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = 'لم يتم الرد بعد';
        statusIcon = Icons.schedule;
    }

    // لون نوع الرسالة
    Color typeColor;
    switch (type) {
      case 'شكوى':
        typeColor = Colors.red;
        break;
      case 'اقتراح':
        typeColor = Colors.blue;
        break;
      case 'إبلاغ عن تاجر':
        typeColor = Colors.orange;
        break;
      default:
        typeColor = Colors.purple;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: hasReply
            ? Border.all(color: Colors.green.withValues(alpha: 0.4), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── رأس البطاقة ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.07),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(type,
                      style: TextStyle(
                          color: typeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Icon(statusIcon, size: 13, color: statusColor),
                    const SizedBox(width: 4),
                    Text(statusLabel,
                        style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                  ]),
                ),
                const Spacer(),
                if (createdDate != null)
                  Text(
                    _formatDate(createdDate),
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 11),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── عنوان الرسالة ─────────────────────────────────
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(details,
                      style: TextStyle(
                          color: isDark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                          fontSize: 13,
                          height: 1.5),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                ],

                // ── رد الإدارة ──────────────────────────────────
                if (hasReply) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.support_agent,
                              size: 16, color: Colors.green),
                          const SizedBox(width: 6),
                          const Text('رد فريق الدعم',
                              style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          const Spacer(),
                          if (replyDate != null)
                            Text(_formatDate(replyDate),
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 11)),
                        ]),
                        const SizedBox(height: 8),
                        Text(reply,
                            style: const TextStyle(
                                fontSize: 14, height: 1.5)),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Icon(Icons.info_outline,
                        size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 6),
                    Text(
                      'سيصلك رد خلال 24-48 ساعة',
                      style: TextStyle(
                          color: Colors.grey[400], fontSize: 12),
                    ),
                  ]),
                ],
              ],
            ),
          ),
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
