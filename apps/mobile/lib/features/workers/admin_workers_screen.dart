import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../work/deliveries_screen.dart';
import 'models.dart';
import 'workers_providers.dart';

/// ADMIN: registrations waiting for a decision, active workers, everyone. New registrations appear in realtime.
class AdminWorkersScreen extends ConsumerStatefulWidget {
  const AdminWorkersScreen({super.key});
  @override
  ConsumerState<AdminWorkersScreen> createState() => _AdminWorkersScreenState();
}

class _AdminWorkersScreenState extends ConsumerState<AdminWorkersScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  String _query = '';

  static const _statusOfTab = ['PENDING_APPROVAL', 'ACTIVE', null];

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.workers),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_shipping_outlined),
            tooltip: l.deliveryNeeded,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DeliveriesScreen())),
          ),
          IconButton(icon: const Icon(Icons.qr_code_scanner), tooltip: l.qrScan, onPressed: () => context.push('/admin/qr-scan')),
        ],
        bottom: TabBar(controller: _tabs, tabs: [Tab(text: l.tabPending), Tab(text: l.tabActive), Tab(text: l.tabAll)]),
      ),
      body: Column(children: [
        const ConnectionBanner(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SearchBar(hintText: l.search, leading: const Icon(Icons.search), onChanged: (v) => setState(() => _query = v), elevation: const WidgetStatePropertyAll(0)),
        ),
        Expanded(
          child: TabBarView(controller: _tabs, children: [
            for (var i = 0; i < 3; i++) _WorkersList(filter: WorkersFilter(status: _statusOfTab[i], query: _query), emptyPending: i == 0),
          ]),
        ),
      ]),
    );
  }
}

class _WorkersList extends ConsumerWidget {
  const _WorkersList({required this.filter, required this.emptyPending});
  final WorkersFilter filter;
  final bool emptyPending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(workersListProvider(filter));
    return RefreshIndicator(
      onRefresh: () => ref.read(workerRepositoryProvider).refresh(full: true),
      child: async.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ListView(children: [EmptyState(icon: Icons.error_outline, title: errorText(context, e))]),
        data: (items) => items.isEmpty
            ? ListView(children: [
                SizedBox(
                  height: 320,
                  child: EmptyState(
                    icon: emptyPending ? Icons.telegram : Icons.groups_outlined,
                    title: emptyPending ? l.emptyPending : l.emptyWorkers,
                    hint: emptyPending ? l.emptyPendingHint : null,
                  ),
                ),
              ])
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _WorkerTile(worker: items[i]),
              ),
      ),
    );
  }
}

class _WorkerTile extends StatelessWidget {
  const _WorkerTile({required this.worker});
  final Worker worker;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final c = worker.collateral;
    final status = switch (worker.status) {
      'PENDING_APPROVAL' => l.statusPending,
      'ACTIVE' => l.statusActive,
      'PAUSED' => l.statusPaused,
      'REJECTED' => l.statusRejected,
      _ => l.statusArchived,
    };
    return Card(
      child: ListTile(
        onTap: () => context.push('/admin/workers/${worker.id}'),
        leading: CircleAvatar(backgroundColor: worker.isPending ? scheme.tertiaryContainer : scheme.primaryContainer, child: Text(initials(worker.fullName))),
        title: Text(worker.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text([worker.code, worker.phone, if (c != null) (c.isMoney ? '${formatUzs(c.amount)} ${l.currency}' : (c.description ?? ''))].where((s) => s.isNotEmpty).join(' · ')),
        trailing: Text(status, style: TextStyle(color: worker.isPending ? scheme.tertiary : scheme.outline, fontSize: 12)),
      ),
    );
  }
}
