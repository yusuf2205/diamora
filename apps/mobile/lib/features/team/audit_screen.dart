import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import 'team_repository.dart';

/// AUDIT_VIEW (§35): every role/permission/manager/collateral/stock/payment/settings/pay-rate change lands here, and
/// nothing here can ever be edited or deleted (the server enforces it in the database itself).
class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final entries = ref.watch(auditProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.audit)),
      body: entries.when(
        loading: () => const SkeletonList(count: 8),
        error: (e, _) => EmptyState(icon: Icons.error_outline, title: errorText(context, e)),
        data: (list) => list.isEmpty
            ? EmptyState(icon: Icons.receipt_long_outlined, title: l.auditEmpty)
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(auditProvider),
                child: ListView.separated(
                  padding: AppTokens.screenPadding.copyWith(top: 8, bottom: 24),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final e = list[i];
                    final when = e.createdAt.length >= 16 ? e.createdAt.substring(0, 16).replaceFirst('T', ' ') : e.createdAt;
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.history),
                      title: Text(e.action),
                      subtitle: Text('${e.entity}${e.entityId != null ? ' #${e.entityId!.substring(0, 8)}' : ''} · ${e.actorRole ?? '—'}'),
                      trailing: Text(when, style: Theme.of(context).textTheme.bodySmall),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
