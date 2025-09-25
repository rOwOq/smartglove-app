import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart'; // ✅ 날짜 포맷용
import 'alert_map_screen.dart'; // 지도 화면 import
import 'package:midas_mobile/config.dart'; // ✅ 서버 주소 통합 import

class AlertHistoryScreen extends StatefulWidget {
  final int guardianId;

  const AlertHistoryScreen({super.key, required this.guardianId});

  @override
  State<AlertHistoryScreen> createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends State<AlertHistoryScreen> {
  List<dynamic> _alerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
  }

  Future<void> _fetchAlerts() async {
    final url = Uri.parse(guardianAlertsUrl(widget.guardianId)); // ✅ 수정

    final res = await http.get(url);
    if (res.statusCode == 200) {
      setState(() {
        _alerts = jsonDecode(res.body);
        _isLoading = false;
      });
    } else {
      print("❌ 알림 내역 가져오기 실패: ${res.statusCode}");
      setState(() => _isLoading = false);
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
    } catch (e) {
      return timestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🧾 알림 내역')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _alerts.isEmpty
          ? const Center(child: Text('📭 알림 기록이 없습니다.'))
          : ListView.separated(
        itemCount: _alerts.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final item = _alerts[index];
          return ListTile(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AlertMapScreen(
                    latitude: double.parse(item['latitude'].toString()),
                    longitude: double.parse(item['longitude'].toString()),
                  ),
                ),
              );
            },
            leading: const Icon(Icons.warning_amber, color: Colors.orange),
            title: Text(
              '👤 사용자: ${item['user_name'] ?? '이름없음'} (ID: ${item['user_id']})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '⏰ 시간: ${_formatTimestamp(item['timestamp'])}\n'
                  '📍 위치: (${item['latitude']}, ${item['longitude']})',
            ),
          );
        },
      ),
    );
  }
}
