import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PanicAlertScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const PanicAlertScreen({super.key, required this.data});

  Future<void> _launchNavigation() async {
    final lat = data['sender_lat'];
    final lon = data['sender_lon'];
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
    final phone = data['sender_phone'];
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPanic = data['alert_type'] == 'panic';
    final name = data['sender_name'] ?? 'Hermano desconocido';
    final grade = data['sender_grade'] ?? '';
    final lodge = data['sender_lodge'] ?? '';
    final granLogia = data['sender_gran_logia'] ?? '';
    final details = data['details'] ?? '';

    return Scaffold(
      backgroundColor: Colors.red.shade900,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 100,
              ),
              const SizedBox(height: 20),
              Text(
                isPanic ? '¡ALERTA DE PÁNICO!' : 'SOLICITUD DE AUXILIO',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      '$grade $name',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lodge,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    Text(
                      granLogia,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    if (details.isNotEmpty) ...[
                      const Divider(color: Colors.white24, height: 30),
                      Text(
                        'Detalles: $details',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _makeCall,
                      icon: const Icon(Icons.call),
                      label: const Text('LLAMAR'),
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
                      icon: const Icon(Icons.navigation),
                      label: const Text('IR AHORA'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'DETENER ALARMA Y CERRAR',
                  style: TextStyle(color: Colors.white70, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
