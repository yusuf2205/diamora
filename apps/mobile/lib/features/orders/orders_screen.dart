import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';

/// One customer order (mirrors OrdersService.dto on the API).
class ClientOrder {
  const ClientOrder({required this.id, required this.code, required this.name, required this.phone, required this.status, required this.source, this.product, this.colorName, this.quantity, this.comment, this.lines = const []});
  final String id, code, name, phone, status, source;
  final String? product, colorName, comment;
  final num? quantity;
  final List<(String, num?)> lines;

  factory ClientOrder.fromJson(Map<String, dynamic> j) => ClientOrder(
        id: j['id'] as String, code: j['code'] as String, name: j['name'] as String, phone: j['phone'] as String,
        status: j['status'] as String, source: (j['source'] as String?) ?? 'PANEL',
        product: (j['product'] as Map<String, dynamic>?)?['name'] as String?, colorName: j['colorName'] as String?,
        quantity: j['quantity'] as num?, comment: j['comment'] as String?,
        lines: [for (final l in (j['lines'] as List<dynamic>?) ?? const []) ((l as Map<String, dynamic>)['colorName'] as String, l['quantity'] as num?)],
      );
}

final clientOrdersProvider = FutureProvider.autoDispose.family<List<ClientOrder>, String>((ref, status) async {
  final j = await ref.watch(apiClientProvider).getJson('/admin/orders', query: {if (status.isNotEmpty) 'status': status});
  return [for (final o in j['items'] as List<dynamic>) ClientOrder.fromJson(o as Map<String, dynamic>)];
});

/// «Заказы клиентов» in the app (the notices about new orders open it): call the customer, one tap to the next step.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});
  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  var _status = 'NEW';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tabs = [('NEW', l.ordersNew), ('CONFIRMED', l.ordersConfirmed), ('IN_WORK', l.ordersInWork), ('DONE', l.ordersDone), ('CANCELLED', l.ordersCancelled), ('', l.ordersAll)];
    final async = ref.watch(clientOrdersProvider(_status));
    return Scaffold(
      appBar: AppBar(title: Text(l.ordersTitle)),
      body: Column(children: [
        SizedBox(
          height: 56,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), children: [
            for (final t in tabs)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(label: Text(t.$2), selected: _status == t.$1, onSelected: (_) => setState(() => _status = t.$1)),
              ),
          ]),
        ),
        Expanded(
          child: async.when(
            loading: () => const SkeletonList(count: 3),
            error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: errorText(context, e)),
            data: (items) => items.isEmpty
                ? EmptyState(icon: Icons.shopping_bag_outlined, title: l.ordersEmpty)
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(clientOrdersProvider(_status)),
                    child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [for (final o in items) _OrderCard(order: o, onChanged: () => ref.invalidate(clientOrdersProvider))]),
                  ),
          ),
        ),
      ]),
    );
  }
}

class _OrderCard extends ConsumerStatefulWidget {
  const _OrderCard({required this.order, required this.onChanged});
  final ClientOrder order;
  final VoidCallback onChanged;
  @override
  ConsumerState<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends ConsumerState<_OrderCard> {
  var _busy = false;

  Future<void> _set(String status) async {
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).patchJson('/admin/orders/${widget.order.id}', body: {'status': status});
      widget.onChanged();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final o = widget.order;
    final text = Theme.of(context).textTheme;
    final source = switch (o.source) { 'SITE' => '🌐 ${l.ordersFromSite}', 'BOT' => '✈️ ${l.ordersFromBot}', _ => '📞 ${l.ordersFromPanel}' };
    final next = switch (o.status) {
      'NEW' => ('CONFIRMED', l.ordersAccept, Icons.check_circle_rounded),
      'CONFIRMED' => ('IN_WORK', l.ordersStart, Icons.content_cut_rounded),
      'IN_WORK' => ('DONE', l.ordersFinish, Icons.celebration_rounded),
      _ => null,
    };
    String m(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${o.name} · ${o.code}', style: text.titleMedium),
          Text(source, style: text.bodySmall),
          const SizedBox(height: 6),
          Text(o.product ?? l.ordersNoItem, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (o.lines.isNotEmpty) ...[
            for (final x in o.lines) Text('• ${x.$1}${x.$2 != null ? ' — ${m(x.$2!)} м' : ''}'),
            if (o.quantity != null) Text(l.ordersTotal(m(o.quantity!)), style: const TextStyle(fontWeight: FontWeight.w600)),
          ] else if (o.colorName != null || o.quantity != null)
            Text([if (o.colorName != null) o.colorName!, if (o.quantity != null) '${m(o.quantity!)} м'].join(' · ')),
          if (o.comment?.isNotEmpty == true) ...[const SizedBox(height: 4), Text('«${o.comment}»', style: text.bodyMedium)],
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: FitButton(kind: FitKind.tonal, icon: Icons.call_rounded, label: o.phone, onPressed: () => launchUrl(Uri.parse('tel:${o.phone}')))),
            if (next != null) ...[
              const SizedBox(width: 8),
              Expanded(child: FitButton(kind: FitKind.filled, icon: next.$3, label: next.$2, onPressed: _busy ? null : () => _set(next.$1))),
            ],
          ]),
          if (o.status == 'NEW')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : () async {
                  final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                    title: Text(l.ordersCancelAsk),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.ordersCancel))],
                  ));
                  if (ok == true) await _set('CANCELLED');
                },
                child: Text(l.ordersCancel),
              ),
            ),
        ]),
      ),
    );
  }
}
