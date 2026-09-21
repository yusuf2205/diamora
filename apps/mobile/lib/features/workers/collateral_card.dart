import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import 'models.dart';

/// Shared by ADMIN (worker card) and WORKER ("Мой залог"). Shows type, amount/description, status and photos.
class CollateralCard extends StatelessWidget {
  const CollateralCard({super.key, required this.collateral, this.actions});
  final Collateral collateral;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = collateral;
    final statusText = switch (c.status) { 'HELD' => l.collateralHeld, 'RETURNED' => l.collateralReturned, _ => l.collateralPending };
    final statusColor = switch (c.status) { 'HELD' => AppTokens.ok, 'RETURNED' => Theme.of(context).colorScheme.outline, _ => AppTokens.warn };
    return Card(
      child: Padding(
        padding: AppTokens.cardPadding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(c.isMoney ? Icons.payments_outlined : Icons.diamond_outlined),
            const SizedBox(width: 8),
            Expanded(child: Text(c.isMoney ? '${l.collateralMoney}: ${formatUzs(c.amount)} ${l.currency}' : (c.description ?? l.collateralItem), style: Theme.of(context).textTheme.titleMedium)),
          ]),
          const SizedBox(height: 8),
          Chip(label: Text(statusText), side: BorderSide.none, backgroundColor: statusColor.withValues(alpha: 0.12), labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
          if (c.estimatedValue != null) Text('${l.estimatedValue}: ${formatUzs(c.estimatedValue)}'),
          if (c.storageLocation != null) Text('${l.storageLocation}: ${c.storageLocation}'),
          if (c.photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: c.photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final f = c.photos[i].file;
                  if (f == null) return const SizedBox.shrink();
                  return GestureDetector(
                    onTap: () => showDialog<void>(context: context, builder: (_) => Dialog(child: InteractiveViewer(child: CachedNetworkImage(imageUrl: f.url, cacheKey: f.id)))),
                    child: ClipRRect(borderRadius: BorderRadius.circular(12), child: CachedNetworkImage(imageUrl: f.thumbUrl, cacheKey: '${f.id}-thumb', width: 84, height: 84, fit: BoxFit.cover)),
                  );
                },
              ),
            ),
          ],
          if (actions != null && actions!.isNotEmpty) ...[const SizedBox(height: 12), ...actions!],
        ]),
      ),
    );
  }
}
