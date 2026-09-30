import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';

/// «Удобное время»: when she is happy for staff to come (deliver materials / collect work) - days, hours, a note.
class VisitTime {
  const VisitTime({required this.days, required this.from, required this.to, this.note});
  final List<int> days; // 1 = Monday
  final String from;
  final String to;
  final String? note;
  Map<String, Object?> toJson() => {'days': days, 'from': from, 'to': to, 'note': note};
  static VisitTime? fromJson(Object? j) {
    if (j is! Map) return null;
    return VisitTime(days: ((j['days'] as List?) ?? const []).map((d) => (d as num).toInt()).toList(), from: j['from'] as String? ?? '10:00', to: j['to'] as String? ?? '18:00', note: j['note'] as String?);
  }
}

final myVisitTimeProvider = FutureProvider.autoDispose<({VisitTime? value, String? text})>((ref) async {
  final j = await ref.watch(apiClientProvider).getJson('/work/visit-time');
  return (value: VisitTime.fromJson(j['visitTime']), text: j['visitText'] as String?);
});

/// Profile tile: «Когда удобно, чтобы приезжали» + what is set now; a tap opens the editor.
class VisitTimeTile extends ConsumerWidget {
  const VisitTimeTile({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final v = ref.watch(myVisitTimeProvider).value;
    return Card(
      child: ListTile(
        key: const Key('visitTimeTile'),
        leading: const Icon(Icons.schedule_rounded),
        title: Text(l.visitTimeTitle),
        subtitle: Text(v?.text ?? l.visitTimeNotSet),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => showFormSheet<void>(context, showDragHandle: true, useSafeArea: false, builder: (_) => VisitTimeSheet(initial: v?.value)),
      ),
    );
  }
}

class VisitTimeSheet extends ConsumerStatefulWidget {
  const VisitTimeSheet({super.key, this.initial});
  final VisitTime? initial;
  @override
  ConsumerState<VisitTimeSheet> createState() => _VisitTimeSheetState();
}

class _VisitTimeSheetState extends ConsumerState<VisitTimeSheet> {
  late final Set<int> _days = {...?widget.initial?.days, if (widget.initial == null) ...[1, 2, 3, 4, 5]};
  late String _from = widget.initial?.from ?? '10:00';
  late String _to = widget.initial?.to ?? '18:00';
  late final _note = TextEditingController(text: widget.initial?.note ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick(bool from) async {
    final cur = (from ? _from : _to).split(':');
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(cur[0]), minute: int.parse(cur[1])), builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!));
    if (t == null) return;
    final v = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() => from ? _from = v : _to = v);
  }

  Future<void> _save(bool clear) async {
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).putJson('/work/visit-time', body: {
        'visitTime': clear ? null : VisitTime(days: (_days.toList()..sort()), from: _from, to: _to, note: _note.text.trim().isEmpty ? null : _note.text.trim()).toJson(),
      });
      ref.invalidate(myVisitTimeProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final names = [l.dayMon, l.dayTue, l.dayWed, l.dayThu, l.dayFri, l.daySat, l.daySun];
    final valid = _days.isNotEmpty && _from.compareTo(_to) < 0;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.visitTimeTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(l.visitTimeHint, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var d = 1; d <= 7; d++)
            FilterChip(
              key: Key('visitDay-$d'),
              label: Text(names[d - 1]),
              selected: _days.contains(d),
              onSelected: (on) => setState(() => on ? _days.add(d) : _days.remove(d)),
            ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: OutlinedButton(key: const Key('visitFrom'), onPressed: () => _pick(true), child: Text('${l.visitFrom} $_from', style: const TextStyle(fontSize: 16)))),
          const SizedBox(width: 12),
          Expanded(child: OutlinedButton(key: const Key('visitTo'), onPressed: () => _pick(false), child: Text('${l.visitTo} $_to', style: const TextStyle(fontSize: 16)))),
        ]),
        if (_from.compareTo(_to) >= 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.visitTimeOrder, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 12),
        TextField(controller: _note, maxLength: 200, decoration: InputDecoration(labelText: l.visitTimeNote, hintText: l.visitTimeNoteHint)),
        const SizedBox(height: 8),
        FilledButton(key: const Key('visitSave'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), onPressed: !valid || _busy ? null : () => _save(false), child: Text(l.save)),
        if (widget.initial != null) TextButton(onPressed: _busy ? null : () => _save(true), child: Text(l.visitTimeClear)),
      ]),
    );
  }
}
