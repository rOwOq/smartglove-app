import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../app_nav.dart';          // ✅ 경로 수정
import '../firebase_options.dart';         // ✅ 옵션 가져와서 안전 초기화

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 백그라운드 isolate에서만 필요. 중복 없이 보장
  try {
    Firebase.app();
  } catch (_) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  final route = message.data['route'] ?? '/location';
  _navigate(route);
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  final route = response.payload ?? '/location';
  _navigate(route);
}

void _navigate(String? route) {
  if (route == null || route.isEmpty) return;
  // 이미 동일 라우트가 떠 있으면 중복 push 안 하는 등 추가 로직이 필요하면 이 함수에서 처리
  navKey.currentState?.pushNamed(route);
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String channelId = 'midas_default';
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    channelId,
    'MIDAS 기본 알림',
    description: '스마트 장갑 알림 채널',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _flnp = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _flnp.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (r) => _navigate(r.payload),
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await _flnp
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _fcm.requestPermission(alert: true, badge: true, sound: true);
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );

    // 포그라운드 수신 → 로컬 알림으로 표시(탭 시 route로 이동)
    FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      final title = n?.title ?? m.data['title'];
      final body  = n?.body  ?? m.data['body'];
      final route = m.data['route'] ?? '/location';
      _showLocal(title, body, payload: route);
    });

    // 백그라운드/종료 상태에서 알림 탭하여 앱이 열렸을 때
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      final route = m.data['route'] ?? '/location';
      _navigate(route);
    });
  }

  Future<void> _showLocal(String? title, String? body, {String? payload}) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        'MIDAS 기본 알림',
        channelDescription: '스마트 장갑 알림 채널',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _flnp.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title ?? '알림',
      body ?? '',
      details,
      payload: payload,
    );
  }

  Future<void> showTestNotification() async {
    await _showLocal('🔔 사용자 위치 갱신', '테스트 알림입니다.', payload: '/location');
  }
}
