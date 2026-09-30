// lib/widgets/multi_image_picker_widget.dart
// ✅ نظام اختيار صور متعدد احترافي مع تحديد صورة الواجهة (الغلاف)
// — يُستخدم في: AddProductScreen، AddOfferScreen، _AdFormScreen، AddShopScreen، EditShopScreen
// — يدعم: صور موجودة (URLs) + صور جديدة (Files)
// — اختيار الغلاف بضغطة واحدة + إشارة تاج ذهبية واضحة
//
// ✅ نظام الميديا الاحترافي — إضافات هذا الإصدار:
// - uploadProgress: عرض نسبة رفع كل صورة جديدة كحلقة تقدم فوق الصورة
//   أثناء الحفظ — المستخدم يرى تقدماً حقيقياً بدلاً من تجمّد الواجهة.
// - isUploading: قفل كل التفاعلات (إضافة/حذف/تغيير غلاف) أثناء الرفع
//   لمنع تغيّر الفهارس في منتصف عملية رفع نشطة.
// - زر معاينة (عدسة) على كل صورة يفتح MediaPreviewDialog كامل الشاشة.
import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/image_helper.dart';
import 'cached_image.dart';
import 'media_preview_dialog.dart';

/// بيانات الحالة التي يُعيدها الـ widget عند أي تغيير
class MultiImageState {
  final List<String> existingUrls;
  final List<File> newFiles;
  final int coverIndex; // index في القائمة المدمجة: existingUrls أولاً ثم newFiles

  const MultiImageState({
    required this.existingUrls,
    required this.newFiles,
    required this.coverIndex,
  });

  bool get isEmpty => existingUrls.isEmpty && newFiles.isEmpty;
  int get totalCount => existingUrls.length + newFiles.length;

  /// URL صورة الغلاف للعرض (إن كانت URL موجودة)
  String? get coverUrl {
    if (existingUrls.isEmpty && newFiles.isEmpty) return null;
    if (coverIndex < existingUrls.length) return existingUrls[coverIndex];
    return null;
  }

  /// File صورة الغلاف (إن كانت ملف جديد)
  File? get coverFile {
    if (newFiles.isEmpty) return null;
    final idx = coverIndex - existingUrls.length;
    if (idx >= 0 && idx < newFiles.length) return newFiles[idx];
    return null;
  }
}

class MultiImagePickerWidget extends StatefulWidget {
  /// الصور المحفوظة مسبقاً في Firestore
  final List<String> initialUrls;

  /// الملفات الجديدة (في حالة التعديل)
  final List<File> initialFiles;

  /// index صورة الغلاف في القائمة المدمجة
  final int initialCoverIndex;

  /// يُستدعى عند أي تغيير (إضافة / حذف / تغيير الغلاف)
  final void Function(MultiImageState state) onChanged;

  /// نسبة أبعاد الصور المُختارة
  final ImageRatio ratio;

  /// الحد الأقصى لعدد الصور
  final int maxImages;

  /// تسمية تظهر فوق الـ widget
  final String label;

  /// ✅ تقدم رفع كل صورة جديدة — المفتاح هو index في قائمة newFiles
  /// (وليس الـ combinedIndex)، والقيمة من 0.0 إلى 1.0.
  /// عندما يكون غير null لصورة، تظهر حلقة تقدم فوقها.
  final Map<int, double>? uploadProgress;

  /// ✅ عند true تُقفل كل التفاعلات (إضافة/حذف/تغيير غلاف) — تُستخدم
  /// أثناء عملية الحفظ لمنع تغيّر الفهارس في منتصف الرفع.
  final bool isUploading;

  const MultiImagePickerWidget({
    super.key,
    this.initialUrls = const [],
    this.initialFiles = const [],
    this.initialCoverIndex = 0,
    required this.onChanged,
    this.ratio = ImageRatio.square,
    this.maxImages = 5,
    this.label = 'الصور',
    this.uploadProgress,
    this.isUploading = false,
  });

  @override
  State<MultiImagePickerWidget> createState() => _MultiImagePickerWidgetState();
}

class _MultiImagePickerWidgetState extends State<MultiImagePickerWidget> {
  late List<String> _urls;
  late List<File> _files;
  late int _coverIndex;

  static const double _thumbSize = 108.0;
  static const double _thumbSpacing = 10.0;

  @override
  void initState() {
    super.initState();
    _urls = List.from(widget.initialUrls);
    _files = List.from(widget.initialFiles);
    _coverIndex = widget.initialCoverIndex.clamp(
        0, (widget.initialUrls.length + widget.initialFiles.length - 1).clamp(0, 999));
  }

  // ── حساب القائمة المدمجة ──────────────────────────────────────────────────
  int get _total => _urls.length + _files.length;
  bool get _canAddMore => _total < widget.maxImages && !widget.isUploading;

  void _notify() {
    widget.onChanged(MultiImageState(
      existingUrls: List.unmodifiable(_urls),
      newFiles: List.unmodifiable(_files),
      coverIndex: _coverIndex,
    ));
  }

  // ── اختيار صورة جديدة ────────────────────────────────────────────────────
  Future<void> _addImage() async {
    if (widget.isUploading) return;

    final source = await ImageHelper.showSourcePicker(context);
    if (source == null || !mounted) return;

    final file = await ImageHelper.pickAndCrop(
      context: context,
      source: source,
      ratio: widget.ratio,
    );
    if (file == null || !mounted) return;

    setState(() {
      _files.add(file);
      // إذا كانت أول صورة → تصبح الغلاف تلقائياً
      if (_total == 1) _coverIndex = 0;
    });
    _notify();
  }

  // ── حذف صورة ─────────────────────────────────────────────────────────────
  void _removeAt(int combinedIndex) {
    if (widget.isUploading) return;

    setState(() {
      if (combinedIndex < _urls.length) {
        _urls.removeAt(combinedIndex);
      } else {
        _files.removeAt(combinedIndex - _urls.length);
      }

      // إعادة ضبط _coverIndex
      final newTotal = _total;
      if (newTotal == 0) {
        _coverIndex = 0;
      } else if (_coverIndex >= newTotal) {
        _coverIndex = 0;
      } else if (_coverIndex > combinedIndex) {
        _coverIndex--;
      } else if (_coverIndex == combinedIndex) {
        _coverIndex = 0;
      }
    });
    _notify();
  }

  // ── تعيين الغلاف ─────────────────────────────────────────────────────────
  void _setCover(int combinedIndex) {
    if (widget.isUploading) return;
    if (_coverIndex == combinedIndex) return;
    setState(() => _coverIndex = combinedIndex);
    _notify();
  }

  // ── معاينة كاملة الشاشة ──────────────────────────────────────────────────
  void _preview(int combinedIndex) {
    final isUrl = combinedIndex < _urls.length;
    MediaPreviewDialog.show(
      context,
      url: isUrl ? _urls[combinedIndex] : null,
      file: isUrl ? null : _files[combinedIndex - _urls.length],
      isVideo: false,
    );
  }

  // ── بناء صورة واحدة ──────────────────────────────────────────────────────
  Widget _buildThumb(int combinedIndex) {
    final isCover = combinedIndex == _coverIndex;
    final isUrl = combinedIndex < _urls.length;

    // ✅ تقدم الرفع — يُحسب فقط للصور الجديدة (newFiles)، باستخدام index
    // ضمن _files (وليس الـ combinedIndex المدمج)
    double? progress;
    if (!isUrl && widget.uploadProgress != null) {
      final fileIndex = combinedIndex - _urls.length;
      progress = widget.uploadProgress![fileIndex];
    }
    final isUploadingThis = progress != null && progress < 1.0;

    return GestureDetector(
      onTap: () => _setCover(combinedIndex),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── إطار الصورة ──────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _thumbSize,
            height: _thumbSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCover
                    ? const Color(0xFFFFB300)
                    : Colors.grey.withValues(alpha: 0.3),
                width: isCover ? 2.5 : 1.0,
              ),
              boxShadow: isCover
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: isUrl
                  ? CachedImage(
                      imageUrl: _urls[combinedIndex],
                      width: _thumbSize,
                      height: _thumbSize,
                      fit: BoxFit.cover,
                    )
                  : Image.file(
                      _files[combinedIndex - _urls.length],
                      width: _thumbSize,
                      height: _thumbSize,
                      fit: BoxFit.cover,
                    ),
            ),
          ),

          // ── طبقة تقدم الرفع ───────────────────────────────────
          if (isUploadingThis)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black.withValues(alpha: 0.55),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 3,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(progress * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── علامة ✓ عند اكتمال الرفع ──────────────────────────
          if (progress != null && progress >= 1.0)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.green.withValues(alpha: 0.25),
                ),
                child: const Center(
                  child: Icon(Icons.check_circle, color: Colors.white, size: 30),
                ),
              ),
            ),

          // ── زر الحذف ────────────────────────────────────────
          if (!widget.isUploading)
            Positioned(
              top: -6,
              right: -6,
              child: GestureDetector(
                onTap: () => _removeAt(combinedIndex),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4,
                      )
                    ],
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),

          // ── زر المعاينة (عدسة) ────────────────────────────────
          if (!isUploadingThis)
            Positioned(
              bottom: -6,
              left: -6,
              child: GestureDetector(
                onTap: () => _preview(combinedIndex),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.zoom_in, color: Colors.white, size: 14),
                ),
              ),
            ),

          // ── شارة الغلاف (تاج ذهبي) ──────────────────────────
          if (isCover && !isUploadingThis)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 26,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 13),
                    SizedBox(width: 3),
                    Text(
                      'واجهة',
                      style: TextStyle(
                        color: Color(0xFFFFB300),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── زر إضافة صورة جديدة ──────────────────────────────────────────────────
  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _addImage,
      child: Container(
        width: _thumbSize,
        height: _thumbSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF5E35B1).withValues(alpha: 0.4),
            width: 1.5,
            style: BorderStyle.solid,
          ),
          color: const Color(0xFF5E35B1).withValues(alpha: 0.05),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              color: const Color(0xFF5E35B1).withValues(alpha: 0.7),
              size: 30,
            ),
            const SizedBox(height: 4),
            Text(
              'إضافة',
              style: TextStyle(
                color: const Color(0xFF5E35B1).withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── التسمية والعداد ───────────────────────────────────
        Row(
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF5E35B1),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF5E35B1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_total / ${widget.maxImages}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF5E35B1),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (widget.isUploading) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF5E35B1)),
              ),
              const SizedBox(width: 4),
              const Text(
                'جارٍ الرفع...',
                style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF5E35B1),
                    fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),

        const SizedBox(height: 10),

        // ── قائمة الصور الأفقية ───────────────────────────────
        SizedBox(
          height: _thumbSize + 12, // مساحة إضافية لـ overflow badge الحذف
          child: _total == 0 && !_canAddMore
              ? const SizedBox.shrink()
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(top: 6, bottom: 0),
                  itemCount: _total + (_canAddMore ? 1 : 0),
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: _thumbSpacing),
                  itemBuilder: (ctx, index) {
                    if (index < _total) return _buildThumb(index);
                    return _buildAddButton();
                  },
                ),
        ),

        const SizedBox(height: 8),

        // ── تلميح ────────────────────────────────────────────
        if (_total > 1)
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 13, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                'اضغط على الصورة لاختيارها كواجهة، أو على 🔍 للمعاينة',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          )
        else if (_total == 0)
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 13, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                'أضف صورة واحدة على الأقل',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
      ],
    );
  }
}
