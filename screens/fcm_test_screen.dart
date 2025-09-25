// 📁 lib/screens/fcm_test_screem.dart  (파일명 그대로 쓴 버전)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:midas_mobile/config.dart'; // fcmNotifyUrl 사용

class FcmTestScreen extends StatelessWidget {
  const FcmTestScreen({super.key});

  Future<void> _sendTestNotification(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❗ 사용자 ID가 없습니다. (user_id)')),
      );
      return;
    }

    final uri = Uri.parse(fcmNotifyUrl); // ✅ 서버 /api/fcm/notify 사용
    final payload = {
      'user_id': userId,
      'title': '서버 발송 테스트',
      'body': '푸시 수신 후 탭하면 위치 화면으로 이동합니다.',
      'data': {'route': '/location'},
    };

    try {
      final res = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        final ok = j['ok'] == true;
        final success = (j['success'] as int?) ?? (ok ? 1 : 0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok && success > 0 ? '✅ 전송 성공 (success: $success)' : '❌ 전송 실패: ${res.body}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 전송 실패 (HTTP ${res.statusCode})')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🚫 오류 발생: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FCM 알림 테스트')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _sendTestNotification(context),
          child: const Text('🔔 테스트 알림 보내기'),
        ),
      ),
    );
  }
}
