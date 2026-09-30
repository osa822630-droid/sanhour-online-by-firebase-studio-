// lib/widgets/shop_media_gallery.dart
// ✅ Fix #74: autoplay Timer مع dispose صحيح لمنع memory leak
// ✅ Fix #186: _selectedIndex.clamp() لمنع RangeError
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ShopMediaGallery extends StatefulWidget {
  final List<String> mediaUrls;
  final List<String> mediaTypes; // 'image' | 'video'

  const ShopMediaGallery({
    super.key,
    required this.mediaUrls,
    required this.mediaTypes,
  });

  @override
  State<ShopMediaGallery> createState() => _ShopMediaGalleryState();
}

class _ShopMediaGalleryState extends State<ShopMediaGallery> {
  int _selectedIndex = 0;
  // ✅ Fix #74: autoplay timer للصور فقط
  Timer? _autoplayTimer;

  bool get _hasMedia => widget.mediaUrls.isNotEmpty;
  bool get _isCurrentVideo =>
      _selectedIndex < widget.mediaTypes.length &&
      widget.mediaTypes[_selectedIndex] == 'video';

  @override
  void initState() {
    super.initState();
    _startAutoplay();
  }

  void _startAutoplay() {
    if (widget.mediaUrls.length <= 1) return;
    _autoplayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      // لا autoplay على الفيديو
      if (_isCurrentVideo) return;
      final next = (_selectedIndex + 1) % widget.mediaUrls.length;
      setState(() => _selectedIndex = next.clamp(0, widget.mediaUrls.length - 1));
    });
  }

  @override
  void dispose() {
    _autoplayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasMedia) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── عنوان القسم ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              const Icon(Icons.photo_library_outlined,
                  color: Color(0xFF5E35B1), size: 20),
              const SizedBox(width: 8),
              const Text(
                'صور وفيديوهات المحل',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${widget.mediaUrls.length} عنصر',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),

        // ─── الصورة/الفيديو الرئيسي ─────────────────────────────────
        GestureDetector(
          onTap: () => _openFullscreen(context, _selectedIndex),
          // ✅ Fix #185: AspectRatio 16:9 بدلاً من ارتفاع ثابت
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.black,
              ),
              clipBehavior: Clip.hardEdge,
              child: _isCurrentVideo
                  ? _VideoThumb(url: widget.mediaUrls[_selectedIndex])
                  : _buildImage(widget.mediaUrls[_selectedIndex]),
            ),
          ),
        ),

        // ─── الصور المصغّرة (Thumbnails) ────────────────────────────
        if (widget.mediaUrls.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.mediaUrls.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => setState(() =>
                    _selectedIndex = i.clamp(0, widget.mediaUrls.length - 1)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 64,
                  height: 64,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _selectedIndex == i
                          ? const Color(0xFF5E35B1)
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      widget.mediaTypes[i] == 'video'
                          ? _VideoThumb(url: widget.mediaUrls[i], isThumb: true)
                          : _buildImage(widget.mediaUrls[i]),
                      if (widget.mediaTypes[i] == 'video')
                        const Center(
                          child: Icon(Icons.play_circle_fill,
                              color: Colors.white70, size: 24),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildImage(String url) => Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image_outlined,
              size: 48, color: Colors.grey),
        ),
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : const Center(child: CircularProgressIndicator()),
      );

  void _openFullscreen(BuildContext context, int startIndex) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      pageBuilder: (_, __, ___) => _FullscreenGallery(
        mediaUrls: widget.mediaUrls,
        mediaTypes: widget.mediaTypes,
        initialIndex: startIndex,
      ),
    ));
  }
}

// ─── عارض الشاشة الكاملة ───────────────────────────────────────────────────
class _FullscreenGallery extends StatefulWidget {
  final List<String> mediaUrls;
  final List<String> mediaTypes;
  final int initialIndex;

  const _FullscreenGallery({
    required this.mediaUrls,
    required this.mediaTypes,
    required this.initialIndex,
  });

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late PageController _ctrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('${_current + 1} / ${widget.mediaUrls.length}',
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ),
      body: PageView.builder(
        controller: _ctrl,
        onPageChanged: (i) => setState(() => _current = i),
        itemCount: widget.mediaUrls.length,
        itemBuilder: (_, i) {
          if (widget.mediaTypes[i] == 'video') {
            return _VideoPlayer(url: widget.mediaUrls[i]);
          }
          return InteractiveViewer(
            child: Center(
              child: Image.network(widget.mediaUrls[i], fit: BoxFit.contain),
            ),
          );
        },
      ),
    );
  }
}

// ─── مصغّر الفيديو (thumbnail) ─────────────────────────────────────────────
class _VideoThumb extends StatelessWidget {
  final String url;
  final bool isThumb;
  const _VideoThumb({required this.url, this.isThumb = false});

  @override
  Widget build(BuildContext context) {
    // نعرض placeholder بنفسجي مع أيقونة تشغيل
    return Container(
      color: const Color(0xFF1A0030),
      child: Center(
        child: Icon(
          Icons.play_circle_outline_rounded,
          color: const Color(0xFF9575CD),
          size: isThumb ? 28 : 52,
        ),
      ),
    );
  }
}

// ─── مشغّل الفيديو الكامل ──────────────────────────────────────────────────
class _VideoPlayer extends StatefulWidget {
  final String url;
  const _VideoPlayer({required this.url});

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
        _ctrl.play();
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return GestureDetector(
      onTap: () =>
          _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play(),
      child: Center(
        child: AspectRatio(
          aspectRatio: _ctrl.value.aspectRatio,
          child: VideoPlayer(_ctrl),
        ),
      ),
    );
  }
}
