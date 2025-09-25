// lib/screens/login_page.dart (최종)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'guardian_home_screen.dart';
import 'user_home_screen.dart';
import 'register_page.dart';
import 'package:midas_mobile/config.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Future<void> _sendFcmToken(int userId, bool isGuardian) async {
    // 보호자 계정만 FCM 토큰 등록
    if (!isGuardian) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      final uri = Uri.parse(fcmTokenRegisterUrl);
      final resp = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'user_id': userId, 'fcm_token': token}),
      );
      debugPrint('✅ sendFcmToken ${resp.statusCode} ${resp.body}');
    } catch (e) {
      debugPrint('❌ sendFcmToken error: $e');
    }
  }

  Future<void> _login() async {
    final loginId = _idController.text.trim();
    final password = _pwController.text.trim();

    if (loginId.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이디와 비밀번호를 입력해주세요.')),
      );
      return;
    }

    final uri = Uri.parse(loginUrl);
    debugPrint('🔗 [Login] POST $uri');

    try {
      final resp = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'login_id': loginId, 'password': password}),
      );
      debugPrint('→ status=${resp.statusCode}');
      if (resp.statusCode != 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 실패 (HTTP ${resp.statusCode})')),
        );
        return;
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;

      final userId = _asInt(data['user_id']);
      final roleRaw = (data['role'] ?? '').toString().toLowerCase().trim();
      // 다양한 표기 허용: guardian / guard / guad
      final isGuardian = ['guardian', 'guard', 'guad'].contains(roleRaw);

      final jwt =
      (data['token'] ?? data['jwt'] ?? data['access_token'] ?? data['jwt_token'])
          ?.toString()
          .trim();
      final serverFcm = (data['fcm_token'] as String?)?.trim();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', userId);
      await prefs.setBool('isGuardianLoggedIn', isGuardian);
      await prefs.setString('role', roleRaw);

      // ✅ 보호자 계정이면 guardian_id 저장, 아니면 제거
      if (isGuardian) {
        await prefs.setInt('guardian_id', userId);
      } else {
        await prefs.remove('guardian_id');
      }

      if (jwt != null && jwt.isNotEmpty) {
        await prefs.setString('jwt_token', jwt);
      }
      if (serverFcm != null && serverFcm.isNotEmpty) {
        await prefs.setString('server_fcm_token', serverFcm);
      }

      await _sendFcmToken(userId, isGuardian);
      if (!mounted) return;

      // 네비게이션 분기
      if (isGuardian) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => GuardianHomeScreen(userId: userId)),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => UserHomeScreen(userId: userId)),
        );
      }
    } catch (e, st) {
      debugPrint('❌ 로그인 예외: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서버와 통신 중 오류가 발생했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/background.png', fit: BoxFit.cover),
          Container(color: Colors.white.withOpacity(0.6)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  const Text(
                    'MIDAS 로그인',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Icon(Icons.location_on, size: 28, color: Colors.grey),
                  const SizedBox(height: 32),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          TextField(
                            controller: _idController,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.person),
                              labelText: '아이디',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _pwController,
                            obscureText: true,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.lock),
                              labelText: '비밀번호',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB66CF4),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('로그인', style: TextStyle(fontSize: 18)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RegisterPage()),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2ABBAF),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('회원가입', style: TextStyle(fontSize: 18)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
