import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:midas_mobile/config.dart'; // ✅ 추가

class MapScreen extends StatefulWidget {
  final int userId;

  const MapScreen({super.key, required this.userId});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _lastLatLng;
  String? _timestamp;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _fetchUserInfoAndLocation(); // ✅ 이름과 위치 둘 다 불러옴
  }

  Future<void> _fetchUserInfoAndLocation() async {
    try {
      final res = await http.get(
        Uri.parse(userLocationUrl(widget.userId)), // ✅ config.dart 활용
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _userName = data['name'];
          _lastLatLng = LatLng(
            double.parse(data['latitude'].toString()),
            double.parse(data['longitude'].toString()),
          );
          _timestamp = data['timestamp'];
        });
      } else {
        print('❌ 사용자 정보 가져오기 실패: ${res.statusCode}');
      }
    } catch (e) {
      print('🚫 예외 발생: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📍 최근 위치')),
      body: _lastLatLng == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          if (_userName != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                '사용자: $_userName',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _lastLatLng!,
                zoom: 16,
              ),
              onMapCreated: (controller) => _mapController = controller,
              markers: {
                Marker(
                  markerId: const MarkerId("last_position"),
                  position: _lastLatLng!,
                  infoWindow: InfoWindow(
                    title: _userName ?? "사용자",
                    snippet: _timestamp ?? "시간 정보 없음",
                  ),
                )
              },
            ),
          ),
        ],
      ),
    );
  }
}
