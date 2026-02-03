import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;
import 'dart:async';
import '../config/l10n.dart';

class PanicAlertScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const PanicAlertScreen({super.key, required this.data});

  @override
  State<PanicAlertScreen> createState() => _PanicAlertScreenState();
}

class _PanicAlertScreenState extends State<PanicAlertScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Maps & Location
  GoogleMapController? _mapController;
  Position? _currentPosition;
  late LatLng _targetLocation;
  Set<Marker> _markers = {};
  
  // Stream
  Stream<List<Map<String, dynamic>>>? _alertStream;
  StreamSubscription<Position>? _positionStream;
  
  // Radar / Bearing
  double _bearing = 0.0;
  double _distanceInMeters = 0.0;
  
  // ID de la alerta para suscripción
  dynamic _alertId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    // 1. Parsear ubicación inicial del payload
    double lat = double.tryParse(widget.data['sender_lat'].toString()) ?? 0.0;
    double lon = double.tryParse(widget.data['sender_lon'].toString()) ?? 0.0;
    _targetLocation = LatLng(lat, lon);

    // 2. Obtener ubicación actual y permisos
    await _checkLocationPermissions();

    // 3. Determinar ID de alerta
    _alertId = widget.data['alert_id'] ?? widget.data['id'];
    
    // Si no viene el ID, buscamos la última alerta de este remitente (por teléfono o nombre)
    if (_alertId == null) {
      try {
        final String? senderPhone = widget.data['sender_phone'];
        if (senderPhone != null) {
          final response = await _supabase
              .from('alertas')
              .select('id')
              .eq('sender_phone', senderPhone)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle(); // Usar maybeSingle para evitar excepción si no hay resultados
          
          if (response != null) {
            _alertId = response['id'];
          }
        }
      } catch (e) {
        debugPrint('Error buscando ID de alerta: $e');
      }
    }

    // 4. Iniciar Stream si tenemos ID, si no, nos quedamos con los datos estáticos
    if (_alertId != null) {
      _setupSupabaseStream();
    }

    setState(() {
      _isLoading = false;
      _updateMarkers();
    });
  }

  Future<void> _checkLocationPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    // Obtener posición inicial
    _currentPosition = await Geolocator.getCurrentPosition();
    _updateBearingAndDistance();

    // Escuchar cambios de posición
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position? position) {
      if (position != null) {
        setState(() {
          _currentPosition = position;
          _updateBearingAndDistance();
        });
      }
    });
  }

  void _setupSupabaseStream() {
    _alertStream = _supabase
        .from('alertas')
        .stream(primaryKey: ['id'])
        .eq('id', _alertId)
        .map((maps) => maps); // maps es List<Map<String, dynamic>>

    _alertStream!.listen((List<Map<String, dynamic>> data) {
      if (data.isNotEmpty) {
        final alert = data.first;
        final newLat = double.tryParse(alert['lat'].toString()) ?? _targetLocation.latitude;
        final newLon = double.tryParse(alert['lon'].toString()) ?? _targetLocation.longitude;
        
        setState(() {
          _targetLocation = LatLng(newLat, newLon);
          _updateMarkers();
          _updateBearingAndDistance();
          
          // Actualizar centro del mapa si es necesario
          _mapController?.animateCamera(CameraUpdate.newLatLng(_targetLocation));
        });
      }
    });
  }

  void _updateMarkers() {
    _markers = {
      // Marcador del Hermano (Rojo)
      Marker(
        markerId: const MarkerId('target'),
        position: _targetLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: widget.data['sender_name'] ?? L10n.brotherLabel(context)),
      ),
    };
  }

  void _updateBearingAndDistance() {
    if (_currentPosition == null) return;

    _distanceInMeters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _targetLocation.latitude,
      _targetLocation.longitude,
    );

    _bearing = Geolocator.bearingBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _targetLocation.latitude,
      _targetLocation.longitude,
    );
  }

  Future<void> _launchNavigation() async {
    final lat = _targetLocation.latitude;
    final lon = _targetLocation.longitude;
    final googleMapsUrl = Uri.parse('google.navigation:q=$lat,$lon');
    final appleMapsUrl = Uri.parse('http://maps.apple.com/?daddr=$lat,$lon');

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl);
    } else if (await canLaunchUrl(appleMapsUrl)) {
      await launchUrl(appleMapsUrl);
    } else {
      final webUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
      await launchUrl(webUrl);
    }
  }

  Future<void> _makeCall() async {
    final phone = widget.data['sender_phone'];
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _openFullScreenMap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenMapScreen(
          targetLocation: _targetLocation,
          currentPosition: _currentPosition,
          markers: _markers,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPanic = widget.data['alert_type'] == 'panic';
    final name = widget.data['sender_name'] ?? L10n.unknownBrotherLabel(context);
    final grade = widget.data['sender_grade'] ?? '';
    final lodge = widget.data['sender_lodge'] ?? '';

    return Scaffold(
      backgroundColor: Colors.red.shade900,
      appBar: AppBar(
        backgroundColor: Colors.red.shade800,
        elevation: 0,
        title: Text(isPanic ? L10n.panicAlertTitle(context) : L10n.assistanceRequestTitleUpper(context), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false, 
        actions: [
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop())
        ],
      ),
      body: Column(
        children: [
          // 1. MAPA INTERACTIVO (Mitad Superior)
          Expanded(
            flex: 5,
            child: GestureDetector(
              onTap: _openFullScreenMap, // Tap para pantalla completa (aunque GoogleMap captura gestures)
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _targetLocation,
                      zoom: 15,
                    ),
                    markers: _markers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    onMapCreated: (controller) => _mapController = controller,
                    onTap: (_) => _openFullScreenMap(), // Capturar tap en el mapa
                  ),
                  // Botón flotante para expandir
                  Positioned(
                    right: 10,
                    top: 10,
                    child: FloatingActionButton.small(
                      onPressed: _openFullScreenMap,
                      backgroundColor: Colors.white,
                      child: const Icon(Icons.fullscreen, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 2. INFORMACIÓN Y RADA (Mitad Inferior)
          Expanded(
            flex: 6, // Un poco más de espacio para la info
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  // Info del Hermano
                  Text(
                    '$grade $name',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  Text(
                    lodge,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),
                  
                  // Radar / Brújula
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Flecha giratoria
                      Transform.rotate(
                        angle: (_bearing * (math.pi / 180)), // Rotación positiva (horaria) para coincidir con bearing
                        // Para una brújula real necesitaríamos flutter_compass, aquí usamos bearing relativo si tuviéramos rumbo dispositivo
                        // Como no tenemos rumbo del dispositivo, mostramos la flecha fija apuntando al 'bearing'
                        // Mejor: Usar un icono estático que indique "Rumbo: X grados" o simplemente la distancia
                        child: const Icon(Icons.navigation, size: 50, color: Colors.red),
                      ),
                      const SizedBox(width: 20),
                       Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            L10n.distanceLabel(context),
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                          ),
                          Text(
                            _distanceInMeters > 1000 
                                ? '${(_distanceInMeters / 1000).toStringAsFixed(1)} km'
                                : '${_distanceInMeters.toStringAsFixed(0)} m',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ],
                      )
                    ],
                  ),
                  
                  const Spacer(),
                  
                  // Botones de Acción
                  Row(
                    children: [
                      Expanded(
                         child: ElevatedButton.icon(
                          onPressed: _makeCall,
                          icon: const Icon(Icons.call),
                          label: Text(L10n.callButton(context)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                         child: ElevatedButton.icon(
                          onPressed: _launchNavigation,
                          icon: const Icon(Icons.near_me), // Icono de navegación
                          label: Text(L10n.goNowButton(context)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- PANTALLA MAPA COMPLETO ---
class FullScreenMapScreen extends StatelessWidget {
  final LatLng targetLocation;
  final Position? currentPosition;
  final Set<Marker> markers;

  const FullScreenMapScreen({
    super.key,
    required this.targetLocation,
    this.currentPosition,
    required this.markers,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: targetLocation,
              zoom: 16,
            ),
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Positioned(
            top: 40,
            left: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              child: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
          )
        ],
      ),
    );
  }
}
