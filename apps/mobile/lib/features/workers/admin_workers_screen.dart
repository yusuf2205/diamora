import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../work/deliveries_screen.dart';
import 'add_worker_sheet.dart';
import 'models.dart';
import 'workers_providers.dart';
import 'assign_manager_screen.dart';

/// ADMIN: registrations waiting for a decision, active workers, everyone. New registrations appear in realtime.
class AdminWorkersScreen extends ConsumerStatefulWidget {
  const AdminWorkersScreen({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  ConsumerState<AdminWorkersScreen> createState() => _AdminWorkersScreenState();
}

class _AdminWorkersScreenState extends ConsumerState<AdminWorkersScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
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
    final me = ref.watch(authControllerProvider).value;
    // a manager adds a new worker on the spot too (an admin approves her afterwards)
    final canInvite = (me?.has('WORKER_APPROVE') ?? false) || me?.role == 'MANAGER';
    return Scaffold(
      // a round button like Telegram's ✎: a wide one covered the list's own message on a short screen
      floatingActionButton: canInvite
          ? FloatingActionButton(
              key: const Key('addWorkerFab'),
              tooltip: l.addWorker,
              onPressed: () => showAddWorkerSheet(context),
              child: const Icon(Icons.person_add_alt_1_rounded),
            )
          : null,
      appBar: AppBar(
        title: Text(l.workers),
        actions: barActions(context, keep: 2, [
          BarAction(icon: Icons.local_shipping_rounded, label: l.deliveryNeeded, onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DeliveriesScreen()))),
          BarAction(icon: Icons.qr_code_scanner_rounded, label: l.qrScan, onTap: () => context.push('/admin/qr-scan')),
          if (ref.watch(authControllerProvider).value?.has('WORKER_ASSIGN_MANAGER') ?? false)
            BarAction(key: const Key('assignManagerOpen'), icon: Icons.manage_accounts_rounded, label: l.assignManagerTitle,
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AssignManagerScreen()))),
        ]),
        bottom: TabBar(controller: _tabs, tabs: [Tab(text: l.tabPending), Tab(text: l.tabActive), Tab(text: l.tabAll)]),
      ),
      body: Column(children: [
        const ConnectionBanner(),
        if (canInvite) const PendingInvitesCard(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SearchBar(hintText: l.search, leading: const Icon(Icons.search_rounded), onChanged: (v) => setState(() => _query = v), elevation: const WidgetStatePropertyAll(0)),
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
        error: (e, _) => ListView(children: [EmptyState(icon: Icons.error_outline_rounded, title: errorText(context, e))]),
        data: (items) => items.isEmpty
            ? ListView(padding: const EdgeInsets.only(bottom: 96), children: [
                SizedBox(
                  height: 320,
                  child: EmptyState(
                    icon: emptyPending ? Icons.telegram_rounded : Icons.groups_rounded,
                    title: emptyPending ? l.emptyPending : l.emptyWorkers,
                    hint: emptyPending ? l.emptyPendingHint : null,
                  ),
                ),
              ])
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), // the last card never under the round button
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
    final narrow = MediaQuery.sizeOf(context).width < 400;
    return Card(
      child: ListTile(
        onTap: () => context.push('/admin/workers/${worker.id}'),
        leading: CircleAvatar(backgroundColor: worker.isPending ? scheme.tertiaryContainer : scheme.primaryContainer, child: Text(initials(worker.fullName))),
        title: Text(worker.fullName, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        // a narrow phone: the status goes into the lines below instead of squeezing the name into three lines
        subtitle: Text(
          [
            [worker.code, if (narrow) status].join(' · '),
            [worker.phone, if (c != null) (c.isMoney ? '${formatUzs(c.amount)} ${l.currency}' : (c.description ?? ''))].where((s) => s.isNotEmpty).join(' · '),
          ].join('\n'),
          maxLines: 2, overflow: TextOverflow.ellipsis,
        ),
        trailing: narrow ? null : Text(status, style: TextStyle(color: worker.isPending ? scheme.tertiary : scheme.outline, fontSize: 12)),
      ),
    );
  }
}
