// lib/widgets/media_gallery_picker_widget.dart
// ✅ نظام معرض وسائط احترافي للمحل — يدعم الصور والفيديوهات معاً.
//
// الفرق بين هذا الـ widget و MultiImagePickerWidget:
// - MultiImagePickerWidget: صور فقط، مع تحديد "صورة غلاف" — يُستخدم في
//   المنتجات/العروض/الإعلانات حيث الصورة الأولى لها معنى خاص.
// - MediaGalleryPickerWidget (هذا الملف): صور + فيديوهات معاً بلا "غلاف"،
//   يُستخدم في معرض وسائط المحل (shop.mediaUrls / shop.mediaTypes) الذي
//   يعرضه ShopMediaGallery للزوار.
//
// مميزات احترافية:
// - فيديوهات جديدة: تُعرض كصورة مصغّرة ثابتة (دون تشغيل) + شارة المدة
//   المحسوبة عبر ImageHelper.getVideoDuration — يتجنب إنشاء عشرات
//   VideoPlayerController في شبكة واحدة (تسريب موارد محتمل).
// - فيديوهات/صور موجودة (URLs): شارة نوع واضحة + معاينة كاملة بالضغط.
// - تتبع تقدم رفع منفصل للصور والفيديوهات الجديدة عبر imageProgress/videoProgress.
// - removedUrls: تتيح للمستدعي حذف الملفات المُزالة من Storage إن أراد.
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/media_upload_service.dart';
import '../utils/image_helper.dart';
import 'cached_image.dart';
import 'media_preview_dialog.dart';

/// الحالة الكاملة لمعرض الوسائط — تُمرَّر للمستدعي عبر onChanged
class MediaGalleryState {
  /// روابط الوسائط الموجودة التي بقيت (لم تُحذف)
  final List<String> keptUrls;

  /// أنواعها المتوازية: 'image' أو 'video'
  final List<String> keptTypes;

  /// صور جديدة (لم تُرفع بعد)
  final List<File> newImages;

  /// فيديوهات جديدة (لم تُرفع بعد)
  final List<File> newVideos;

  /// روابط وُجدت في initialUrls ثم حُذفت — للمستدعي صلاحية حذفها من Storage
  final List<String> removedUrls;

  const MediaGalleryState({
    required this.keptUrls,
    required this.keptTypes,
    required this.newImages,
    required this.newVideos,
    required this.removedUrls,
  });

  bool get isEmpty =>
      keptUrls.isEmpty && newImages.isEmpty && newVideos.isEmpty;

  int get totalCount => keptUrls.length + newImages.length + newVideos.length;
}

/// عنصر فيديو جديد محلي مع مدته (تُحسب مرة واحدة عند الإضافة)
class _NewVideo {
  final File file;
  final Duration? duration;
  const _NewVideo(this.file, this.duration);
}

/// عنصر داخلي موحَّد لتمثيل أي خانة في الشبكة
enum _SlotKind { existingImage, existingVideo, newImage, newVideo }

class _Slot {
  final _SlotKind kind;
  final int dataIndex; // index داخل القائمة المصدر المناسبة
  const _Slot(this.kind, this.dataIndex);
}

class MediaGalleryPickerWidget extends StatefulWidget {
  /// روابط الوسائط الموجودة مسبقاً
  final List<String> initialUrls;

  /// أنواعها المتوازية: 'image' أو 'video' (بنفس طول initialUrls)
  final List<String> initialTypes;

  /// الحد الأقصى الإجمالي لعناصر المعرض
  final int maxItems;

  /// يُستدعى عند أي تغيير
  final void Function(MediaGalleryState state) onChanged;

  /// تقدم رفع كل صورة جديدة — المفتاح index ضمن newImages، القيمة 0.0–1.0
  final Map<int, double>? imageProgress;

  /// تقدم رفع كل فيديو جديد — المفتاح index ضمن newVideos، القيمة 0.0–1.0
  final Map<int, double>? videoProgress;

  /// قفل التفاعلات أثناء الرفع
  final bool isUploading;

  const MediaGalleryPickerWidget({
    super.key,
    this.initialUrls = const [],
    this.initialTypes = const [],
    this.maxItems = 8,
    required this.onChanged,
    this.imageProgress,
    this.videoProgress,
    this.isUploading = false,
  });

  @override
  State<MediaGalleryPickerWidget> createState() =>
      _MediaGalleryPickerWidgetState();
}

class _MediaGalleryPickerWidgetState extends State<MediaGalleryPickerWidget> {
  late List<String> _urls;
  late List<String> _types;
  final List<File> _newImages = [];
  final List<_NewVideo> _newVideos = [];
  final List<String> _removedUrls = [];

  static const double _thumbSize = 108.0;
  static const double _thumbSpacing = 10.0;

  @override
  void initState() {
    super.initState();
    _urls = List.from(widget.initialUrls);
    // ✅ حماية من عدم تطابق الطول بين initialUrls وinitialTypes
    _types = List.generate(
      _urls.length,
      (i) => i < widget.initialTypes.length ? widget.initialTypes[i] : 'image',
    );
  }

  int get _total => _urls.length + _newImages.length + _newVideos.length;
  bool get _canAddMore => _total < widget.maxItems && !widget.isUploading;

  void _notify() {
    widget.onChanged(MediaGalleryState(
      keptUrls: List.unmodifiable(_urls),
      keptTypes: List.unmodifiable(_types),
      newImages: List.unmodifiable(_newImages),
      newVideos: List.unmodifiable(_newVideos.map((v) => v.file)),
      removedUrls: List.unmodifiable(_removedUrls),
    ));
  }

  // ── إضافة وسيط جديد ─────────────────────────────────────────────────────
  Future<void> _addMedia() async {
    if (widget.isUploading) return;

    final choice = await ImageHelper.showMediaSourcePicker(context, allowVideo: true);
    if (choice == null || !mounted) return;

    if (choice.isVideo) {
      final file = await ImageHelper.pickVideo(context: context, source: choice.source);
      if (file == null || !mounted) return;

      // ✅ حساب المدة مرة واحدة عند الإضافة — تُعرض كشارة على المصغّرة
      final duration = await ImageHelper.getVideoDuration(file);
      if (!mounted) return;

      setState(() => _newVideos.add(_NewVideo(file, duration)));
      _notify();
    } else {
      final file = await ImageHelper.pickAndCrop(
        context: context,
        source: choice.source,
        ratio: ImageRatio.wide, // 16:9 يطابق AspectRatio معرض المحل
      );
      if (file == null || !mounted) return;

      setState(() => _newImages.add(file));
      _notify();
    }
  }

  // ── حذف عنصر ─────────────────────────────────────────────────────────────
  void _removeSlot(_Slot slot) {
    if (widget.isUploading) return;

    setState(() {
      switch (slot.kind) {
        case _SlotKind.existingImage:
        case _SlotKind.existingVideo:
          _removedUrls.add(_urls[slot.dataIndex]);
          _urls.removeAt(slot.dataIndex);
          _types.removeAt(slot.dataIndex);
          break;
        case _SlotKind.newImage:
          _newImages.removeAt(slot.dataIndex);
          break;
        case _SlotKind.newVideo:
          _newVideos.removeAt(slot.dataIndex);
          break;
      }
    });
    _notify();
  }

  // ── معاينة ────────────────────────────────────────────────────────────
  void _preview(_Slot slot) {
    switch (slot.kind) {
      case _SlotKind.existingImage:
        MediaPreviewDialog.show(context, url: _urls[slot.dataIndex], isVideo: false);
        break;
      case _SlotKind.existingVideo:
        MediaPreviewDialog.show(context, url: _urls[slot.dataIndex], isVideo: true);
        break;
      case _SlotKind.newImage:
        MediaPreviewDialog.show(context, file: _newImages[slot.dataIndex], isVideo: false);
        break;
      case _SlotKind.newVideo:
        MediaPreviewDialog.show(
            context, file: _newVideos[slot.dataIndex].file, isVideo: true);
        break;
    }
  }

  /// بناء قائمة الخانات بالترتيب: موجودة (صور+فيديو) ثم صور جديدة ثم فيديو جديد
  List<_Slot> _buildSlots() {
    final slots = <_Slot>[];
    for (int i = 0; i < _urls.length; i++) {
      slots.add(_Slot(
        _types[i] == 'video' ? _SlotKind.existingVideo : _SlotKind.existingImage,
        i,
      ));
    }
    for (int i = 0; i < _newImages.length; i++) {
      slots.add(_Slot(_SlotKind.newImage, i));
    }
    for (int i = 0; i < _newVideos.length; i++) {
      slots.add(_Slot(_SlotKind.newVideo, i));
    }
    return slots;
  }

  // ── بناء خانة واحدة ──────────────────────────────────────────────────────
  Widget _buildSlot(_Slot slot) {
    final isVideo =
        slot.kind == _SlotKind.existingVideo || slot.kind == _SlotKind.newVideo;

    // ✅ تقدم الرفع بحسب نوع الخانة
    double? progress;
    if (slot.kind == _SlotKind.newImage) {
      progress = widget.imageProgress?[slot.dataIndex];
    } else if (slot.kind == _SlotKind.newVideo) {
      progress = widget.videoProgress?[slot.dataIndex];
    }
    final isUploadingThis = progress != null && progress < 1.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── إطار الوسيط ──────────────────────────────────────
        Container(
          width: _thumbSize,
          height: _thumbSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            color: Colors.grey.shade900,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _buildThumbContent(slot, isVideo),
          ),
        ),

        // ── طبقة تقدم الرفع ───────────────────────────────────
        if (isUploadingThis)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.black.withValues(alpha: 0.6),
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
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),

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
              onTap: () => _removeSlot(slot),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4),
                  ],
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),

        // ── زر المعاينة ────────────────────────────────────────
        if (!isUploadingThis)
          Positioned(
            bottom: -6,
            left: -6,
            child: GestureDetector(
              onTap: () => _preview(slot),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isVideo ? Icons.play_circle_outline : Icons.zoom_in,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// محتوى المصغّرة بحسب نوع الخانة
  Widget _buildThumbContent(_Slot slot, bool isVideo) {
    switch (slot.kind) {
      case _SlotKind.existingImage:
        return CachedImage(
          imageUrl: _urls[slot.dataIndex],
          width: _thumbSize,
          height: _thumbSize,
          fit: BoxFit.cover,
        );

      case _SlotKind.existingVideo:
        return _videoPlaceholder(label: 'فيديو');

      case _SlotKind.newImage:
        return Image.file(
          _newImages[slot.dataIndex],
          width: _thumbSize,
          height: _thumbSize,
          fit: BoxFit.cover,
        );

      case _SlotKind.newVideo:
        final v = _newVideos[slot.dataIndex];
        final label = v.duration != null
            ? ImageHelper.formatDuration(v.duration!)
            : 'فيديو';
        return _videoPlaceholder(label: label);
    }
  }

  /// مصغّرة ثابتة للفيديو — تتجنب إنشاء VideoPlayerController لكل عنصر
  /// في الشبكة (أداء/ذاكرة)؛ المعاينة الكاملة تُشغِّل الفيديو فعلياً.
  Widget _videoPlaceholder({required String label}) {
    return Container(
      width: _thumbSize,
      height: _thumbSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey.shade800, Colors.grey.shade900],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 22),
          ),
          Positioned(
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _addMedia,
      child: Container(
        width: _thumbSize,
        height: _thumbSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF5E35B1).withValues(alpha: 0.4),
            width: 1.5,
          ),
          color: const Color(0xFF5E35B1).withValues(alpha: 0.05),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                color: const Color(0xFF5E35B1).withValues(alpha: 0.7), size: 28),
            const SizedBox(height: 2),
            Text('إضافة',
                style: TextStyle(
                    color: const Color(0xFF5E35B1).withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            Text('صورة/فيديو',
                style: TextStyle(
                    color: const Color(0xFF5E35B1).withValues(alpha: 0.5),
                    fontSize: 9)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slots = _buildSlots();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text(
            'معرض وسائط المحل',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF5E35B1)),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF5E35B1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${slots.length} / ${widget.maxItems}',
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF5E35B1), fontWeight: FontWeight.bold),
            ),
          ),
          if (widget.isUploading) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5E35B1)),
            ),
            const SizedBox(width: 4),
            const Text('جارٍ الرفع...',
                style: TextStyle(
                    fontSize: 11, color: Color(0xFF5E35B1), fontWeight: FontWeight.w600)),
          ],
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: _thumbSize + 12,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(top: 6, bottom: 0),
            itemCount: slots.length + (_canAddMore ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(width: _thumbSpacing),
            itemBuilder: (ctx, index) {
              if (index < slots.length) return _buildSlot(slots[index]);
              return _buildAddButton();
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.info_outline, size: 13, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'صور وفيديوهات تظهر في معرض وسائط صفحة محلك. الحد الأقصى للفيديو '
              '${MediaUploadService.defaultMaxVideoSeconds} ثانية.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),
        ]),
      ],
    );
  }
}
