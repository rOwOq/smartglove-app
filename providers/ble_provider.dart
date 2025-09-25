import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:midas_mobile/config.dart';

class BleProvider with ChangeNotifier {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  String _connectionStatus = '🔌 연결되지 않음';
  String _receivedData = '';

  // 손가락 상태
  bool thumbBent = false;   // 엄지 (F1)
  bool indexBent = false;   // 검지 (F2)
  bool middleBent = false;  // 중지 (F3)
  bool ringBent = false;    // 약지 (F4)
  bool pinkyBent = false;   // 소지 (F5)

  StreamSubscription? _scanSub;

  BluetoothDevice? get device => _device;
  String get connectionStatus => _connectionStatus;
  String get receivedData => _receivedData;

  // ──────────────────────────────
  // BLE 스캔 및 연결
  // ──────────────────────────────
  Future<void> startScanAndConnect() async {
    await FlutterBluePlus.stopScan();
    _connectionStatus = '🔍 스캔 중...';
    notifyListeners();

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        // 👉 이름 필터 완화: 비어있지 않고 'MyFlexBLE' 포함하면 연결
        print('🔍 탐색된 장치: ${r.device.name}, id: ${r.device.id}');
        if (r.device.name.isNotEmpty && r.device.name.contains('MyFlexBLE')) {
          print('🎯 MyFlexBLE 발견 → 연결 시도');
          await FlutterBluePlus.stopScan();
          await _scanSub?.cancel();

          _device = r.device;
          _connectionStatus = '🔄 연결 중...';
          notifyListeners();

          try {
            await _device!.connect(autoConnect: false);
            _connectionStatus = '✅ 연결됨';
            notifyListeners();

            List<BluetoothService> services = await _device!.discoverServices();
            for (var service in services) {
              for (var characteristic in service.characteristics) {
                if (characteristic.uuid.toString() ==
                    'abcd1234-ab12-cd34-ef56-abcdef123456') {
                  _characteristic = characteristic;
                  await _characteristic!.setNotifyValue(true);

                  _characteristic!.value.listen((value) {
                    final data = utf8.decode(value);
                    print('📩 RX: $data');
                    _receivedData = data;
                    notifyListeners();

                    // 👉 손가락 상태 해석
                    _handleFingerStates(data);
                  });
                }
              }
            }
          } catch (e) {
            print('❌ 연결 오류: $e');
            _connectionStatus = '⚠️ 연결 실패';
            notifyListeners();
          }
        }
      }
    });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
  }

  // ──────────────────────────────
  // 손가락 상태 해석
  // ──────────────────────────────
  Future<void> _handleFingerStates(String data) async {
    final states = _parseFingerStates(data);

    thumbBent  = states['F1'] == 'CLOSED';
    indexBent  = states['F2'] == 'CLOSED';
    middleBent = states['F3'] == 'CLOSED';
    ringBent   = states['F4'] == 'CLOSED';
    pinkyBent  = states['F5'] == 'CLOSED';

    notifyListeners();

    if (indexBent) {
      print("🟥 검지 CLOSED → 위치 전송 실행");
      await _sendLocationToServer();
      await _sendAlertToServer("사용자가 검지를 굽혔습니다", "위치를 확인하세요.");
    }

    if (middleBent) {
      print("📸 중지 CLOSED → 사진 촬영 기능 실행 (별도 구현)");
    }

    if (ringBent) {
      print("🔊 약지 CLOSED → TTS '살려주세요' 실행 (별도 구현)");
    }
  }

  Map<String, String> _parseFingerStates(String data) {
    final Map<String, String> states = {};
    final parts = data.split(" ");
    for (var part in parts) {
      final kv = part.split(":");
      if (kv.length == 2) {
        states[kv[0]] = kv[1];
      }
    }
    return states;
  }

  // ──────────────────────────────
  // 서버 위치 전송
  // ──────────────────────────────
  Future<void> _sendLocationToServer() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');

      final url = Uri.parse(positionUrl);
      final body = jsonEncode({
        'user_id': userId,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
      });

      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      print("📤 위치 전송 결과: ${res.statusCode} - ${res.body}");
    } catch (e) {
      print("❌ 위치 전송 오류: $e");
    }
  }

  // ──────────────────────────────
  // 서버 알림 전송
  // ──────────────────────────────
  Future<void> _sendAlertToServer(String title, String body) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');

      final url = Uri.parse(fcmNotifyUrl);
      final payload = jsonEncode({
        'user_id': userId,
        'title': title,
        'body': body,
      });

      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: payload,
      );

      print("📤 알림 전송 결과: ${res.statusCode} - ${res.body}");
    } catch (e) {
      print("❌ 알림 전송 오류: $e");
    }
  }

  // ──────────────────────────────
  // BLE 연결 해제
  // ──────────────────────────────
  Future<void> disconnect() async {
    try {
      if (_device != null) {
        await _device!.disconnect();
        print("🔌 BLE 연결 해제 완료");
      }
    } catch (e) {
      print("⚠️ disconnect 오류: $e");
    } finally {
      _device = null;
      _characteristic = null;
      _receivedData = '';
      _connectionStatus = '🔌 연결되지 않음';
      notifyListeners();
    }
  }
}
