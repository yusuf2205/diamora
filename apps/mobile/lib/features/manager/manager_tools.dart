import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../work/create_assignment_screen.dart';

String _two(int v) => v.toString().padLeft(2, '0');
String _date(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';
String _dateTime(DateTime d) => '${_two(d.day)}.${_two(d.month)} ${_two(d.hour)}:${_two(d.minute)}';

// ---- «Кто простаивает» ------------------------------------------------------------------------------------------------
/// GET /admin/workers-idle: her workers without any work on their hands, those asking for work first, then the longest idle.
final idleWorkersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.listen(realtimeEventsProvider, (_, next) {
    final t = next.value?.type ?? '';
    if (t.startsWith('assignment.') || t.startsWith('worker.') || t.startsWith('job_request.')) ref.invalidateSelf();
  });
  final j = await ref.watch(apiClientProvider).getJson('/admin/workers-idle');
  return ((j['items'] as List?) ?? const []).cast<Map>().map((x) => x.cast<String, dynamic>()).toList();
});

class IdleWorkersScreen extends ConsumerWidget {
  const IdleWorkersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final list = ref.watch(idleWorkersProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.idleTitle)),
      body: list.when(
        loading: () => const SkeletonList(count: 5),
        error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: errorText(context, e)),
        data: (items) => items.isEmpty
            ? EmptyState(icon: Icons.celebration_rounded, title: l.idleNone)
            : RefreshIndicator(
                onRefresh: () => ref.refresh(idleWorkersProvider.future),
                child: ListView(padding: AppTokens.screenPadding.copyWith(top: 8, bottom: 24), children: [
                  Text(l.idleHint, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  for (final w in items) _IdleTile(w: w),
                ]),
              ),
      ),
    );
  }
}

class _IdleTile extends StatelessWidget {
  const _IdleTile({required this.w});
  final Map<String, dynamic> w;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final days = (w['idleDays'] as num).toInt();
    final q = w['qualityPercent'];
    final lines = [
      w['everWorked'] == true ? l.idleDays('$days') : l.idleNeverWorked,
      if (q != null) l.idleQuality('$q'),
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: () => context.push('/admin/workers/${w['workerId']}'),
            child: Row(children: [
              Expanded(child: Text('${w['fullName']}', style: Theme.of(context).textTheme.titleMedium)),
              if (w['wantsWork'] == true)
                Chip(label: Text(l.idleWantsWork), visualDensity: VisualDensity.compact, backgroundColor: Colors.green.withValues(alpha: 0.15)),
            ]),
          ),
          Text(lines.join(' · '), style: TextStyle(color: days >= 7 ? scheme.error : scheme.onSurfaceVariant, fontWeight: days >= 7 ? FontWeight.w700 : null)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              key: Key('giveWork-${w['workerId']}'),
              icon: const Icon(Icons.add_task_rounded),
              label: Text(l.idleGiveWork),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CreateAssignmentScreen(workerId: w['workerId'] as String))),
            ),
          ),
        ]),
      ),
    );
  }
}

// ---- «Напоминания себе» -----------------------------------------------------------------------------------------------
final remindersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final j = await ref.watch(apiClientProvider).getJson('/me/reminders');
  return ((j['items'] as List?) ?? const []).cast<Map>().map((x) => x.cast<String, dynamic>()).toList();
});

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final list = ref.watch(remindersProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.remindersTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('addReminder'),
        onPressed: () => showReminderSheet(context),
        icon: const Icon(Icons.alarm_add_rounded),
        label: Text(l.reminderAdd),
      ),
      body: list.when(
        loading: () => const SkeletonList(count: 4),
        error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: errorText(context, e)),
        data: (items) => items.isEmpty
            ? EmptyState(icon: Icons.alarm_rounded, title: l.remindersEmpty, hint: l.remindersEmptyHint)
            : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [for (final r in items) _ReminderTile(r: r)]),
      ),
    );
  }
}

class _ReminderTile extends ConsumerWidget {
  const _ReminderTile({required this.r});
  final Map<String, dynamic> r;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final done = r['done'] == true;
    final due = DateTime.parse(r['dueAt'] as String).toLocal();
    final late = !done && due.isBefore(DateTime.now());
    final worker = (r['worker'] as Map?)?.cast<String, dynamic>();
    Future<void> act(Future<void> Function() f) async {
      try {
        await f();
        ref.invalidate(remindersProvider);
      } catch (e) {
        if (context.mounted) showError(context, e);
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Checkbox(value: done, onChanged: (v) => act(() => ref.read(apiClientProvider).patchJson('/me/reminders/${r['id']}', body: {'done': v ?? false}))),
        title: Text('${r['text']}', style: done ? const TextStyle(decoration: TextDecoration.lineThrough) : null),
        subtitle: Text([_dateTime(due), if (worker != null) worker['fullName']].join(' · '), style: TextStyle(color: late ? Theme.of(context).colorScheme.error : null)),
        onTap: worker == null ? null : () => context.push('/admin/workers/${worker['id']}'),
        trailing: IconButton(tooltip: l.deleteAction, icon: const Icon(Icons.delete_outline_rounded), onPressed: () => act(() => ref.read(apiClientProvider).delete('/me/reminders/${r['id']}'))),
      ),
    );
  }
}

/// «Напомнить»: what, when (quick: tomorrow 9:00, in 3 days, next Monday, or any date and time), optionally about a worker.
Future<void> showReminderSheet(BuildContext context, {String? workerId, String? workerName, String? text}) =>
    showFormSheet<void>(context, showDragHandle: true, useSafeArea: false, builder: (_) => _ReminderSheet(workerId: workerId, workerName: workerName, text: text));

class _ReminderSheet extends ConsumerStatefulWidget {
  const _ReminderSheet({this.workerId, this.workerName, this.text});
  /// «Напомнить» from a chat message: its words, ready to edit
  final String? text;
  final String? workerId;
  final String? workerName;
  @override
  ConsumerState<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends ConsumerState<_ReminderSheet> {
  late final _text = TextEditingController(text: widget.text);
  late DateTime _at = _tomorrowAt9();
  bool _busy = false;

  static DateTime _tomorrowAt9() { final n = DateTime.now(); return DateTime(n.year, n.month, n.day + 1, 9); }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final d = await showDatePicker(context: context, initialDate: _at, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_at));
    if (!mounted) return;
    setState(() => _at = DateTime(d.year, d.month, d.day, t?.hour ?? 9, t?.minute ?? 0));
  }

  Future<void> _save() async {
    if (_text.text.trim().isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).postJson('/me/reminders', body: {'text': _text.text.trim(), 'dueAt': _at.toUtc().toIso8601String(), 'workerId': ?widget.workerId});
      ref.invalidate(remindersProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).reminderSaved(_dateTime(_at)))));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final n = DateTime.now();
    final quick = <(String, DateTime)>[
      (l.reminderTomorrow, _tomorrowAt9()),
      (l.reminderIn3Days, DateTime(n.year, n.month, n.day + 3, 9)),
      (l.reminderNextMonday, DateTime(n.year, n.month, n.day + (8 - n.weekday), 9)),
    ];
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 4, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.workerName == null ? l.reminderAdd : '${l.reminderAdd}: ${widget.workerName}', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        TextField(key: const Key('reminderText'), controller: _text, autofocus: true, maxLength: 500, minLines: 1, maxLines: 3, decoration: InputDecoration(labelText: l.reminderWhat, hintText: l.reminderWhatHint)),
        Wrap(spacing: 8, runSpacing: 6, children: [
          for (final q in quick) ChoiceChip(label: Text(q.$1), selected: _at == q.$2, onSelected: (_) => setState(() => _at = q.$2)),
          ActionChip(avatar: const Icon(Icons.event_rounded, size: 18), label: Text(_dateTime(_at)), onPressed: _pick),
        ]),
        const SizedBox(height: 16),
        FilledButton(key: const Key('saveReminder'), onPressed: _busy ? null : _save, child: Text(l.save)),
      ]),
    );
  }
}

// ---- «Замена на время отпуска» ----------------------------------------------------------------------------------------
final awayProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async => ref.watch(apiClientProvider).getJson('/me/away'));

class AwayScreen extends ConsumerStatefulWidget {
  const AwayScreen({super.key});
  @override
  ConsumerState<AwayScreen> createState() => _AwayScreenState();
}

class _AwayScreenState extends ConsumerState<AwayScreen> {
  String? _substituteId;
  DateTime? _until;
  bool _busy = false;

  Future<void> _run(Future<Map<String, dynamic>> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
      ref.invalidate(awayProvider);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final state = ref.watch(awayProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.awayTitle)),
      body: state.when(
        loading: () => const SkeletonList(count: 2),
        error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: errorText(context, e)),
        data: (d) {
          final covering = ((d['covering'] as List?) ?? const []).cast<Map>();
          final subs = ((d['substitutes'] as List?) ?? const []).cast<Map>();
          return ListView(padding: AppTokens.screenPadding.copyWith(top: 8, bottom: 24), children: [
            if (d['away'] == true)
              Card(
                color: Colors.orange.withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.awayNow(_date(DateTime.parse(d['until'] as String).toLocal()), '${(d['substitute'] as Map?)?['fullName'] ?? ''}'), style: text.titleMedium),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const Key('awayBack'),
                      onPressed: _busy ? null : () => _run(() => ref.read(apiClientProvider).postJson('/me/back')),
                      icon: const Icon(Icons.home_rounded), label: Text(l.awayBack),
                    ),
                  ]),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(l.awayHint('${d['myWorkers']}'), style: text.bodyMedium),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: const Key('awaySubstitute'),
                      initialValue: _substituteId,
                      decoration: InputDecoration(labelText: l.awaySubstitute),
                      items: [for (final s in subs) DropdownMenuItem(value: s['id'] as String, child: Text('${s['fullName']}'))],
                      onChanged: (v) => setState(() => _substituteId = v),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.event_rounded),
                      label: Text(_until == null ? l.awayUntilPick : l.awayUntil(_date(_until!))),
                      onPressed: () async {
                        final now = DateTime.now();
                        final d = await showDatePicker(context: context, initialDate: now.add(const Duration(days: 7)), firstDate: now.add(const Duration(days: 1)), lastDate: now.add(const Duration(days: 120)));
                        if (d != null) setState(() => _until = DateTime(d.year, d.month, d.day, 8));
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('awayGo'),
                      onPressed: _busy || _substituteId == null || _until == null
                          ? null
                          : () => _run(() => ref.read(apiClientProvider).postJson('/me/away', body: {'substituteId': _substituteId, 'until': _until!.toUtc().toIso8601String()})),
                      child: Text(l.awayGo),
                    ),
                  ]),
                ),
              ),
            if (covering.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l.awayCovering, style: text.titleMedium),
              for (final c in covering)
                ListTile(
                  leading: const Icon(Icons.people_alt_rounded),
                  title: Text('${(c['manager'] as Map)['fullName']}'),
                  subtitle: Text(l.awayCoveringLine('${c['workers']}', c['until'] == null ? '—' : _date(DateTime.parse(c['until'] as String).toLocal()))),
                ),
            ],
          ]);
        },
      ),
    );
  }
}

/// On «Обзор»: «Без работы: N» -> «Кто простаивает» (shown only when someone is idle).
class IdleBanner extends ConsumerWidget {
  const IdleBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(idleWorkersProvider).value?.length ?? 0;
    if (n == 0) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Card(
        child: ListTile(
          key: const Key('idleBanner'),
          leading: const Icon(Icons.hourglass_empty_rounded, color: Colors.orange),
          title: Text(l.idleBanner('$n'), style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(l.idleTitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push('/admin/idle'),
        ),
      ),
    );
  }
}
