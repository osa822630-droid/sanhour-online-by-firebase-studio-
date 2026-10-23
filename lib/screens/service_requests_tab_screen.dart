// lib/screens/service_requests_tab_screen.dart
// ✅ تاب طلبات الخدمات: عرض + تقديم عروض + قبول + أرشيف التعاملات
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/service_request_model.dart';
import '../models/service_bid_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_footer.dart';
import '../widgets/context_search_bar.dart';
import 'post_service_request_screen.dart';
import 'provider_registration_screen.dart';
import 'my_service_history_screen.dart';

class ServiceRequestsTabScreen extends StatefulWidget {
  const ServiceRequestsTabScreen({super.key});

  @override
  State<ServiceRequestsTabScreen> createState() =>
      _ServiceRequestsTabScreenState();
}

class _ServiceRequestsTabScreenState
    extends State<ServiceRequestsTabScreen> {
  final _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _sub;
  List<ServiceRequestModel> _requests = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final Set<String> _selectedCategories = {}; // multi-select

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
    _sub = _db
        .collection('service_requests')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _requests = snap.docs.map((d) {
          final data = Map<String, dynamic>.from(d.data());
          data['id'] = d.id;
          return ServiceRequestModel.fromMap(data);
        }).toList();
        _isLoading = false;
      });
    }, onError: (_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  List<ServiceRequestModel> get _filtered {
    var res = List<ServiceRequestModel>.from(_requests);
    if (_selectedCategories.isNotEmpty) {
      res = res
          .where((r) => _selectedCategories.contains(r.category.name))
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      res = res
          .where((r) =>
              r.title.toLowerCase().contains(q) ||
              r.description.toLowerCase().contains(q) ||
              r.location.toLowerCase().contains(q))
          .toList();
    }
    // العاجل أولاً
    res.sort((a, b) {
      if (a.urgent && !b.urgent) return -1;
      if (!a.urgent && b.urgent) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return res;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final requests = _filtered;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0E0E1A) : const Color(0xFFF8F7FF),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // زر التسجيل كمزوّد خدمة
          if (!auth.isGuest)
            FloatingActionButton(
              heroTag: 'provider',
              mini: true,
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              tooltip: 'تسجيلي كمزوّد خدمة',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const ProviderRegistrationScreen()),
              ),
              child: const Icon(Icons.engineering_outlined, size: 20),
            ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'request',
            onPressed: () {
              // ✅ Item #11: نفس حراسة نشر الوظيفة — user == null بيغطي الضيف
              // وغير المسجّل، وبنوقفه قبل ما يفتح فورم مش هيقدر يبعته.
              if (auth.user == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('يجب تسجيل الدخول لطلب خدمة'),
                  backgroundColor: Colors.red,
                ));
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PostServiceRequestScreen()),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('طلب خدمة'),
            backgroundColor: const Color(0xFF5E35B1),
            foregroundColor: Colors.white,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── شريط البحث ────────────────────────────────────────
          ContextSearchBar(
            hint: 'ابحث عن خدمة تحتاجها...',
            onSearch: (q) => setState(() => _searchQuery = q),
            showFilterButton: true,
            filters: [
              SearchFilter(
                id: 'sort',
                label: 'الترتيب',
                options: ['الأحدث', 'العاجل أولاً', 'الأقل عروضاً'],
              ),
            ],
            onFilterChanged: (_, __) {},
          ),

          // ── فلتر الفئات (Multi-select) ─────────────────────
          _buildCategoryFilter(isDark),

          // ── بانر طلباتي السابقة ────────────────────────────
          if (!auth.isGuest)
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MyServiceHistoryScreen()),
              ),
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.teal.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.history, color: Colors.teal, size: 18),
                  const SizedBox(width: 8),
                  const Text('طلباتي وعروضي السابقة',
                      style: TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const Spacer(),
                  const Icon(Icons.arrow_back_ios,
                      size: 13, color: Colors.teal),
                ]),
              ),
            ),

          // ── النتائج ──────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : requests.isEmpty
                    ? _buildEmpty()
                    : ListView(
                        padding:
                            const EdgeInsets.fromLTRB(12, 8, 12, 80),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${requests.length} طلب مفتوح',
                              style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12),
                            ),
                          ),
                          ...requests.map(
                              (r) => _buildRequestCard(r, isDark)),
                          const AppFooter(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // ── فلتر الفئات ───────────────────────────────────────────────────
  Widget _buildCategoryFilter(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: SizedBox(
        height: 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: ServiceRequestCategory.values.map((cat) {
            final isSelected =
                _selectedCategories.contains(cat.name);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedCategories.remove(cat.name);
                  } else {
                    _selectedCategories.add(cat.name);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF5E35B1)
                      : (isDark ? Colors.grey[800] : Colors.grey[100]),
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected
                      ? null
                      : Border.all(
                          color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: Text(
                  ServiceRequestModel.categoryLabel(cat),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.grey[300] : Colors.grey[700]),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── بطاقة الطلب ───────────────────────────────────────────────────
  Widget _buildRequestCard(ServiceRequestModel req, bool isDark) {
    final auth = context.read<AuthProvider>();
    final isOwner = auth.user?.id == req.clientId;
    final daysAgo =
        DateTime.now().difference(req.createdAt).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── شريط العاجل ────────────────────────────────────
          if (req.urgent)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: const BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(14)),
              ),
              child: const Row(children: [
                Icon(Icons.flash_on, color: Colors.white, size: 14),
                SizedBox(width: 6),
                Text('عاجل',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ]),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      ServiceRequestModel.categoryLabel(req.category),
                      style: const TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                          fontSize: 11),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    daysAgo == 0 ? 'اليوم' : 'منذ $daysAgo يوم',
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 11),
                  ),
                  if (isOwner) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _confirmDeleteRequest(req.id),
                      child: const Icon(Icons.delete_outline,
                          color: Colors.red, size: 20),
                    ),
                  ],
                ]),

                const SizedBox(height: 10),
                Text(req.title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(req.description,
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                        height: 1.5),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),

                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  _chip(Icons.location_on_outlined, req.location),
                  _chip(
                      Icons.attach_money,
                      req.suggestedPrice != null
                          ? 'مقترح: ${req.suggestedPrice!.toStringAsFixed(0)} جنيه'
                          : req.priceNote),
                  _chip(Icons.people_outline,
                      '${req.bidsCount} عرض مقدّم'),
                ]),

                const SizedBox(height: 14),

                // ── الأزرار ────────────────────────────────────
                if (isOwner)
                  // صاحب الطلب يعرض العروض
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showBids(context, req),
                      icon: const Icon(Icons.list_alt, size: 16),
                      label: Text(
                          'عرض العروض (${req.bidsCount})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5E35B1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8)),
                      ),
                    ),
                  )
                else
                  // مزوّد الخدمة يقدّم عرضاً
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showBidDialog(context, req),
                      icon: const Icon(Icons.price_check, size: 16),
                      label: const Text('تقديم عرض سعر'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: Colors.grey.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ]),
      );

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.handyman_outlined,
                  size: 80, color: Colors.grey[300]),
              const SizedBox(height: 16),
              const Text('لا توجد طلبات خدمات مفتوحة',
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 8),
              const Text(
                'اضغط "طلب خدمة" لنشر ما تحتاجه',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );

  // ── تقديم عرض ────────────────────────────────────────────────────
  Future<void> _showBidDialog(
      BuildContext context, ServiceRequestModel req) async {
    final auth = context.read<AuthProvider>();
    if (auth.isGuest) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('يجب تسجيل الدخول لتقديم عرض'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    final priceCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
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
            const Text('تقديم عرض سعر',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('للطلب: ${req.title}',
                style: const TextStyle(
                    color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'سعرك المقترح (جنيه) *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'ملاحظة أو تفاصيل إضافية (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  if (priceCtrl.text.trim().isEmpty) return;
                  final price =
                      double.tryParse(priceCtrl.text.trim()) ?? 0;
                  if (price <= 0) return;

                  final user = auth.user!;
                  final bid = ServiceBidModel(
                    id: '',
                    requestId: req.id,
                    providerId: user.id,
                    providerName: user.name,
                    providerPhone: user.phone,
                    offeredPrice: price,
                    note: noteCtrl.text.trim(),
                    status: BidStatus.pending,
                    createdAt: DateTime.now(),
                  );

                  // ✅ Fix #15: معرّف العرض يُولَّد مسبقاً ويُكتب مع المستند في
                  // كتابة واحدة (كان add بـ id فارغ ثم update للـ id: كتابتان،
                  // والقواعد تشترط id == معرّف المستند ولا تسمح بالتعديل الثاني)
                  final bidRef = _db.collection('service_bids').doc();
                  await bidRef.set({...bid.toMap(), 'id': bidRef.id});

                  // تحديث عدد العروض
                  await _db.collection('service_requests').doc(req.id).update({
                    'bidsCount': FieldValue.increment(1),
                  });

                  // إشعار لصاحب الطلب
                  await _db.collection('notifications').add({
                    'title': '💰 عرض جديد على طلبك!',
                    'body': '${user.name} قدّم عرضاً بـ ${price.toStringAsFixed(0)} جنيه',
                    'type': 'new_bid',
                    'targetUserId': req.clientId,
                    'fromUserId': user.id,
                    'data': {
                      'route': 'service_request:${req.id}',
                      'channel': 'user_favorites',
                    },
                    'isRead': false,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تقديم عرضك بنجاح ✅'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white),
                child: const Text('إرسال العرض',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    // ✅ Fix #69: dispose controllers بعد إغلاق الـ bottom sheet
    ).whenComplete(() {
      priceCtrl.dispose();
      noteCtrl.dispose();
    });
  }

  // ── عرض قائمة العروض لصاحب الطلب ────────────────────────────────
  Future<void> _showBids(
      BuildContext context, ServiceRequestModel req) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _BidsListScreen(request: req),
      ),
    );
  }

  Future<void> _confirmDeleteRequest(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إغلاق الطلب؟'),
        content: const Text(
            'سيُخفى الطلب عن الشاشة العامة. يمكنك مراجعته في "طلباتي السابقة".'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _db.collection('service_requests').doc(id).update({
        'status': 'closed',
      });
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// شاشة قائمة العروض لصاحب الطلب مع قبول / رفض
// ══════════════════════════════════════════════════════════════════════════════
class _BidsListScreen extends StatelessWidget {
  final ServiceRequestModel request;
  const _BidsListScreen({required this.request});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text('عروض: ${request.title}',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15)),
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db
            .collection('service_bids')
            .where('requestId', isEqualTo: request.id)
            .orderBy('createdAt', descending: false)
            .snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final bids = snap.data!.docs.map((d) {
            final data = Map<String, dynamic>.from(d.data() as Map);
            data['id'] = d.id;
            return ServiceBidModel.fromMap(data);
          }).toList();

          if (bids.isEmpty) {
            return const Center(child: Text('لا توجد عروض بعد'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bids.length,
            itemBuilder: (_, i) => _buildBidCard(context, bids[i], db),
          );
        },
      ),
    );
  }

  Widget _buildBidCard(
      BuildContext context, ServiceBidModel bid, FirebaseFirestore db) {
    final statusColor = bid.isPending
        ? Colors.orange
        : bid.isAccepted
            ? Colors.green
            : Colors.grey;
    final statusLabel = bid.isPending
        ? '⏳ بانتظار ردك'
        : bid.isAccepted
            ? '✅ مقبول'
            : '❌ مرفوض';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    const Color(0xFF5E35B1).withValues(alpha: 0.12),
                child: Text(
                  bid.providerName.isNotEmpty
                      ? bid.providerName.substring(0, 1).toUpperCase()
                      : 'م',
                  style: const TextStyle(
                      color: Color(0xFF5E35B1),
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bid.providerName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text(
                      'عرض سعر: ${bid.offeredPrice.toStringAsFixed(0)} جنيه',
                      style: const TextStyle(
                          color: Color(0xFF5E35B1),
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ]),

            if (bid.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(bid.note,
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 13, height: 1.4)),
            ],

            // معلومات التواصل (مرئية بعد القبول فقط لصاحب الطلب)
            if (bid.isAccepted) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Text('✅ تم القبول — معلومات التواصل',
                        style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(
                                'tel:${bid.providerPhone}');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                          icon: const Icon(Icons.phone, size: 15),
                          label: Text(bid.providerPhone),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green,
                              side: const BorderSide(
                                  color: Colors.green)),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ],

            // أزرار القبول / الرفض
            if (bid.isPending) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _rejectBid(context, bid, db),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red)),
                    child: const Text('رفض'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _acceptBid(context, bid, db),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white),
                    child: const Text('قبول'),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _acceptBid(
    BuildContext context,
    ServiceBidModel bid,
    FirebaseFirestore db,
  ) async {
    // ✅ عند القبول:
    // 1. تحديث حالة العرض → accepted
    // 2. إخفاء الطلب عن العامة → status: accepted
    // 3. رفض باقي العروض تلقائياً
    // 4. إشعار لمزوّد الخدمة بالقبول

    // ✅ Fix #14: هوية المرسل تُقرأ قبل أي await (بدل استخدام context بعده)
    final senderId = context.read<AuthProvider>().user?.id ?? '';

    final batch = db.batch();

    // قبول هذا العرض
    batch.update(db.collection('service_bids').doc(bid.id), {
      'status': 'accepted',
    });

    // إخفاء الطلب عن العامة
    batch.update(db.collection('service_requests').doc(bid.requestId), {
      'status': 'accepted',
      'acceptedBidId': bid.id,
    });

    await batch.commit();

    // رفض باقي العروض
    final others = await db
        .collection('service_bids')
        .where('requestId', isEqualTo: bid.requestId)
        .where('status', isEqualTo: 'pending')
        .get();
    final rejectBatch = db.batch();
    for (final d in others.docs) {
      if (d.id != bid.id) {
        rejectBatch.update(d.reference, {'status': 'rejected'});
      }
    }
    if (others.docs.isNotEmpty) await rejectBatch.commit();

    // إشعار لمزوّد الخدمة المقبول
    await db.collection('notifications').add({
      'title': '🎉 تم قبول عرضك!',
      'body':
          'صاحب الطلب وافق على عرضك. تحقق من معلومات التواصل.',
      'type': 'bid_accepted',
      'targetUserId': bid.providerId,
      'fromUserId': senderId,
      'data': {
        'route': 'service_request:${bid.requestId}',
        'channel': 'user_favorites',
      },
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('تم القبول ✅ — ستظهر معلومات التواصل الآن'),
      backgroundColor: Colors.green,
    ));
  }

  Future<void> _rejectBid(
    BuildContext context,
    ServiceBidModel bid,
    FirebaseFirestore db,
  ) async {
    await db.collection('service_bids').doc(bid.id).update({
      'status': 'rejected',
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('تم رفض العرض'),
      backgroundColor: Colors.grey,
      duration: Duration(seconds: 1),
    ));
  }
}
