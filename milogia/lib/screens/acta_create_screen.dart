import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as crypto_hash;

import '../models/user_model.dart';
// import '../config/l10n.dart'; // Descomenta esto si lo usas en este archivo

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
  
  // Controlador del Editor Nativo
  final quill.QuillController _controller = quill.QuillController.basic();
  
  final TextEditingController _fechaTenidaController = TextEditingController();
  final String _tipoActa = 'Ordinaria';
  int? _idGradoSeleccionado;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fechaTenidaController.text = DateTime.now().toIso8601String().split('T')[0];
    _idGradoSeleccionado = widget.selectedProfile.idGrado;
  }

  @override
  void dispose() {
    _controller.dispose();
    _fechaTenidaController.dispose();
    super.dispose();
  }

  Future<void> _guardarActa() async {
    setState(() => _isLoading = true);
    try {
      final String plainText = _controller.document.toPlainText().toLowerCase();
      if (plainText.trim().isEmpty) throw Exception("El acta no puede estar vacía.");

      // Generación del Delta (Formato Original)
      final String jsonContent = jsonEncode(_controller.document.toDelta().toJson());

      // Llave de prueba (Asegúrate de cambiar esto por tu llave real en el futuro)
      final keyBytes = List<int>.generate(32, (i) => i + 1); 
      final secretKey = SecretKey(keyBytes);

      // Índice de búsqueda
      final List<String> words = plainText.split(RegExp(r'\W+')).where((w) => w.length > 3).toSet().toList();
      List<String> indiceBusqueda = [];
      for (var word in words) {
        var bytes = utf8.encode(word + base64Encode(keyBytes));
        indiceBusqueda.add(crypto_hash.sha256.convert(bytes).toString());
      }

      // Cifrado AES-256-GCM
      final algorithm = AesGcm.with256bits();
      final nonce = algorithm.newNonce();
      final secretBox = await algorithm.encrypt(
        utf8.encode(jsonContent),
        secretKey: secretKey,
        nonce: nonce,
      );

      // Guardado en BD
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Acta cifrada y guardada con éxito.")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Lógica de Filtrado de Grados
    final gradosDisponibles = widget.root.catalogos.grados_catalogo.values
        .expand((lista) => lista)
        .where((g) {
      if (widget.selectedProfile.esGranLogia) return g.idGrado <= widget.selectedProfile.idGrado;
      return g.Grupo == widget.selectedProfile.Grupo && g.idGrado <= widget.selectedProfile.idGrado;
    }).toList();

    // 2. Validación segura del Dropdown
    final int? gradoValido = gradosDisponibles.any((g) => g.idGrado == _idGradoSeleccionado) 
        ? _idGradoSeleccionado 
        : (gradosDisponibles.isNotEmpty ? gradosDisponibles.first.idGrado : null);

    return Scaffold(
      backgroundColor: Colors.grey[100], // Fondo sutil para distinguir el editor
      appBar: AppBar(
        title: const Text('Nueva Acta Cifrada'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _guardarActa,
            // Agregamos un indicador de carga al guardar
            icon: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                : const Icon(Icons.lock_outline),
          )
        ],
      ),
      // IMPORTANTE: Column asegura que los widgets de adentro se ordenen de arriba a abajo
      body: Column(
        children: [
          // SECCIÓN SUPERIOR: Controles
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _fechaTenidaController,
                    decoration: const InputDecoration(labelText: 'Fecha Tenida', border: OutlineInputBorder()),
                    readOnly: true,
                    onTap: () async {
                      DateTime? p = await showDatePicker(
                        context: context, 
                        initialDate: DateTime.now(), 
                        firstDate: DateTime(2000), 
                        lastDate: DateTime(2100)
                      );
                      if (p != null) setState(() => _fechaTenidaController.text = p.toIso8601String().split('T')[0]);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: gradoValido,
                    decoration: const InputDecoration(labelText: 'Grado del Acta', border: OutlineInputBorder()),
                    items: gradosDisponibles.isEmpty 
                        ? [const DropdownMenuItem<int>(value: null, child: Text("Sin grados"))]
                        : gradosDisponibles.map((g) => DropdownMenuItem<int>(value: g.idGrado, child: Text(g.Descripcion))).toList(),
                    onChanged: gradosDisponibles.isEmpty ? null : (v) => setState(() => _idGradoSeleccionado = v),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1, thickness: 1),

          // SECCIÓN MEDIA: Barra de Herramientas Quill
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: quill.QuillSimpleToolbar(
              controller: _controller,
              config: const quill.QuillSimpleToolbarConfig(
                // Ocultamos controles que no necesitas para un acta masónica formal
                showFontFamily: false,
                showSearchButton: false,
                showInlineCode: false,
                showSubscript: false,
                showSuperscript: false,
                showColorButton: false,
                showBackgroundColorButton: false,
              ),
            ),
          ),
          
          const Divider(height: 1, thickness: 1),

          // SECCIÓN INFERIOR: El Editor de Texto
          // IMPORTANTE: Expanded le dice al editor "Ocupa todo el espacio que sobra hacia abajo"
          Expanded(
            child: Container(
              color: Colors.white, // El lienzo blanco como una hoja de papel
              padding: const EdgeInsets.all(16.0),
              child: quill.QuillEditor.basic(
                controller: _controller,
                config: const quill.QuillEditorConfig(
                  padding: EdgeInsets.zero, // El padding ya lo maneja el Container de arriba
                  autoFocus: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}