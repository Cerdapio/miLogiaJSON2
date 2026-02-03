import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart' as dio;
import 'package:milogia/config/auth_config.dart';
import '../models/user_model.dart';
import 'app_drawer.dart';
import 'documents_screen.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:milogia/config/l10n.dart';

class RadioCreateScreen extends StatefulWidget {
  final RootModel root;
  final PerfilOpcion selectedProfile;

  const RadioCreateScreen({
    super.key, 
    required this.root, 
    required this.selectedProfile
  });

  @override
  State<RadioCreateScreen> createState() => _RadioCreateScreenState();
}

class _RadioCreateScreenState extends State<RadioCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  DateTime? _validUntil;
  String _periodicity = 'once';
  String _targetAudience = 'own_lodge';
  PlatformFile? _attachment;
  bool _isLoading = false;

  final SupabaseClient _supabase = Supabase.instance.client;

  Map<String, Color> _getThemeColors() {
    final colores = widget.selectedProfile.colores;
    Color parseHex(String? hex, Color fallback) {
      if (hex == null || hex.isEmpty) return fallback;
      String h = hex.replaceFirst('#', '');
      if (h.length == 6) h = 'FF$h';
      try { return Color(int.parse(h, radix: 16)); } catch (_) { return fallback; }
    }
    return {
      'bg': parseHex(colores.C1, const Color(0xFFF5F5F5)),
      'text': parseHex(colores.C2, const Color(0xFF222222)),
      'card': parseHex(colores.C3, Colors.white),
      'accent': parseHex(colores.C4, const Color(0xFFDAA520)),
    };
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'doc', 'docx'],
    );
    if (result != null) {
      setState(() {
        _attachment = result.files.first;
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _validUntil = picked;
      });
    }
  }

  Future<void> _scanDocument() async {
    try {
      List<String> pictures = await CunningDocumentScanner.getPictures() ?? [];
      if (!mounted) return;
      if (pictures.isNotEmpty) {
        final filePath = pictures.first;
        final file = File(filePath);
        final bytes = await file.readAsBytes();
        
        setState(() {
          _attachment = PlatformFile(
            name: 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg',
            size: bytes.length,
            bytes: bytes,
            path: filePath,
          );
        });
      }
    } catch (e) {
      debugPrint('Error al escanear: $e');
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${L10n.scanErrorMsg(context)}$e')));
      }
    }
  }

  Future<void> _submitRadio() async {
    if (!_formKey.currentState!.validate()) return;
    
    final userUuid = widget.root.user.authUuid;
    if (userUuid == null) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.userUuidNotFound(context))),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? publicUrl;

      // 1. Subir a Storage mediante una Edge Function (para saltar RLS)
      if (_attachment != null) {
        final bytes = _attachment!.bytes ?? (_attachment!.path != null ? await File(_attachment!.path!).readAsBytes() : null);
         if (bytes == null) {
          throw Exception(L10n.fileReadError(context));
        }
        
        final functionUrl = '$supabaseUrl/functions/v1/upload-radio';
        final headers = {
          'Authorization': 'Bearer ${_supabase.auth.currentSession?.accessToken}',
        };

        final formData = dio.FormData();
        formData.files.add(MapEntry(
          'file', 
          dio.MultipartFile.fromBytes(bytes, filename: _attachment!.name)
        ));
        formData.fields.add(MapEntry('logiaId', widget.selectedProfile.idLogia.toString()));

        final dioClient = dio.Dio();
        final response = await dioClient.post(
          functionUrl,
          data: formData,
          options: dio.Options(headers: headers),
        );

        if (response.statusCode == 200) {
           publicUrl = response.data['publicUrl'];
        } else {
          throw Exception('${L10n.uploadFileError(context)}: ${response.data['error']}');
        }
      }

      // 2. Insertar en la tabla 'radios'
      final radioData = {
        'issuing_user_id': userUuid,
        'issuing_logia_id': widget.selectedProfile.idLogia,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'document_url': publicUrl,
        'valid_until': _validUntil?.toIso8601String(),
        'periodicity': _periodicity,
        'target_audience': _targetAudience,
        'is_active': true,
      };

      final response = await _supabase
          .from('radios')
          .insert(radioData)
          .select()
          .single();

      final radioId = response['idradio'];

      // 3. Llamar a la Edge Function para notificación inmediata
      await _supabase.functions.invoke(
        'radio-alert',
        body: {'idradio': radioId},
      );

       if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.radioEmittedSuccess(context))),
        );
        // Navegamos a DocumentsScreen para ver el resultado, usando pushReplacement porque el stack estaba vacío (abierto desde Drawer con replacement)
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => DocumentsScreen(root: widget.root, selectedProfile: widget.selectedProfile))
        );
      }
    } catch (e) {
      debugPrint('Error al emitir radio: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _getThemeColors();
    
     return Scaffold(
      backgroundColor: theme['bg'],
      appBar: AppBar(
        title: Text(L10n.emitRadioTitle(context)),
        backgroundColor: theme['bg'],
        foregroundColor: theme['text'],
        elevation: 0,
      ),
      drawer: AppDrawer(root: widget.root, selectedProfile: widget.selectedProfile),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: theme['accent']))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. INFORMACIÓN GENERAL
                  Card(
                    color: theme['card'],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                             children: [
                              Icon(Icons.edit_note, color: theme['accent']),
                              const SizedBox(width: 8),
                              Text(L10n.generalInfoTitle(context), style: TextStyle(color: theme['text'], fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: 10),
                           _buildTextField(
                            controller: _titleController,
                            label: L10n.radioTitleLabel(context),
                            icon: Icons.title,
                            theme: theme,
                            validator: (v) => v!.isEmpty ? L10n.requiredField(context) : null,
                          ),
                          const SizedBox(height: 15),
                           _buildTextField(
                            controller: _descriptionController,
                            label: L10n.radioDescriptionLabel(context),
                            icon: Icons.description,
                            theme: theme,
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. CONFIGURACIÓN
                  Card(
                    color: theme['card'],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                             children: [
                              Icon(Icons.settings_suggest, color: theme['accent']),
                              const SizedBox(width: 8),
                              Text(L10n.configurationTitle(context), style: TextStyle(color: theme['text'], fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                             value: _periodicity,
                            dropdownColor: theme['card'],
                            style: TextStyle(color: theme['text']),
                            decoration: _inputDecoration(L10n.periodicityLabel(context), Icons.repeat, theme),
                            items: [
                              DropdownMenuItem(value: 'once', child: Text(L10n.periodicityOnce(context), style: TextStyle(color: theme['text']))),
                              DropdownMenuItem(value: 'daily', child: Text(L10n.periodicityDaily(context), style: TextStyle(color: theme['text']))),
                              DropdownMenuItem(value: 'weekly', child: Text(L10n.periodicityWeekly(context), style: TextStyle(color: theme['text']))),
                              DropdownMenuItem(value: 'monthly', child: Text(L10n.periodicityMonthly(context), style: TextStyle(color: theme['text']))),
                            ],
                            onChanged: (v) => setState(() => _periodicity = v!),
                          ),
                          const SizedBox(height: 15),
                          InkWell(
                             onTap: _selectDate,
                            child: InputDecorator(
                              decoration: _inputDecoration(L10n.validUntilLabel(context), Icons.event, theme),
                              child: Text(
                                _validUntil == null 
                                  ? L10n.selectDateOptional(context) 
                                  : DateFormat('dd/MM/yyyy').format(_validUntil!),
                                style: TextStyle(color: theme['text']),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          DropdownButtonFormField<String>(
                             value: _targetAudience,
                            dropdownColor: theme['card'],
                            style: TextStyle(color: theme['text']),
                            decoration: _inputDecoration(L10n.targetAudienceLabel(context), Icons.public, theme),
                            items: [
                              // 1. Own Lodge / Mi Logia (Available to everyone)
                              DropdownMenuItem(value: 'own_lodge', child: Text(L10n.audienceOwnLodge(context), style: TextStyle(color: theme['text']))),
                              
                              // 2. Logic for Secretary (Profile 5) -> Can emit to "My Grand Lodge"
                              if (widget.selectedProfile.idPerfil == 5)
                                DropdownMenuItem(value: 'grand_lodge', child: Text("Mi Gran Logia", style: TextStyle(color: theme['text']))),

                              // 3. Logic for Grand Lodge -> Can emit to Subordinates & Other GLs
                              if (widget.selectedProfile.esGranLogia) ...[
                                DropdownMenuItem(value: 'subordinate_lodges', child: Text(L10n.audienceSubordinateLodges(context), style: TextStyle(color: theme['text']))),
                                DropdownMenuItem(value: 'other_grand_lodges', child: Text("Otras Grandes Logias", style: TextStyle(color: theme['text']))),
                              ]
                            ],
                            onChanged: (v) => setState(() => _targetAudience = v!),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. ADJUNTOS
                  Card(
                    color: theme['card'],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 25),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                             children: [
                              Icon(Icons.attach_file, color: theme['accent']),
                              const SizedBox(width: 8),
                              Text(L10n.attachmentsTitle(context), style: TextStyle(color: theme['text'], fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: 15),
                           Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              OutlinedButton.icon(
                                 onPressed: _pickFile,
                                icon: Icon(Icons.upload_file, color: theme['accent']),
                                label: Text(
                                  _attachment == null ? L10n.uploadFileButton(context) : L10n.changeFileButton(context),
                                  style: TextStyle(color: theme['text']),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: theme['accent']!),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                              ),
                               ElevatedButton.icon(
                                onPressed: _scanDocument,
                                icon: const Icon(Icons.camera_alt, color: Colors.white),
                                label: Text(L10n.scanButton(context), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme['accent'],
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                          if (_attachment != null)
                            Container(
                              margin: const EdgeInsets.only(top: 15),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme['bg']?.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: theme['accent']!.withOpacity(0.3))
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green[400], size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _attachment!.name, 
                                      style: TextStyle(color: theme['text'], fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                    onPressed: () => setState(() => _attachment = null),
                                  )
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // BOTÓN FINAL
                  Container(
                    margin: const EdgeInsets.only(bottom: 40),
                    padding: const EdgeInsets.all(4), // Borde simulado
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [theme['accent']!, theme['accent']!.withOpacity(0.7)]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: theme['accent']!.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                      ]
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _submitRadio,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white, // Fondo blanco para contraste con gradiente
                          foregroundColor: theme['accent'], // Texto accent
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                           children: [
                            const Icon(Icons.send_rounded),
                            const SizedBox(width: 10),
                            Text(
                              L10n.emitRadioButton(context),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, Map<String, Color> theme) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: theme['text']?.withOpacity(0.7)),
      prefixIcon: Icon(icon, color: theme['accent']),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme['accent']!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme['accent']!.withOpacity(0.5)),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Map<String, Color> theme,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: _inputDecoration(label, icon, theme),
      style: TextStyle(color: theme['text']),
      validator: validator,
    );
  }
}
