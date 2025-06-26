import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Velocímetro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const SpeedometerScreen(),
    );
  }
}

class SpeedometerScreen extends StatefulWidget {
  const SpeedometerScreen({super.key});

  @override
  State<SpeedometerScreen> createState() => _SpeedometerScreenState();
}

class _SpeedometerScreenState extends State<SpeedometerScreen> {
  double _currentSpeed = 0.0;
  double _distance = 0.0;
  double _averageSpeed = 0.0;
  Duration _elapsedTime = Duration.zero;
  Position? _lastPosition;
  DateTime? _startTime;
  bool _isTracking = false;
  final _numberFormat = NumberFormat('#,##0.0', 'pt_BR');
  
  // Mapa
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<LatLng> _trackPoints = [];
  
  // Busca de endereço
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  
  // Posição inicial (São Paulo)
  static const LatLng _initialPosition = LatLng(-23.5505, -46.6333);

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _lastPosition = position;
        _addMarker(LatLng(position.latitude, position.longitude), 'Sua posição');
      });
      
      _animateToPosition(LatLng(position.latitude, position.longitude));
    } catch (e) {
      print('Erro ao obter localização: $e');
    }
  }

  void _startTracking() async {
    setState(() {
      _isTracking = true;
      _startTime = DateTime.now();
      _distance = 0.0;
      _averageSpeed = 0.0;
      _elapsedTime = Duration.zero;
      _trackPoints.clear();
      _polylines.clear();
    });

    await WakelockPlus.enable();

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).listen((Position position) {
      LatLng currentLatLng = LatLng(position.latitude, position.longitude);
      
      if (_lastPosition != null) {
        double distanceInMeters = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );

        setState(() {
          _distance += distanceInMeters / 1000;
          _currentSpeed = position.speed * 3.6;
          _elapsedTime = DateTime.now().difference(_startTime!);
          if (_elapsedTime.inSeconds > 0) {
            _averageSpeed = (_distance / _elapsedTime.inHours);
          }
          
          // Adicionar ponto ao rastro
          _trackPoints.add(currentLatLng);
          _updateTrackPolyline();
          
          // Atualizar marcador de posição atual
          _updateCurrentPositionMarker(currentLatLng);
        });
      } else {
        setState(() {
          _trackPoints.add(currentLatLng);
          _updateTrackPolyline();
          _updateCurrentPositionMarker(currentLatLng);
        });
      }
      _lastPosition = position;
    });
  }

  void _stopTracking() {
    setState(() {
      _isTracking = false;
      _currentSpeed = 0.0;
    });
    WakelockPlus.disable();
  }

  void _reset() {
    setState(() {
      _distance = 0.0;
      _averageSpeed = 0.0;
      _elapsedTime = Duration.zero;
      _startTime = DateTime.now();
      _lastPosition = null;
      _trackPoints.clear();
      _polylines.clear();
      _markers.clear();
    });
  }

  void _addMarker(LatLng position, String title) {
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId(title),
          position: position,
          infoWindow: InfoWindow(title: title),
        ),
      );
    });
  }

  void _updateCurrentPositionMarker(LatLng position) {
    setState(() {
      _markers.removeWhere((marker) => marker.markerId.value == 'Posição Atual');
      _markers.add(
        Marker(
          markerId: const MarkerId('Posição Atual'),
          position: position,
          infoWindow: const InfoWindow(title: 'Posição Atual'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    });
  }

  void _updateTrackPolyline() {
    if (_trackPoints.length > 1) {
      setState(() {
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('track'),
            points: _trackPoints,
            color: Colors.blue,
            width: 3,
          ),
        );
      });
    }
  }

  void _animateToPosition(LatLng position) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(position, 15),
    );
  }

  Future<void> _searchAddress(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // Usar a API de geocoding do Google (requer chave de API)
      // Por simplicidade, vou usar uma busca básica
      List<Location> locations = await locationFromAddress(query);
      
      setState(() {
        _searchResults = locations.map((location) => {
          'name': query,
          'latitude': location.latitude,
          'longitude': location.longitude,
        }).toList();
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults.clear();
        _isSearching = false;
      });
      print('Erro na busca: $e');
    }
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    LatLng position = LatLng(result['latitude'], result['longitude']);
    _addMarker(position, result['name']);
    _animateToPosition(position);
    
    setState(() {
      _searchResults.clear();
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Velocímetro',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Barra de busca
          _buildSearchBar(),
          // Mapa
          Expanded(
            flex: 2,
            child: _buildMap(),
          ),
          // Painel de velocímetro
          Expanded(
            flex: 1,
            child: _buildSpeedometerPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.primary,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _searchAddress,
            decoration: InputDecoration(
              hintText: 'Buscar endereço...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
          ),
          if (_searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return ListTile(
                    leading: const Icon(Icons.location_on),
                    title: Text(result['name']),
                    onTap: () => _selectSearchResult(result),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return GoogleMap(
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
      },
      initialCameraPosition: const CameraPosition(
        target: _initialPosition,
        zoom: 15,
      ),
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
    );
  }

  Widget _buildSpeedometerPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildSpeedDisplay(),
          const SizedBox(height: 20),
          _buildInfoCards(),
          const SizedBox(height: 20),
          _buildControlButtons(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSpeedDisplay() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            'VELOCIDADE ATUAL',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_numberFormat.format(_currentSpeed)}',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const Text(
            'km/h',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildInfoCard(
              'Distância',
              '${_numberFormat.format(_distance)} km',
              Icons.route,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildInfoCard(
              'Média',
              '${_numberFormat.format(_averageSpeed)} km/h',
              Icons.speed,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildInfoCard(
              'Tempo',
              _formatDuration(_elapsedTime),
              Icons.timer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: _isTracking ? _stopTracking : _startTracking,
            icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
            label: Text(_isTracking ? 'Parar' : 'Iniciar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isTracking ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
          const SizedBox(width: 20),
          ElevatedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh),
            label: const Text('Reset'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }
}
