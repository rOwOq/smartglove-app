// lib/screens/register_page.dart  (최종)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:midas_mobile/config.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _selectedRole; // 'user' | 'guardian'
  String _registerStatus = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 회원가입 후(보호자일 때) 보조 서버에 FCM 토큰 등록
  Future<void> _sendFcmTokenIfGuardian({
    required int userId,
    required String role,
  }) async {
    if (role.toLowerCase() != 'guardian') return;

    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('⚠️ FCM 토큰 미발급(잠시 후 재시도 필요)');
        return;
      }

      final uri = Uri.parse(fcmTokenRegisterUrl); // ← /api/fcm/register-token
      final resp = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'user_id': userId, 'fcm_token': fcmToken}),
      );
      debugPrint('✅ FCM 토큰 저장 status: ${resp.statusCode}, body: ${resp.body}');
    } catch (e) {
      debugPrint('❌ FCM 토큰 저장 예외: $e');
    }
  }

  Future<void> _register() async {
    final loginId = _idController.text.trim();
    final password = _passwordController.text.trim();
    final role = _selectedRole; // 'user' or 'guardian'

    if (loginId.isEmpty || password.isEmpty || role == null) {
      setState(() => _registerStatus = '❌ 모든 항목을 입력해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
      _registerStatus = '';
    });

    final uri = Uri.parse(registerUrl); // 메인 백엔드 회원가입
    try {
      final resp = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'login_id': loginId,
          'password': password,
          'role': role,
        }),
      );

      if (resp.statusCode == 201) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final userId = (data['user_id'] as num).toInt();

        // 보호자면 FCM 토큰 등록
        await _sendFcmTokenIfGuardian(userId: userId, role: role);

        setState(() => _registerStatus = '✅ 회원가입 성공!');
        if (mounted) Navigator.pop(context);
      } else if (resp.statusCode == 409) {
        setState(() => _registerStatus = '❌ 이미 존재하는 아이디입니다.');
      } else {
        setState(() => _registerStatus = '❌ 회원가입 실패 (HTTP ${resp.statusCode})');
      }
    } catch (e) {
      setState(() => _registerStatus = '🚫 오류 발생: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 배경 이미지
          Image.asset('assets/images/background.png', fit: BoxFit.cover),
          // 폼
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  const Text(
                    '회원가입',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _idController,
                    decoration: const InputDecoration(
                      labelText: '아이디',
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '비밀번호',
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('역할 선택:', style: TextStyle(color: Colors.black)),
                  ListTile(
                    title: const Text('사용자', style: TextStyle(color: Colors.black)),
                    leading: Radio<String>(
                      value: 'user',
                      groupValue: _selectedRole,
                      onChanged: (v) => setState(() => _selectedRole = v),
                    ),
                  ),
                  ListTile(
                    title: const Text('보호자', style: TextStyle(color: Colors.black)),
                    leading: Radio<String>(
                      value: 'guardian', // 서버 일관성: 'guardian'
                      groupValue: _selectedRole,
                      onChanged: (v) => setState(() => _selectedRole = v),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_registerStatus.isNotEmpty)
                    Text(_registerStatus, style: const TextStyle(color: Colors.redAccent)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2ABBAF),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('회원가입', style: TextStyle(fontSize: 18, color: Colors.white)),
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
