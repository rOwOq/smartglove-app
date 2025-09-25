// lib/screens/last_location_screen.dart (최종본)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';  // ✅ 도로명 주소 변환
import 'package:midas_mobile/config.dart';

class LastLocationScreen extends StatefulWidget {
  final int? userId; // 특정 사용자 ID

  const LastLocationScreen({super.key, this.userId});

  @override
  State<LastLocationScreen> createState() => _LastLocationScreenState();
}

class _LastLocationScreenState extends State<LastLocationScreen> {
  LatLng? _lastPosition;
  String? _timestamp;
  String? _address;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadLastLocation();
  }

  Future<void> _loadLastLocation() async {
    setState(() => _loading = true);
    try {
      final id = widget.userId ?? 31; // 기본 user_id=31
      final url = Uri.parse(userLocationUrl(id));
      final resp = await http.get(url);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);

        final latRaw = data['latitude'];
        final lngRaw = data['longitude'];
        final tsRaw = data['timestamp'];

        final lat = double.tryParse(latRaw.toString());
        final lng = double.tryParse(lngRaw.toString());

        if (lat != null && lng != null) {
          String addr = "(${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})";
          try {
            // ✅ 위도/경도를 도로명 주소로 변환
            final placemarks = await placemarkFromCoordinates(lat, lng);
            if (placemarks.isNotEmpty) {
              final place = placemarks.first;
              addr =
              "${place.street ?? ''}, ${place.locality ?? ''} ${place.administrativeArea ?? ''}";
            }
          } catch (e) {
            debugPrint("주소 변환 실패: $e");
          }

          setState(() {
            _lastPosition = LatLng(lat, lng);
            _timestamp = tsRaw != null
                ? DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(tsRaw))
                : null;
            _address = addr;
          });
        } else {
          throw Exception("좌표 변환 실패");
        }
      } else {
        throw Exception("서버 응답 오류: ${resp.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ 마지막 위치 불러오기 오류: $e");
      setState(() {
        _address = "주소를 가져오는 데 실패했습니다.\n$e";
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '📍 마지막 위치',
          style: TextStyle(color: Colors.black87), // ✅ 검정색으로 수정
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _loadLastLocation,
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: Card(
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.hardEdge,
              elevation: 4,
              child: _lastPosition == null
                  ? const Center(child: Text("위치 정보 없음"))
                  : GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _lastPosition!,
                  zoom: 16,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('lastLocation'),
                    position: _lastPosition!,
                    infoWindow: InfoWindow(
                      title: '마지막 위치',
                      snippet: _timestamp ?? '',
                    ),
                  )
                },
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
              ),
            ),
          ),
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Colors.yellow.shade100,
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_timestamp != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              color: Colors.black54),
                          const SizedBox(width: 8),
                          Text(
                            _timestamp!,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: Colors.black54),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _address ?? "주소 정보 없음",
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
