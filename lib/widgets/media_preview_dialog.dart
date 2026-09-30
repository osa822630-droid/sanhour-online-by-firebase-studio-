// lib/widgets/media_preview_dialog.dart
// ✅ معاينة كاملة الشاشة لصورة أو فيديو — قبل الرفع (File) أو بعده (URL).
// يدعم التكبير/التصغير للصور (InteractiveViewer) والتشغيل/الإيقاف للفيديو
// مع تأبيد صحيح لـ VideoPlayerController لمنع تسريب الموارد.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'cached_image.dart';

class MediaPreviewDialog extends StatefulWidget {
  /// ملف محلي (قبل الرفع) — أولوية على [url] إن وُجد
  final File? file;

  /// رابط بعيد (بعد الرفع)
  final String? url;

  /// هل المحتوى فيديو؟ افتراضياً صورة
  final bool isVideo;

  const MediaPreviewDialog({
    super.key,
    this.file,
    this.url,
    this.isVideo = false,
  });

  /// طريقة مختصرة لعرض المعاينة كـ dialog كامل الشاشة
  static Future<void> show(
    BuildContext context, {
    File? file,
    String? url,
    bool isVideo = false,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (_) => MediaPreviewDialog(file: file, url: url, isVideo: isVideo),
    );
  }

  @override
  State<MediaPreviewDialog> createState() => _MediaPreviewDialogState();
}

class _MediaPreviewDialogState extends State<MediaPreviewDialog> {
  VideoPlayerController? _videoCtrl;
  bool _videoError = false;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final controller = widget.file != null
          ? VideoPlayerController.file(widget.file!)
          : VideoPlayerController.networkUrl(Uri.parse(widget.url ?? ''));

      _videoCtrl = controller;
      await controller.initialize();
      if (!mounted) return;
      setState(() => _videoReady = true);
      controller.play();
      controller.setLooping(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _videoError = true);
    }
  }

  @override
  void dispose() {
    // ✅ تأبيد صريح — يمنع تسريب موارد مُشغِّل الفيديو
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Center(child: _buildContent()),
          Positioned(
            top: 8,
            left: 8,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (widget.isVideo) return _buildVideo();

    // ── صورة ──────────────────────────────────────────────────────────
    final imageWidget = widget.file != null
        ? Image.file(widget.file!, fit: BoxFit.contain)
        : CachedImage(
            imageUrl: widget.url ?? '',
            fit: BoxFit.contain,
            errorWidget: const Icon(Icons.broken_image_outlined,
                color: Colors.white54, size: 64),
          );

    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 4,
      child: imageWidget,
    );
  }

  Widget _buildVideo() {
    if (_videoError) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.white54, size: 64),
          SizedBox(height: 12),
          Text('تعذّر تشغيل الفيديو',
              style: TextStyle(color: Colors.white70)),
        ],
      );
    }
    if (!_videoReady || _videoCtrl == null) {
      return const CircularProgressIndicator(color: Colors.white);
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          _videoCtrl!.value.isPlaying
              ? _videoCtrl!.pause()
              : _videoCtrl!.play();
        });
      },
      child: AspectRatio(
        aspectRatio: _videoCtrl!.value.aspectRatio == 0
            ? 16 / 9
            : _videoCtrl!.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_videoCtrl!),
            AnimatedOpacity(
              opacity: _videoCtrl!.value.isPlaying ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow,
                    color: Colors.white, size: 36),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
