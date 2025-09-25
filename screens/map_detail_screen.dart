import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapDetailScreen extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String timestamp;

  const MapDetailScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final LatLng position = LatLng(latitude, longitude);

    return Scaffold(
      appBar: AppBar(title: const Text('🗺️ 위치 상세 보기')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: position,
          zoom: 16,
        ),
        markers: {
          Marker(
            markerId: const MarkerId('selected_location'),
            position: position,
            infoWindow: InfoWindow(
              title: '위치',
              snippet: timestamp,
            ),
          ),
        },
      ),
    );
  }
}
