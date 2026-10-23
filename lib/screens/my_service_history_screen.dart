// lib/screens/my_service_history_screen.dart
// ✅ Fix #33: cursor-based pagination لكلا التابَّيْن (طلباتي / عروضي)
// ✅ Fix #33: إضافة ScrollController + _loadMore عند الوصول لآخر القائمة
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/service_request_model.dart';
import '../models/service_bid_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_footer.dart';

class MyServiceHistoryScreen extends StatefulWidget {
  const MyServiceHistoryScreen({super.key});

  @override
  State<MyServiceHistoryScreen> createState() =>
      _MyServiceHistoryScreenState();
}

class _MyServiceHistoryScreenState
    extends State<MyServiceHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _db = FirebaseFirestore.instance;

  static const int _pageSize = 15;

  // ── Requests state ─────────────────────────────────────────────────
  final List<ServiceRequestModel> _myRequests = [];
  DocumentSnapshot? _lastReqDoc;
  bool _loadingRequests = true;
  bool _hasMoreRequests = true;
  bool _fetchingMoreReq = false;
  String? _reqError;
  final ScrollController _reqScrollCtrl = ScrollController();

  // ── Bids state ─────────────────────────────────────────────────────
  final List<ServiceBidModel> _myBids = [];
  DocumentSnapshot? _lastBidDoc;
  bool _loadingBids = true;
  bool _hasMoreBids = true;
  bool _fetchingMoreBid = false;
  String? _bidError;
  final ScrollController _bidScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    final uid = context.read<AuthProvider>().user?.id;
    if (uid != null) {
      _loadRequests(uid);
      _loadBids(uid);
    }
    _reqScrollCtrl.addListener(() {
      if (_reqScrollCtrl.position.pixels >=
              _reqScrollCtrl.position.maxScrollExtent - 200 &&
          !_fetchingMoreReq &&
          _hasMoreRequests) {
        final uid = context.read<AuthProvider>().user?.id;
        if (uid != null) _loadMoreRequests(uid);
      }
    });
    _bidScrollCtrl.addListener(() {
      if (_bidScrollCtrl.position.pixels >=
              _bidScrollCtrl.position.maxScrollExtent - 200 &&
          !_fetchingMoreBid &&
          _hasMoreBids) {
        final uid = context.read<AuthProvider>().user?.id;
        if (uid != null) _loadMoreBids(uid);
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _reqScrollCtrl.dispose();
    _bidScrollCtrl.dispose();
    super.dispose();
  }

  // ── Requests pagination ────────────────────────────────────────────

  Future<void> _loadRequests(String uid, {bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _myRequests.clear();
        _lastReqDoc = null;
        _hasMoreRequests = true;
        _loadingRequests = true;
        _reqError = null;
      });
    }
    try {
      Query q = _db
          .collection('service_requests')
          .where('clientId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);
      if (_lastReqDoc != null) q = q.startAfterDocument(_lastReqDoc!);
      final snap = await q.get();
      if (!mounted) return;
      final docs = snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data() as Map);
        data['id'] = d.id;
        return ServiceRequestModel.fromMap(data);
      }).toList();
      setState(() {
        _myRequests.addAll(docs);
        _lastReqDoc = snap.docs.isNotEmpty ? snap.docs.last : _lastReqDoc;
        _hasMoreRequests = snap.docs.length == _pageSize;
        _loadingRequests = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingRequests = false;
          _reqError = 'تعذّر تحميل الطلبات. اضغط للمحاولة.';
        });
      }
    }
  }

  Future<void> _loadMoreRequests(String uid) async {
    if (_fetchingMoreReq) return;
    setState(() => _fetchingMoreReq = true);
    await _loadRequests(uid);
    if (mounted) setState(() => _fetchingMoreReq = false);
  }

  // ── Bids pagination ────────────────────────────────────────────────

  Future<void> _loadBids(String uid, {bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _myBids.clear();
        _lastBidDoc = null;
        _hasMoreBids = true;
        _loadingBids = true;
        _bidError = null;
      });
    }
    try {
      Query q = _db
          .collection('service_bids')
          .where('providerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);
      if (_lastBidDoc != null) q = q.startAfterDocument(_lastBidDoc!);
      final snap = await q.get();
      if (!mounted) return;
      final docs = snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data() as Map);
        data['id'] = d.id;
        return ServiceBidModel.fromMap(data);
      }).toList();
      setState(() {
        _myBids.addAll(docs);
        _lastBidDoc = snap.docs.isNotEmpty ? snap.docs.last : _lastBidDoc;
        _hasMoreBids = snap.docs.length == _pageSize;
        _loadingBids = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingBids = false;
          _bidError = 'تعذّر تحميل العروض. اضغط للمحاولة.';
        });
      }
    }
  }

  Future<void> _loadMoreBids(String uid) async {
    if (_fetchingMoreBid) return;
    setState(() => _fetchingMoreBid = true);
    await _loadBids(uid);
    if (mounted) setState(() => _fetchingMoreBid = false);
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uid = context.read<AuthProvider>().user?.id;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0E0E1A) : const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text('طلباتي وعروضي',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              text: 'طلباتي (${_myRequests.length}${_hasMoreRequests ? '+' : ''})',
              icon: const Icon(Icons.request_page_outlined, size: 18),
            ),
            Tab(
              text: 'عروضي (${_myBids.length}${_hasMoreBids ? '+' : ''})',
              icon: const Icon(Icons.price_check, size: 18),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildRequestsTab(isDark, uid),
          _buildBidsTab(isDark, uid),
        ],
      ),
    );
  }

  // ── Requests Tab ───────────────────────────────────────────────────

  Widget _buildRequestsTab(bool isDark, String? uid) {
    if (_loadingRequests && _myRequests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_reqError != null && _myRequests.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(_reqError!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => uid != null ? _loadRequests(uid, refresh: true) : null,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ]),
      );
    }
    if (_myRequests.isEmpty) {
      return _emptyState('لم تنشر أي طلبات بعد',
          'طلبات الخدمات التي تنشرها ستظهر هنا',
          Icons.request_page_outlined);
    }
    return RefreshIndicator(
      onRefresh: () async => uid != null ? _loadRequests(uid, refresh: true) : null,
      child: ListView.builder(
        controller: _reqScrollCtrl,
        padding: const EdgeInsets.all(12),
        itemCount: _myRequests.length + (_hasMoreRequests ? 1 : 1),
        itemBuilder: (ctx, i) {
          if (i == _myRequests.length) {
            if (_hasMoreRequests) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            return const AppFooter();
          }
          return _buildRequestCard(_myRequests[i], isDark);
        },
      ),
    );
  }

  // ── Bids Tab ───────────────────────────────────────────────────────

  Widget _buildBidsTab(bool isDark, String? uid) {
    if (_loadingBids && _myBids.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_bidError != null && _myBids.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(_bidError!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => uid != null ? _loadBids(uid, refresh: true) : null,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ]),
      );
    }
    if (_myBids.isEmpty) {
      return _emptyState('لم تقدّم أي عروض بعد',
          'العروض التي تقدّمها على طلبات الخدمات ستظهر هنا',
          Icons.price_check_outlined);
    }
    return RefreshIndicator(
      onRefresh: () async => uid != null ? _loadBids(uid, refresh: true) : null,
      child: ListView.builder(
        controller: _bidScrollCtrl,
        padding: const EdgeInsets.all(12),
        itemCount: _myBids.length + (_hasMoreBids ? 1 : 1),
        itemBuilder: (ctx, i) {
          if (i == _myBids.length) {
            if (_hasMoreBids) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            return const AppFooter();
          }
          return _buildBidCard(_myBids[i], isDark);
        },
      ),
    );
  }

  // ── Cards ──────────────────────────────────────────────────────────

  Widget _buildRequestCard(ServiceRequestModel r, bool isDark) {
    final statusColor = r.isOpen
        ? Colors.green
        : r.isAccepted ? Colors.blue : Colors.grey;
    final statusLabel = r.isOpen
        ? '🟢 مفتوح'
        : r.isAccepted ? '✅ مقبول' : '🔴 مغلق';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(ServiceRequestModel.categoryLabel(r.category),
                  style: const TextStyle(color: Colors.teal, fontSize: 11)),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          const SizedBox(height: 8),
          Text(r.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.people_outline, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text('${r.bidsCount} عرض مقدّم',
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            const SizedBox(width: 12),
            Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Expanded(
              child: Text(r.location,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildBidCard(ServiceBidModel bid, bool isDark) {
    final Color statusColor;
    final String statusLabel;
    switch (bid.status) {
      case BidStatus.accepted:
        statusColor = Colors.green;
        statusLabel = '✅ مقبول';
        break;
      case BidStatus.rejected:
        statusColor = Colors.grey;
        statusLabel = '❌ مرفوض';
        break;
      default:
        statusColor = Colors.orange;
        statusLabel = '⏳ بانتظار الرد';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(
              'عرض سعر: ${bid.offeredPrice.toStringAsFixed(0)} جنيه',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF5E35B1)),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
            const SizedBox(height: 6),
            Text(bid.note,
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ],
          if (bid.isAccepted) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Column(children: [
                const Text(
                  '🎉 تم قبول عرضك! معلومات التواصل مع صاحب الطلب:',
                  style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                FutureBuilder<DocumentSnapshot>(
                  future: _db.collection('service_requests').doc(bid.requestId).get(),
                  builder: (_, snap) {
                    if (!snap.hasData || !snap.data!.exists) {
                      return const Text('جاري التحميل...',
                          style: TextStyle(color: Colors.grey, fontSize: 12));
                    }
                    final data = snap.data!.data() as Map<String, dynamic>;
                    final clientPhone = data['clientPhone'] as String? ?? '';
                    return Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse('tel:$clientPhone');
                            if (await canLaunchUrl(uri)) launchUrl(uri);
                          },
                          icon: const Icon(Icons.phone, size: 16),
                          label: Text(clientPhone),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green,
                              side: const BorderSide(color: Colors.green)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final clean = clientPhone.replaceAll(RegExp(r'[^0-9]'), '');
                          final number = clean.startsWith('20') ? clean : '2$clean';
                          final uri = Uri.parse('https://wa.me/$number');
                          if (await canLaunchUrl(uri)) {
                            launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.message, size: 16),
                        label: const Text('واتساب'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF25D366),
                            side: const BorderSide(color: Color(0xFF25D366))),
                      ),
                    ]);
                  },
                ),
              ]),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'تاريخ التقديم: ${bid.createdAt.day}/${bid.createdAt.month}/${bid.createdAt.year}',
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
        ]),
      ),
    );
  }

  Widget _emptyState(String title, String subtitle, IconData icon) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ]),
        ),
      );
}
