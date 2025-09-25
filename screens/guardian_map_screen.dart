import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:midas_mobile/config.dart';

class GuardianMapScreen extends StatefulWidget {
  final int guardianId;

  const GuardianMapScreen({super.key, required this.guardianId});

  @override
  State<GuardianMapScreen> createState() => _GuardianMapScreenState();
}

class _GuardianMapScreenState extends State<GuardianMapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserLocations();
  }

  Future<void> _fetchUserLocations() async {
    final url = Uri.parse(guardianUsersLocationUrl(widget.guardianId)); // ✅ 수정

    final res = await http.get(url);

    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);

      Set<Marker> markers = {};
      for (var entry in data) {
        if (entry['location'] != null) {
          final loc = entry['location'];
          final marker = Marker(
            markerId: MarkerId("user_${entry['user_id']}"),
            position: LatLng(loc['latitude'], loc['longitude']),
            infoWindow: InfoWindow(
              title: '사용자 ID: ${entry['user_id']}',
              snippet: '시간: ${loc['timestamp']}',
            ),
          );
          markers.add(marker);
        }
      }

      setState(() {
        _markers = markers;
        _isLoading = false;
      });
    } else {
      print('❌ 사용자 위치 불러오기 실패: ${res.statusCode}');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🗺️ 전체 사용자 위치')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _markers.isNotEmpty
              ? _markers.first.position
              : const LatLng(37.0, 127.0),
          zoom: 12,
        ),
        onMapCreated: (controller) => _mapController = controller,
        markers: _markers,
      ),
    );
  }
}
