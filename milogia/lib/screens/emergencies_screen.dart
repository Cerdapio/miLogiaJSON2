import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
//import 'dart:io';


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

  @override
  void initState() {
    super.initState();
    _emergenciesFuture = _fetchEmergencies();
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
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: c3));
          } else if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}', style: TextStyle(color: c2)));
          } else if (!snap.hasData || snap.data!.isEmpty) {
            return Center(child: Text('No tienes contactos de emergencia.', style: TextStyle(color: c2)));
          } else {
            final list = snap.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                //Padding(
                //  padding: const EdgeInsets.all(16.0),
                //  child: Text('Tus contactos de emergencia', style: TextStyle(color: c2, fontSize: 18, fontWeight: FontWeight.bold)),
              // ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme['card'], 
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme['bg'],
                      radius: 24,
                      child: Icon(Icons.local_hospital, color: theme['accent']),//Icons.account_balance_wallet, color: theme['accent']),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tus contactos de emergencia', style: TextStyle(color: theme['text'], fontWeight: FontWeight.bold, fontSize: 16)),
                          //Text(widget.selectedProfile.LogiaNombre, style: TextStyle(color: theme['text']?.withOpacity(0.7), fontSize: 12)),
                        ],
                      ),
                    ),
                    ],
                ),
              ),
                Expanded(
                  child: ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) => _buildContactCard(list[i], c1, c2, c3, c4),
                  ),
                ),
              ],
            );
          }
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