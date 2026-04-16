import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/user_model.dart';
import '../config/l10n.dart';

class CredencialScreen extends StatefulWidget {
  final RootModel root;
  final PerfilOpcion selectedProfile;

  const CredencialScreen({
    Key? key,
    required this.root,
    required this.selectedProfile,
  }) : super(key: key);

  @override
  State<CredencialScreen> createState() => _CredencialScreenState();
}

class _CredencialScreenState extends State<CredencialScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFront = true;

  // Gyroscope variables
  double _pitch = 0.0;
  double _roll = 0.0;
  StreamSubscription<AccelerometerEvent>? _gyroscopeSubscription;

  // TOTP QR Data
  late String _qrData;
  Timer? _qrTimer;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _setupGyroscope();
    _generateQRData();

    // Regenerate QR every 5 minutes
    _qrTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _generateQRData();
    });
  }

  void _setupGyroscope() {
    _gyroscopeSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      if (!mounted) return;
      setState(() {
        // Map accelerometer output (-9.8 to 9.8 roughly) to a -1.0 to 1.0 ratio
        // When device is held vertically, Y is roughly 9.8, so we compare variation
        _pitch = ((event.y - 4.9) / 4.9).clamp(-1.0, 1.0);
        _roll = (-event.x / 4.9).clamp(-1.0, 1.0);
      });
    });
  }

  void _generateQRData() {
    setState(() {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _qrData = "https://google.com/?val=$timestamp";
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    _gyroscopeSubscription?.cancel();
    _qrTimer?.cancel();
    super.dispose();
  }

  void _toggleFlip() {
    if (_isFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    _isFront = !_isFront;
  }

  Color _parseHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    String h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    try {
      return Color(int.parse(h, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  String _driveToDirect(String url) {
    if (url.contains('drive.google.com')) {
      final idMatch = RegExp(r'/d/([a-zA-Z0-9_-]{10,})').firstMatch(url);
      if (idMatch != null) return 'https://drive.google.com/uc?export=view&id=${idMatch.group(1)}';
      final idQuery = RegExp(r'id=([a-zA-Z0-9_-]{10,})').firstMatch(url);
      if (idQuery != null) return 'https://drive.google.com/uc?export=view&id=${idQuery.group(1)}';
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = widget.selectedProfile.colores;
    final primaryTheme = _parseHex(themeColors.C1, const Color(0xFFF5F5F5));
    final secondaryTheme = _parseHex(themeColors.C4, const Color(0xFFDAA520));

    return Scaffold(
      backgroundColor: Colors.black, // Dark background around the card
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Pasaporte Masónico",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w300),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: GestureDetector(
            onTap: _toggleFlip,
            child: AnimatedBuilder(
              animation: _flipAnimation,
              builder: (context, child) {
                final angle = _flipAnimation.value * pi;
                final transform = Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // Perspective
                  ..rotateY(angle);

                return Transform(
                  transform: transform,
                  alignment: Alignment.center,
                  child: angle >= (pi / 2)
                      ? Transform(
                          transform: Matrix4.identity()..rotateY(pi),
                          alignment: Alignment.center,
                          child: _buildBackCard(secondaryTheme),
                        )
                      : _buildFrontCard(secondaryTheme),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContainer({required Widget child, required Color accentColor}) {
    // Aceleration-based shimmer for metallic effect over the background
    final double shimmerX = _roll;
    final double shimmerY = _pitch;

    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.85, // Fill more space
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF0a0b0d), // Base dark color
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
            offset: Offset(shimmerX * 10, shimmerY * 10),
          )
        ],
        border: Border.all(
          color: accentColor.withOpacity(0.5 + (_pitch.abs() * 0.5).clamp(0.0, 0.5)),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Marca de agua de Mosaico (Logo) que recibe el destello
            Positioned.fill(
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) {
                  return RadialGradient(
                    center: Alignment(shimmerX, shimmerY),
                    radius: 2.0,
                    colors: [
                      accentColor.withOpacity(0.0), // Sombra base
                      Colors.amber.withOpacity((0.6 + (_roll.abs() * 0.8)).clamp(0.0, 1.0)), // Luz dorada metálica más fuerte
                      accentColor.withOpacity(0.0),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ).createShader(bounds);
                },
                child: Opacity(
                  opacity: 0.4, // Mayor opacidad para que se vea claramente
                  child: Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 280,
                      height: 280,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            
            // Main Content
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildFrontCard(Color themeAccent) {
    final user = widget.root.user;
    final profile = widget.selectedProfile;
    
    // Simulate regularity logic (Mock boolean)
    final bool esRegular = true; 
    final Color regularityColor = esRegular ? Colors.greenAccent : Colors.redAccent.withOpacity(0.5);

    final double shimmerX = _roll * 0.3;
    final double shimmerY = _pitch * 0.3;

    // Signature Fetch
    final firmasActivas = widget.root.catalogos.firmas_catalogo
        .where((f) => f.iddLogia == widget.selectedProfile.idLogia && f.activo);
    final vmSignatureUrl = firmasActivas.isNotEmpty ? firmasActivas.first.vm : "";
    final secSignatureUrl = firmasActivas.isNotEmpty ? firmasActivas.first.sec : "";

    return _buildCardContainer(
      accentColor: themeAccent,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // MITAD SUPERIOR (FOTO, NOMBRE, DATOS LOGIA)
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Titulo
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "GRAN LOGIA COSMOS A.C.",
                            style: TextStyle(
                              color: themeAccent,
                              fontSize: 16,
                              letterSpacing: 1.0,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            "(CHIHUAHUA, MÉXICO)",
                            style: TextStyle(
                              color: themeAccent.withOpacity(0.8),
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "MEMBRESÍA Nº LPT411124", // Placeholder
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      
                      const Spacer(),
                      
                      // Row: Photo & Basic Data
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Center: Profile Image with glowing rectangular border
                          Container(
                            width: 100,
                            height: 130,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: regularityColor.withOpacity(0.6),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                )
                              ],
                              border: Border.all(color: regularityColor, width: 3),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: user.Foto.isNotEmpty
                                  ? Image.network(
                                      _driveToDirect(user.Foto),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 70, color: Colors.white),
                                    )
                                  : const Icon(Icons.person, size: 70, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 10),
                                Text(
                                  user.Nombre.toUpperCase(),
                                  style: TextStyle(
                                    color: themeAccent,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  esRegular ? "REGULARIDAD ACTIVA (Verde)" : "IRREGULAR (Rojo)",
                                  style: TextStyle(
                                    color: regularityColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  profile.Abreviatura.isNotEmpty ? profile.Abreviatura : "M⸫M⸫ (MAESTRO MASÓN)",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "PUESTO: ${profile.PerfilNombre}\n(2024-2026)",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const Spacer(),

                      // Masonic Data List
                      _buildCenteredDataRow("INICIADO:", user.FechaNacimiento, themeAccent), // Map correct field later
                      const SizedBox(height: 4),
                      _buildCenteredDataRow("LOGIA MADRE:", profile.LogiaNombre, themeAccent),
                      const SizedBox(height: 2),
                      Text(
                        "CHIH. - MÉXICO",
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(color: Colors.white24, height: 1),
                ),

                // MITAD INFERIOR (50% - CÓDIGO QR Y FIRMA)
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // QR Code placed in front
                      Column(
                        children: [
                          Text(
                            "ESCANÉAME\n(VALIDACIÓN GLOBAL)",
                            style: TextStyle(color: themeAccent, fontSize: 12, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: themeAccent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: QrImageView(
                              data: _qrData,
                              version: QrVersions.auto,
                              size: 100.0, // QR ligeramente más pequeño
                              backgroundColor: themeAccent,
                              foregroundColor: Colors.black, // Dark QR
                            ),
                          ),
                        ],
                      ),

                      // 3 Firmas al frente
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildSignatureCol("SEC⸫", secSignatureUrl, themeAccent),
                          _buildSignatureCol("V⸫ M⸫", vmSignatureUrl, themeAccent),
                          _buildSignatureCol("ORAD⸫", "", themeAccent),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Hovering 3D Hologram - Efecto Tornasol ajustado para verse y sentirse plata holográfica
          Positioned(
            top: 20 + (shimmerY * 15),
            left: 20 + (shimmerX * 15),
            child: ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (bounds) => RadialGradient(
                center: Alignment.center,
                radius: 0.5,
                //begin: Alignment.topLeft,
                //end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.0),
                  Colors.blueAccent.withOpacity(0.5),
                  Colors.purpleAccent.withOpacity(0.5),
                  Colors.white.withOpacity(0.8),
                  Colors.greenAccent.withOpacity(0.5),
                ],
                stops: [0.0, 0.2 + _roll.abs(), 0.5, 0.8 - _pitch.abs(), 1.0],
                transform: GradientRotation(_roll * pi),
              ).createShader(bounds),
              child: Opacity(
                opacity: 0.8 + (_pitch.abs() * 0.2), 
                child: Image.asset(
                  'assets/images/hologram_icon.png',
                  width: 55,
                  // Si no lo encuentra o no aplica shader sin base color
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenteredDataRow(String label, String value, Color accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: accent,
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDataColumn(String label, String value, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 10,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBackCard(Color themeAccent) {
    final user = widget.root.user;
    // Extracting emergency info
    String bloodType = "O+"; // Mock or extract from user if available
    String allergies = "Ninguna"; // Mock or extract
    String emergencyContact = "N/A";
    
    if (user.contactosEmergencia.isNotEmpty) {
      emergencyContact = "${user.contactosEmergencia.first.Nombre} - ${user.contactosEmergencia.first.Telefono}";
    }

    return _buildCardContainer(
      accentColor: themeAccent,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "INFORMACIÓN ADICIONAL",
                style: TextStyle(color: themeAccent, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Emergency Data Detailed
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildDataColumn("SANGRE", bloodType, themeAccent),
                        _buildDataColumn("ALERGIAS", allergies, themeAccent),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDataColumn("AVISO DE EMERGENCIA", emergencyContact, themeAccent),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Other details or placeholders for future features
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("DIRECCIÓN DE LA LOGIA:", style: TextStyle(color: themeAccent, fontSize: 9)),
                    const SizedBox(height: 2),
                    Text("Conocida (Consultar en App)", style: TextStyle(color: Colors.white, fontSize: 11)),
                    
                    const SizedBox(height: 12),
                    Text("VIGENCIA DE CREDENCIAL:", style: TextStyle(color: themeAccent, fontSize: 9)),
                    const SizedBox(height: 2),
                    Text("2024 - 2026", style: TextStyle(color: Colors.white, fontSize: 11)),
                  ],
                ),
              ),

              // La sección completa de firmas fue trasladada arriba.
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildSignatureCol(String label, String url, Color themeAccent) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 35,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white38, width: 1)),
          ),
          child: Center(
            child: url.isNotEmpty
                ? Image.network(
                    _driveToDirect(url),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _buildSignaturePlaceholder(themeAccent, size: 10),
                  )
                : _buildSignaturePlaceholder(themeAccent, size: 10),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white54, fontSize: 8, letterSpacing: 1.0),
        ),
      ],
    );
  }

  Widget _buildSignaturePlaceholder(Color themeAccent, {double size = 16}) {
    return Text(
      "Firma Digital",
      style: TextStyle(
        fontFamily: 'Cursive',
        color: themeAccent,
        fontSize: size,
      ),
    );
  }
}

// El CustomPainter MasonicGridPainter ya no de dibujará, se deja preparado o comentado si se necesita para otras partes.
