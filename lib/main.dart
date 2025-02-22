import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

// This is the background task handler
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case 'checkGeofence':
        await checkGeofenceInBackground();
        break;
    }
    return Future.value(true);
  });
}

Future<void> checkGeofenceInBackground() async {
  final prefs = await SharedPreferences.getInstance();
  final geofenceLat = prefs.getDouble('geofenceLat') ?? 37.7749;
  final geofenceLng = prefs.getDouble('geofenceLng') ?? -122.4194;
  final geofenceRadius = prefs.getDouble('geofenceRadius') ?? 1000.0;
  final wasInside = prefs.getBool('wasInside') ?? false;

  try {
    // Get current position with low accuracy to save battery
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
      ),
    );

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      geofenceLat,
      geofenceLng,
    );

    final isInside = distance <= geofenceRadius;

    // Only notify if the state has changed
    if (isInside != wasInside) {
      await showBackgroundNotification(
        isInside ? 'Entered Restricted Area' : 'Left Restricted Area',
        isInside
            ? 'You have entered the restricted zone'
            : 'You have left the restricted zone',
      );
      await prefs.setBool('wasInside', isInside);
    }
  } catch (e) {
    debugPrint('Background location error: $e');
  }
}

Future<void> showBackgroundNotification(String title, String body) async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Workmanager
  await Workmanager().initialize(callbackDispatcher);

  // Initialize notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await FlutterLocalNotificationsPlugin().initialize(initializationSettings);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Background Geofencing Demo',
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
  Set<Circle> _circles = {};
  final Set<Marker> _markers = {};
  static const LatLng _geofenceCenter = LatLng(21.197803, 72.832405);
  static const double _geofenceRadius = 1000;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _setupGeofence();
    _initializeBackgroundTask();
    _saveGeofenceData();
  }

  Future<void> _saveGeofenceData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('geofenceLat', _geofenceCenter.latitude);
    await prefs.setDouble('geofenceLng', _geofenceCenter.longitude);
    await prefs.setDouble('geofenceRadius', _geofenceRadius);
  }

  Future<void> _requestPermissions() async {
    await Permission.location.request();
    await Permission.notification.request();

    // Request background location permission
    if (await Permission.location.isGranted) {
      await Permission.locationAlways.request();
    }
  }

  Future<void> _initializeBackgroundTask() async {
    await Workmanager().registerPeriodicTask(
      "checkGeofence",
      "checkGeofence",
      frequency: const Duration(minutes: 15), // Minimum interval in Android
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Geofencing Demo'),
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
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
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Background monitoring is active\nChecks location every 15 minutes',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
