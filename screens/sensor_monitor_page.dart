import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';



class BleProvider with ChangeNotifier {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  String _connectionStatus = '🔌 연결되지 않음';
  String _receivedData = '';

  BluetoothDevice? get device => _device;
  String get connectionStatus => _connectionStatus;
  String get receivedData => _receivedData;

  Future<void> startScanAndConnect() async {
    print('🔎 BLE 스캔 시작');
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        print('🔍 탐색된 장치: ${r.device.name}, id: ${r.device.id}');
        if (r.device.name == 'MyFlexBLE') {
          print('🎯 MyFlexBLE 찾음! 연결 시도');
          await FlutterBluePlus.stopScan();
          _device = r.device;
          _connectionStatus = '🔄 연결 중...';
          notifyListeners();

          try {
            await _device!.connect();
            print('✅ Flutter BLE 연결됨: ${_device!.name}');
          } catch (e) {
            print('❌ BLE 연결 실패: $e');
            _connectionStatus = '❌ 연결 실패';
            notifyListeners();
            return;
          }

          await _discoverServices();
          break;
        }
      }
    });
  }

  Future<void> _discoverServices() async {
    if (_device == null) return;
    List<BluetoothService> services = await _device!.discoverServices();
    print('📋 서비스 개수: ${services.length}');
    for (var service in services) {
      print('🔍 서비스 UUID: ${service.uuid}');
      for (var c in service.characteristics) {
        print('🟠 characteristic UUID: ${c.uuid} / notify: ${c.properties.notify} / read: ${c.properties.read}');
        if (c.properties.notify) {
          _characteristic = c;
          try {
            await c.setNotifyValue(true);
            print('✅ notify 활성화 성공: ${c.uuid}');
          } catch (e) {
            print('❌ notify 활성화 실패: $e');
          }
          c.value.listen((value) {
            final str = utf8.decode(value);
            print('📨 BLE 데이터 수신: $str');
            _receivedData = str;
            notifyListeners();
          });
          _connectionStatus = '✅ 연결됨: ${_device!.name}';
          notifyListeners();
          break;
        }
      }
    }
  }

  void disconnect() async {
    if (_device != null) {
      await _device!.disconnect();
      _connectionStatus = '🔌 연결 해제됨';
      _device = null;
      _receivedData = '';
      notifyListeners();
      print('🔌 BLE 연결 해제 완료');
    }
  }
}
