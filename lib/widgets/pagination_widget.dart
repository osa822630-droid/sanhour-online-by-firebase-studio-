// lib_widgets_pagination_widget.dart
import 'package:flutter/material.dart';

class PaginationWidget extends StatefulWidget {
  final Future<void> Function() onLoadMore;
  final bool hasMore;
  final bool isLoading;
  final String? noMoreText;
  final String? loadingText;
  final double loadingIndicatorSize;
  final Color loadingIndicatorColor;

  const PaginationWidget({
    super.key,
    required this.onLoadMore,
    required this.hasMore,
    required this.isLoading,
    this.noMoreText,
    this.loadingText,
    this.loadingIndicatorSize = 20.0,
    this.loadingIndicatorColor = Colors.blue,
  });

  @override
  State<PaginationWidget> createState() => _PaginationWidgetState();
}

class _PaginationWidgetState extends State<PaginationWidget> {
  // ❌ تم حذف ScrollController الداخلي لأنه كان غير متصل بالقائمة ويسبب مشاكل
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    // ✅ التحسين: بمجرد بناء هذا الويدجت (معناه إن المستخدم وصل لآخر القائمة)
    // نبدأ التحميل تلقائياً لو فيه داتا لسه
    if (widget.hasMore && !widget.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadMore();
      });
    }
  }

  Future<void> _loadMore() async {
    // ✅ حماية إضافية من الاستدعاء المتكرر
    if (!widget.hasMore || widget.isLoading || _isLoadingMore) return;

    if (mounted) setState(() => _isLoadingMore = true);

    try {
      await widget.onLoadMore();
    } catch (e) {
      debugPrint('خطأ في تحميل المزيد: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10), // ✅ مسافة جمالية
      child: Column(
        mainAxisSize: MainAxisSize.min, // ✅ عشان مياخدش مساحة زيادة
        children: [
          // لو بيحمل (سواء من بره أو من جوه) نعرض اللودينج
          if (_isLoadingMore || widget.isLoading) _buildLoadingIndicator(),

          // لو مفيش داتا تاني ومش بيحمل
          if (!widget.hasMore && !widget.isLoading) _buildNoMoreItems(),

          // لو فيه داتا بس لسه مبيحملش (حالة نادرة مع التحميل التلقائي، بس بنسيب الزر احتياطي)
          if (widget.hasMore && !_isLoadingMore && !widget.isLoading)
            _buildLoadMoreButton(),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: widget.loadingIndicatorSize,
              height: widget.loadingIndicatorSize,
              child: CircularProgressIndicator(
                strokeWidth: 2.5, // ✅ تحسين السمك
                valueColor:
                    AlwaysStoppedAnimation<Color>(widget.loadingIndicatorColor),
              ),
            ),
            if (widget.loadingText != null) ...[
              const SizedBox(width: 10),
              Text(widget.loadingText!,
                  style: const TextStyle(color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoMoreItems() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Text(
          widget.noMoreText ?? 'تم عرض كل العناصر',
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: TextButton(
          onPressed: _loadMore,
          style: TextButton.styleFrom(
            foregroundColor: widget.loadingIndicatorColor, // ✅ تنسيق الزر
          ),
          child: const Text('تحميل المزيد'),
        ),
      ),
    );
  }
}

// =========================================================
// ✅ PaginationListView: يدعم التحميل عند الوصول للنهاية
// =========================================================
class PaginationListView extends StatelessWidget {
  final List<Widget> children;
  final Future<void> Function() onLoadMore;
  final bool hasMore;
  final bool isLoading;
  final ScrollController? controller;
  final EdgeInsets? padding;
  final String? noMoreText;
  final String? loadingText;

  const PaginationListView({
    super.key,
    required this.children,
    required this.onLoadMore,
    required this.hasMore,
    required this.isLoading,
    this.controller,
    this.padding,
    this.noMoreText,
    this.loadingText,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(), // ✅ ضمان السكرول دائماً
      padding: padding,
      // عدد العناصر + 1 عشان الـ Loader في الآخر
      itemCount: children.length + 1,
      itemBuilder: (context, index) {
        if (index == children.length) {
          // ده آخر عنصر، هيظهر الـ PaginationWidget ويبدأ التحميل التلقائي
          return PaginationWidget(
            onLoadMore: onLoadMore,
            hasMore: hasMore,
            isLoading: isLoading,
            noMoreText: noMoreText,
            loadingText: loadingText,
          );
        }
        return children[index];
      },
    );
  }
}

// =========================================================
// ✅ PaginationGridView: شبكة مع دعم التحميل
// =========================================================
class PaginationGridView extends StatelessWidget {
  final List<Widget> children;
  final Future<void> Function() onLoadMore;
  final bool hasMore;
  final bool isLoading;
  final ScrollController? controller;
  final EdgeInsets? padding;
  final SliverGridDelegate gridDelegate;
  final String? noMoreText;
  final String? loadingText;

  const PaginationGridView({
    super.key,
    required this.children,
    required this.onLoadMore,
    required this.hasMore,
    required this.isLoading,
    this.controller,
    this.padding,
    required this.gridDelegate,
    this.noMoreText,
    this.loadingText,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(), // ✅ ضمان السكرول
      slivers: [
        SliverPadding(
          padding: padding ?? EdgeInsets.zero,
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) => children[index],
              childCount: children.length,
            ),
            gridDelegate: gridDelegate,
          ),
        ),
        // ✅ اللودر بيتحط تحت الشبكة باستخدام SliverToBoxAdapter
        SliverToBoxAdapter(
          child: PaginationWidget(
            onLoadMore: onLoadMore,
            hasMore: hasMore,
            isLoading: isLoading,
            noMoreText: noMoreText,
            loadingText: loadingText,
          ),
        ),
      ],
    );
  }
}
