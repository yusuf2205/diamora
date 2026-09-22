import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import 'inventory_repository.dart';
import 'models.dart';

/// Materials / Stock / 9 m Kit templates (M2 §5-9, §31): SUPER_ADMIN and an ADMIN/MANAGER with `INVENTORY_MANAGE` can
/// record a receipt and assemble kits; `INVENTORY_VIEW` alone is read-only, matching the server exactly (every write
/// below is refused server-side for a viewer even if this screen's FAB were somehow reachable).
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});
  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this);
  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final me = ref.watch(authControllerProvider).value;
    if (me == null || !me.has('INVENTORY_VIEW')) {
      return Scaffold(appBar: AppBar(title: Text(l.inventory)), body: EmptyState(icon: Icons.lock_outline, title: l.teamNoAccess));
    }
    final canManage = me.has('INVENTORY_MANAGE');
    return Scaffold(
      appBar: AppBar(
        title: Text(l.inventory),
        actions: [IconButton(icon: const Icon(Icons.qr_code_scanner), tooltip: l.qrScan, onPressed: () => context.push('/admin/qr-scan'))],
        bottom: TabBar(controller: _tabs, tabs: [Tab(text: l.materials), Tab(text: l.kits)]),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(onPressed: () => _tabs.index == 0 ? _materialActions(context) : _createKitDialog(context), child: const Icon(Icons.add))
          : null,
      body: TabBarView(controller: _tabs, children: [_MaterialsTab(canManage: canManage), _KitsTab(canManage: canManage)]),
    );
  }

  Future<void> _materialActions(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.add_box_outlined), title: Text(l.materialAdd), onTap: () => Navigator.of(ctx).pop('new')),
          ListTile(leading: const Icon(Icons.move_to_inbox_outlined), title: Text(l.stockReceipt), onTap: () => Navigator.of(ctx).pop('receipt')),
        ]),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'new':
        await _newMaterialDialog(context);
      case 'receipt':
        await _receiptDialog(context);
    }
  }

  Future<void> _newMaterialDialog(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final categories = await ref.read(materialCategoriesProvider.future);
    if (!context.mounted) return;
    final name = TextEditingController();
    final minStock = TextEditingController(text: '0');
    String? categoryId = categories.isEmpty ? null : categories.first.id;
    String unit = 'PCS';
    const units = ['METER', 'GRAM', 'PCS', 'SET', 'ROLL', 'PACKAGE'];
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setState) => AlertDialog(
          title: Text(l.materialAdd),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: InputDecoration(labelText: l.materialName)),
            const SizedBox(height: 8),
            if (categories.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: categoryId,
                items: [for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
                onChanged: (v) => setState(() => categoryId = v),
              ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: unit,
              items: [for (final u in units) DropdownMenuItem(value: u, child: Text(u))],
              onChanged: (v) => setState(() => unit = v ?? unit),
            ),
            const SizedBox(height: 8),
            TextField(controller: minStock, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: l.materialMinStock)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.of(dCtx).pop(true), child: Text(l.save)),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(inventoryRepositoryProvider).createMaterial(name: name.text.trim(), categoryId: categoryId, unit: unit, minStock: minStock.text.trim());
      ref.invalidate(materialsProvider);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _receiptDialog(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final materials = await ref.read(materialsProvider.future);
    if (!context.mounted || materials.isEmpty) return;
    String materialId = materials.first.id;
    final qty = TextEditingController();
    final comment = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setState) => AlertDialog(
          title: Text(l.stockReceipt),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l.stockReceiptHint, style: Theme.of(dCtx).textTheme.bodySmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: materialId,
              isExpanded: true,
              items: [for (final m in materials) DropdownMenuItem(value: m.id, child: Text('${m.name} (${m.unit})', overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() => materialId = v ?? materialId),
            ),
            const SizedBox(height: 8),
            TextField(controller: qty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: l.quantity)),
            const SizedBox(height: 8),
            TextField(controller: comment, decoration: InputDecoration(labelText: l.commentOptional)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.of(dCtx).pop(true), child: Text(l.save)),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(inventoryRepositoryProvider).receipt(materialId: materialId, quantity: qty.text.trim(), comment: comment.text.trim().isEmpty ? null : comment.text.trim());
      ref.invalidate(materialsProvider);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _createKitDialog(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final materials = await ref.read(materialsProvider.future);
    if (!context.mounted || materials.isEmpty) return;
    final name = TextEditingController();
    final rows = <(String materialId, TextEditingController qty)>[(materials.first.id, TextEditingController())];
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setState) => AlertDialog(
          title: Text(l.kitAssemble),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: name, decoration: InputDecoration(labelText: l.kitTemplateName)),
                const SizedBox(height: 8),
                for (var i = 0; i < rows.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: rows[i].$1,
                          isExpanded: true,
                          items: [for (final m in materials) DropdownMenuItem(value: m.id, child: Text(m.name, overflow: TextOverflow.ellipsis))],
                          onChanged: (v) => setState(() => rows[i] = (v ?? rows[i].$1, rows[i].$2)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(width: 80, child: TextField(controller: rows[i].$2, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: l.quantity))),
                      IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: rows.length > 1 ? () => setState(() => rows.removeAt(i)) : null),
                    ]),
                  ),
                Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => setState(() => rows.add((materials.first.id, TextEditingController()))), icon: const Icon(Icons.add), label: Text(l.kitAddMaterial))),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.of(dCtx).pop(true), child: Text(l.save)),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(inventoryRepositoryProvider).createKit(
            name: name.text.trim(),
            items: [for (final r in rows) if (r.$2.text.trim().isNotEmpty) {'materialId': r.$1, 'requiredQuantity': r.$2.text.trim()}],
          );
      ref.invalidate(kitTemplatesProvider);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}

class _MaterialsTab extends ConsumerWidget {
  const _MaterialsTab({required this.canManage});
  final bool canManage;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(materialsProvider);
    return async.when(
      loading: () => const SkeletonList(),
      error: (e, _) => EmptyState(icon: Icons.error_outline, title: errorText(context, e)),
      data: (items) => items.isEmpty
          ? EmptyState(icon: Icons.inventory_2_outlined, title: l.materialsEmpty)
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(materialsProvider),
              child: ListView.separated(
                padding: AppTokens.screenPadding.copyWith(top: 8, bottom: 88),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final m = items[i];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: m.low ? Theme.of(context).colorScheme.errorContainer : Theme.of(context).colorScheme.primaryContainer, child: const Icon(Icons.inventory_2_outlined)),
                      title: Text(m.name),
                      subtitle: Text([if (m.categoryName != null) m.categoryName!, m.unit].join(' · ')),
                      trailing: Text('${m.balance} ${m.unit}${m.low ? ' · ${l.stockLow}' : ''}', style: TextStyle(color: m.low ? Theme.of(context).colorScheme.error : null, fontWeight: m.low ? FontWeight.w600 : null)),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _KitsTab extends ConsumerWidget {
  const _KitsTab({required this.canManage});
  final bool canManage;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(kitTemplatesProvider);
    return async.when(
      loading: () => const SkeletonList(),
      error: (e, _) => EmptyState(icon: Icons.error_outline, title: errorText(context, e)),
      data: (items) => items.isEmpty
          ? EmptyState(icon: Icons.style_outlined, title: l.kitsEmpty)
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(kitTemplatesProvider),
              child: ListView.separated(
                padding: AppTokens.screenPadding.copyWith(top: 8, bottom: 88),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final t = items[i];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.style_outlined)),
                      title: Text(t.name),
                      subtitle: Text('${t.ribbonMeters.toStringAsFixed(0)} м · ${t.items.length} материалов'),
                      trailing: canManage ? FilledButton.tonal(onPressed: () => _assemble(context, ref, t), child: Text(l.kitAssemble)) : null,
                    ),
                  );
                },
              ),
            ),
    );
  }

  Future<void> _assemble(BuildContext context, WidgetRef ref, KitTemplate t) async {
    final l = AppLocalizations.of(context);
    final count = TextEditingController(text: '1');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(t.name),
        content: TextField(controller: count, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.kitCount)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.of(dCtx).pop(true), child: Text(l.kitAssemble)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final result = await ref.read(inventoryRepositoryProvider).assembleKit(t.id, int.tryParse(count.text.trim()) ?? 1);
      ref.invalidate(kitTemplatesProvider);
      ref.invalidate(materialsProvider);
      if (context.mounted) await _showQr(context, l, result);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _showQr(BuildContext context, AppLocalizations l, KitAssembled result) => showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(l.kitAssembled, style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('${result.kitTemplateName} × ${result.count} = ${result.totalMeters} м'),
              const SizedBox(height: 16),
              QrImageView(data: result.qrCode, size: 200),
              const SizedBox(height: 8),
              SelectableText(result.qrCode, style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(l.confirm))),
            ]),
          ),
        ),
      );
}
