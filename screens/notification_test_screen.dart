// 📁 lib/screens/notification_test_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:midas_mobile/config.dart'; // fcmNotifyUrl 사용

class NotificationTestScreen extends StatefulWidget {
  final int userId; // 보호자가 연동한 사용자 ID
  const NotificationTestScreen({super.key, required this.userId});

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  String _statusMessage = '';
  bool _sending = false;

  Future<void> _sendTestNotification() async {
    final uri = Uri.parse(fcmNotifyUrl); // ✅ 서버의 /api/fcm/notify
    setState(() {
      _sending = true;
      _statusMessage = '전송 중...';
    });

    try {
      final payload = {
        'user_id': widget.userId,
        'title': '서버 발송 테스트',
        'body': '푸시가 수신되면 탭해서 위치 화면으로 이동합니다.',
        'data': {'route': '/location'},
      };

      final res = await http.post(
        uri,
        headers: const {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final ok = json['ok'] == true;
        final success = (json['success'] as int?) ?? (ok ? 1 : 0);
        setState(() {
          _statusMessage = ok && success > 0
              ? '✅ 알림 전송 성공 (success: $success)'
              : '❌ 전송 실패: ${res.body}';
        });
      } else {
        setState(() {
          _statusMessage = '❌ 전송 실패 (HTTP ${res.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '🚫 오류 발생: $e';
      });
    } finally {
      setState(() {
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알림 테스트')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _sending ? null : _sendTestNotification,
                icon: const Icon(Icons.notifications_active),
                label: Text(_sending ? '전송 중...' : '테스트 알림 보내기'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
              ),
              const SizedBox(height: 20),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
