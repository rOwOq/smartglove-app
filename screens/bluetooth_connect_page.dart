import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:midas_mobile/providers/ble_provider.dart';

class SensorMonitorPage extends StatelessWidget {
  const SensorMonitorPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Sensor Monitor')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 연결 상태 표시 (빈 문자열일 경우 '알 수 없음' 표시)
            Text(
              '연결 상태: ${ble.connectionStatus.isNotEmpty ? ble.connectionStatus : "알 수 없음"}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            // 수신 데이터 표시 (빈 문자열일 경우 '데이터 없음' 표시)
            Text(
              '수신 데이터: ${ble.receivedData.isNotEmpty ? ble.receivedData : "데이터 없음"}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            // 연결 중 상태일 때 로딩 인디케이터 표시
            if (ble.connectionStatus == '🔄 연결 중...')
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
