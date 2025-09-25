// lib/screens/location_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:midas_mobile/config.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationScreen extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final int? userId;

  const LocationScreen({
    Key? key,
    this.latitude,
    this.longitude,
    this.userId,
  }) : super(key: key);

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _loading = false;
  bool _hasPermission = false;

  double? _lat;
  double? _lng;
  String? _address;
  DateTime? _fetchedAt;

  @override
  void initState() {
    super.initState();
    _lat = widget.latitude;
    _lng = widget.longitude;
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.location.request();
    setState(() => _hasPermission = status == PermissionStatus.granted);
    if (_hasPermission) await _loadLocation();
  }

  Future<void> _loadLocation() async {
    setState(() => _loading = true);
    try {
      if (_lat == null || _lng == null) {
        final id = widget.userId ?? 31;
        final url = Uri.parse(userLocationUrl(id));
        final resp = await http.get(url);

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);

          // ✅ 문자열이 와도 double 변환
          final latRaw = data['latitude'];
          final lngRaw = data['longitude'];
          _lat = double.tryParse(latRaw.toString());
          _lng = double.tryParse(lngRaw.toString());

          debugPrint("📍 서버 응답 좌표: lat=$_lat, lng=$_lng");
        } else {
          throw Exception("서버 오류: ${resp.statusCode}");
        }
      }

      if (_lat == null || _lng == null) {
        throw Exception('좌표 오류 (서버에서 null 반환)');
      }

      // ✅ 역지오코딩 (주소 변환)
      _address = await _reverseGeocode(_lat!, _lng!);
      _fetchedAt = DateTime.now();

      final pos = LatLng(_lat!, _lng!);

      // ✅ 마커 갱신
      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('marker'),
            position: pos,
            infoWindow: const InfoWindow(title: "사용자 위치"),
          )
        };
      });

      // ✅ 카메라 이동
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pos, 15));
    } catch (e) {
      _address = '주소를 가져오는 데 실패했습니다.\n$e';
      debugPrint('❌ LocationScreen load error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    final key = googleMapsApiKey;
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&language=ko&key=$key',
    );
    final resp = await http.get(uri);
    if (resp.statusCode == 200) {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      if (json['status'] == 'OK') {
        final results = json['results'] as List<dynamic>;
        if (results.isNotEmpty) {
          return results[0]['formatted_address'] as String;
        }
      }
    }
    return '주소를 가져오는 데 실패했습니다.';
  }

  Future<void> _callNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _navigate() async {
    if (_lat == null || _lng == null) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${_lat!},${_lng!}&travelmode=driving'
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fetchedStr = _fetchedAt == null
        ? ''
        : DateFormat('yyyy-MM-dd HH:mm:ss').format(_fetchedAt!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('현재 위치'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLocation)
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(_lat ?? 37.5665, _lng ?? 126.9780),
              zoom: 12,
            ),
            markers: _markers,
            onMapCreated: (controller) {
              _mapController = controller;
              _loadLocation();
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Card(
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '상세 주소',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_address ?? '주소를 가져오는 중...'),
                    if (fetchedStr.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '날짜 시간: $fetchedStr',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _callNumber('119'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)
                              ),
                            ),
                            child: const Text(
                              '119',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _callNumber('112'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)
                              ),
                            ),
                            child: const Text(
                              '112',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _navigate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)
                              ),
                            ),
                            child: const Text(
                              '길찾기',
                              style: TextStyle(color: Colors.white),
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
        ],
      ),
    );
  }
}
