// lib/screens/job_ads_tab_screen.dart
// ✅ تاب الوظائف: عرض + بحث + فلترة + نشر إعلان + الاشتراك في المجالات
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/job_ad_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_footer.dart';
import '../widgets/context_search_bar.dart';
import 'post_job_ad_screen.dart';

class JobAdsTabScreen extends StatefulWidget {
  const JobAdsTabScreen({super.key});

  @override
  State<JobAdsTabScreen> createState() => _JobAdsTabScreenState();
}

class _JobAdsTabScreenState extends State<JobAdsTabScreen> {
  final _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _sub;
  List<JobAdModel> _allJobs = [];
  bool _isLoading = true;
  String _searchQuery = '';
  JobCategory? _selectedCategory;
  Set<String> _subscribedCategories = {};

  @override
  void initState() {
    super.initState();
    _listenToJobs();
    _loadSubscriptions();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _listenToJobs() {
    _sub = _db
        .collection('job_ads')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _allJobs = snap.docs.map((d) {
          final data = Map<String, dynamic>.from(d.data());
          data['id'] = d.id;
          return JobAdModel.fromMap(data);
        }).toList();
        _isLoading = false;
      });
    }, onError: (_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  Future<void> _loadSubscriptions() async {
    final uid = context.read<AuthProvider>().user?.id;
    if (uid == null) return;
    try {
      final doc = await _db.collection('job_subscriptions').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _subscribedCategories = Set<String>.from(
              doc.data()?['categories'] as List? ?? []);
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleSubscription(JobCategory cat) async {
    final uid = context.read<AuthProvider>().user?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('يجب تسجيل الدخول لتفعيل الإشعارات'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    final catName = JobAdModel.categoryToString(cat);
    final isSubbed = _subscribedCategories.contains(catName);
    setState(() {
      if (isSubbed) {
        _subscribedCategories.remove(catName);
      } else {
        _subscribedCategories.add(catName);
      }
    });
    await _db.collection('job_subscriptions').doc(uid).set({
      'categories': _subscribedCategories.toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isSubbed
          ? 'تم إلغاء الإشعارات لـ "${JobAdModel.categoryLabel(cat)}"'
          : 'ستصلك إشعارات عند وجود وظائف في "${JobAdModel.categoryLabel(cat)}"'),
      backgroundColor: isSubbed ? Colors.grey : Colors.green,
      duration: const Duration(seconds: 2),
    ));
  }

  List<JobAdModel> get _filtered {
    var res = List<JobAdModel>.from(_allJobs);
    if (_selectedCategory != null) {
      res = res.where((j) => j.category == _selectedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      res = res
          .where((j) =>
              j.title.toLowerCase().contains(q) ||
              j.description.toLowerCase().contains(q) ||
              j.location.toLowerCase().contains(q))
          .toList();
    }
    return res;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final jobs = _filtered;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0E0E1A) : const Color(0xFFF8F7FF),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PostJobAdScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('نشر وظيفة'),
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── شريط البحث ────────────────────────────────────────
          ContextSearchBar(
            hint: 'ابحث عن وظيفة...',
            onSearch: (q) => setState(() => _searchQuery = q),
            filters: [
              SearchFilter(
                id: 'category',
                label: 'نوع الوظيفة',
                options: [
                  'الكل',
                  ...JobCategory.values
                      .map((c) => JobAdModel.categoryLabel(c)),
                ],
              ),
            ],
            onFilterChanged: (id, val) {
              if (id == 'category') {
                setState(() {
                  if (val == 'الكل') {
                    _selectedCategory = null;
                  } else {
                    _selectedCategory = JobCategory.values.firstWhere(
                      (c) => JobAdModel.categoryLabel(c) == val,
                      orElse: () => JobCategory.other,
                    );
                  }
                });
              }
            },
          ),

          // ── شريط الاشتراكات ───────────────────────────────────
          if (!auth.isGuest)
            _buildSubscriptionStrip(isDark),

          // ── النتائج ──────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : jobs.isEmpty
                    ? _buildEmpty()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${jobs.length} إعلان وظيفة',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 12),
                            ),
                          ),
                          ...jobs.map((j) => _buildJobCard(j, isDark)),
                          const AppFooter(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // ── شريط الاشتراكات ───────────────────────────────────────────────
  Widget _buildSubscriptionStrip(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.notifications_active_outlined,
                size: 14, color: Color(0xFF5E35B1)),
            const SizedBox(width: 6),
            Text(
              'فعّل إشعارات المجالات اللي تهمك:',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600),
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: JobCategory.values.map((cat) {
                final catName = JobAdModel.categoryToString(cat);
                final isSubbed = _subscribedCategories.contains(catName);
                return GestureDetector(
                  onTap: () => _toggleSubscription(cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSubbed
                          ? const Color(0xFF5E35B1)
                          : (isDark
                              ? Colors.grey[800]
                              : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(20),
                      border: isSubbed
                          ? null
                          : Border.all(
                              color: Colors.grey.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      if (isSubbed)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.notifications_active,
                              size: 13, color: Colors.white),
                        ),
                      Text(
                        JobAdModel.categoryLabel(cat),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSubbed
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSubbed
                              ? Colors.white
                              : (isDark
                                  ? Colors.grey[300]
                                  : Colors.grey[700]),
                        ),
                      ),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ── بطاقة الوظيفة ─────────────────────────────────────────────────
  Widget _buildJobCard(JobAdModel job, bool isDark) {
    final daysSince =
        DateTime.now().difference(job.createdAt).inDays;
    final auth = context.read<AuthProvider>();
    final isOwner = auth.user?.id == job.posterId;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── الرأس ──────────────────────────────────────────
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  JobAdModel.categoryLabel(job.category),
                  style: const TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.bold,
                      fontSize: 11),
                ),
              ),
              const Spacer(),
              Text(
                daysSince == 0
                    ? 'اليوم'
                    : 'منذ $daysSince يوم',
                style: TextStyle(
                    color: Colors.grey[500], fontSize: 11),
              ),
              if (isOwner) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _confirmDelete(job.id),
                  child: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                ),
              ],
            ]),

            const SizedBox(height: 10),

            // ── العنوان ────────────────────────────────────────
            Text(job.title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(job.description,
                style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    height: 1.5),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),

            const SizedBox(height: 12),

            // ── التفاصيل ───────────────────────────────────────
            Wrap(spacing: 8, runSpacing: 6, children: [
              _chip(Icons.location_on_outlined, job.location),
              _chip(Icons.payments_outlined, job.salary),
              _chip(Icons.schedule_outlined, job.workType),
              if (job.requiredCount > 1)
                _chip(Icons.people_outline, '${job.requiredCount} مطلوبين'),
            ]),

            const SizedBox(height: 14),

            // ── زر التواصل ────────────────────────────────────
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _callPhone(job.posterPhone),
                  icon: const Icon(Icons.phone, size: 16),
                  label: Text(job.posterPhone),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _openWhatsApp(job.posterPhone),
                icon: const Icon(Icons.message, size: 16),
                label: const Text('واتساب'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF25D366),
                  side: const BorderSide(color: Color(0xFF25D366)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ]),
    );
  }

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.work_off_outlined,
                  size: 80, color: Colors.grey[300]),
              const SizedBox(height: 16),
              const Text('لا توجد وظائف حالياً',
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 8),
              const Text(
                'كن أول من ينشر وظيفة في سنهور',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );

  Future<void> _confirmDelete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف إعلان الوظيفة؟'),
        content: const Text('سيتم حذف الإعلان نهائياً.'),
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
    if (ok != true) return;
    await _db.collection('job_ads').doc(id).update({'isActive': false});
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWhatsApp(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final number = clean.startsWith('20') ? clean : '2$clean';
    final uri = Uri.parse('https://wa.me/$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
