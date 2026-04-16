import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill; 
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as crypto_hash;

import '../models/user_model.dart';
import '../config/l10n.dart';

class ActaCreateScreen extends StatefulWidget {
  final RootModel root;
  final PerfilOpcion selectedProfile;

  const ActaCreateScreen({
    super.key,
    required this.root,
    required this.selectedProfile,
  });

  @override
  State<ActaCreateScreen> createState() => _ActaCreateScreenState();
}

class _ActaCreateScreenState extends State<ActaCreateScreen> {
  final _supabase = Supabase.instance.client;
  
  // Nuevo controlador nativo
  final quill.QuillController _controller = quill.QuillController.basic();
  
  final TextEditingController _fechaTenidaController = TextEditingController();
  String _tipoActa = 'Ordinaria';
  int? _idGradoSeleccionado;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fechaTenidaController.text = DateTime.now().toIso8601String().split('T')[0];
    _idGradoSeleccionado = widget.selectedProfile.idGrado;
  }

  Future<void> _guardarActa() async {
    setState(() => _isLoading = true);
    try {
      print("Paso 1: Extrayendo texto...");
      final String plainText = _controller.document.toPlainText().toLowerCase();
      if (plainText.trim().isEmpty) throw Exception("El acta está vacía.");

      print("Paso 2: Generando Delta JSON...");
      final String jsonContent = jsonEncode(_controller.document.toDelta().toJson());
      
      print("Paso 3: Preparando Criptografía...");
      final keyBytes = List<int>.generate(32, (i) => i + 1); 
      final secretKey = SecretKey(keyBytes);

      print("Paso 4: Creando Índice de Búsqueda...");
      final List<String> words = plainText.split(RegExp(r'\W+'))
          .where((w) => w.length > 3).toSet().toList();

      List<String> indiceBusqueda = [];
      for (var word in words) {
        var bytes = utf8.encode(word + base64Encode(keyBytes));
        indiceBusqueda.add(crypto_hash.sha256.convert(bytes).toString());
      }

      print("Paso 5: Encriptando (AES-256-GCM)...");
      final algorithm = AesGcm.with256bits();
      final nonce = algorithm.newNonce();
      final secretBox = await algorithm.encrypt(
        utf8.encode(jsonContent),
        secretKey: secretKey,
        nonce: nonce,
      );

      print("Paso 6: Guardando en Supabase...");
      await _supabase.from('actas').insert({
        'iddLogia': widget.selectedProfile.idLogia,
        'Fecha': DateTime.now().toIso8601String(),
        'fecha_tenida': _fechaTenidaController.text,
        'Tipo': _tipoActa,
        'idGrado': _idGradoSeleccionado,
        'ContenidoJSON': {
          "nonce": base64Encode(nonce),
          "mac": base64Encode(secretBox.mac.bytes),
        },
        'contenido_cifrado': base64Encode(secretBox.cipherText),
        'indice_busqueda': indiceBusqueda,
        'idUsuarioCreador': widget.root.user.idUsuario,
        'Activo': true,
      });

      print("Paso 7: ¡Éxito!");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Acta guardada con éxito")));
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      // Esto nos dirá exactamente la línea del error
      print("FALLÓ EN EL TRY-CATCH: $e");
      print("TRAZA DEL ERROR: $stackTrace");
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filtrado dinámico de grados
    final gradosDisponibles = widget.root.catalogos.grados_catalogo.values
        .expand((lista) => lista)
        .where((g) {
      if (widget.selectedProfile.esGranLogia) return g.idGrado <= widget.selectedProfile.idGrado;
      return g.Grupo == widget.selectedProfile.Grupo && g.idGrado <= widget.selectedProfile.idGrado;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Acta Cifrada'),
        actions: [IconButton(onPressed: _isLoading ? null : _guardarActa, icon: const Icon(Icons.lock_outline))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _fechaTenidaController,
                        decoration: const InputDecoration(labelText: 'Fecha Tenida', border: OutlineInputBorder()),
                        readOnly: true,
                        onTap: () async {
                          DateTime? p = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                          if (p != null) setState(() => _fechaTenidaController.text = p.toIso8601String().split('T')[0]);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _idGradoSeleccionado,
                        decoration: const InputDecoration(labelText: 'Grado del Acta', border: OutlineInputBorder()),
                        items: gradosDisponibles.map((g) => DropdownMenuItem(value: g.idGrado, child: Text(g.Descripcion))).toList(),
                        onChanged: (v) => setState(() => _idGradoSeleccionado = v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 1. Barra de herramientas actualizada para v11+
          quill.QuillSimpleToolbar(
            controller: _controller,
          ),
          
          // 2. Editor actualizado para v11+
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                color: Colors.white,
              ),
              // Envolvemos en Padding para reemplazar el que quitamos del config
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: quill.QuillEditor.basic(
                  controller: _controller,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}