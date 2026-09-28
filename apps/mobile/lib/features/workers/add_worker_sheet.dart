import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../team/team_repository.dart';

/// A link that was created but not opened yet.
class WorkerInvite {
  const WorkerInvite({required this.id, required this.fullName, required this.phone, this.url});
  final String id;
  final String fullName;
  final String phone;
  /// only in the create response: the raw link is never stored on the server
  final String? url;
  factory WorkerInvite.fromJson(Map<String, dynamic> j) =>
      WorkerInvite(id: j['id'] as String, fullName: j['fullName'] as String, phone: j['phone'] as String, url: j['url'] as String?);
}

final workerInvitesProvider = FutureProvider.autoDispose<List<WorkerInvite>>((ref) async {
  ref.listen(realtimeEventsProvider, (_, next) {
    if (next.value?.type.startsWith('worker.') ?? false) ref.invalidateSelf();
  });
  final j = await ref.watch(apiClientProvider).getJson('/workers/invitations');
  return ((j['items'] as List?) ?? const []).map((x) => WorkerInvite.fromJson((x as Map).cast<String, dynamic>())).toList();
});

/// «Добавить мастерицу»: name + phone (+ manager) -> a one-time Telegram link, shown as a big QR for in-person use.
/// She opens it and is ACTIVE at once — no questionnaire, no approval.
class AddWorkerSheet extends ConsumerStatefulWidget {
  const AddWorkerSheet({super.key});
  @override
  ConsumerState<AddWorkerSheet> createState() => _AddWorkerSheetState();
}

class _AddWorkerSheetState extends ConsumerState<AddWorkerSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController(text: '+998 ');
  String? _managerId;
  var _busy = false;
  WorkerInvite? _created;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().length >= 2 && _phone.text.replaceAll(RegExp(r'\D'), '').length >= 9;

  Future<void> _create() async {
    if (!_valid || _busy) return;
    setState(() => _busy = true);
    try {
      final j = await ref.read(apiClientProvider).postJson('/workers/invitations', body: {'fullName': _name.text.trim(), 'phone': _phone.text.trim(), 'managerId': _managerId});
      ref.invalidate(workerInvitesProvider);
      if (mounted) setState(() => _created = WorkerInvite.fromJson(j));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final canManager = ref.watch(authControllerProvider).value?.has('WORKER_ASSIGN_MANAGER') ?? false;
    final managers = canManager ? ref.watch(managersProvider).value ?? const [] : const [];
    final created = _created;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.addWorkerTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (created == null) ...[
            TextField(controller: _name, autofocus: true, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: l.addWorkerFullName), onChanged: (_) => setState(() {})),
            const SizedBox(height: 12),
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: l.phone, prefixIcon: const Icon(Icons.phone_rounded)), onChanged: (_) => setState(() {})),
            if (canManager && managers.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _managerId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.addWorkerManager),
                items: [
                  DropdownMenuItem<String?>(value: null, child: Text(l.addWorkerNoManager)),
                  for (final m in managers.where((m) => m.user.status == 'ACTIVE')) DropdownMenuItem<String?>(value: m.user.id, child: Text(m.user.fullName, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _managerId = v),
              ),
            ],
            const SizedBox(height: 12),
            Text(l.addWorkerHint, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            SizedBox(
              height: AppTokens.buttonHeight,
              child: FilledButton(
                onPressed: _valid && !_busy ? _create : null,
                child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l.addWorkerGetLink),
              ),
            ),
          ] else ...[
            Text(created.fullName, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Center(child: Container(color: Colors.white, padding: const EdgeInsets.all(8), child: QrImageView(data: created.url!, size: 220))),
            const SizedBox(height: 8),
            Text(l.addWorkerLinkReady, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: AppTokens.buttonHeight,
              child: FilledButton.icon(
                icon: const Icon(Icons.send_rounded),
                label: Text(l.addWorkerSendTelegram),
                onPressed: () => launchUrl(
                  Uri.parse('https://t.me/share/url?url=${Uri.encodeComponent(created.url!)}&text=${Uri.encodeComponent('Здравствуйте, ${created.fullName}! Вас добавили в Diamoraa — откройте ссылку.')}'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy_rounded),
              label: Text(l.addWorkerCopy),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: created.url!));
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(l.addWorkerCopied)));
                }
              },
            ),
          ],
        ]),
      ),
    );
  }
}

/// «Приглашены — ещё не открыли ссылку»: visible at a glance, cancellable.
class PendingInvitesCard extends ConsumerWidget {
  const PendingInvitesCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final invites = ref.watch(workerInvitesProvider).value ?? const [];
    if (invites.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.invitesPending, style: Theme.of(context).textTheme.titleSmall),
          for (final i in invites)
            Row(children: [
              const Icon(Icons.hourglass_top_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('${i.fullName} · ${i.phone}', overflow: TextOverflow.ellipsis)),
              TextButton(
                onPressed: () async {
                  try {
                    await ref.read(apiClientProvider).deleteJson('/workers/invitations/${i.id}');
                    ref.invalidate(workerInvitesProvider);
                  } catch (e) {
                    if (context.mounted) showError(context, e);
                  }
                },
                child: Text(l.inviteCancel),
              ),
            ]),
        ]),
      ),
    );
  }
}
