import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../l10n/app_localizations.dart';
import '../network/api_client.dart';
import '../providers.dart';
import '../storage/token_store.dart';
import '../ui/widgets.dart';

/// One entry of the bell (mirrors AppNotifier.list on the API).
class AppNotice {
  const AppNotice({required this.id, required this.type, required this.title, this.body, this.link, required this.read, required this.createdAt});
  final String id;
  final String type;
  final String title;
  final String? body;
  final String? link;
  final bool read;
  final DateTime createdAt;
  factory AppNotice.fromJson(Map<String, dynamic> j) => AppNotice(
        id: j['id'] as String, type: j['type'] as String, title: j['title'] as String? ?? '', body: j['body'] as String?, link: j['link'] as String?,
        read: j['read'] as bool? ?? false, createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class NoticeFeed {
  const NoticeFeed({required this.items, required this.unread});
  final List<AppNotice> items;
  final int unread;
}

final noticesProvider = FutureProvider<NoticeFeed>((ref) async {
  ref.listen(realtimeEventsProvider, (_, next) { if (next.value?.type == 'notification.created') ref.invalidateSelf(); });
  final j = await ref.watch(apiClientProvider).getJson('/me/notifications');
  return NoticeFeed(
    items: ((j['items'] as List?) ?? const []).map((x) => AppNotice.fromJson((x as Map).cast<String, dynamic>())).toList(),
    unread: (j['unread'] as num?)?.toInt() ?? 0,
  );
});

// ---- Android system notifications -------------------------------------------------------------------------------------------

const _prefSince = 'notices.since';
const _prefForeground = 'app.foregroundAt';
const _taskName = 'diamoraa.notices';
final _plugin = FlutterLocalNotificationsPlugin();
const _details = NotificationDetails(
  android: AndroidNotificationDetails('diamoraa_main', 'Diamoraa', channelDescription: 'Работа, выплаты, склад', importance: Importance.high, priority: Priority.high),
);

bool get _supported => !kIsWeb && Platform.isAndroid;

/// Where a tap on a system notification should go (set once the router exists).
void Function(String link)? onNoticeTap;

Future<void> initSystemNotifications() async {
  if (!_supported) return;
  await _plugin.initialize(
    settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    onDidReceiveNotificationResponse: (r) { final link = r.payload; if (link != null && link.isNotEmpty) onNoticeTap?.call(link); },
  );
  final launch = await _plugin.getNotificationAppLaunchDetails();
  final link = launch?.notificationResponse?.payload;
  if (launch?.didNotificationLaunchApp == true && link != null && link.isNotEmpty) {
    WidgetsBinding.instance.addPostFrameCallback((_) => onNoticeTap?.call(link));
  }
}

Future<void> showSystemNotice({required String id, required String title, String? body, String? link}) async {
  if (!_supported) return;
  await _plugin.show(id: id.hashCode & 0x7fffffff, title: title, body: body, notificationDetails: _details, payload: link);
}

/// Background: every ~15 min Android wakes this (even when Diamoraa is closed), it asks the server what is new and shows
/// it as system notifications. Skipped while the app itself is open (it gets notices in realtime then).
@pragma('vm:entry-point')
void noticesCallbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fg = DateTime.tryParse(prefs.getString(_prefForeground) ?? '');
      if (fg != null && DateTime.now().difference(fg) < const Duration(minutes: 2)) return true;
      final tokens = SecureTokenStore();
      if (await tokens.readAccess() == null) return true; // signed out
      final api = ApiClient(tokens: tokens, onSessionExpired: () {});
      final since = prefs.getString(_prefSince) ?? DateTime.now().subtract(const Duration(minutes: 20)).toUtc().toIso8601String();
      final j = await api.getJson('/me/notifications', query: {'since': since, 'limit': 20});
      final items = ((j['items'] as List?) ?? const []).map((x) => AppNotice.fromJson((x as Map).cast<String, dynamic>())).toList();
      await _plugin.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
      for (final n in items.reversed.where((n) => !n.read)) {
        await showSystemNotice(id: n.id, title: n.title, body: n.body, link: n.link);
      }
      if (items.isNotEmpty) await prefs.setString(_prefSince, items.first.createdAt.toUtc().toIso8601String());
    } catch (_) {/* offline: next run */}
    return true;
  });
}

/// Called by both shells once signed in: permission, background check, and «the app is open» heartbeat.
Future<void> startNoticeDelivery(SharedPreferences prefs) async {
  if (!_supported) return;
  await prefs.setString(_prefForeground, DateTime.now().toIso8601String());
  await prefs.setString(_prefSince, prefs.getString(_prefSince) ?? DateTime.now().toUtc().toIso8601String());
  await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  await Workmanager().initialize(noticesCallbackDispatcher);
  await Workmanager().registerPeriodicTask(_taskName, _taskName,
      frequency: const Duration(minutes: 15), constraints: Constraints(networkType: NetworkType.connected), existingWorkPolicy: ExistingPeriodicWorkPolicy.keep);
}

Future<void> markForeground(SharedPreferences prefs) => prefs.setString(_prefForeground, DateTime.now().toIso8601String());

/// Remember what the app already showed in realtime, so the background check never shows it twice.
Future<void> noteShown(SharedPreferences prefs) => prefs.setString(_prefSince, DateTime.now().toUtc().toIso8601String());

Future<void> stopNoticeDelivery() async {
  if (!_supported) return;
  await Workmanager().cancelByUniqueName(_taskName);
}

// ---- UI ------------------------------------------------------------------------------------------------------------------------

/// The bell with the unread count, for every main app bar.
class NoticeBell extends ConsumerWidget {
  const NoticeBell({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final unread = ref.watch(noticesProvider).value?.unread ?? 0;
    return IconButton(
      tooltip: l.noticesTitle,
      icon: Badge(isLabelVisible: unread > 0, label: Text(unread > 99 ? '99+' : '$unread'), child: const Icon(Icons.notifications_rounded)),
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NoticesScreen())),
    );
  }
}

class NoticesScreen extends ConsumerWidget {
  const NoticesScreen({super.key});

  Future<void> _read(WidgetRef ref, {List<String>? ids, bool all = false}) async {
    try {
      await ref.read(apiClientProvider).postJson('/me/notifications/read', body: {'ids': ?ids, if (all) 'all': true});
      ref.invalidate(noticesProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(noticesProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.noticesTitle),
        actions: [
          if ((async.value?.unread ?? 0) > 0)
            IconButton(tooltip: l.noticesReadAll, icon: const Icon(Icons.done_all_rounded), onPressed: () => _read(ref, all: true)),
        ],
      ),
      body: async.when(
        loading: () => const SkeletonList(count: 5),
        error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: errorText(context, e)),
        data: (feed) => feed.items.isEmpty
            ? EmptyState(icon: Icons.notifications_none_rounded, title: l.noticesEmpty)
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(noticesProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: feed.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final n = feed.items[i];
                    final t = n.createdAt.toLocal();
                    final when = '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                    return InkWell(
                      onTap: () {
                        if (!n.read) _read(ref, ids: [n.id]);
                        final link = n.link;
                        if (link != null && link.isNotEmpty) {
                          Navigator.of(context).pop();
                          GoRouter.of(context).push(link);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(width: 9, height: 9, decoration: BoxDecoration(color: n.read ? Colors.transparent : scheme.primary, shape: BoxShape.circle)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w500 : FontWeight.w800, fontSize: 15)),
                              if (n.body?.isNotEmpty == true) ...[const SizedBox(height: 2), Text(n.body!, style: Theme.of(context).textTheme.bodyMedium)],
                              const SizedBox(height: 4),
                              Text(when, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                            ]),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

/// Wraps both shells once signed in: turns on background delivery, keeps «the app is open» fresh, and shows each
/// realtime notice as an Android notification (so it is seen even when the phone is in the pocket with the app alive).
class NoticeDelivery extends ConsumerStatefulWidget {
  const NoticeDelivery({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<NoticeDelivery> createState() => _NoticeDeliveryState();
}

class _NoticeDeliveryState extends ConsumerState<NoticeDelivery> {
  AppLifecycleListener? _life;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPrefsProvider);
    startNoticeDelivery(prefs).catchError((_) {});
    _life = AppLifecycleListener(onResume: () => markForeground(prefs), onShow: () => markForeground(prefs));
  }

  @override
  void dispose() {
    _life?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(realtimeEventsProvider, (_, next) {
      final e = next.value;
      if (e == null || e.type != 'notification.created') return;
      final prefs = ref.read(sharedPrefsProvider);
      markForeground(prefs);
      noteShown(prefs);
      showSystemNotice(id: '${e.data['notificationId']}', title: '${e.data['title'] ?? ''}', body: e.data['body'] as String?, link: e.data['link'] as String?);
    });
    return widget.child;
  }
}
