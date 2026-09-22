import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../settings/company_contact.dart';
import 'catalog_repository.dart';
import 'models.dart';

/// WORKER default screen ("Наши работы", §10-11): a beautiful, informational catalog. No prices, no cart, no checkout.
class WorkerCatalogScreen extends ConsumerWidget {
  const WorkerCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final items = ref.watch(publishedCatalogProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.catalog)),
      body: Column(children: [
        const ConnectionBanner(),
        Expanded(
          child: items.when(
            loading: () => const SkeletonList(count: 6),
            error: (e, _) => EmptyState(icon: Icons.error_outline, title: errorText(context, e)),
            data: (list) => list.isEmpty
                ? EmptyState(icon: Icons.auto_awesome_outlined, title: l.catalogEmpty, hint: l.catalogEmptyHint)
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(publishedCatalogProvider),
                    child: GridView.builder(
                      padding: AppTokens.screenPadding.copyWith(top: 12, bottom: 24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.72),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _CatalogCard(item: list[i]),
                    ),
                  ),
          ),
        ),
      ]),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({required this.item});
  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CatalogItemDetailScreen(itemId: item.id))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              item.mainPhoto != null
                  ? Image(image: CachedNetworkImageProvider(item.mainPhoto!.thumbUrl ?? item.mainPhoto!.url), fit: BoxFit.cover)
                  : Container(color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Icon(Icons.image_outlined, size: 40)),
              if (item.isNew)
                Positioned(
                  top: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(8)),
                    child: Text(l.catalogNew, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
              if (item.colors.isNotEmpty) Text(item.colors.map((c) => c.name).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ]),
      ),
    );
  }
}

class CatalogItemDetailScreen extends ConsumerWidget {
  const CatalogItemDetailScreen({super.key, required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final item = ref.watch(publishedItemProvider(itemId));
    final contact = ref.watch(companyContactProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.catalog)),
      body: item.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(icon: Icons.error_outline, title: errorText(context, e)),
        data: (i) => ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          if (i.media.isNotEmpty)
            SizedBox(
              height: 320,
              child: PageView(children: [
                for (final m in i.media)
                  m.isVideo
                      ? Container(color: Colors.black, child: const Center(child: Icon(Icons.play_circle_outline, color: Colors.white, size: 56)))
                      : (m.file != null ? Image(image: CachedNetworkImageProvider(m.file!.url), fit: BoxFit.cover) : const ColoredBox(color: Colors.black12)),
              ]),
            ),
          Padding(
            padding: AppTokens.screenPadding.copyWith(top: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(i.name, style: Theme.of(context).textTheme.headlineSmall)),
                if (i.isNew) Chip(label: Text(l.catalogNew)),
              ]),
              const SizedBox(height: 4),
              Text(_availabilityLabel(l, i.availability), style: Theme.of(context).textTheme.labelLarge),
              if (i.variants.any((v) => v.color != null)) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, children: [for (final v in i.variants) if (v.color != null) Chip(label: Text(v.label != null && v.label!.isNotEmpty ? '${v.color!.name} · ${v.label}' : v.color!.name))]),
              ],
              if ((i.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(i.description!, style: Theme.of(context).textTheme.bodyMedium),
              ],
              const SizedBox(height: 24),
              contact.maybeWhen(
                data: (c) => Row(children: [
                  if ((c.phone ?? '').isNotEmpty)
                    Expanded(child: OutlinedButton.icon(onPressed: () => launchUrl(Uri.parse('tel:${c.phone}')), icon: const Icon(Icons.call_outlined), label: Text(l.catalogCall))),
                  if ((c.phone ?? '').isNotEmpty && (c.telegramUrl ?? '').isNotEmpty) const SizedBox(width: 12),
                  if ((c.telegramUrl ?? '').isNotEmpty)
                    Expanded(child: FilledButton.icon(onPressed: () => _openTelegram(c.telegramUrl!), icon: const Icon(Icons.send_outlined), label: Text(l.catalogTelegram))),
                ]),
                orElse: () => const SizedBox.shrink(),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  String _availabilityLabel(AppLocalizations l, String a) => switch (a) {
        'ON_REQUEST' => l.catalogOnRequest,
        'UNAVAILABLE' => l.catalogUnavailable,
        _ => l.catalogAvailable,
      };

  Future<void> _openTelegram(String url) async {
    final appUri = Uri.parse(url.replaceFirst('https://t.me/', 'tg://resolve?domain='));
    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
    } else {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}
