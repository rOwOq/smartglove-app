import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AlertMapScreen extends StatelessWidget {
  final double latitude;
  final double longitude;

  const AlertMapScreen({
    Key? key,
    required this.latitude,
    required this.longitude,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final LatLng alertPosition = LatLng(latitude, longitude);

    return Scaffold(
      appBar: AppBar(title: const Text('📍 알림 위치 지도')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: alertPosition,
          zoom: 16,
        ),
        markers: {
          Marker(
            markerId: const MarkerId('alert'),
            position: alertPosition,
            infoWindow: const InfoWindow(title: '이상 행동 위치'),
          ),
        },
      ),
    );
  }
}
