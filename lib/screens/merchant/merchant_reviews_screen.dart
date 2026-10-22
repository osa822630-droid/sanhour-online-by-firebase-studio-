
// lib/screens/merchant/merchant_reviews_screen.dart
// ✅ Pagination: cursor-based بـ pageSize=15 مع ScrollController
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:sanhour_online/models/review_model.dart';
import 'package:sanhour_online/widgets/custom_app_bar.dart';
import 'package:sanhour_online/widgets/empty_state_widget.dart';

class MerchantReviewsScreen extends StatefulWidget {
  final String shopId;

  const MerchantReviewsScreen({super.key, required this.shopId});

  @override
  State<MerchantReviewsScreen> createState() => _MerchantReviewsScreenState();
}

class _MerchantReviewsScreenState extends State<MerchantReviewsScreen> {
  static const int _pageSize = 15;

  final List<Review> _reviews = [];
  DocumentSnapshot? _lastDoc;
  bool _isLoading = true;
  bool _hasMore = true;
  bool _isFetchingMore = false;
  String? _errorMsg;
  String _filter = 'all';

  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
              _scrollCtrl.position.maxScrollExtent - 200 &&
          !_isFetchingMore &&
          _hasMore) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReviews({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _reviews.clear();
        _lastDoc = null;
        _hasMore = true;
        _errorMsg = null;
        _isLoading = true;
      });
    }
    try {
      // جلب تقييمات المحل مباشرةً
      Query q = FirebaseFirestore.instance
          .collection('reviews')
          .where('targetId', isEqualTo: widget.shopId)
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);
      if (_lastDoc != null) q = q.startAfterDocument(_lastDoc!);

      final snap = await q.get();
      final docs = snap.docs.map((d) => Review.fromFirestore(d)).toList();

      if (mounted) {
        setState(() {
          _reviews.addAll(docs);
          _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : _lastDoc;
          _hasMore = snap.docs.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'تعذّر تحميل التقييمات. اضغط للمحاولة.';
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isFetchingMore) return;
    setState(() => _isFetchingMore = true);
    await _loadReviews();
    if (mounted) setState(() => _isFetchingMore = false);
  }

  List<Review> get _filteredReviews {
    switch (_filter) {
      case 'replied':
        return _reviews.where((r) => r.reply != null && r.reply!.isNotEmpty).toList();
      case 'not_replied':
        return _reviews.where((r) => r.reply == null || r.reply!.isEmpty).toList();
      case 'shop':
        return _reviews.where((r) => r.targetType == 'shop').toList();
      case 'product':
        return _reviews.where((r) => r.targetType == 'product').toList();
      default:
        return _reviews;
    }
  }

  void _showReplyDialog(Review review) {
    final replyController = TextEditingController(text: review.reply);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text('الرد على تقييم ${review.userName}'),
          content: TextField(
            controller: replyController,
            decoration: const InputDecoration(hintText: 'اترك الرد فارغاً للحذف'),
            maxLines: 5,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final newReply = replyController.text;
                Navigator.of(dialogCtx).pop();
                await _submitReply(review, newReply);
              },
              child: const Text('إرسال الرد'),
            ),
          ],
        );
      },
    // ✅ Fix #64: dispose controller بعد إغلاق الـ dialog
    ).whenComplete(() => replyController.dispose());
  }

  Future<void> _submitReply(Review review, String reply) async {
    final reviewRef = FirebaseFirestore.instance.collection('reviews').doc(review.id);
    await reviewRef.update({
      'reply': reply.isEmpty ? FieldValue.delete() : reply,
      'repliedAt': reply.isEmpty ? FieldValue.delete() : FieldValue.serverTimestamp(),
    });
    // ✅ بعد تحويل الشاشة لـ Pagination مفيش _reviewsFuture ولا _fetchReviews؛
    // بنعيد تحميل أول صفحة عبر مسار الـ refresh الموجود (بيصفّر الحالة ويعيد الجلب).
    if (mounted) await _loadReviews(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredReviews;
    return Scaffold(
      appBar: CustomAppBar(title: 'تقييمات المتجر والمنتجات', hasBackButton: true),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: _isLoading && _reviews.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _errorMsg != null && _reviews.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 12),
                            Text(_errorMsg!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _loadReviews(refresh: true),
                              icon: const Icon(Icons.refresh),
                              label: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? EmptyStateWidget(
                            message: _filter == 'all'
                                ? 'لا توجد تقييمات لعرضها حالياً'
                                : 'لا توجد تقييمات تطابق هذا الفلتر',
                            icon: Icons.reviews_outlined,
                          )
                        : RefreshIndicator(
                            onRefresh: () => _loadReviews(refresh: true),
                            child: ListView.builder(
                              controller: _scrollCtrl,
                              padding: const EdgeInsets.all(8.0),
                              itemCount: filtered.length + (_hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == filtered.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                        child: CircularProgressIndicator(strokeWidth: 2)),
                                  );
                                }
                                return _buildReviewCard(filtered[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
             const SizedBox(width: 4),
            FilterChip(label: const Text('الكل'), selected: _filter == 'all', onSelected: (sel) => setState(() => _filter = 'all')),
            const SizedBox(width: 8),
            FilterChip(label: const Text('تقييمات المتجر'), selected: _filter == 'shop', onSelected: (sel) => setState(() => _filter = 'shop')),
             const SizedBox(width: 8),
            FilterChip(label: const Text('تقييمات المنتجات'), selected: _filter == 'product', onSelected: (sel) => setState(() => _filter = 'product')),
             const SizedBox(width: 8),
            FilterChip(label: const Text('تم الرد عليها'), selected: _filter == 'replied', onSelected: (sel) => setState(() => _filter = 'replied')),
             const SizedBox(width: 8),
            FilterChip(label: const Text('لم يتم الرد'), selected: _filter == 'not_replied', onSelected: (sel) => setState(() => _filter = 'not_replied')),
             const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(Review review) {
    final bool isReplied = review.reply != null && review.reply!.isNotEmpty;
    final isShopReview = review.targetType == 'shop';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReviewHeader(review),
            if (!isShopReview) ...[
                 const SizedBox(height: 8),
                _buildReviewedItem(review),
            ],
            const Divider(),
            Text(review.comment, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 10),
            if (isReplied)
              _buildReplySection(review)
            else
              Align(
                alignment: Alignment.bottomLeft,
                child: TextButton.icon(
                  onPressed: () => _showReplyDialog(review),
                  icon: const Icon(Icons.reply, size: 18),
                  label: const Text('إضافة رد'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewHeader(Review review) {
    return Row(
      children: [
        CircleAvatar(
          backgroundImage: (review.userImage != null && review.userImage!.isNotEmpty)
              ? NetworkImage(review.userImage!)
              : null,
          child: (review.userImage == null || review.userImage!.isEmpty)
              ? const Icon(Icons.person)
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(review.userName ?? 'مستخدم', style: const TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: List.generate(5, (i) => Icon(i < review.rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 18)),
              ),
            ],
          ),
        ),
        Text(DateFormat('dd-MM-yyyy').format(review.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

    Widget _buildReviewedItem(Review review) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
      child: Row(
        children: [
          review.targetImage != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(review.targetImage!, width: 40, height: 40, fit: BoxFit.cover),
                )
              : const Icon(Icons.shopping_bag, size: 40, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('المنتج المُقيَّم:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text(review.targetName ?? 'منتج غير متوفر', style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplySection(Review review) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ردك:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(review.reply ?? ''),
           const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                review.repliedAt != null ? DateFormat('dd-MM-yyyy hh:mm a').format(review.repliedAt!) : '',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              InkWell(
                onTap: () => _showReplyDialog(review),
                child: const Text('تعديل الرد', style: TextStyle(color: Colors.deepPurple, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
