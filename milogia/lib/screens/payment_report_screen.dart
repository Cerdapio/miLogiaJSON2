import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:milogia/models/user_model.dart';
import 'package:milogia/models/pago_model.dart';
import 'package:milogia/config/auth_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milogia/screens/app_drawer.dart';
import 'package:milogia/screens/pago_screen.dart';
import 'package:dio/dio.dart' as dio;

class PaymentReportScreen extends StatefulWidget {
  final RootModel root;
  final PerfilOpcion selectedProfile;

  const PaymentReportScreen({super.key, required this.root, required this.selectedProfile});

  @override
  State<PaymentReportScreen> createState() => _PaymentReportScreenState();
}

class _PaymentReportScreenState extends State<PaymentReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montoController = TextEditingController();
  final _folioController = TextEditingController();
  final _referenciaController = TextEditingController(); // La referencia interna de la ficha
  DateTime _fechaPago = DateTime.now();
  File? _imageFile;
  bool _isUploading = false;
  late LogiaTheme _theme;

  // NUEVOS CAMPOS PARA RELACIÓN
  List<PagoModel> _pendingPagos = [];
  PagoModel? _selectedPago;
  bool _isLoadingPagos = true;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _fetchPendingPagos();
  }

  Future<void> _fetchPendingPagos() async {
    try {
      final supabase = Supabase.instance.client;
      // 1. Obtener pagos pendientes (fichas generadas)
      final response = await supabase
          .from('movcPagos')
          .select()
          .eq('idUsuario', widget.root.user.idUsuario)
          .eq('idFormaPago', 2) // 2 = Transferencia
          .eq('Estatus', 'Pendiente') 
          .eq('Activo', true)
          .order('Fecha', ascending: false);

      // 2. Obtener reportes activos para excluirlos (Todo lo que NO sea Rechazado)
      final existingReports = await supabase
          .from('movcPagosReportados')
          .select('idPago')
          .eq('idUsuario', widget.root.user.idUsuario)
          .neq('Estatus', 'Rechazado'); // Traemos todo lo que NO esté rechazado (Revision, Aprobado, etc)

      final reportedIds = (existingReports as List)
          .map((r) => r['idPago'] as int?)
          .where((id) => id != null)
          .toSet();

      final data = response as List<dynamic>;
      setState(() {
        // Filtrar aquellos pagos que YA tienen un reporte activo
        _pendingPagos = data
            .map((e) => PagoModel.fromJson(e))
            .where((p) => !reportedIds.contains(p.idPago))
            .toList();
            
        _isLoadingPagos = false;
      });
    } catch (e) {
      print('Error cargando pagos filtrados: $e');
      setState(() => _isLoadingPagos = false);
    }
  }

  void _loadTheme() {
    final colores = widget.selectedProfile.colores;
    _theme = LogiaTheme(
      nombre: 'Dynamic',
      primaryColor: _parseHex(colores.C1, const Color(0xFFF5F5F5)),
      secondaryColor: _parseHex(colores.C4, const Color(0xFFDAA520)),
      accentColor: _parseHex(colores.C2, const Color(0xFF222222)),
      backgroundColor: _parseHex(colores.C3, Colors.white),
    );
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await showModalBottomSheet<XFile?>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Tomar Foto'),
            onTap: () async => Navigator.pop(ctx, await picker.pickImage(source: ImageSource.camera, imageQuality: 70)),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Galería'),
            onTap: () async => Navigator.pop(ctx, await picker.pickImage(source: ImageSource.gallery, imageQuality: 70)),
          ),
        ],
      ),
    );

    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate() || _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor llena todos los campos y sube la foto del comprobante')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 1. Subir imagen usando Edge Function (bypass RLS)
      final bytes = await _imageFile!.readAsBytes();
      final functionUrl = '$supabaseUrl/functions/v1/upload-radio';
      final headers = {
        'Authorization': 'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken}',
      };

      final formData = dio.FormData();
      formData.files.add(MapEntry(
        'file', 
        dio.MultipartFile.fromBytes(bytes, filename: 'payment_${DateTime.now().millisecondsSinceEpoch}.jpg')
      ));
      formData.fields.add(MapEntry('logiaId', widget.selectedProfile.idLogia.toString()));
      formData.fields.add(const MapEntry('folder', 'payments'));

      final dioClient = dio.Dio();
      final uploadResponse = await dioClient.post(
        functionUrl,
        data: formData,
        options: dio.Options(headers: headers),
      );

      if (uploadResponse.statusCode != 200) {
        throw Exception('Error al subir comprobante via Function: ${uploadResponse.data['error']}');
      }

      final String filePath = uploadResponse.data['filePath'];
      // La URL pública sigue siendo útil para la UI, pero guardamos el PATH en la DB
      // final String publicUrl = uploadResponse.data['publicUrl'];

      // 2. Guardar reporte en base de datos
      await Supabase.instance.client.from('movcPagosReportados').insert({
        'iddLogia': widget.selectedProfile.idLogia,
        'idUsuario': widget.root.user.idUsuario,
        'FechaPagoReal': DateFormat('yyyy-MM-dd').format(_fechaPago),
        'Monto': double.parse(_montoController.text),
        'FolioBancario': _folioController.text,
        'ReferenciaUnica': _referenciaController.text,
        'UrlComprobante': filePath, // Guardamos el path relativo para el bucket
        'MetodoPago': 'Transferencia',
        'Estatus': 'Revision',
        'idPago': _selectedPago?.idPago, 
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte enviado con éxito. El Tesorero lo validará pronto.')),
        );
        // Navegamos a PagoScreen para evitar pantalla negra (stack vacío desde Drawer)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PagoScreen(
              root: widget.root,
              selectedProfile: widget.selectedProfile,
              initialTab: 0, // Volver a "Mis Pagos"
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _theme.backgroundColor,
      appBar: AppBar(
        title: Text('REPORTAR PAGO', style: TextStyle(color: _theme.secondaryColor, fontWeight: FontWeight.bold)),
        backgroundColor: _theme.primaryColor,
        iconTheme: IconThemeData(color: _theme.secondaryColor),
      ),
      drawer: AppDrawer(root: widget.root, selectedProfile: widget.selectedProfile),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ingresa los datos de tu transferencia', style: TextStyle(color: _theme.primaryColor, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              if (_isLoadingPagos)
                const Center(child: CircularProgressIndicator())
              else if (_pendingPagos.isNotEmpty) ...[
                Text('Selecciona un pago pendiente (opcional)', style: TextStyle(color: _theme.primaryColor.withOpacity(0.7), fontSize: 14)),
                const SizedBox(height: 8),
                DropdownButtonFormField<PagoModel>(
                  value: _selectedPago,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.list_alt),
                  ),
                  isExpanded: true,
                  hint: const Text('Pagos generados sin reportar'),
                  items: [
                    const DropdownMenuItem<PagoModel>(
                      value: null,
                      child: Text('Otro (Ingreso manual)'),
                    ),
                    ..._pendingPagos.map((p) => DropdownMenuItem(
                      value: p,
                      child: Text('\$${p.importe} - ${p.fecha} (ID: ${p.idPago})'),
                    )),
                  ],
                  onChanged: (PagoModel? val) {
                    setState(() {
                      _selectedPago = val;
                      if (val != null) {
                        _montoController.text = val.importe.toString();
                        _referenciaController.text = val.idPago.toString(); // Usamos el ID como referencia sugerida
                      }
                    });
                  },
                ),
                const SizedBox(height: 20),
              ],
              
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _montoController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Monto Pagado',
                          prefixText: '\$ ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 15),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _fechaPago,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setState(() => _fechaPago = picked);
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Fecha del Pago',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            prefixIcon: const Icon(Icons.calendar_today),
                          ),
                          child: Text(DateFormat('dd/MM/yyyy').format(_fechaPago)),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _folioController,
                        decoration: InputDecoration(
                          labelText: 'Folio o Clave de Rastreo (Opcional)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _referenciaController,
                        decoration: InputDecoration(
                          labelText: 'Referencia de la Ficha (Opcional)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 25),
              Text('Comprobante (Imagen)', style: TextStyle(color: _theme.primaryColor, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              
              Center(
                child: InkWell(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: _theme.primaryColor.withOpacity(0.3), width: 2),
                    ),
                    child: _imageFile == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, size: 50, color: _theme.primaryColor),
                              const SizedBox(height: 10),
                              const Text('Toca para subir foto del comprobante'),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.file(_imageFile!, fit: BoxFit.cover),
                          ),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _theme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: _isUploading ? null : _submitReport,
                  child: _isUploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('ENVIAR REPORTE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
