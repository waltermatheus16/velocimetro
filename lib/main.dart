import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
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

  void _startTracking() async {
    setState(() {
      _isTracking = true;
      _startTime = DateTime.now();
      _distance = 0.0;
      _averageSpeed = 0.0;
      _elapsedTime = Duration.zero;
    });

    await WakelockPlus.enable();

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).listen((Position position) {
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildSpeedDisplay(),
              const SizedBox(height: 30),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.background,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
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
                      _buildInfoCards(),
                      const SizedBox(height: 20),
                      _buildControlButtons(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_numberFormat.format(_currentSpeed)}',
            style: const TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Text(
            'km/h',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: Colors.white,
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
