import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_service.dart';

/// Push notifications (FCM). Fully optional: if the FIREBASE_* keys are not
/// in `.env`, every method is a silent no-op and the app runs as before.
///
/// `.env` keys (from Firebase console → Project settings → Your apps):
///   FIREBASE_PROJECT_ID, FIREBASE_MESSAGING_SENDER_ID,
///   FIREBASE_ANDROID_API_KEY, FIREBASE_ANDROID_APP_ID,
///   FIREBASE_IOS_API_KEY,     FIREBASE_IOS_APP_ID
class PushService {
  PushService._();
  static final instance = PushService._();

  static const _channel = AndroidNotificationChannel(
    'lifekit_default', // must match backend pushRoutes android.channelId
    'LifeKit',
    description: 'Bookings, messages and account updates',
    importance: Importance.high,
  );

  final _local = FlutterLocalNotificationsPlugin();
  GlobalKey<NavigatorState>? _navigatorKey;
  void Function(Map<String, dynamic> data)? _onOpen;
  bool _ready = false;
  String? _token;
  StreamSubscription<String>? _refreshSub;

  bool get isEnabled => _ready;

  static FirebaseOptions? _options() {
    String? env(String k) {
      final v = dotenv.env[k];
      return v == null || v.isEmpty ? null : v;
    }

    final project = env('FIREBASE_PROJECT_ID');
    final sender = env('FIREBASE_MESSAGING_SENDER_ID');
    final ios = !kIsWeb && Platform.isIOS;
    final apiKey = env(ios ? 'FIREBASE_IOS_API_KEY' : 'FIREBASE_ANDROID_API_KEY');
    final appId = env(ios ? 'FIREBASE_IOS_APP_ID' : 'FIREBASE_ANDROID_APP_ID');
    if (project == null || sender == null || apiKey == null || appId == null) return null;
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: sender,
      projectId: project,
      iosBundleId: ios ? 'com.lifekit.app' : null,
    );
  }

  /// Call once at startup. [onOpen] runs when the user taps a notification.
  Future<void> init({
    required GlobalKey<NavigatorState> navigatorKey,
    required void Function(Map<String, dynamic> data) onOpen,
  }) async {
    if (kIsWeb || _ready) return;
    final options = _options();
    if (options == null) return; // not configured → push stays off
    _navigatorKey = navigatorKey;
    _onOpen = onOpen;
    try {
      await Firebase.initializeApp(options: options);

      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_stat_notify'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) => _open(_decode(r.payload)),
      );
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // iOS shows banners itself while the app is open; Android needs help.
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data));
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        // Wait for the first screen before navigating.
        Future.delayed(const Duration(seconds: 2), () => _open(initial.data));
      }

      ApiService.beforeSessionCleared = unregister;
      _ready = true;
    } catch (e) {
      debugPrint('Push init failed: $e');
    }
  }

  /// Ask permission (first time only) and register this device for the
  /// signed-in user. Safe to call on every app open.
  Future<void> registerForUser() async {
    if (!_ready) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      if (Platform.isIOS) {
        // APNs token must exist before FCM can issue one on iOS.
        await FirebaseMessaging.instance.getAPNSToken();
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      _token = token;
      await ApiService().registerPushToken(token, Platform.isIOS ? 'ios' : 'android');
      _refreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        _token = t;
        ApiService().registerPushToken(t, Platform.isIOS ? 'ios' : 'android');
      });
    } catch (e) {
      debugPrint('Push register failed: $e');
    }
  }

  /// Detach this device from the account (called just before logout).
  Future<void> unregister() async {
    if (!_ready) return;
    final token = _token ?? await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await ApiService().unregisterPushToken(token).timeout(const Duration(seconds: 5));
    }
    await _refreshSub?.cancel();
    _refreshSub = null;
    _token = null;
    await FirebaseMessaging.instance.deleteToken();
  }

  Future<void> _showForeground(RemoteMessage m) async {
    final n = m.notification;
    if (n == null || !Platform.isAndroid) return; // iOS presents it natively
    await _local.show(
      m.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_stat_notify',
          color: const Color(0xFF89273B),
        ),
      ),
      payload: _encode(m.data),
    );
  }

  void _open(Map<String, dynamic> data) {
    if (_navigatorKey?.currentState == null) return;
    _onOpen?.call(data);
  }

  // Payload is a tiny "type|reference_id" string — enough to route the tap.
  static String _encode(Map<String, dynamic> d) => '${d['type'] ?? ''}|${d['reference_id'] ?? ''}';
  static Map<String, dynamic> _decode(String? p) {
    final parts = (p ?? '|').split('|');
    return {'type': parts.first, 'reference_id': parts.length > 1 ? parts[1] : ''};
  }
}
