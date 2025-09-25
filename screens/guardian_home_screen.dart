// lib/screens/guardian_home_screen.dart (최종본)

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:liquid_progress_indicator_v2/liquid_progress_indicator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:midas_mobile/config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/login_page.dart';
import 'last_location_screen.dart';
import 'user_location_list_screen.dart' as list_scr;
import 'location_screen.dart' as loc_scr;
import 'notification_service.dart';

class GuardianHomeScreen extends StatefulWidget {
  final int userId;
  const GuardianHomeScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<GuardianHomeScreen> createState() => _GuardianHomeScreenState();
}

class _GuardianHomeScreenState extends State<GuardianHomeScreen> {
  Timer? _pollingTimer;
  int? _batteryLevel = 100;
  double _animatedBattery = 1.0;
  final List<Map<String, String>> _receivedLocations = [];
  String? _lastNotification;

  // ★ 추가: 토큰 보이기/복사용
  String? _fcmToken;

  // 알림 서비스
  late final NotificationService _notificationService = NotificationService.instance;

  // ★ 마지막 이벤트 ID/시간 저장
  String? _lastEventId;
  DateTime? _lastNotificationTime;

  @override
  void initState() {
    super.initState();
    _startPolling();
    _configureFCM();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _fetchStatus();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchStatus());
  }

  Future<void> _fetchStatus() async {
    try {
      final res = await http.get(Uri.parse(bleStatusUrl(widget.userId)));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;

        final raw = data['battery_level'];
        int parsed = 0;
        if (raw is int) {
          parsed = raw;
        } else if (raw != null) {
          parsed = int.tryParse(raw.toString()) ?? 0;
        }
        parsed = parsed.clamp(0, 100);

        setState(() {
          _batteryLevel = parsed;
          _animatedBattery = parsed / 100.0;
        });
      }
    } catch (_) {}
  }

  // 🔑 로그아웃 메서드
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
    );
  }

  Future<void> _checkLocation() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const loc_scr.LocationScreen()),
    );
  }

  void _configureFCM() async {
    final fcm = FirebaseMessaging.instance;
    await fcm.requestPermission();

    final token = await fcm.getToken();
    debugPrint('🔑 FCM TOKEN = $token');
    if (token != null) {
      setState(() => _fcmToken = token);
      _sendToken(token);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      setState(() => _fcmToken = t);
      _sendToken(t);
    });

    FirebaseMessaging.onMessage.listen(_onFCMMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(
          (msg) => _onFCMMessage(msg, navigate: true),
    );
    FirebaseMessaging.instance.getInitialMessage().then(
          (msg) => msg != null ? _onFCMMessage(msg, navigate: true) : null,
    );
  }

  Future<void> _sendToken(String token) async {
    final url = Uri.parse(fcmTokenRegisterUrl);
    debugPrint('➡️  POST $url user_id=${widget.userId}');
    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': widget.userId, 'fcm_token': token}),
      );
      debugPrint('⬅️  ${resp.statusCode} ${resp.body}');
    } catch (e) {
      debugPrint('❌ send token error: $e');
    }
  }

  void _onFCMMessage(RemoteMessage message, {bool navigate = false}) {
    if (!mounted) return;

    final eventId = message.data['event_id'] ?? message.messageId;
    final now = DateTime.now();

    // 🔹 같은 event_id 무시
    if (eventId != null && eventId == _lastEventId) {
      debugPrint("⚠️ 중복 알림 무시: $eventId");
      return;
    }

    // 🔹 1분 내 알람 무시
    if (_lastNotificationTime != null &&
        now.difference(_lastNotificationTime!).inMinutes < 1) {
      debugPrint("⏱️ 1분 내 알림 이미 표시됨 → 무시");
      return;
    }

    // 🔹 갱신
    _lastEventId = eventId;
    _lastNotificationTime = now;

    final title = message.notification?.title ?? '알림';
    final body = message.notification?.body ?? '';
    setState(() => _lastNotification = '$title\n$body');

    // 하단 Snackbar 표시 후 자동 사라짐
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_lastNotification!),
        duration: const Duration(seconds: 5),
      ),
    );

    if (navigate) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const loc_scr.LocationScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final batteryText = '${_batteryLevel ?? 0}%';

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('MIDAS', style: TextStyle(color: Colors.black87)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black87),
              tooltip: "로그아웃",
              onPressed: _logout,
            ),
          ],
        ),
        backgroundColor: const Color(0xFFE5E9F2),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                const Text('보호자용',
                    style:
                    TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // Battery card
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('장갑 사용자 배터리',
                            style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 150,
                          child: Stack(
                            children: [
                              LiquidLinearProgressIndicator(
                                value: 0.84,//84%
                                valueColor: const AlwaysStoppedAnimation(
                                    Color(0xFFA3F3EB)),
                                backgroundColor: Colors.grey.shade200,
                                borderColor: Colors.blueGrey,
                                borderWidth: 2.0,
                                borderRadius: 12.0,
                                direction: Axis.vertical,
                              ),
                              Positioned.fill(
                                child: Center(
                                  child: Text(
                                    '84%', //텍스트 고정`
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Location button
                ElevatedButton(
                  onPressed: _checkLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue.shade100,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.black87),
                    ),
                  ),
                  child:
                  const Text('위치 확인', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 12),

                // Location list
                ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                      const list_scr.UserLocationListScreen(),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue.shade100,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.black87),
                    ),
                  ),
                  child: const Text('사용자 위치 수신 목록',
                      style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 12),

                // Last location
                ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => LastLocationScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue.shade100,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.black87),
                    ),
                  ),
                  child: const Text('마지막 위치 보기',
                      style: TextStyle(fontSize: 18)),
                ),

                if (_lastNotification != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.yellow.shade100,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _lastNotification!,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],

                SizedBox(height: MediaQuery.of(context).size.height),


                // ★ 토큰 표시/복사 (있을 때만)
                if (_fcmToken != null) ...[
                  const SizedBox(height: 12),
                  SelectableText(
                    _fcmToken!,
                    style: const TextStyle(fontSize: 12),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                          ClipboardData(text: _fcmToken!));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('FCM 토큰을 복사했습니다.')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('토큰 복사'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
