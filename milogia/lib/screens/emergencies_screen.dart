import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';


import '../models/user_model.dart';
//import 'home_screen.dart';
//import 'emergencies_screen.dart';

import '../models/emergency_model.dart';
import 'app_drawer.dart';
import '../utils/dropdown_utils.dart';

final _supabase = Supabase.instance.client;

class EmergenciesScreen extends StatefulWidget {
  final RootModel root;
  final PerfilOpcion selectedProfile;
  const EmergenciesScreen({super.key, required this.root, required this.selectedProfile});

  @override
  State<EmergenciesScreen> createState() => _EmergenciesScreenState();
}

class _EmergenciesScreenState extends State<EmergenciesScreen> {
  late Future<List<EmergencyModel>> _emergenciesFuture;
  bool _isXiaomi = false;
  bool _miuiPermissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _emergenciesFuture = _fetchEmergencies();
    _checkDeviceType();
  }

  Future<void> _checkDeviceType() async {
    if (Platform.isAndroid) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        final manufacturer = androidInfo.manufacturer.toLowerCase();
        if (manufacturer.contains('xiaomi') || 
            manufacturer.contains('redmi') || 
            manufacturer.contains('poco')) {
          if (mounted) setState(() => _isXiaomi = true);
          
          // Verificar si ya tiene los permisos activados
          const channel = MethodChannel('com.milogia.app/settings');
          final granted = await channel.invokeMethod<bool>('checkMiuiPermissions');
          if (mounted) setState(() => _miuiPermissionsGranted = granted ?? false);
        }
      } catch (e) {
        debugPrint('Error detectando dispositivo: $e');
      }
    }
  }

  Future<void> _openXiaomiSettings() async {
    try {
      const channel = MethodChannel('com.milogia.app/settings');
      await channel.invokeMethod('openMiuiPermissionSettings');
    } on PlatformException catch (e) {
      debugPrint('Error abriendo ajustes: ${e.message}');
    }
  }

  // -----------------------
  // Helpers
  // -----------------------
  Color _parseColor(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    String h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    try {
      return Color(int.parse(h, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  bool _hasPermission(int code) {
    return widget.selectedProfile.permisos.contains(code);
  }

  
  
  
  Future<List<EmergencyModel>> _fetchEmergencies() async {
    try {
      // 🛑 CORRECCIÓN: Se elimina .execute(). El await en el select devuelve la data directamente.
      final data = await _supabase 
          .from('catdUsuarioEmergencias')
          .select()
          .eq('idUsuario', widget.root.user.idUsuario)
          .order('idEmergencia', ascending: true);
          
      // El manejo de errores ahora se hace con el try-catch

      final list = (data as List<dynamic>? ?? []).map((e) {
        // Normalizar keys al modelo EmergencyModel.fromJson
        return EmergencyModel.fromJson(Map<String, dynamic>.from(e as Map));
      }).toList();
      return list;
    } catch (e) {
      // Si hay un error, el catch lo atrapa.
      rethrow;
    }
  }

  Future<void> _addOrUpdateEmergency(EmergencyModel contact) async {
    try {
      final map = {
        'Nombre': contact.nombre,
        'Telefono': contact.telefono,
        'Direccion': contact.direccion,
        'idUsuario': widget.root.user.idUsuario,
        'Porcentaje': contact.porcentaje,
        'Beneficiario': contact.beneficiario ? 1 : 0,
        'idParentezco': contact.idParentezco,
        'Activo': 1,
      };

      if (contact.idEmergencia == 0) {
        // 🛑 CORRECCIÓN: Se elimina .execute() y el manejo de res.error
        await _supabase.from('catdUsuarioEmergencias').insert(map);
      } else {
        // 🛑 CORRECCIÓN: Se elimina .execute() y el manejo de res.error
        await _supabase
            .from('catdUsuarioEmergencias')
            .update(map)
            .eq('idEmergencia', contact.idEmergencia)
            .eq('idUsuario', widget.root.user.idUsuario);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(contact.idEmergencia == 0 ? 'Contacto agregado.' : 'Contacto actualizado.')));
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteEmergency(int idEmergencia) async {
    try {
      // 🛑 CORRECCIÓN: Se elimina .execute() y el manejo de res.error
      await _supabase
          .from('catdUsuarioEmergencias')
          .delete()
          .eq('idEmergencia', idEmergencia)
          .eq('idUsuario', widget.root.user.idUsuario);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contacto eliminado.')));
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _refresh() {
    setState(() {
      _emergenciesFuture = _fetchEmergencies();
    });
  }

  // --- LÓGICA DE PANICO Y AUXILIO ---

  Future<void> _triggerAlert(String type, {String? details}) async {
    setState(() => _isLoading = true);

    try {
      // 1. Verificar/Pedir permisos de GPS
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Permisos de ubicación denegados.';
      }
      
      // 2. Obtener detalles del remitente para la pantalla de emergencia
      final senderGrade = widget.selectedProfile.Abreviatura;
      final senderLodge = widget.selectedProfile.LogiaNombre;
      
      // Intentar obtener el nombre de la Gran Logia
      String senderGrandLodge = 'Jurisdicción Cosmos';
      try {
        final currentLodgeId = widget.selectedProfile.idLogia;
        final currentLodgeData = widget.root.catalogos.logias_catalogo.firstWhere(
          (l) => l.idLogia == currentLodgeId
        );
        final gdLodgeData = widget.root.catalogos.logias_catalogo.firstWhere(
          (l) => l.idLogia == currentLodgeData.idGranLogia
        );
        senderGrandLodge = gdLodgeData.Nombre;
      } catch (_) {}

      // 3. Obtener ubicación
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );

      // 4. Llamar a Edge Function con el nuevo protocolo
      final payload = {
        'sender_id': widget.root.user.idUsuario,
        'sender_name': widget.root.user.Nombre,
        'sender_phone': widget.root.user.Telefono,
        'sender_grade': senderGrade,
        'sender_lodge': senderLodge,
        'sender_gran_logia': senderGrandLodge,
        'type': type,
        'assistance_details': details,
        'lat': pos.latitude,
        'lon': pos.longitude,
        'radius_km': 15,
      };
      
      debugPrint('Enviando alerta pánico: $payload');

      final res = await _supabase.functions.invoke('panic-alert', body: payload);

      if (res.status != 200) throw 'Error al enviar alerta: ${res.status}';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Alerta enviada correctamente.'), backgroundColor: Colors.green)
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
        );
        print ('Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAssistanceDialog() {
    String selectedType = 'Médico';
    final detailsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Solicitud de Auxilio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                items: ['Médico', 'Mecánico', 'Seguridad', 'Vial', 'Otro']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => selectedType = v ?? 'Otro',
                decoration: const InputDecoration(labelText: 'Tipo de ayuda'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsCtrl,
                decoration: const InputDecoration(labelText: 'Detalles (opcional)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                Navigator.pop(ctx);
                _triggerAlert('assistance', details: '${selectedType}: ${detailsCtrl.text}');
              },
              child: const Text('Enviar Auxilio'),
            ),
          ],
        );
      },
    );
  }

  bool _isLoading = false;

  // -----------------------
  // UI: Formulario para agregar/editar
  // -----------------------
  void _showFormDialog({EmergencyModel? contact}) {
    final isEditing = contact != null;
    if (!isEditing && !_hasPermission(1)) return; // permiso 1 = crear
    if (isEditing && !_hasPermission(3)) return; // permiso 3 = editar

    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController(text: contact?.nombre ?? '');
    final telefonoCtrl = TextEditingController(text: contact?.telefono ?? '');
    final direccionCtrl = TextEditingController(text: contact?.direccion ?? '');
    int? selectedParentezco = contact?.idParentezco;
    bool beneficiario = contact?.beneficiario ?? false;
    final porcentajeCtrl = TextEditingController(text: (contact?.porcentaje ?? 0).toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isEditing ? 'Editar contacto' : 'Nuevo contacto'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                ),
                TextFormField(
                  controller: telefonoCtrl,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                ),
                TextFormField(
                  controller: direccionCtrl,
                  decoration: const InputDecoration(labelText: 'Dirección'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: ensureValidDropdownValue(selectedParentezco, widget.root.catalogos.parentezcos.map((p) => p.idParentezco).toList()),
                  decoration: const InputDecoration(labelText: 'Parentezco'),
                  items: widget.root.catalogos.parentezcos
                      .map((p) => DropdownMenuItem<int>(value: p.idParentezco, child: Text(p.Descripcion)))
                      .toList(),
                  onChanged: (v) => selectedParentezco = v,
                  validator: (v) => v == null ? 'Seleccione parentezco' : null,
                ),
                const SizedBox(height: 8),
                StatefulBuilder(
                  builder: (BuildContext context, StateSetter setDialogState) {
                    return Row(
                      children: [
                        const Text('Beneficiario'),
                        const SizedBox(width: 12),
                        Switch(
                          value: beneficiario,
                          onChanged: (val) {
                            // Usar el setDialogState proporcionado por StatefulBuilder
                            setDialogState(() {
                              beneficiario = val;
                              if (!beneficiario) porcentajeCtrl.text = '0';
                            });
                          },
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 120,
                          child: TextFormField(
                            controller: porcentajeCtrl,
                            // La propiedad 'enabled' ahora se actualiza al cambiar 'beneficiario'
                            enabled: beneficiario,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(suffixText: '%', labelText: 'Porcentaje'),
                            validator: (v) {
                              if (beneficiario) {
                                final n = int.tryParse(v ?? '');
                                if (n == null || n < 0 || n > 100) return '0-100';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final newContact = EmergencyModel(
                  idEmergencia: contact?.idEmergencia ?? 0,
                  idUsuario: widget.root.user.idUsuario,
                  idParentezco: selectedParentezco ?? 0,
                  nombre: nombreCtrl.text,
                  direccion: direccionCtrl.text,
                  telefono: telefonoCtrl.text,
                  activo: '1',
                  porcentaje: int.tryParse(porcentajeCtrl.text) ?? 0,
                  beneficiario: beneficiario,
                );
                Navigator.of(ctx).pop();
                _addOrUpdateEmergency(newContact);
              },
              child: Text(isEditing ? 'Guardar' : 'Agregar'),
            ),
          ],
        );
      },
    );
  }

  // -----------------------
  // UI: Card de contacto
  // -----------------------
  Widget _buildContactCard(EmergencyModel e, Color c1, Color c2, Color c3, Color c4) {
    final canEdit = _hasPermission(3);
    final canDelete = _hasPermission(2);

    return Card(
      color: c3,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Expanded(child: Text(e.nombre, style: TextStyle(color: c2, fontSize: 18, fontWeight: FontWeight.bold))),
              if (e.beneficiario)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: c4, borderRadius: BorderRadius.circular(12)),
                  child: Text('${e.porcentaje}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Parentezco: ${_getParentezcoDesc(e.idParentezco)}', style: TextStyle(color: c2.withOpacity(0.9))),
          const SizedBox(height: 4),
          Text('Tel: ${e.telefono}', style: TextStyle(color: c2.withOpacity(0.9))),
          const SizedBox(height: 4),
          Text('Dir: ${e.direccion}', style: TextStyle(color: c2.withOpacity(0.9))),
          if (canEdit || canDelete)
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (canEdit)
                IconButton(
                  icon: Icon(Icons.edit, color: c4),
                  onPressed: () => _showFormDialog(contact: e),
                ),
              if (canDelete)
                IconButton(
                  icon: Icon(Icons.delete_forever, color: c4),
                  onPressed: () => _confirmDelete(e),
                ),
            ]),
        ]),
      ),
    );
  }

  String _getParentezcoDesc(int id) {
    final found = widget.root.catalogos.parentezcos.where((p) => p.idParentezco == id);
    return found.isNotEmpty ? found.first.Descripcion : 'Desconocido';
  }

  void _confirmDelete(EmergencyModel contact) {
    if (!_hasPermission(2)) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('Eliminar contacto "${contact.nombre}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteEmergency(contact.idEmergencia);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // -----------------------
  // Build
  // -----------------------
   Map<String, Color> _getThemeColors() {
    final colores = widget.selectedProfile.colores;
    Color parseHex(String? hex, Color fallback) {
      if (hex == null || hex.isEmpty) return fallback;
      String h = hex.replaceFirst('#', '');
      if (h.length == 6) h = 'FF$h';
      try {
        return Color(int.parse(h, radix: 16));
      } catch (_) {
        return fallback;
      }
    }

    return {
      'bg': parseHex(colores.C1, const Color(0xFFF5F5F5)),
      'text': parseHex(colores.C2, const Color(0xFF222222)),
      'card': parseHex(colores.C3, Colors.white),
      'accent': parseHex(colores.C4, const Color(0xFFDAA520)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colores = widget.selectedProfile.colores;
    final c1 = _parseColor(colores.C1, const Color(0xFFF0F0F0));
    final c2 = _parseColor(colores.C2, const Color(0xFF222222));
    final c3 = _parseColor(colores.C3, Colors.white);
    final c4 = _parseColor(colores.C4, const Color(0xFFDAA520));
    final theme = _getThemeColors();
    
    return Scaffold(
      backgroundColor: c1,
      appBar: AppBar(
        title: Text('Contactos de Emergencia', style: TextStyle(color: c2)),
        backgroundColor: c1,
        iconTheme: IconThemeData(color: c3),
        elevation: 0,
      ),
      drawer: AppDrawer(
      root: widget.root, 
      selectedProfile: widget.selectedProfile! // Usamos ! porque ya validaste en el padre o usa la lógica segura
    ),
      body: FutureBuilder<List<EmergencyModel>>(
        future: _emergenciesFuture,
        builder: (context, snap) {
          final theme = _getThemeColors();
          final c1 = theme['bg']!;
          final c2 = theme['text']!;
          final c3 = theme['card']!;
          final c4 = theme['accent']!;

          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: c4));
          }

          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}', style: TextStyle(color: c2)));
          }

          final list = snap.data ?? [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c3,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: c1,
                      radius: 24,
                      child: Icon(Icons.local_hospital, color: c4),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tus contactos de emergencia',
                              style: TextStyle(color: c2, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_isXiaomi && !_miuiPermissionsGranted)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Configuración para Xiaomi/MIUI',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Para que la alerta despierte tu equipo, debes activar "Mostrar en pantalla de bloqueo" en la siguiente pantalla.',
                        style: TextStyle(fontSize: 12),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _openXiaomiSettings,
                          icon: const Icon(Icons.settings_suggest, size: 18),
                          label: const Text('Configurar Directo'),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : () => _triggerAlert('panic'),
                        icon: const Icon(Icons.warning, color: Colors.white),
                        label: const Text('PÁNICO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _showAssistanceDialog,
                        icon: const Icon(Icons.help_outline, color: Colors.white),
                        label: const Text('AUXILIO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade800,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoading) const LinearProgressIndicator(color: Colors.red),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text('No tienes contactos de emergencia.',
                              textAlign: TextAlign.center, style: TextStyle(color: c2, fontSize: 16)),
                        ),
                      )
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, i) => _buildContactCard(list[i], c1, c2, c3, c4),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _hasPermission(1)
          ? FloatingActionButton(
              onPressed: () => _showFormDialog(),
              backgroundColor: c4,
              child: Icon(Icons.add, color: c1),
            )
          : null,
    );
  }
}