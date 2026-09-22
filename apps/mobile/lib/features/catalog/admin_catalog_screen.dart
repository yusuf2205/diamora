import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import 'catalog_repository.dart';
import 'models.dart';

/// ADMIN "Каталог работ" (§16): create, photograph, publish/hide. Everything lands on the NAS at once (D-022: this is a
/// critical write, never queued offline).
class AdminCatalogScreen extends ConsumerWidget {
  const AdminCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final items = ref.watch(staffCatalogProvider(const StaffCatalogFilter()));
    return Scaffold(
      appBar: AppBar(title: Text(l.catalogAdminTitle)),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _create(context, ref), icon: const Icon(Icons.add), label: Text(l.catalogAddItem)),
      body: items.when(
        loading: () => const SkeletonList(count: 5),
        error: (e, _) => EmptyState(icon: Icons.error_outline, title: errorText(context, e)),
        data: (list) => list.isEmpty
            ? EmptyState(icon: Icons.auto_awesome_outlined, title: l.catalogEmpty)
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(staffCatalogProvider(const StaffCatalogFilter())),
                child: ListView.separated(
                  padding: AppTokens.screenPadding.copyWith(top: 8, bottom: 88),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _Row(item: list[i]),
                ),
              ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.catalogAddItem),
        content: TextField(controller: controller, autofocus: true, decoration: InputDecoration(labelText: l.catalogItemName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: Text(l.save)),
        ],
      ),
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    try {
      final created = await ref.read(catalogRepositoryProvider).create(name);
      ref.invalidate(staffCatalogProvider(const StaffCatalogFilter()));
      if (context.mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminCatalogDetailScreen(itemId: created.id)));
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item});
  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest, backgroundImage: item.mainPhoto != null ? NetworkImage(item.mainPhoto!.thumbUrl ?? item.mainPhoto!.url) : null, child: item.mainPhoto == null ? const Icon(Icons.image_outlined) : null),
        title: Text(item.name),
        subtitle: Text(_statusLabel(l, item.status)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminCatalogDetailScreen(itemId: item.id))),
      ),
    );
  }

  String _statusLabel(AppLocalizations l, String? s) => switch (s) {
        'PUBLISHED' => l.catalogStatusPublished,
        'HIDDEN' => l.catalogStatusHidden,
        _ => l.catalogStatusDraft,
      };
}

class AdminCatalogDetailScreen extends ConsumerStatefulWidget {
  const AdminCatalogDetailScreen({super.key, required this.itemId});
  final String itemId;
  @override
  ConsumerState<AdminCatalogDetailScreen> createState() => _AdminCatalogDetailScreenState();
}

class _AdminCatalogDetailScreenState extends ConsumerState<AdminCatalogDetailScreen> {
  bool _busy = false;

  Future<void> _addPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000);
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(catalogRepositoryProvider).addMedia(widget.itemId, await picked.readAsBytes(), picked.name);
      ref.invalidate(staffCatalogItemProvider(widget.itemId));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _togglePublish(CatalogItem item) async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      if (item.status == 'PUBLISHED') {
        await ref.read(catalogRepositoryProvider).hide(widget.itemId);
      } else {
        await ref.read(catalogRepositoryProvider).publish(widget.itemId);
      }
      ref.invalidate(staffCatalogItemProvider(widget.itemId));
      ref.invalidate(staffCatalogProvider(const StaffCatalogFilter()));
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('409') ? l.catalogPublishNeedsPhoto : null;
        showError(context, msg ?? e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final item = ref.watch(staffCatalogItemProvider(widget.itemId));
    return Scaffold(
      appBar: AppBar(title: Text(l.catalogAdminTitle)),
      body: item.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(icon: Icons.error_outline, title: errorText(context, e)),
        data: (i) => ListView(padding: AppTokens.screenPadding.copyWith(top: 16, bottom: 24), children: [
          Text(i.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          if (i.media.isNotEmpty)
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: i.media.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, idx) {
                  final m = i.media[idx];
                  return Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTokens.radius),
                      child: m.file != null
                          ? Image.network(m.file!.thumbUrl ?? m.file!.url, width: 120, height: 120, fit: BoxFit.cover)
                          : Container(width: 120, height: 120, color: Colors.black12, child: const Icon(Icons.movie_outlined)),
                    ),
                    if (m.isMain) Positioned(top: 4, left: 4, child: Icon(Icons.star, color: Theme.of(context).colorScheme.primary)),
                  ]);
                },
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _busy ? null : _addPhoto, icon: const Icon(Icons.add_a_photo_outlined), label: Text(l.catalogAddPhoto)),
          const SizedBox(height: 20),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.catalogMarkNew),
            value: i.isNew,
            onChanged: _busy ? null : (v) async {
              setState(() => _busy = true);
              try {
                await ref.read(catalogRepositoryProvider).update(widget.itemId, isNew: v);
                ref.invalidate(staffCatalogItemProvider(widget.itemId));
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : () => _togglePublish(i),
            child: Text(i.status == 'PUBLISHED' ? l.catalogHide : l.catalogPublish),
          ),
        ]),
      ),
    );
  }
}
