// user_location_list_screen.dart — 최종본
//
// 변경 요약
// - 좌표값은 UI에서 제거
// - 처음부터 "도로명 주소 변환" 실행
// - 주소 미도착시 "주소 변환 중..." 표시

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:midas_mobile/config.dart';

class UserLocationListScreen extends StatefulWidget {
  const UserLocationListScreen({Key? key}) : super(key: key);

  @override
  State<UserLocationListScreen> createState() => _UserLocationListScreenState();
}

class _UserLocationListScreenState extends State<UserLocationListScreen> {
  final List<Map<String, String>> _locations = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLocations();
  }

  Future<int?> _getGuardianId() async {
    final prefs = await SharedPreferences.getInstance();
    final gId = prefs.getInt('guardian_id');
    if (gId != null) return gId;

    final role = (prefs.getString('role') ?? '').trim().toLowerCase();
    if (['guardian', 'guard', 'guad'].contains(role)) {
      final uId = prefs.getInt('user_id');
      if (uId != null) {
        await prefs.setInt('guardian_id', uId);
        return uId;
      }
    }
    return null;
  }

  Future<void> _fetchLocations() async {
    setState(() {
      _loading = true;
      _error = null;
      _locations.clear();
    });

    try {
      final guardianId = await _getGuardianId();
      if (guardianId == null) throw Exception('guardian_id 없음');

      final url = Uri.parse(guardianUsersLocationUrl(guardianId));
      final resp = await http.get(url, headers: const {'Accept': 'application/json'});

      if (resp.statusCode != 200) throw Exception('서버 오류: ${resp.statusCode}');

      final body = jsonDecode(resp.body);
      if (body is! Map || body['ok'] != true) throw Exception('응답 형식 오류');

      final List<dynamic> list = (body['data'] as List?) ?? const [];

      for (int i = 0; i < list.length; i++) {
        final e = (list[i] as Map<String, dynamic>);
        final lat = double.tryParse('${e['latitude']}') ?? 0.0;
        final lng = double.tryParse('${e['longitude']}') ?? 0.0;

        // ✅ 시간 포맷팅
        String rawTime = e['timestamp']?.toString() ?? '';
        DateTime parsed = DateTime.tryParse(rawTime) ?? DateTime.now();
        final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(parsed);

        // 처음에는 "주소 변환 중..." 표시
        _locations.add({'time': timeStr, 'address': '주소 변환 중...'});

        // ✅ 도로명 주소 변환
        if (lat != 0.0 && lng != 0.0) {
          _reverseGeocode(lat, lng).then((addr) {
            if (!mounted) return;
            setState(() {
              _locations[i]['address'] = addr;
            });
          });
        }
      }

      setState(() {});
    } catch (e) {
      setState(() {
        _error = '❌ 위치 불러오기 오류: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    final key = googleMapsApiKey;
    if (key.isEmpty) return '주소 정보 없음';

    final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&language=ko&key=$key');
    try {
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        if (json['status'] == 'OK') {
          final results = json['results'] as List<dynamic>;
          if (results.isNotEmpty) {
            return results[0]['formatted_address'] as String? ?? '주소 정보 없음';
          }
        }
      }
    } catch (_) {}
    return '주소 정보 없음';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        leading: const BackButton(color: Colors.black87),
        title: const Text(
          '📋 사용자 위치 수신 목록',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _fetchLocations,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : _locations.isEmpty
          ? const Center(child: Text('위치 기록이 없습니다.'))
          : ListView.builder(
        itemCount: _locations.length,
        itemBuilder: (ctx, idx) {
          final item = _locations[idx];
          final addr = item['address'] ?? '주소 정보 없음';
          final time = item['time'] ?? '시간 정보 없음';

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: ListTile(
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              leading: const Icon(Icons.location_on,
                  size: 32, color: Colors.blueAccent),
              title: Text(
                addr,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              subtitle: Text(
                time,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
