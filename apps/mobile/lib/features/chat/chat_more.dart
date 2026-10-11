import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import 'chat_models.dart';
import 'chat_repository.dart';

/// Chat like Telegram, and more (owner, 2026-10-11): what the special messages look like (poll, location, contact, card,
/// a link's card), the swipe to reply, the pop-in of a new message, quick replies.

// ---- a poll ---------------------------------------------------------------------------------------------------------------
class PollBubble extends ConsumerStatefulWidget {
  const PollBubble({super.key, required this.message, required this.fg, required this.onChanged});
  final ChatMessage message;
  final Color fg;
  final ValueChanged<ChatMessage> onChanged;
  @override
  ConsumerState<PollBubble> createState() => _PollBubbleState();
}

class _PollBubbleState extends ConsumerState<PollBubble> {
  bool _busy = false;
  Set<int>? _picking; // a multiple-answer poll: ticks before «Ответить»

  Future<void> _vote(List<int> options) async {
    setState(() => _busy = true);
    try {
      HapticFeedback.selectionClick();
      widget.onChanged(await ref.read(chatRepositoryProvider).vote(widget.message.id, options));
      _picking = null;
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showVoters() async {
    final l = AppLocalizations.of(context);
    try {
      final j = await ref.read(chatRepositoryProvider).voters(widget.message.id);
      if (!mounted) return;
      await showAppSheet<void>(
        context: context, scrollable: true, showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.chatPollVoters, style: Theme.of(ctx).textTheme.titleMedium),
              for (final o in ((j['options'] as List?) ?? const []).cast<Map>()) ...[
                const SizedBox(height: 12),
                Text('${o['text']} · ${(o['people'] as List).length}', style: Theme.of(ctx).textTheme.titleSmall),
                for (final p in (o['people'] as List).cast<Map>()) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${p['fullName']}')),
              ],
            ]),
          ),
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final p = widget.message.poll ?? const {};
    final options = ((p['options'] as List?) ?? const []).cast<Map>();
    final voters = (p['voters'] as num?)?.toInt() ?? 0;
    final multiple = p['multiple'] == true;
    final iVoted = options.any((o) => o['mine'] == true);
    final fg = widget.fg;
    return SizedBox(
      width: 250,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${p['question'] ?? ''}', style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 15.5)),
        Text(multiple ? l.chatPollMultiple : l.chatPollSingle, style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 12)),
        const SizedBox(height: 8),
        for (final (i, o) in options.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              key: Key('poll-${widget.message.id}-$i'),
              borderRadius: BorderRadius.circular(8),
              onTap: _busy
                  ? null
                  : () {
                      if (multiple && !iVoted) {
                        setState(() { final s = _picking ?? <int>{}; s.contains(i) ? s.remove(i) : s.add(i); _picking = s; });
                      } else if (o['mine'] == true) {
                        _vote(const []); // tap my answer again: take it back
                      } else {
                        _vote([i]);
                      }
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(
                      o['mine'] == true || (_picking?.contains(i) ?? false) ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 20, color: o['mine'] == true || (_picking?.contains(i) ?? false) ? scheme.primary : fg.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${o['text']}', style: TextStyle(color: fg))),
                    if (iVoted) Text('${voters == 0 ? 0 : ((o['count'] as num) * 100 / voters).round()}%', style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
                  ]),
                  if (iVoted)
                    Padding(
                      padding: const EdgeInsets.only(left: 28, top: 4),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: voters == 0 ? 0 : (o['count'] as num) / voters),
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, _) => ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: v, minHeight: 5, backgroundColor: fg.withValues(alpha: 0.1))),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        if (multiple && !iVoted && (_picking?.isNotEmpty ?? false))
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 38)), onPressed: _busy ? null : () => _vote(_picking!.toList()), child: Text(l.chatPollAnswer)),
        Row(children: [
          Text(l.chatPollVotes('$voters'), style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 12)),
          const Spacer(),
          if (voters > 0) TextButton(style: TextButton.styleFrom(visualDensity: VisualDensity.compact), onPressed: _showVoters, child: Text(l.chatPollWho)),
        ]),
      ]),
    );
  }
}

// ---- location, contact, card ------------------------------------------------------------------------------------------------
class LocationBubble extends StatelessWidget {
  const LocationBubble({super.key, required this.data, required this.fg});
  final Map<String, dynamic> data;
  final Color fg;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lat = (data['latitude'] as num).toDouble(), lng = (data['longitude'] as num).toDouble();
    return InkWell(
      onTap: () async {
        final app = Uri.parse('yandexmaps://maps.yandex.ru/?pt=$lng,$lat&z=16&l=map');
        if (!await launchUrl(app, mode: LaunchMode.externalApplication).catchError((_) => false)) {
          await launchUrl(Uri.parse('https://yandex.uz/maps/?pt=$lng,$lat&z=16&l=map'), mode: LaunchMode.externalApplication);
        }
      },
      child: SizedBox(
        width: 240,
        child: Row(children: [
          CircleAvatar(backgroundColor: Colors.red.withValues(alpha: 0.15), child: const Icon(Icons.location_on_rounded, color: Colors.red)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${data['label'] ?? l.chatLocation}', style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
              Text(l.chatOpenMap, style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 12.5)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class ContactBubble extends StatelessWidget {
  const ContactBubble({super.key, required this.data, required this.fg});
  final Map<String, dynamic> data;
  final Color fg;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final phone = '${data['phone'] ?? ''}';
    return SizedBox(
      width: 240,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(child: Text(initials('${data['name'] ?? ''}'))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${data['name'] ?? ''}', style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
              Text(phone, style: TextStyle(color: fg.withValues(alpha: 0.75))),
            ]),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          TextButton.icon(onPressed: () => launchUrl(Uri.parse('tel:$phone')), icon: const Icon(Icons.call_rounded, size: 18), label: Text(l.call)),
          TextButton.icon(
            onPressed: () { Clipboard.setData(ClipboardData(text: phone)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.chatCopied))); },
            icon: const Icon(Icons.copy_rounded, size: 18), label: Text(l.chatCopy),
          ),
        ]),
      ]),
    );
  }
}

/// A work / an order / a worker right in the chat: what it is and a button that opens it.
class CardBubble extends StatelessWidget {
  const CardBubble({super.key, required this.data, required this.fg});
  final Map<String, dynamic> data;
  final Color fg;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (data['type']) { 'assignment' => Icons.content_cut_rounded, 'order' => Icons.shopping_bag_rounded, _ => Icons.person_rounded };
    return Container(
      width: 250,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: fg.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: scheme.primary, width: 4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 6),
          Expanded(child: Text('${data['title'] ?? ''}', style: TextStyle(color: fg, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
        if ((data['subtitle'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text('${data['subtitle']}', style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 13))),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
            onPressed: data['link'] == null ? null : () => context.push('${data['link']}'),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(l.chatOpenCard),
          ),
        ),
      ]),
    );
  }
}

/// The first link's page, like Telegram: site, title, a line, the picture.
class LinkPreviewCard extends StatelessWidget {
  const LinkPreviewCard({super.key, required this.preview, required this.fg});
  final Map<String, dynamic> preview;
  final Color fg;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final image = preview['image'] as String?;
    return InkWell(
      onTap: () => launchUrl(Uri.parse('${preview['url']}'), mode: LaunchMode.externalApplication),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: scheme.primary, width: 3)), color: fg.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (preview['site'] != null) Text('${preview['site']}', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 12.5)),
          if (preview['title'] != null) Text('${preview['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
          if (preview['description'] != null) Text('${preview['description']}', maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 13)),
          if (image != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: image, height: 130, width: 240, fit: BoxFit.cover, errorWidget: (_, _, _) => const SizedBox.shrink())),
            ),
        ]),
      ),
    );
  }
}

// ---- gestures and motion ----------------------------------------------------------------------------------------------------
/// Telegram's swipe to reply: the bubble follows the finger to the left (or right), a reply arrow fills in, and
/// letting go past the mark replies (with a little buzz).
class SwipeToReply extends StatefulWidget {
  const SwipeToReply({super.key, required this.child, required this.onReply, this.enabled = true});
  final Widget child;
  final VoidCallback onReply;
  final bool enabled;
  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> with SingleTickerProviderStateMixin {
  late final AnimationController _back = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  double _dx = 0;
  bool _armed = false;
  static const _mark = 64.0;

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  double _from = 0;

  @override
  void initState() {
    super.initState();
    _back.addListener(() { if (mounted) setState(() => _dx = _from * (1 - Curves.easeOut.transform(_back.value))); });
  }

  void _end() {
    if (_dx.abs() >= _mark) widget.onReply();
    _from = _dx;
    _armed = false;
    _back.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final progress = (_dx.abs() / _mark).clamp(0.0, 1.0);
    return GestureDetector(
      onHorizontalDragUpdate: (d) {
        setState(() => _dx = (_dx + d.delta.dx).clamp(-_mark * 1.4, _mark * 1.4));
        if (!_armed && _dx.abs() >= _mark) { _armed = true; HapticFeedback.lightImpact(); }
        if (_armed && _dx.abs() < _mark) _armed = false;
      },
      onHorizontalDragEnd: (_) => _end(),
      onHorizontalDragCancel: _end,
      child: Stack(alignment: _dx < 0 ? Alignment.centerRight : Alignment.centerLeft, children: [
        if (_dx != 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Transform.scale(
              scale: 0.6 + 0.4 * progress,
              child: Opacity(opacity: progress, child: CircleAvatar(radius: 16, backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: const Icon(Icons.reply_rounded, size: 18))),
            ),
          ),
        Transform.translate(offset: Offset(_dx, 0), child: widget.child),
      ]),
    );
  }
}

/// A new message pops in: a short slide up + fade + a touch of scale (only messages that arrive while the chat is open).
class PopIn extends StatefulWidget {
  const PopIn({super.key, required this.child, required this.animate, this.fromRight = false});
  final Widget child;
  final bool animate;
  final bool fromRight;
  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 260), value: widget.animate ? 0 : 1);
  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Opacity(
        opacity: _c.value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - t.value)),
          child: Transform.scale(scale: 0.92 + 0.08 * t.value, alignment: widget.fromRight ? Alignment.bottomRight : Alignment.bottomLeft, child: child),
        ),
      ),
      child: widget.child,
    );
  }
}

/// A reaction chip that pops when it appears or changes.
class ReactionPop extends StatelessWidget {
  const ReactionPop({super.key, required this.child, required this.count});
  final Widget child;
  final int count;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        key: ValueKey(count),
        tween: Tween(begin: 0.6, end: 1),
        duration: const Duration(milliseconds: 380),
        curve: Curves.elasticOut,
        builder: (_, s, c) => Transform.scale(scale: s, child: c),
        child: child,
      );
}

// ---- sheets ------------------------------------------------------------------------------------------------------------
/// «Опрос»: a question and 2..10 answers, one or several allowed.
Future<({String question, List<String> options, bool multiple})?> showPollSheet(BuildContext context) =>
    showFormSheet<({String question, List<String> options, bool multiple})>(context, showDragHandle: true, useSafeArea: false, builder: (_) => const _PollSheet());

class _PollSheet extends StatefulWidget {
  const _PollSheet();
  @override
  State<_PollSheet> createState() => _PollSheetState();
}

class _PollSheetState extends State<_PollSheet> {
  final _q = TextEditingController();
  final _opts = [TextEditingController(), TextEditingController()];
  bool _multiple = false;

  @override
  void dispose() {
    _q.dispose();
    for (final c in _opts) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _ok => _q.text.trim().isNotEmpty && _opts.where((c) => c.text.trim().isNotEmpty).length >= 2;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.chatPoll, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(key: const Key('pollQuestion'), controller: _q, autofocus: true, maxLength: 300, decoration: InputDecoration(labelText: l.chatPollQuestion, hintText: l.chatPollQuestionHint), onChanged: (_) => setState(() {})),
          for (final (i, c) in _opts.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: TextField(key: Key('pollOption-$i'), controller: c, maxLength: 100, decoration: InputDecoration(labelText: l.chatPollOption('${i + 1}'), counterText: ''), onChanged: (_) => setState(() {})),
            ),
          if (_opts.length < 10) Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => setState(() => _opts.add(TextEditingController())), icon: const Icon(Icons.add_rounded), label: Text(l.chatPollAddOption))),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: _multiple, onChanged: (v) => setState(() => _multiple = v), title: Text(l.chatPollMultiple)),
          FilledButton(
            key: const Key('pollSend'),
            onPressed: !_ok ? null : () => Navigator.pop(context, (question: _q.text.trim(), options: [for (final c in _opts) if (c.text.trim().isNotEmpty) c.text.trim()], multiple: _multiple)),
            child: Text(l.chatSend),
          ),
        ]),
      ),
    );
  }
}

/// «Контакт»: a name and a phone to send.
Future<({String name, String phone})?> showContactSheet(BuildContext context) {
  final l = AppLocalizations.of(context);
  final name = TextEditingController();
  final phone = TextEditingController(text: '+998 ');
  return showFormSheet<({String name, String phone})>(context, showDragHandle: true, useSafeArea: false, builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.chatContact, style: Theme.of(ctx).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(key: const Key('contactName'), controller: name, autofocus: true, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: l.teamFullName)),
          const SizedBox(height: 8),
          TextField(key: const Key('contactPhone'), controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: l.phone)),
          const SizedBox(height: 12),
          FilledButton(key: const Key('contactSend'), onPressed: () { if (name.text.trim().isNotEmpty && phone.text.replaceAll(RegExp(r'\D'), '').length >= 5) Navigator.pop(ctx, (name: name.text.trim(), phone: phone.text.trim())); }, child: Text(l.chatSend)),
        ]),
      ));
}

/// «Карточка» (staff): find a work / a worker / an order and send it as a card.
Future<({String type, String id})?> showCardPicker(BuildContext context, WidgetRef ref) => showAppSheet<({String type, String id})>(
      context: context, showDragHandle: true, builder: (_) => const _CardPicker(),
    );

class _CardPicker extends ConsumerStatefulWidget {
  const _CardPicker();
  @override
  ConsumerState<_CardPicker> createState() => _CardPickerState();
}

class _CardPickerState extends ConsumerState<_CardPicker> {
  Map<String, dynamic>? _found;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    List<Map> list(String k) => ((_found?[k] as List?) ?? const []).cast<Map>();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 8),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: Column(children: [
            TextField(
              key: const Key('cardSearch'),
              autofocus: true,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: l.chatCardSearch),
              onChanged: (q) async {
                if (q.trim().length < 2) return setState(() => _found = null);
                final r = await ref.read(apiClientProvider).getJson('/admin/search', query: {'q': q.trim()});
                if (mounted) setState(() => _found = r);
              },
            ),
            Expanded(
              child: ListView(children: [
                for (final w in list('works')) ListTile(leading: const Icon(Icons.content_cut_rounded), title: Text('${w['code']} · ${w['worker']}'), subtitle: Text('${w['product']}'), onTap: () => Navigator.pop(context, (type: 'assignment', id: '${w['id']}'))),
                for (final w in list('workers')) ListTile(leading: const Icon(Icons.person_rounded), title: Text('${w['fullName']}'), subtitle: Text('${w['code']}'), onTap: () => Navigator.pop(context, (type: 'worker', id: '${w['id']}'))),
                for (final o in list('orders')) ListTile(leading: const Icon(Icons.shopping_bag_rounded), title: Text('${o['code']} · ${o['name']}'), onTap: () => Navigator.pop(context, (type: 'order', id: '${o['id']}'))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ---- quick replies -------------------------------------------------------------------------------------------------------
/// «Быстрые ответы»: a few ready phrases (kept on this phone), one tap puts one into the message field.
class QuickReplies {
  static const _key = 'chat_quick_replies';
  static List<String> load(WidgetRef ref, AppLocalizations l) {
    final raw = ref.read(sharedPrefsProvider).getString(_key);
    if (raw == null) return [l.quickReply1, l.quickReply2, l.quickReply3, l.quickReply4];
    return (jsonDecode(raw) as List).cast<String>();
  }

  static Future<void> save(WidgetRef ref, List<String> items) => ref.read(sharedPrefsProvider).setString(_key, jsonEncode(items));
}

Future<String?> showQuickReplies(BuildContext context, WidgetRef ref) {
  final l = AppLocalizations.of(context);
  return showAppSheet<String>(
    context: context,
    showDragHandle: true,
    scrollable: true,
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      final items = QuickReplies.load(ref, l);
      return SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 4), child: Text(l.quickReplies, style: Theme.of(ctx).textTheme.titleMedium)),
          for (final (i, t) in items.indexed)
            ListTile(
              key: Key('quick-$i'),
              leading: const Icon(Icons.bolt_rounded),
              title: Text(t),
              onTap: () => Navigator.pop(ctx, t),
              trailing: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () async { await QuickReplies.save(ref, [...items]..removeAt(i)); set(() {}); }),
            ),
          ListTile(
            leading: const Icon(Icons.add_rounded),
            title: Text(l.quickReplyAdd),
            onTap: () async {
              final c = TextEditingController();
              final t = await showDialog<String>(context: ctx, builder: (d) => AlertDialog(
                    title: Text(l.quickReplyAdd),
                    content: TextField(controller: c, autofocus: true, maxLength: 200),
                    actions: [TextButton(onPressed: () => Navigator.pop(d), child: Text(l.cancel)), FilledButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: Text(l.save))],
                  ));
              if (t != null && t.isNotEmpty) { await QuickReplies.save(ref, [...items, t]); set(() {}); }
            },
          ),
        ]),
      );
    }),
  );
}
