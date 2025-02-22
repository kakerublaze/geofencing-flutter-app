import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotifications();
  runApp(const MyApp());
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geofencing Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  Location location = Location();
  Set<Circle> _circles = {};
  Set<Marker> _markers = {};
  LatLng? _currentPosition;
  bool _isInGeofence = false;

  // Define geofence center and radius
  static const LatLng _geofenceCenter =
      LatLng(21.197803, 72.832405); // Example: San Francisco
  static const double _geofenceRadius = 1000; // 1km radius

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _setupGeofence();
    _setupLocationTracking();
  }

  Future<void> _requestPermissions() async {
    await Permission.location.request();
    await Permission.notification.request();
  }

  void _setupGeofence() {
    _circles = {
      Circle(
        circleId: const CircleId('geofence'),
        center: _geofenceCenter,
        radius: _geofenceRadius,
        fillColor: Colors.blue.withOpacity(0.3),
        strokeColor: Colors.blue,
        strokeWidth: 2,
      ),
    };
  }

  void _setupLocationTracking() {
    location.onLocationChanged.listen((LocationData currentLocation) {
      setState(() {
        _currentPosition = LatLng(
          currentLocation.latitude!,
          currentLocation.longitude!,
        );

        _markers = {
          Marker(
            markerId: const MarkerId('currentLocation'),
            position: _currentPosition!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure),
          ),
        };

        _checkGeofence();
      });

      _controller?.animateCamera(
        CameraUpdate.newLatLng(_currentPosition!),
      );
    });
  }

  void _checkGeofence() {
    if (_currentPosition != null) {
      double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _geofenceCenter.latitude,
        _geofenceCenter.longitude,
      );

      bool isInGeofence = distance <= _geofenceRadius;

      if (isInGeofence != _isInGeofence) {
        _isInGeofence = isInGeofence;
        if (isInGeofence) {
          _showNotification(
              'Geofence Alert', 'You have entered the restricted area!');
        }
      }
    }
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'geofence_channel',
      'Geofence Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Geofencing Demo')),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: _geofenceCenter,
          zoom: 14,
        ),
        circles: _circles,
        markers: _markers,
        onMapCreated: (GoogleMapController controller) {
          _controller = controller;
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
}
