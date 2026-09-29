import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_exception.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../team/team_screen.dart' show teamRoleLabel;
import 'chat_list_screen.dart' show chatWhen;
import 'chat_models.dart';
import 'chat_repository.dart';

final myProfileProvider = FutureProvider.autoDispose<MyProfile>((ref) => ref.watch(chatRepositoryProvider).myProfile());

/// A round photo, or the initials.
class PersonPhoto extends StatelessWidget {
  const PersonPhoto({super.key, required this.name, this.url, this.radius = 20, this.online = false});
  final String name;
  final String? url;
  final double radius;
  final bool online;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final avatar = url != null
        ? CircleAvatar(radius: radius, backgroundImage: CachedNetworkImageProvider(url!))
        : CircleAvatar(radius: radius, backgroundColor: scheme.primaryContainer, foregroundColor: scheme.onPrimaryContainer, child: Text(initials(name), style: TextStyle(fontWeight: FontWeight.w700, fontSize: radius * 0.6)));
    if (!online) return avatar;
    return Stack(children: [
      avatar,
      Positioned(right: 0, bottom: 0, child: Container(width: 13, height: 13, decoration: BoxDecoration(color: const Color(0xFF16A34A), shape: BoxShape.circle, border: Border.all(color: scheme.surface, width: 2)))),
    ]);
  }
}

String lastSeenText(AppLocalizations l, ChatPerson p) =>
    p.online ? l.onlineNow : p.lastSeenAt != null ? l.chatLastSeen(chatWhen(l, p.lastSeenAt!)) : teamRoleLabel(l, p.role);

/// «Мой профиль», like Telegram's «Информация»: tap the photo to change it; «о себе» (140), @username.
class MyProfileSheet extends ConsumerStatefulWidget {
  const MyProfileSheet({super.key});
  @override
  ConsumerState<MyProfileSheet> createState() => _MyProfileSheetState();
}

class _MyProfileSheetState extends ConsumerState<MyProfileSheet> {
  final _bio = TextEditingController();
  final _username = TextEditingController();
  bool _filled = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _bio.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _photo() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1024, maxHeight: 1024);
    if (x == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(chatRepositoryProvider).setAvatar(x.path);
      ref.invalidate(myProfileProvider);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(chatRepositoryProvider).updateMyProfile(bio: _bio.text.trim(), username: _username.text.trim());
      ref.invalidate(myProfileProvider);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.code == 'USERNAME_TAKEN' ? l.chatUsernameTaken : errorText(context, e));
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final me = ref.watch(myProfileProvider);
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: me.when(
        loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text(errorText(context, e)),
        data: (p) {
          if (!_filled) { _bio.text = p.bio ?? ''; _username.text = p.username ?? ''; _filled = true; }
          return SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(
                child: GestureDetector(
                  key: const Key('myAvatar'),
                  onTap: _busy ? null : _photo,
                  child: Stack(children: [
                    PersonPhoto(name: p.fullName, url: p.avatar, radius: 52),
                    Positioned(right: 0, bottom: 0, child: CircleAvatar(radius: 18, child: Icon(Icons.photo_camera_rounded, size: 18, semanticLabel: l.chatChangeAvatar))),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              Text(p.fullName, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              Text(l.onlineNow, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 16),
              TextField(key: const Key('myBio'), controller: _bio, maxLength: 140, decoration: InputDecoration(labelText: l.chatBio, helperText: l.chatBioHint, helperMaxLines: 2)),
              const SizedBox(height: 8),
              ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.phone_rounded), title: Text(p.phone), subtitle: Text(l.chatPhone)),
              TextField(key: const Key('myUsername'), controller: _username, decoration: InputDecoration(labelText: l.chatUsername, prefixText: '@', helperText: l.chatUsernameHint, helperMaxLines: 2)),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
              const SizedBox(height: 16),
              FilledButton(key: const Key('mySave'), onPressed: _busy ? null : _save, child: Text(l.save)),
              if (p.avatar != null)
                TextButton(
                  onPressed: _busy ? null : () async { await ref.read(chatRepositoryProvider).setAvatar(null); ref.invalidate(myProfileProvider); },
                  child: Text(l.chatRemoveAvatar, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
            ]),
          );
        },
      ),
    );
  }
}

/// A person's card, like Telegram's right panel: photo, status, phone (staff), @username, «о себе», counts.
class PersonProfileView extends ConsumerWidget {
  const PersonProfileView({super.key, required this.userId, this.onOpenTab});
  final String userId;
  final ValueChanged<String>? onOpenTab;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final q = ref.watch(_profileProvider(userId));
    return q.when(
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Text(errorText(context, e)),
      data: (p) {
        final c = p.counts;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: GestureDetector(
              onTap: p.avatarFull == null ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => Scaffold(
                    backgroundColor: Colors.black,
                    appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
                    body: Center(child: InteractiveViewer(child: CachedNetworkImage(imageUrl: p.avatarFull!))),
                  ))),
              child: PersonPhoto(name: p.person.fullName, url: p.person.avatar, radius: 48),
            ),
          ),
          const SizedBox(height: 8),
          Text(p.person.fullName, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          Text(lastSeenText(l, p.person), textAlign: TextAlign.center, style: TextStyle(color: p.person.online ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 8),
          if (p.phone != null) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.phone_rounded), title: Text(p.phone!), subtitle: Text(l.chatPhone), onTap: () => launchUrl(Uri.parse('tel:${p.phone}'))),
          if (p.person.username != null) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.alternate_email_rounded), title: Text('@${p.person.username}', style: TextStyle(color: Theme.of(context).colorScheme.primary)), subtitle: Text(l.chatUsername)),
          if (p.bio != null && p.bio!.isNotEmpty) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.info_outline_rounded), title: Text(p.bio!), subtitle: Text(l.chatBio)),
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.badge_outlined), title: Text(teamRoleLabel(l, p.person.role)), subtitle: Text(l.chatRole)),
          if (c != null) ...[
            const Divider(),
            for (final (key, icon, text, tab) in [
              ('photos', Icons.photo_outlined, l.chatCountPhotos(c['photos'] ?? 0), 'media'),
              ('videos', Icons.videocam_outlined, l.chatCountVideos(c['videos'] ?? 0), 'media'),
              ('files', Icons.insert_drive_file_outlined, l.chatCountFiles((c['files'] ?? 0) + (c['audio'] ?? 0)), 'files'),
              ('links', Icons.link_rounded, l.chatCountLinks(c['links'] ?? 0), 'links'),
              ('voice', Icons.mic_none_rounded, l.chatCountVoice(c['voice'] ?? 0), 'voice'),
            ])
              ListTile(key: Key('count-$key'), dense: true, contentPadding: EdgeInsets.zero, leading: Icon(icon), title: Text(text), onTap: onOpenTab == null ? null : () => onOpenTab!(tab)),
          ],
        ]);
      },
    );
  }
}

final _profileProvider = FutureProvider.autoDispose.family<ChatProfile, String>((ref, id) => ref.watch(chatRepositoryProvider).profile(id));

/// Bars of a voice message (the played part filled); tap / drag to seek.
class Waveform extends StatelessWidget {
  const Waveform({super.key, required this.bars, required this.progress, required this.color, this.onSeek});
  final List<int> bars;
  final double progress;
  final Color color;
  final ValueChanged<double>? onSeek;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        void seek(double dx) => onSeek?.call((dx / box.maxWidth).clamp(0.0, 1.0));
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => seek(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => seek(d.localPosition.dx),
          child: SizedBox(
            height: 28,
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              for (var i = 0; i < bars.length; i++)
                Expanded(
                  child: Center(
                    child: Container(
                      width: 3,
                      height: (bars[i] / 31 * 26).clamp(3, 26).toDouble(),
                      decoration: BoxDecoration(color: i / bars.length <= progress ? color : color.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
            ]),
          ),
        );
      });
}

/// Bars for a message: its recorded waveform, or a stable pattern from its id.
List<int> barsFor(List<int>? waveform, String id, {int n = 40}) {
  if (waveform != null && waveform.isNotEmpty) {
    final out = <int>[];
    for (var i = 0; i < n; i++) {
      out.add(waveform[(i * waveform.length / n).floor().clamp(0, waveform.length - 1)].clamp(1, 31));
    }
    return out;
  }
  var h = id.codeUnits.fold<int>(2166136261, (a, c) => ((a ^ c) * 16777619) & 0x7fffffff);
  return List.generate(n, (i) { h = ((h ^ i) * 16777619) & 0x7fffffff; return 6 + h % 22; });
}

/// Loudness samples (0-1) -> [n] bars 0-31.
List<int> toBars(List<double> samples, {int n = 48}) {
  if (samples.isEmpty) return const [];
  final max = samples.fold<double>(0.05, (a, b) => b > a ? b : a);
  return List.generate(n, (i) {
    final from = (i * samples.length / n).floor();
    final to = ((i + 1) * samples.length / n).floor().clamp(from + 1, samples.length);
    var peak = 0.0;
    for (var j = from; j < to; j++) { if (samples[j] > peak) peak = samples[j]; }
    return (peak / max * 31).round().clamp(1, 31);
  });
}
