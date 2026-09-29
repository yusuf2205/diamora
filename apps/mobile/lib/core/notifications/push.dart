import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../features/chat/chat_repository.dart' show openChatRoomId;
import '../network/api_client.dart';
import 'app_notifications.dart';

/// Instant notifications through Firebase Cloud Messaging. The server sends DATA-ONLY messages; the app shows them
/// itself under the notice's own id, so the same notice arriving again (realtime socket, the 15-minute background check)
/// replaces it instead of doubling it. Without Firebase configured in the build everything here quietly does nothing and
/// the 15-minute background check keeps working as before.
bool _ready = false;

bool get _supported => !kIsWeb && Platform.isAndroid;

/// Runs in a separate isolate while the app is in the background or closed.
@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(RemoteMessage m) async {
  await Firebase.initializeApp();
  await initSystemNotifications(background: true);
  await _show(m);
}

Future<void> _show(RemoteMessage m) async {
  final d = m.data;
  final title = d['title'] as String?;
  if (title == null || title.isEmpty) return;
  final body = d['body'] as String?;
  final link = d['link'] as String?;
  await showSystemNotice(id: '${d['id'] ?? m.messageId}', title: title, body: (body?.isEmpty ?? true) ? null : body, link: (link?.isEmpty ?? true) ? null : link);
}

/// App open: a chat message for the chat already on screen is not shown again as a notification.
Future<void> _showForeground(RemoteMessage m) async {
  final link = m.data['link'] as String?;
  if (m.data['kind'] == 'chat' && openChatRoomId != null && link == '/chat/$openChatRoomId') return;
  await _show(m);
}

/// Once per app start (main): Firebase + the background handler + foreground messages.
Future<void> initPush() async {
  if (!_supported || _ready) return;
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(pushBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_showForeground); // app open: same id as the realtime copy -> one notification
    _ready = true;
  } catch (_) {/* this build has no Firebase config: background check only */}
}

/// After sign-in: tell the server this phone's token (and again whenever Firebase rotates it).
Future<void> registerPush(ApiClient api) async {
  if (!_ready) return;
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await api.postJson('/me/push-token', body: {'token': token, 'platform': 'android'});
    FirebaseMessaging.instance.onTokenRefresh.listen((t) => api.postJson('/me/push-token', body: {'token': t, 'platform': 'android'}).catchError((_) => <String, dynamic>{}));
  } catch (_) {/* offline: next start */}
}

/// On sign-out: this phone must stop getting the previous user's notifications.
Future<void> unregisterPush(ApiClient api) async {
  if (!_ready) return;
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await api.deleteJson('/me/push-token', body: {'token': token});
    await FirebaseMessaging.instance.deleteToken();
  } catch (_) {/* the server drops dead tokens by itself */}
}
