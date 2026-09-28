import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit_labels.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import 'team_repository.dart';

/// AUDIT_VIEW (§35): who changed what and when, in words. The SUPER_ADMIN can «Очистить журнал»: the screen starts over
/// (first line: who cleared it); the rows themselves are never deleted on the server, so nobody can hide what was done.
class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final entries = ref.watch(auditProvider);
    final isSuper = ref.watch(authControllerProvider).value?.isSuperAdmin ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(l.audit), actions: [
        if (isSuper)
          IconButton(key: const Key('auditClear'), tooltip: l.auditClear, icon: const Icon(Icons.delete_sweep_rounded), onPressed: () => _clear(context, ref)),
      ]),
      body: entries.when(
        loading: () => const SkeletonList(count: 8),
        error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: errorText(context, e)),
        data: (list) => list.isEmpty
            ? EmptyState(icon: Icons.receipt_long_rounded, title: l.auditEmpty)
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(auditProvider),
                child: ListView.separated(
                  padding: AppTokens.screenPadding.copyWith(top: 8, bottom: 24),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final e = list[i];
                    final at = DateTime.tryParse(e.createdAt)?.toLocal();
                    final when = at == null ? '' : '${at.day.toString().padLeft(2, '0')}.${at.month.toString().padLeft(2, '0')} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history_rounded),
                      title: Text(auditLabel(e.action), maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text([if (e.targetName != null) e.targetName!, e.actorName ?? e.actorRole ?? '—'].join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Text(when, style: Theme.of(context).textTheme.bodySmall),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    if (!await confirmDelete(context, title: l.auditClear, body: l.auditClearConfirm) || !context.mounted) return;
    try {
      await ref.read(teamRepositoryProvider).clearAudit();
      ref.invalidate(auditProvider);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}
