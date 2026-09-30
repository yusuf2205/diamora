import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/location/where_am_i.dart';
import '../../l10n/app_localizations.dart';
import '../team/models.dart';
import 'route_plan.dart';

/// «Маршрут»: pick whom to visit (those with work to collect or to deliver are ticked), get the shortest round from
/// where I am, and open it in Yandex Maps with every stop in order.
class RouteSheet extends ConsumerStatefulWidget {
  const RouteSheet({super.key, required this.rows});
  final List<LiveLocationRow> rows;
  @override
  ConsumerState<RouteSheet> createState() => _RouteSheetState();
}

class _RouteSheetState extends ConsumerState<RouteSheet> {
  late final List<RouteStop> _all;
  late final Set<String> _picked;
  ({List<RouteStop> order, double km})? _plan;
  ({double lat, double lng})? _start;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final seen = <String>{};
    _all = [
      for (final r in widget.rows)
        if (r.workerId != null && seen.add('${r.userId}|${r.isHome}'))
          RouteStop(
            id: '${r.userId}|${r.isHome}',
            name: r.fullName,
            lat: r.latitude,
            lng: r.longitude,
            note: [if (r.toPickup) 'pickup', if (r.toDeliver) 'deliver', if (r.overdue) 'overdue'].join(','),
          ),
    ]..sort((a, b) {
        // those with something waiting first, then by name
        final w = ((b.note ?? '').isNotEmpty ? 1 : 0) - ((a.note ?? '').isNotEmpty ? 1 : 0);
        return w != 0 ? w : a.name.compareTo(b.name);
      });
    // who has something waiting is ticked from the start
    _picked = {for (final s in _all) if ((s.note ?? '').isNotEmpty) s.id};
  }

  Future<void> _build() async {
    setState(() => _busy = true);
    // fast even without GPS (a tablet): last known place / a rough fix / my point on the server; null = from the first stop
    final start = await whereAmI(ref);
    final stops = _all.where((s) => _picked.contains(s.id)).toList();
    final from = start ?? (lat: stops.first.lat, lng: stops.first.lng);
    if (!mounted) return;
    setState(() {
      _start = start;
      _plan = planRoute(from, stops);
      _busy = false;
    });
  }

  /// the Yandex Maps / Navigator app when it is installed, else the site in the browser
  Future<void> _openYandex(List<RouteStop> order) async {
    final web = yandexRouteUrl(_start, order);
    final app = Uri.parse(web.toString().replaceFirst('https://yandex.ru/maps/', 'yandexmaps://maps.yandex.ru/'));
    try {
      if (await launchUrl(app, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    await launchUrl(web, mode: LaunchMode.externalApplication);
  }

  String _noteText(AppLocalizations l, String? note) => [
        if (note?.contains('pickup') ?? false) l.routeToPickup,
        if (note?.contains('deliver') ?? false) l.routeToDeliver,
        if (note?.contains('overdue') ?? false) l.routeOverdue,
      ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final plan = _plan;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(plan == null ? l.routeTitle : l.routeReady(plan.order.length, plan.km.toStringAsFixed(1)), style: Theme.of(context).textTheme.titleLarge),
          ),
          if (_all.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text(l.routeNobody)),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              if (plan == null)
                for (final s in _all)
                  CheckboxListTile(
                    key: Key('routeStop-${s.id}'),
                    value: _picked.contains(s.id),
                    onChanged: (v) => setState(() => v == true ? _picked.add(s.id) : _picked.remove(s.id)),
                    title: Text(s.name),
                    subtitle: (s.note ?? '').isEmpty ? null : Text(_noteText(l, s.note), style: TextStyle(color: scheme.primary)),
                  )
              else
                for (final (i, s) in plan.order.indexed)
                  ListTile(
                    key: Key('routeOrder-$i'),
                    leading: CircleAvatar(radius: 16, backgroundColor: scheme.primary, child: Text('${i + 1}', style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w700))),
                    title: Text(s.name),
                    subtitle: (s.note ?? '').isEmpty ? null : Text(_noteText(l, s.note)),
                  ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: plan == null
                ? FilledButton.icon(
                    key: const Key('routeBuild'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _picked.isEmpty || _busy ? null : _build,
                    icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.route_rounded),
                    label: Text(l.routeBuild(_picked.length)),
                  )
                : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    FilledButton.icon(
                      key: const Key('routeOpen'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      onPressed: () => _openYandex(plan.order),
                      icon: const Icon(Icons.navigation_rounded),
                      label: Text(l.routeOpenYandex),
                    ),
                    TextButton(onPressed: () => setState(() => _plan = null), child: Text(l.routeChange)),
                    if (_start == null) Text(l.routeNoStart, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                  ]),
          ),
        ]),
      ),
    );
  }
}
