import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/location/geo.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';

/// Blocks the working part of the app until location is actually usable (§20): checks Location Services, foreground and
/// background permission, in that order, and shows exactly what is missing — it never pretends to switch a system setting
/// on by itself. Once [LocationStatus.ok], it starts the background tracker (D-030) and shows [child].
class LocationGate extends ConsumerStatefulWidget {
  const LocationGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<LocationGate> createState() => _LocationGateState();
}

class _LocationGateState extends ConsumerState<LocationGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // returning from the system Settings screen (or turning GPS on) must be picked up without a manual pull-to-refresh
    if (state == AppLifecycleState.resumed) ref.invalidate(locationStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(locationStatusProvider);
    return status.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => _GapScreen(gap: LocationGap.foregroundDenied), // ask again rather than lock the person out on a transient error
      data: (s) {
        if (s.ok) {
          WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(locationTrackerProvider).start());
          return widget.child;
        }
        ref.read(locationTrackerProvider).stop();
        return _GapScreen(gap: s.gap);
      },
    );
  }
}

class _GapScreen extends ConsumerStatefulWidget {
  const _GapScreen({required this.gap});
  final LocationGap gap;
  @override
  ConsumerState<_GapScreen> createState() => _GapScreenState();
}

class _GapScreenState extends ConsumerState<_GapScreen> {
  bool _busy = false;

  Future<void> _act() async {
    setState(() => _busy = true);
    final geo = ref.read(geoProvider);
    try {
      switch (widget.gap) {
        case LocationGap.servicesDisabled:
          await geo.openLocationSettings();
        case LocationGap.foregroundDenied:
          await geo.requestForeground();
        case LocationGap.foregroundDeniedForever:
        case LocationGap.backgroundDeniedForever:
          await geo.openAppSettings();
        case LocationGap.backgroundDenied:
          await geo.requestBackground();
        case LocationGap.none:
          break;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      ref.invalidate(locationStatusProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (icon, title, body, action) = switch (widget.gap) {
      LocationGap.servicesDisabled => (Icons.location_disabled, l.locationServicesOffTitle, l.locationServicesOffBody, l.locationOpenSettings),
      LocationGap.foregroundDenied => (Icons.location_on_outlined, l.locationForegroundTitle, l.locationForegroundBody, l.locationAllow),
      LocationGap.foregroundDeniedForever => (Icons.location_off_outlined, l.locationForegroundTitle, l.locationDeniedForeverBody, l.locationOpenAppSettings),
      LocationGap.backgroundDenied => (Icons.my_location, l.locationBackgroundTitle, l.locationBackgroundBody, l.locationAllow),
      LocationGap.backgroundDeniedForever => (Icons.my_location, l.locationBackgroundTitle, l.locationDeniedForeverBody, l.locationOpenAppSettings),
      LocationGap.none => (Icons.check_circle, '', '', ''),
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 72, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 20),
              Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(body, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 28),
              FilledButton(key: const Key('locationGateAction'), onPressed: _busy ? null : _act, child: Text(action)),
              const SizedBox(height: 8),
              TextButton(onPressed: () => ref.invalidate(locationStatusProvider), child: Text(l.retry)),
            ]),
          ),
        ),
      ),
    );
  }
}
