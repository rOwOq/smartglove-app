// lib/screens/user_home_screen.dart (최종본)

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:midas_mobile/config.dart';
import 'package:midas_mobile/screens/login_page.dart';
import 'package:midas_mobile/providers/ble_provider.dart';

class UserHomeScreen extends StatefulWidget {
  final int userId;
  const UserHomeScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  Timer? _timer;
  bool? _bleConnectedFromServer;
  bool _photoTaken = false;   // 중지(F3) 연타 방지
  bool _takingPhoto = false;

  BleProvider? _bleProvider;
  VoidCallback? _bleListener;
  bool _listenerAdded = false;

  static const MethodChannel _audioChannel = MethodChannel('midas_mobile/audio');
  bool _speakerConnected = false;

  Future<void> _checkSpeakerConnected() async {
    try {
      final on = await _audioChannel.invokeMethod<bool>('isBluetoothA2dpOn') ?? false;
      if (!mounted) return;
      setState(() => _speakerConnected = on);
    } on PlatformException catch (_) {
      if (!mounted) return;
      setState(() => _speakerConnected = false);
    }
  }

  Future<void> _fetchStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final url = Uri.parse(bleStatusUrl(widget.userId));
      final resp = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          _bleConnectedFromServer = data['glove_connected'] == true;
        });
      }
    } catch (_) {}
  }

  void _startStatusPolling() {
    _fetchStatus();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchStatus());
  }

  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  String _description = '';
  final FlutterTts _flutterTts = FlutterTts();

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('ko-KR');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.awaitSpeakCompletion(true);
  }

  Future<void> _takePhoto() async {
    if (_takingPhoto) return;
    _takingPhoto = true;
    try {
      final photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo == null) {
        _takingPhoto = false;
        return;
      }

      setState(() {
        _imageFile = File(photo.path);
        _description = '사진 분석 중…';
      });

      final bytes = await _imageFile!.readAsBytes();
      final base64Img = base64Encode(bytes);

      final aiResp = await http.post(
        Uri.parse(imageDescriptionUrl),
        headers: const {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'image': base64Img}),
      );

      String desc = '설명을 받지 못했습니다.';
      if (aiResp.statusCode == 200) {
        final js = jsonDecode(aiResp.body) as Map<String, dynamic>;
        final d = (js['description'] as String?)?.trim();
        if (d != null && d.isNotEmpty) desc = d;
      } else {
        desc = '설명 생성 실패 (HTTP ${aiResp.statusCode})';
      }

      if (!mounted) return;
      setState(() => _description = desc);
      await _flutterTts.stop();
      await _flutterTts.speak(desc);
    } catch (e) {
      if (!mounted) return;
      setState(() => _description = '분석 중 오류 발생: $e');
    } finally {
      _takingPhoto = false;
    }
  }

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

  @override
  void initState() {
    super.initState();
    _startStatusPolling();
    _initTts();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bleProvider = Provider.of<BleProvider>(context, listen: false);

      _bleListener = () {
        final bp = _bleProvider;
        if (!mounted || bp == null) return;

        if (bp.ringBent) {
          _flutterTts.stop();
          _flutterTts.speak('살려주세요');
        }

        if (bp.middleBent && !_photoTaken) {
          _photoTaken = true;
          _takePhoto();
        } else if (!bp.middleBent) {
          _photoTaken = false;
        }
      };

      if (_bleListener != null) {
        _bleProvider!.addListener(_bleListener!);
        _listenerAdded = true;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_listenerAdded && _bleListener != null) {
      _bleProvider?.removeListener(_bleListener!);
    }
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bleProvider = Provider.of<BleProvider>(context);
    final isBleConnected = bleProvider.connectionStatus.contains('✅');

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MIDAS'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black),
              tooltip: "로그아웃",
              onPressed: _logout,
            ),
          ],
        ),
        backgroundColor: const Color(0xFFE5E9F2),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '장갑 사용자용',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // BLE 상태 카드
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.bluetooth, size: 32, color: Colors.blueAccent),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          bleProvider.connectionStatus == '🔌 연결되지 않음'
                              ? (_bleConnectedFromServer == null
                              ? 'BLE 연결 상태 확인 중…'
                              : _bleConnectedFromServer == true
                              ? '장갑 연결됨 (서버)'
                              : '장갑 연결 안됨 (서버)')
                              : bleProvider.connectionStatus,
                          style: TextStyle(
                            fontSize: 16,
                            color: bleProvider.connectionStatus.contains('✅')
                                ? Colors.green
                                : (bleProvider.connectionStatus.contains('❌') ||
                                _bleConnectedFromServer == false)
                                ? Colors.red
                                : Colors.black54,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (isBleConnected) {
                            await bleProvider.disconnect();
                            if (!mounted) return;
                            setState(() => _speakerConnected = false);
                          } else {
                            // 🔄 재연결 버튼 동작
                            await bleProvider.disconnect(); // 혹시 남아있는 연결 정리
                            await bleProvider.startScanAndConnect();
                            await _checkSpeakerConnected();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          isBleConnected ? Colors.redAccent : Colors.blueAccent,
                        ),
                        child: Text(isBleConnected ? '연결 해제' : '재연결'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 배터리 상태
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.battery_full, size: 32, color: Colors.teal),
                          SizedBox(width: 16),
                          Text('배터리 상태',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 0.84),
                        duration: const Duration(seconds: 1),
                        builder: (context, value, _) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: value,
                              minHeight: 12,
                              backgroundColor: Colors.grey.shade300,
                              valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.teal),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 84.0),
                          duration: const Duration(seconds: 1),
                          builder: (context, value, _) {
                            return Text(
                              '${value.toInt()}%',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 사진 찍기 버튼
              ElevatedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('사진 찍기', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 16),

              if (_imageFile != null) ...[
                Image.file(_imageFile!),
                const SizedBox(height: 12),
              ],

              Text(
                _description,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
