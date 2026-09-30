import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'models.dart';

/// The item's photos, whole (never cropped): a swipeable strip with dots and «2 / 5»; a tap opens them full screen
/// with pinch zoom. The strip's height follows the screen (a tablet gets a bigger picture).
class CatalogGallery extends StatefulWidget {
  const CatalogGallery({super.key, required this.media});
  final List<CatalogMedia> media;
  @override
  State<CatalogGallery> createState() => _CatalogGalleryState();
}

class _CatalogGalleryState extends State<CatalogGallery> {
  final _page = PageController();
  int _i = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final height = (width * 0.75).clamp(240.0, 520.0);
    return SizedBox(
      height: height,
      child: Stack(children: [
        PageView.builder(
          key: const Key('catalogGallery'),
          controller: _page,
          itemCount: media.length,
          onPageChanged: (i) => setState(() => _i = i),
          itemBuilder: (context, i) {
            final m = media[i];
            return GestureDetector(
              onTap: m.isVideo || m.file == null ? null : () => _openFull(context, i),
              child: _Slide(media: m, background: scheme.surfaceContainerHighest),
            );
          },
        ),
        if (media.length > 1) ...[
          Positioned(
            top: 10, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
              child: Text('${_i + 1} / ${media.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
          Positioned(
            bottom: 10, left: 0, right: 0,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < media.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _i ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(color: i == _i ? Colors.white : Colors.white54, borderRadius: BorderRadius.circular(4), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)]),
                ),
            ]),
          ),
        ],
      ]),
    );
  }

  void _openFull(BuildContext context, int start) {
    final photos = widget.media.where((m) => !m.isVideo && m.file != null).toList();
    final index = photos.indexOf(widget.media[start]);
    Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, _, _) => CatalogPhotoViewer(photos: photos, start: index < 0 ? 0 : index),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ));
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.media, required this.background});
  final CatalogMedia media;
  final Color background;
  @override
  Widget build(BuildContext context) {
    if (media.isVideo) {
      return Container(color: Colors.black, child: const Center(child: Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 64)));
    }
    final f = media.file;
    if (f == null) return ColoredBox(color: background);
    return Stack(fit: StackFit.expand, children: [
      // the same photo, blurred and dimmed, fills the sides - the photo itself is shown whole on top
      if (f.thumbUrl != null)
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Image(image: CachedNetworkImageProvider(f.thumbUrl!), fit: BoxFit.cover, color: Colors.black38, colorBlendMode: BlendMode.darken, errorBuilder: (_, _, _) => ColoredBox(color: background)),
        )
      else
        ColoredBox(color: background),
      Image(
        image: CachedNetworkImageProvider(f.url),
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()),
        errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image_rounded, size: 48)),
      ),
    ]);
  }
}

/// Full screen: swipe between photos, pinch / double-tap to zoom, ✕ or a swipe down to close.
class CatalogPhotoViewer extends StatefulWidget {
  const CatalogPhotoViewer({super.key, required this.photos, required this.start});
  final List<CatalogMedia> photos;
  final int start;
  @override
  State<CatalogPhotoViewer> createState() => _CatalogPhotoViewerState();
}

class _CatalogPhotoViewerState extends State<CatalogPhotoViewer> {
  late final _page = PageController(initialPage: widget.start);
  late int _i = widget.start;
  double _drag = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('catalogPhotoViewer'),
      backgroundColor: Colors.black.withValues(alpha: (1 - _drag.abs() / 400).clamp(0.3, 1.0)),
      body: SafeArea(
        child: Stack(children: [
          GestureDetector(
            onVerticalDragUpdate: (d) => setState(() => _drag += d.delta.dy),
            onVerticalDragEnd: (_) => _drag.abs() > 120 ? Navigator.pop(context) : setState(() => _drag = 0),
            child: Transform.translate(
              offset: Offset(0, _drag),
              child: PageView.builder(
                controller: _page,
                itemCount: widget.photos.length,
                onPageChanged: (i) => setState(() => _i = i),
                itemBuilder: (_, i) => InteractiveViewer(
                  maxScale: 5,
                  child: Center(child: Image(image: CachedNetworkImageProvider(widget.photos[i].file!.url), fit: BoxFit.contain)),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4, left: 4,
            child: IconButton(
              key: const Key('catalogViewerClose'),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (widget.photos.length > 1)
            Positioned(top: 16, right: 16, child: Text('${_i + 1} / ${widget.photos.length}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }
}
