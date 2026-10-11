import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';

/// «Кружок» like Telegram: the front camera in a circle, one big button (tap to start, tap to stop), a ring that fills up to
/// 60 s, switch the camera, then «Отправить» or «Заново». Returns the recorded file's path.
class VideoNoteRecorder extends StatefulWidget {
  const VideoNoteRecorder({super.key});
  static Future<String?> open(BuildContext context) => Navigator.of(context, rootNavigator: true).push<String>(
        PageRouteBuilder<String>(opaque: false, barrierColor: Colors.black87, pageBuilder: (_, _, _) => const VideoNoteRecorder(), transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c)),
      );
  @override
  State<VideoNoteRecorder> createState() => _VideoNoteRecorderState();
}

class _VideoNoteRecorderState extends State<VideoNoteRecorder> with SingleTickerProviderStateMixin {
  static const _max = Duration(seconds: 60);
  CameraController? _c;
  List<CameraDescription> _cams = const [];
  int _cam = 0;
  bool _recording = false;
  String? _done;
  Object? _error;
  late final AnimationController _ring = AnimationController(vsync: this, duration: _max);

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      _cams = await availableCameras();
      if (_cams.isEmpty) throw StateError('no camera');
      final front = _cams.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
      _cam = front < 0 ? 0 : front;
      await _open();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _open() async {
    final old = _c;
    final c = CameraController(_cams[_cam], ResolutionPreset.medium, enableAudio: true);
    await c.initialize();
    await old?.dispose();
    if (!mounted) { await c.dispose(); return; }
    setState(() => _c = c);
  }

  Future<void> _toggle() async {
    final c = _c;
    if (c == null) return;
    if (!_recording) {
      HapticFeedback.mediumImpact();
      await c.startVideoRecording();
      setState(() { _recording = true; _done = null; });
      _ring.forward(from: 0).whenComplete(() { if (_recording) _toggle(); });
    } else {
      final f = await c.stopVideoRecording();
      _ring.stop();
      HapticFeedback.lightImpact();
      setState(() { _recording = false; _done = f.path; });
    }
  }

  @override
  void dispose() {
    _ring.dispose();
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final side = MediaQuery.sizeOf(context).shortestSide * 0.78;
    final c = _c;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(children: [
          Align(alignment: Alignment.topLeft, child: IconButton(color: Colors.white, icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context))),
          const Spacer(),
          SizedBox(
            width: side + 12, height: side + 12,
            child: Stack(alignment: Alignment.center, children: [
              AnimatedBuilder(
                animation: _ring,
                builder: (_, _) => SizedBox(width: side + 12, height: side + 12, child: CircularProgressIndicator(value: _recording ? _ring.value : 0, strokeWidth: 5, color: Colors.redAccent, backgroundColor: Colors.white24)),
              ),
              ClipOval(
                child: SizedBox(
                  width: side, height: side,
                  child: _error != null
                      ? ColoredBox(color: Colors.black, child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l.chatCameraFailed, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)))))
                      : c == null || !c.value.isInitialized
                          ? const ColoredBox(color: Colors.black, child: Center(child: CircularProgressIndicator()))
                          : FittedBox(fit: BoxFit.cover, child: SizedBox(width: c.value.previewSize?.height ?? side, height: c.value.previewSize?.width ?? side, child: CameraPreview(c))),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _ring,
            builder: (_, _) {
              final s = (_ring.value * _max.inSeconds).floor();
              return Text(_recording ? '0:${s.toString().padLeft(2, '0')}' : (_done != null ? l.chatVideoNoteReady : l.chatVideoNoteHint), style: const TextStyle(color: Colors.white, fontSize: 15));
            },
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              IconButton(
                color: Colors.white, iconSize: 30, tooltip: l.chatSwitchCamera,
                onPressed: _recording || _cams.length < 2 ? null : () async { _cam = (_cam + 1) % _cams.length; await _open(); },
                icon: const Icon(Icons.cameraswitch_rounded),
              ),
              GestureDetector(
                key: const Key('videoNoteRecord'),
                onTap: c == null ? null : _toggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 76, height: 76,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                  child: Center(child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _recording ? 28 : 58, height: _recording ? 28 : 58,
                    decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(_recording ? 6 : 29)),
                  )),
                ),
              ),
              IconButton(
                key: const Key('videoNoteSend'),
                color: Colors.white, iconSize: 30, tooltip: l.chatSend,
                onPressed: _done == null ? null : () => Navigator.pop(context, _done),
                icon: const Icon(Icons.send_rounded),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
