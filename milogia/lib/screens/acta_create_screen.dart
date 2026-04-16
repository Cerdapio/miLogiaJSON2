import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quill_html_editor/quill_html_editor.dart';
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
  final QuillEditorController _controller = QuillEditorController();
  
  final TextEditingController _fechaTenidaController = TextEditingController();
  String _tipoActa = 'Ordinaria';
  int? _idGradoSeleccionado;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fechaTenidaController.text = DateTime.now().toIso8601String().split('T')[0];
    
    // Inicialización inteligente del grado según el perfil
    _idGradoSeleccionado = widget.selectedProfile.idGrado;
  }

  // --- LÓGICA CRIPTOGRÁFICA (PILAR 1 Y 2) ---
  Future<void> _guardarActa() async {
    setState(() => _isLoading = true);
    try {
      String htmlContent = await _controller.getText();
      if (htmlContent.isEmpty || htmlContent == '<p><br></p>') throw Exception("El acta está vacía.");

      // 1. Obtención de llave (Simulada, debe venir de tu login seguro)
      final keyBytes = List<int>.generate(32, (i) => i + 1); 
      final secretKey = SecretKey(keyBytes);

      // 2. Pilar 2: Índice Ciego para Búsqueda
      final String plainText = htmlContent.replaceAll(RegExp(r'<[^>]*>'), ' ').toLowerCase();
      final List<String> words = plainText.split(RegExp(r'\W+'))
          .where((w) => w.length > 3).toSet().toList();

      List<String> indiceBusqueda = [];
      for (var word in words) {
        var bytes = utf8.encode(word + base64Encode(keyBytes));
        indiceBusqueda.add(crypto_hash.sha256.convert(bytes).toString());
      }

      // 3. Pilar 1: Cifrado AES-256-GCM
      final algorithm = AesGcm.with256bits();
      final nonce = algorithm.newNonce();
      final secretBox = await algorithm.encrypt(
        utf8.encode(htmlContent), // Ciframos el HTML puro
        secretKey: secretKey,
        nonce: nonce,
      );

      // 4. Guardado respetando tu tabla 'actas'
      await _supabase.from('actas').insert({
        'iddLogia': widget.selectedProfile.idLogia,
        'Fecha': DateTime.now().toIso8601String(), // Fecha de registro
        'fecha_tenida': _fechaTenidaController.text,
        'Tipo': _tipoActa,
        'idGrado': _idGradoSeleccionado, // Vital para tus políticas RLS
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Acta guardada con éxito")));
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
    // Filtrado dinámico de grados para escalabilidad
    // Extraemos las listas del Map, las aplanamos y luego filtramos
    final gradosDisponibles = widget.root.catalogos.grados_catalogo.values
        .expand((listaDeGrados) => listaDeGrados) // <--- Esto convierte el Map en una sola Lista
        .where((g) {
      if (widget.selectedProfile.esGranLogia) {
        return g.idGrado <= widget.selectedProfile.idGrado;
      }
      return g.Grupo == widget.selectedProfile.Grupo && 
             g.idGrado <= widget.selectedProfile.idGrado;
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
                        items: gradosDisponibles.map((g) => DropdownMenuItem<int>(
                        value: g.idGrado, 
                        child: Text(g.Descripcion) // Usa g.descripcion (en minúscula) si tu modelo lo tiene así
                        )).toList(),
                        onChanged: (v) => setState(() => _idGradoSeleccionado = v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ToolBar(controller: _controller, toolBarColor: Colors.grey[200]),
          Expanded(
            child: QuillHtmlEditor(
              controller: _controller,
              hintText: 'Escribe el trazado de la tenida...',
              minHeight: 400,
              textStyle: const TextStyle(fontSize: 16),
              padding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }
}