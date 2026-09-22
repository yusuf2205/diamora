import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../catalog/catalog_repository.dart';
import '../catalog/models.dart';
import '../inventory/inventory_repository.dart';
import '../settings/pay_rate.dart';
import '../workers/models.dart';
import '../workers/workers_providers.dart';
import 'assignment_admin_repository.dart';

/// M3 §4: "Выдать работу" — a short, guided flow instead of a form full of technical fields. A MANAGER only ever sees
/// her own workers in the picker (the same server-scoped list as everywhere else); the server re-validates everything
/// regardless of what the client shows.
class CreateAssignmentScreen extends ConsumerStatefulWidget {
  const CreateAssignmentScreen({super.key, this.workerId});
  final String? workerId;
  @override
  ConsumerState<CreateAssignmentScreen> createState() => _CreateAssignmentScreenState();
}

class _CreateAssignmentScreenState extends ConsumerState<CreateAssignmentScreen> {
  late int _step = widget.workerId != null ? 1 : 0;
  Worker? _worker;
  CatalogItem? _product;
  CatalogVariant? _variant;
  int? _kitCount; // 1=9m, 2=18m, 3=27m
  DateTime? _dueDate;
  final _comment = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  int get _lastStep => 5;

  bool get _canGoNext => switch (_step) {
        0 => _worker != null,
        1 => _product != null,
        2 => _variant != null,
        3 => _kitCount != null,
        _ => true,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (widget.workerId != null && _worker == null) {
      final w = ref.watch(workerDetailProvider(widget.workerId!));
      w.whenData((worker) => WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _worker = worker);
          }));
    }
    final title = switch (_step) {
      0 => l.assignSelectWorker,
      1 => l.assignStepProduct,
      2 => l.assignStepVariant,
      3 => l.assignStepVolume,
      4 => l.assignStepDue,
      _ => l.assignStepSummary,
    };
    return Scaffold(
      appBar: AppBar(title: Text(title), leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop())),
      body: SafeArea(
        child: Column(children: [
          _StepDots(step: _step, total: _lastStep + 1),
          Expanded(child: _busy ? const Center(child: CircularProgressIndicator()) : _buildStep(l)),
        ]),
      ),
      bottomNavigationBar: _busy
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  if (_step > (widget.workerId != null ? 1 : 0))
                    Expanded(child: OutlinedButton(onPressed: () => setState(() => _step--), child: Text(l.back))),
                  if (_step > (widget.workerId != null ? 1 : 0)) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: !_canGoNext
                          ? null
                          : _step == _lastStep
                              ? _submit
                              : () => setState(() => _step++),
                      child: Text(_step == _lastStep ? l.assignSubmit : l.next),
                    ),
                  ),
                ]),
              ),
            ),
    );
  }

  Widget _buildStep(AppLocalizations l) {
    switch (_step) {
      case 0:
        return _WorkerPicker(selected: _worker, onSelected: (w) => setState(() => _worker = w));
      case 1:
        return _ProductPicker(selected: _product, onSelected: (p) => setState(() {
              _product = p;
              _variant = null;
              _kitCount = null;
            }));
      case 2:
        return _VariantPicker(product: _product!, selected: _variant, onSelected: (v) => setState(() {
              _variant = v;
              _kitCount = null;
            }));
      case 3:
        return _VolumePicker(selected: _kitCount, onSelected: (c) => setState(() => _kitCount = c));
      case 4:
        return _DueAndComment(due: _dueDate, comment: _comment, onDueChanged: (d) => setState(() => _dueDate = d));
      default:
        return _Summary(worker: _worker!, product: _product!, variant: _variant!, kitCount: _kitCount!, dueDate: _dueDate, comment: _comment.text);
    }
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final kits = await ref.read(inventoryRepositoryProvider).kits();
      final matches = kits.where((k) => k.active && (k.variantId == null || k.variantId == _variant!.id)).toList();
      if (matches.isEmpty) {
        if (mounted) showError(context, ApiException(code: 'NO_KIT', message: l.assignNoKitTemplate));
        return;
      }
      final kit = matches.first;
      final result = await ref.read(assignmentAdminRepositoryProvider).create(
            workerId: _worker!.id, productModelId: _product!.id, productVariantId: _variant!.id, colorId: _variant!.color!.id,
            materialKitTemplateId: kit.id, kitCount: _kitCount!, dueAt: _dueDate, notes: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
          );
      if (!mounted) return;
      context.pop();
      context.push('/admin/assignments/${result.id}');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.assignSuccess)));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'INSUFFICIENT_STOCK') {
        final materialId = (e.details is Map) ? (e.details as Map)['materialId'] as String? : null;
        final kits = await ref.read(inventoryRepositoryProvider).kits();
        String? name;
        for (final k in kits) {
          final item = k.items.where((i) => i.materialId == materialId).firstOrNull;
          if (item != null) { name = item.materialName; break; }
        }
        if (mounted) showError(context, ApiException(code: e.code, message: name != null ? l.insufficientStockDetail(name) : l.insufficientStockGeneric));
      } else {
        if (mounted) showError(context, e);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.step, required this.total});
  final int step;
  final int total;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < total; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == step ? 22 : 8, height: 8,
            decoration: BoxDecoration(color: i <= step ? scheme.primary : scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
          ),
      ]),
    );
  }
}

class _WorkerPicker extends ConsumerWidget {
  const _WorkerPicker({required this.selected, required this.onSelected});
  final Worker? selected;
  final ValueChanged<Worker> onSelected;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final workers = ref.watch(workersListProvider(const WorkersFilter(status: 'ACTIVE')));
    return workers.when(
      loading: () => const SkeletonList(count: 5),
      error: (e, _) => EmptyState(icon: Icons.error_outline, title: errorText(context, e)),
      data: (items) => items.isEmpty
          ? EmptyState(icon: Icons.person_off_outlined, title: l.assignEmptyWorkers)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final w = items[i];
                final sel = selected?.id == w.id;
                return _SelectCard(selected: sel, onTap: () => onSelected(w), title: w.fullName, subtitle: w.phone, leading: const Icon(Icons.person_outline));
              },
            ),
    );
  }
}

class _ProductPicker extends ConsumerWidget {
  const _ProductPicker({required this.selected, required this.onSelected});
  final CatalogItem? selected;
  final ValueChanged<CatalogItem> onSelected;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final items = ref.watch(staffCatalogProvider(const StaffCatalogFilter()));
    return items.when(
      loading: () => const SkeletonList(count: 5),
      error: (e, _) => EmptyState(icon: Icons.error_outline, title: errorText(context, e)),
      data: (models) => models.isEmpty
          ? EmptyState(icon: Icons.auto_awesome_outlined, title: l.assignEmptyProducts)
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.85),
              itemCount: models.length,
              itemBuilder: (_, i) {
                final m = models[i];
                final sel = selected?.id == m.id;
                return _ProductCard(item: m, selected: sel, onTap: () => onSelected(m));
              },
            ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.item, required this.selected, required this.onTap});
  final CatalogItem item;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
          color: selected ? scheme.primaryContainer.withValues(alpha: 0.3) : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: item.mainPhoto != null
                ? Image.network(item.mainPhoto!.thumbUrl ?? item.mainPhoto!.url, fit: BoxFit.cover)
                : ColoredBox(color: scheme.surfaceContainerHighest, child: Icon(Icons.auto_awesome_outlined, color: scheme.outline, size: 32)),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

class _VariantPicker extends StatelessWidget {
  const _VariantPicker({required this.product, required this.selected, required this.onSelected});
  final CatalogItem product;
  final CatalogVariant? selected;
  final ValueChanged<CatalogVariant> onSelected;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final variants = product.variants.where((v) => v.active && v.color != null).toList();
    if (variants.isEmpty) return EmptyState(icon: Icons.palette_outlined, title: l.assignNoVariants);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: variants.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final v = variants[i];
        final sel = selected?.id == v.id;
        final color = _hexColor(v.color?.hex);
        return _SelectCard(
          selected: sel, onTap: () => onSelected(v),
          title: v.label?.isNotEmpty == true ? '${v.color!.name} · ${v.label}' : v.color!.name,
          leading: Container(width: 28, height: 28, decoration: BoxDecoration(color: color ?? Theme.of(context).colorScheme.outline, shape: BoxShape.circle)),
        );
      },
    );
  }

  Color? _hexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }
}

class _VolumePicker extends StatelessWidget {
  const _VolumePicker({required this.selected, required this.onSelected});
  final int? selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final options = [(1, l.workMeters9), (2, l.workMeters18), (3, l.workMeters27)];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        for (final (count, label) in options) ...[
          _VolumeCard(count: count, label: label, selected: selected == count, onTap: () => onSelected(count)),
          const SizedBox(height: 12),
        ],
      ]),
    );
  }
}

class _VolumeCard extends StatelessWidget {
  const _VolumeCard({required this.count, required this.label, required this.selected, required this.onTap});
  final int count;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
          color: selected ? scheme.primaryContainer.withValues(alpha: 0.3) : null,
        ),
        child: Center(child: Text(label, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: selected ? scheme.primary : null))),
      ),
    );
  }
}

class _DueAndComment extends StatelessWidget {
  const _DueAndComment({required this.due, required this.comment, required this.onDueChanged});
  final DateTime? due;
  final TextEditingController comment;
  final ValueChanged<DateTime?> onDueChanged;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(l.assignDueOptional, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.event_outlined),
        onPressed: () async {
          final picked = await showDatePicker(context: context, initialDate: due ?? DateTime.now().add(const Duration(days: 3)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
          onDueChanged(picked);
        },
        label: Text(due == null ? l.assignNoDueDate : '${due!.day.toString().padLeft(2, '0')}.${due!.month.toString().padLeft(2, '0')}.${due!.year}'),
      ),
      const SizedBox(height: 24),
      Text(l.assignStepComment, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      TextField(controller: comment, maxLines: 3, decoration: InputDecoration(hintText: l.commentOptional, border: const OutlineInputBorder())),
    ]);
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({required this.worker, required this.product, required this.variant, required this.kitCount, required this.dueDate, required this.comment});
  final Worker worker;
  final CatalogItem product;
  final CatalogVariant variant;
  final int kitCount;
  final DateTime? dueDate;
  final String comment;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final meters = kitCount * 9;
    final rate = ref.watch(payRateProvider).value;
    final ratePerKit = rate != null ? int.tryParse(rate.ratePerKit) : null;
    final expected = ratePerKit != null ? ratePerKit * kitCount : null;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SummaryRow(label: l.assignSummaryWorker, value: worker.fullName),
            _SummaryRow(label: l.assignSummaryModel, value: product.name),
            _SummaryRow(label: l.assignSummaryColor, value: variant.color!.name),
            _SummaryRow(label: l.assignSummaryVolume, value: '$meters м'),
            if (dueDate != null) _SummaryRow(label: l.assignSummaryDue, value: '${dueDate!.day.toString().padLeft(2, '0')}.${dueDate!.month.toString().padLeft(2, '0')}.${dueDate!.year}'),
            if (expected != null) _SummaryRow(label: l.assignSummaryPayment, value: '${formatUzs(expected.toString())} ${l.currency}'),
            if (comment.trim().isNotEmpty) _SummaryRow(label: l.assignStepComment, value: comment.trim()),
          ]),
        ),
      ),
    ]);
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 130, child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
        ]),
      );
}

class _SelectCard extends StatelessWidget {
  const _SelectCard({required this.selected, required this.onTap, required this.title, this.subtitle, this.leading});
  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String? subtitle;
  final Widget? leading;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
          color: selected ? scheme.primaryContainer.withValues(alpha: 0.3) : null,
        ),
        child: Row(children: [
          if (leading != null) ...[leading!, const SizedBox(width: 14)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              if (subtitle != null) Text(subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ]),
          ),
          if (selected) Icon(Icons.check_circle, color: scheme.primary),
        ]),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
