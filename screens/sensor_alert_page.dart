import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';

class SensorAlertPage extends StatefulWidget {
  const SensorAlertPage({Key? key}) : super(key: key);

  @override
  State<SensorAlertPage> createState() => _SensorAlertPageState();
}

class _SensorAlertPageState extends State<SensorAlertPage> {
  late final FlutterTts _tts;
  StreamSubscription<List<int>>? _sub;
  bool _isDanger = false;
  final double _threshold = 400.0;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts()..setLanguage('ko-KR');
    _startScan();
  }

  Future<void> _startScan() async {
    // BLE 스캔 → connect → notify 설정 → _sub = c.value.listen(_onData);
  }

  void _onData(List<int> raw) {
    final m = json.decode(utf8.decode(raw)) as Map<String, dynamic>;
    final minVal = [m['f1'],m['f2'],m['f3'],m['f4']].map((e)=>(e as num).toDouble()).reduce((a,b)=>a<b?a:b);

    if (minVal <= _threshold && !_isDanger) {
      _isDanger = true;
      _tts.stop();
      _tts.speak('살려주세요');
    } else if (minVal > _threshold) {
      _isDanger = false;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(title: const Text('센서 알림 모드')),
      body: Center(
        child: Text(
          _isDanger ? '⚠️ 위험 감지됨' : '✅ 안전',
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
