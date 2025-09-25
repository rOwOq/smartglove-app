// 📁 screens/location_list_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserLocationListScreen extends StatefulWidget {
  const UserLocationListScreen({super.key});

  @override
  State<UserLocationListScreen> createState() => _UserLocationListScreenState();
}

class _UserLocationListScreenState extends State<UserLocationListScreen> {
  List<Map<String, dynamic>> _locations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLocationList();
  }

  Future<void> _fetchLocationList() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null) {
      print('❗user_id 없음');
      return;
    }
    // 개인 ip 삽입
    final url = Uri.parse('개인 ip 삽입/api/positions/$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _locations = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      } else {
        print('❌ 위치 목록 불러오기 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('🚫 예외 발생: $e');
    }
  }

  void _openMap(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      print('⚠️ 지도 열기 실패');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('위치 수신 목록')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: _locations.length,
        itemBuilder: (context, index) {
          final loc = _locations[index];
          return ListTile(
            leading: const Icon(Icons.location_on),
            title: Text('위도: ${loc['latitude']}\n경도: ${loc['longitude']}'),
            subtitle: Text('시간: ${loc['timestamp']}'),
            onTap: () => _openMap(loc['latitude'], loc['longitude']),
          );
        },
      ),
    );
  }
}
