// lib/widgets/shop_media_gallery.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'cached_image.dart';

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
      if (_isCurrentVideo) return;
      final next = (_selectedIndex + 1) % widget.mediaUrls.length;
      setState(
          () => _selectedIndex = next.clamp(0, widget.mediaUrls.length - 1));
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
        GestureDetector(
          onTap: () => _openFullscreen(context, _selectedIndex),
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
        if (widget.mediaUrls.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.mediaUrls.length,
              itemBuilder: (_, i) {
                final isVid =
                    i < widget.mediaTypes.length && widget.mediaTypes[i] == 'video';
                return GestureDetector(
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
                        isVid
                            ? _VideoThumb(
                                url: widget.mediaUrls[i], isThumb: true)
                            : _buildImage(widget.mediaUrls[i]),
                        if (isVid)
                          const Center(
                            child: Icon(Icons.play_circle_fill,
                                color: Colors.white70, size: 24),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildImage(String url) => CachedImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
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
          final isVid =
              i < widget.mediaTypes.length && widget.mediaTypes[i] == 'video';
          if (isVid) {
            return _VideoPlayer(url: widget.mediaUrls[i]);
          }
          return InteractiveViewer(
            child: Center(
              child: CachedImage(
                imageUrl: widget.mediaUrls[i],
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VideoThumb extends StatelessWidget {
  final String url;
  final bool isThumb;
  const _VideoThumb({required this.url, this.isThumb = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A0030),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_circle_outline_rounded,
              color: const Color(0xFF9575CD),
              size: isThumb ? 28 : 52,
            ),
            if (!isThumb) ...[
              const SizedBox(height: 6),
              const Text(
                'اضغط لتشغيل الفيديو',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VideoPlayer extends StatefulWidget {
  final String url;
  const _VideoPlayer({required this.url});

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> {
  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _ctrl = ctrl;
      await ctrl.initialize();
      if (!mounted) return;
      setState(() => _initialized = true);
      await ctrl.setLooping(true);
      await ctrl.play();
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.white54, size: 56),
            SizedBox(height: 12),
            Text('تعذّر تشغيل هذا الفيديو',
                style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }
    if (!_initialized || _ctrl == null) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          _ctrl!.value.isPlaying ? _ctrl!.pause() : _ctrl!.play();
        });
      },
      child: Center(
        child: AspectRatio(
          aspectRatio:
              _ctrl!.value.aspectRatio == 0 ? 16 / 9 : _ctrl!.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_ctrl!),
              AnimatedOpacity(
                opacity: _ctrl!.value.isPlaying ? 0.0 : 1.0,
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
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: VideoProgressIndicator(
                  _ctrl!,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Color(0xFF7C4DFF),
                    bufferedColor: Colors.white38,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
