import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/auth_config.dart'; 
import '../config/l10n.dart';
import '../models/user_model.dart'; 
import 'app_drawer.dart'; 
import '../utils/dropdown_utils.dart';
import '../models/attendance_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';



class DocumentsScreen extends StatefulWidget {
  final RootModel root;
  final PerfilOpcion? selectedProfile; 

  const DocumentsScreen({super.key, required this.root, required this.selectedProfile});
    
  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  
  DocumentosCatalogo? _selectedDocType;
  int? _selectedGrado;
  final TextEditingController _descripcionController = TextEditingController();
  bool _isLoading = false;

  Map<int, List<Documento>> _groupedDocuments = {};
  
  // Attendance Module State
  List<ListaLogiasPorUsuario> _miembrosLogia = [];
  Map<int, AttendanceStatus> _attendanceStates = {}; // idUsuario -> status
  List<SessionAttendance> _sessions = [];
  List<MemberAttendance> _allMemberAttendances = [];
  bool _isAttendanceLoading = false;
  int _attendanceSubTab = 0; // 0: History/Sessions, 1: Report, 2: Config
  
  // Config Cycle State
  DateTime? _cycleStartDate;
  DateTime? _cycleEndDate;
  int _sessionDayOfWeek = 2; // Tuesday (1: Mon, 2: Tue...)
  SessionAttendance? _editingSession;



  @override
  void initState() {
    super.initState();
    _groupDocumentsByGrade();
    _loadMiembros();
    _loadAttendanceData();
  }

  void _loadMiembros() {
    final currentLogiaId = widget.selectedProfile?.idLogia ?? 0;
    setState(() {
      _miembrosLogia = widget.root.catalogos.listaLogiasPorUsuario.where((u) {
        return u.perfiles.any((p) => p.idLogia == currentLogiaId);
      }).toList();
    });
  }

  Future<void> _loadAttendanceData() async {
    final currentLogiaId = widget.selectedProfile?.idLogia ?? 0;
    setState(() => _isAttendanceLoading = true);
    try {
      final sessionsRes = await _supabase
          .from('sesiones_asistencia')
          .select()
          .eq('iddLogia', currentLogiaId)
          .order('Fecha', ascending: true);
      
      final attRes = await _supabase
          .from('asistencia_miembros')
          .select('*, sesiones_asistencia!inner(*)')
          .eq('sesiones_asistencia.iddLogia', currentLogiaId);
      
      if (mounted) {
        setState(() {
          _sessions = (sessionsRes as List).map((json) => SessionAttendance.fromJson(json)).toList();
          _allMemberAttendances = (attRes as List).map((json) => MemberAttendance.fromJson(json)).toList();
        });
      }
    } catch (e) {
      debugPrint("Error loading attendance data: $e");
    } finally {
      if (mounted) setState(() => _isAttendanceLoading = false);
    }
  }

  Future<void> _generateCycle() async {
    if (_cycleStartDate == null || _cycleEndDate == null) return;
    
    final currentLogiaId = widget.selectedProfile?.idLogia ?? 0;
    List<SessionAttendance> generatedSessions = [];
    DateTime current = _cycleStartDate!;
    
    // Find first occurrence of chosen day
    while (current.weekday != _sessionDayOfWeek) {
      current = current.add(const Duration(days: 1));
    }

    while (current.isBefore(_cycleEndDate!) || current.isAtSameMomentAs(_cycleEndDate!)) {
      generatedSessions.add(SessionAttendance(
        iddLogia: currentLogiaId,
        fecha: current,
        tipo: 'TO',
      ));
      current = current.add(const Duration(days: 7));
    }

    setState(() => _isAttendanceLoading = true);
    try {
      final List<Map<String, dynamic>> records = generatedSessions.map((s) => s.toJson()).toList();
      await _supabase.from('sesiones_asistencia').insert(records);
      _loadAttendanceData();
      _showSuccessDialog("Ciclo Generado", "Se han generado ${generatedSessions.length} sesiones.");
    } catch (e) {
      _showErrorDialog("Error", e.toString());
    } finally {
      if (mounted) setState(() => _isAttendanceLoading = false);
    }
  }

  Future<void> _saveSessionAttendance(SessionAttendance session) async {
    setState(() => _isAttendanceLoading = true);
    try {
      // Delete previous records for this session to avoid duplicates
      if (session.idSession != null) {
        await _supabase.from('asistencia_miembros').delete().eq('idSession', session.idSession!);
      }

      final List<Map<String, dynamic>> records = _attendanceStates.entries.map((entry) {
        return MemberAttendance(
          idSession: session.idSession!,
          idUsuario: entry.key,
          estado: entry.value,
        ).toJson();
      }).toList();

      await _supabase.from('asistencia_miembros').insert(records);
      
      // Update session info (Hospitalario/Trabajos/Tipo)
      await _supabase.from('sesiones_asistencia').update({
        'Tipo': session.tipo,
        'Hospitalario': session.hospitalario,
        'Trabajos': session.trabajos,
      }).eq('idSession', session.idSession!);

      _loadAttendanceData();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showErrorDialog("Error", e.toString());
    } finally {
      if (mounted) setState(() => _isAttendanceLoading = false);
    }
  }


  @override
  void dispose() {
    _descripcionController.dispose();
    super.dispose();
  }

  void _groupDocumentsByGrade() {
    final Map<int, List<Documento>> tempMap = {};
    final int currentLogiaId = widget.selectedProfile?.idLogia ?? 0;
    
    final filteredDocuments = widget.root.user.documentos.where((userDoc) {
      return userDoc.iddLogia == currentLogiaId; 
    }).toList();
    
    for (var userDoc in filteredDocuments) {
      final int gradoEncontrado = userDoc.idGrado ?? 0; 
      
      if (!tempMap.containsKey(gradoEncontrado)) {
        tempMap[gradoEncontrado] = [];
      }
      tempMap[gradoEncontrado]!.add(userDoc);
    }

    tempMap.forEach((key, list) {
      list.sort((a, b) => b.Fecha.compareTo(a.Fecha));
    });

    setState(() {
      _groupedDocuments = tempMap;
    });
  }

  List<RadioModel> _getFilteredRadios() {
    final currentLogiaId = widget.selectedProfile?.idLogia ?? 0;
    
    int idGranLogia = 0;
    try {
        final currentLogiaData = widget.root.catalogos.logias_catalogo
          .firstWhere((l) => l.idLogia == currentLogiaId);
        idGranLogia = currentLogiaData.idGranLogia;
    } catch (_) {}

    return widget.root.user.radios.where((radio) {
      if (radio.targetAudience == 'all_lodges') return true;
      if (radio.issuingLogiaId == currentLogiaId) return true;
      if (radio.targetAudience == 'subordinate_lodges' && radio.issuingLogiaId == idGranLogia) return true;
      return false;
    }).toList();
  }

  String _getCuentaBancariaForLogia() {
    final currentLogiaId = widget.selectedProfile?.idLogia ?? 0;
    final allConcepts = widget.root.catalogos.conceptos_catalogo;

    for (var concepto in allConcepts) {
      for (var detalle in concepto.detalles) {
        if (detalle.iddLogia == currentLogiaId && detalle.ctaBanco.isNotEmpty) {
          return detalle.ctaBanco;
        }
      }
    }
    return L10n.notConfiguredAccount(context);
  }

  ConceptoDetalle? _getDetallePagoEspecifico() {
    if (_selectedDocType == null) return null;

    final gradoBusqueda = _selectedDocType!.RequiereGrado ? (_selectedGrado ?? 0) : 0;
    int idConceptoGenerico = 0;

    try {
      final detalleDoc = _selectedDocType!.detalles.firstWhere(
        (d) => d.Grado == gradoBusqueda,
        orElse: () => _selectedDocType!.detalles.first, 
      );
      idConceptoGenerico = detalleDoc.idConcepto; 
    } catch (e) {
      return null; 
    }
    
    if (idConceptoGenerico == 0) return null;

    try {
      final conceptoCat = widget.root.catalogos.conceptos_catalogo.firstWhere(
        (c) => c.idConcepto == idConceptoGenerico,
      );

      final idLogiaActual = widget.selectedProfile?.idLogia ?? 0;
      
      final detalleEspecifico = conceptoCat.detalles.firstWhere(
        (d) => d.iddLogia == idLogiaActual && d.idGrado == gradoBusqueda,
        orElse: () {
             return conceptoCat.detalles.firstWhere(
                (d) => d.iddLogia == idLogiaActual,
                orElse: () => conceptoCat.detalles.first
             );
        }
      );
      return detalleEspecifico;
    } catch (e) {
      return null;
    }
  }

  Future<void> _procesarSolicitud() async {
    if (_selectedDocType == null) return;
    
    if (_selectedDocType!.RequiereGrado && _selectedGrado == null) {
      _showErrorDialog(L10n.incompleteData(context), L10n.selectGradeMsg(context));
      return;
    }
    if (_selectedDocType!.RequiereDescripcion && _descripcionController.text.isEmpty) {
      _showErrorDialog(L10n.incompleteData(context), L10n.requireDescriptionMsg(context));
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_selectedDocType!.RequierePago) {
        final detallePago = _getDetallePagoEspecifico();
        if (detallePago != null && detallePago.Costo > 0) {
           await _generarPagoReferencia(detallePago);
        } else {
           _showErrorDialog(L10n.configError(context), L10n.noCostoFound(context));
        }
      } else {
        _showSuccessDialog(L10n.requestSentTitle(context), '${L10n.requestSentMsgPrefix(context)} ${_selectedDocType!.Descripcion}${L10n.requestSentMsgSuffix(context)}');
      }
    } catch (e) {
      _showErrorDialog(L10n.isEn(context) ? 'Error' : 'Error', e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generarPagoReferencia(ConceptoDetalle detallePago) async {
    final fecha = DateTime.now().toIso8601String();
    final importe = detallePago.Costo;
    final iddConceptoReal = detallePago.iddConcepto;

    try {
      final insertRes = await _supabase
          .from('movcPagos')
          .insert({
            'idUsuario': widget.root.user.idUsuario,
            'Importe': importe,
            'Fecha': fecha,
            'idFormaPago': 2, 
            'Folio': '0',    
            'Activo': 1,
          })
          .select()
          .single();

      final idPagoGenerado = insertRes['idPago'] as int;

      await _supabase.from('movdPagos').insert({
        'idPago': idPagoGenerado,
        'iddConcepto': iddConceptoReal,
        'Cantidad': 1,
      });

      if (mounted) {
        Navigator.of(context).pop(); 
        _showPaymentSlipDialog(idPagoGenerado, importe, _selectedDocType!.Descripcion);
      }
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Map<String, Color> _getThemeColors() {
    final colores = widget.selectedProfile?.colores;
    
    Color parseHex(String? hex, Color fallback) {
      if (hex == null || hex.isEmpty) return fallback;
      String h = hex.replaceFirst('#', '');
      if (h.length == 6) h = 'FF$h';
      try { return Color(int.parse(h, radix: 16)); } catch (_) { return fallback; }
    }

    if (colores != null) {
      return {
        'bg': parseHex(colores.C1, const Color(0xFFF5F5F5)),
        'text': parseHex(colores.C2, const Color(0xFF222222)),
        'card': parseHex(colores.C3, Colors.white),
        'accent': parseHex(colores.C4, const Color(0xFFDAA520)),
      };
    }
    return {
      'bg': const Color(0xFFF5F5F5),
      'text': const Color(0xFF222222),
      'card': Colors.white,
      'accent': const Color(0xFFDAA520),
    };
  }

  void _showRequestDocumentDialog() {
    _selectedDocType = null;
    _selectedGrado = null;
    _descripcionController.clear();
    
    final perfilId = widget.selectedProfile?.idPerfil ?? 0;
    final maxGradoUsuario = widget.selectedProfile?.idGrado ?? 0; 

    final docsSolicitables = widget.root.catalogos.documentos_catalogo
        .where((d) {
          if (!d.Solicitud) return false;
          final desc = d.Descripcion.toLowerCase();
          if (desc.contains('radio') || desc.contains('plancha')) {
            return perfilId == 5; 
          }
          return true;
        })
        .toList();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final theme = _getThemeColors();
            final detallePreview = _getDetallePagoEspecifico();
            final costoPreview = detallePreview?.Costo;

            final List<DocumentosCatalogoDetalle> selectableDetails = _selectedDocType?.detalles
                .where((det) => det.Grado > -1 && det.Grado <= maxGradoUsuario)
                .toList() ?? [];

            selectableDetails.sort((a, b) => a.Grado.compareTo(b.Grado));

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: theme['card'],
              title: Text(L10n.requestDocumentTitle(context), style: TextStyle(color: theme['text'])),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (docsSolicitables.isEmpty)
                       Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(L10n.labelNoPermissionsDocs(context), style: TextStyle(color: theme['text'])),
                      )
                    else
                      DropdownButtonFormField<DocumentosCatalogo>(
                        isExpanded: true,
                        decoration: InputDecoration(labelText: L10n.labelDocType(context), labelStyle: TextStyle(color: theme['text'])),
                        dropdownColor: theme['card'],
                        value: ensureValidDropdownValue(_selectedDocType, docsSolicitables),
                        items: docsSolicitables.map((d) => DropdownMenuItem(
                          value: d,
                          child: Text(d.Descripcion, style: TextStyle(color: theme['text']), overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (val) {
                          setStateDialog(() {
                            _selectedDocType = val;
                            _selectedGrado = null; 
                          });
                        },
                      ),
                    
                    const SizedBox(height: 16),

                    if (_selectedDocType != null && _selectedDocType!.RequiereGrado && selectableDetails.isNotEmpty)
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        decoration: InputDecoration(labelText: '${L10n.labelGradeMax(context)}$maxGradoUsuario)', labelStyle: TextStyle(color: theme['text'])),
                        dropdownColor: theme['card'],
                        value: ensureValidDropdownValue(_selectedGrado, selectableDetails.map((d) => d.Grado).toList()),
                        items: selectableDetails.map((detail) {
                          return DropdownMenuItem<int>(
                            value: detail.Grado,
                            child: Text(detail.NombreCorto, style: TextStyle(color: theme['text']), overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setStateDialog(() {
                            _selectedGrado = val;
                          });
                        },
                      ),
                    
                    if (_selectedDocType != null && _selectedDocType!.RequiereGrado && selectableDetails.isEmpty)
                       Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Text("${L10n.labelNoGradesAvailable(context)}$maxGradoUsuario).", style: TextStyle(color: Colors.red, fontSize: 12)),
                      ),

                    if (_selectedDocType != null && (_selectedDocType!.RequiereDescripcion || _selectedDocType!.Descripcion == "Tema libre"))
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: TextField(
                          controller: _descripcionController,
                          maxLines: 2,
                          style: TextStyle(color: theme['text']),
                          decoration: InputDecoration(
                            labelText: L10n.labelDescriptionReason(context),
                            labelStyle: TextStyle(color: theme['text']),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),

                    if (_selectedDocType != null && _selectedDocType!.RequierePago)
                      Padding(
                        padding: const EdgeInsets.only(top: 20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(L10n.labelCosto(context), style: TextStyle(color: theme['text'])),
                            Text(
                              costoPreview != null 
                                ? NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(costoPreview) 
                                : "...",
                              style: TextStyle(color: theme['accent'], fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                 TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(L10n.cancelButton(context)),
                ),
                if (docsSolicitables.isNotEmpty)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: theme['accent']),
                    onPressed: _isLoading ? null : () async {
                      await _procesarSolicitud();
                    },
                    child: Text(
                      _selectedDocType?.RequierePago == true ? L10n.buttonPayRequest(context) : L10n.buttonRequestOnly(context),
                      style: const TextStyle(color: Colors.white),
                    ),
                  )
              ],
            );
          },
        );
      },
    );
  }

  void _showPaymentSlipDialog(int idPago, double importe, String concepto) {
    final theme = _getThemeColors();
    final cuentaBanco = _getCuentaBancariaForLogia();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme['card'],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(L10n.referenceGeneratedTitle(context)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 10),
            Text("${L10n.referenceGeneratedFor(context)}$concepto", textAlign: TextAlign.center, style: TextStyle(color: theme['text'])),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme['bg'],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _infoRow(L10n.referenceLabel(context), "$idPago", theme),
                  _infoRow(L10n.accountDestLabel(context), cuentaBanco, theme),
                  const Divider(),
                  _infoRow(L10n.importeLabel(context), NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(importe), theme, isBold: true),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(L10n.understoodButton(context))),
        ],
      ),
    );
  }
  
  Widget _infoRow(String label, String value, Map<String, Color> theme, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: theme['text'], fontSize: 13)),
          Flexible(
            child: Text(value, 
              style: TextStyle(
                color: isBold ? theme['accent'] : theme['text'], 
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: isBold ? 15 : 13
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String msg) {
    if (!mounted) return;
    showDialog(context: context, builder: (_) => AlertDialog(title: Text(title, style: const TextStyle(color: Colors.red)), content: Text(msg), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))]));
  }
  
  void _showSuccessDialog(String title, String msg) {
    if (!mounted) return;
    showDialog(context: context, builder: (_) => AlertDialog(title: Text(title, style: const TextStyle(color: Colors.green)), content: Text(msg), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))]));
  }

  Widget _buildMyDocumentsView(Map<String, Color> theme) {
    final sortedGrades = _groupedDocuments.keys.toList()..sort();
    final visibleRadios = _getFilteredRadios();

    return Column(
      children: [
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
                child: Icon(Icons.folder_shared, color: theme['accent']),
              ),
              const SizedBox(width: 12),
               Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(L10n.labelPersonalLibrary(context), style: TextStyle(color: theme['text'], fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('${_groupedDocuments.values.expand((x) => x).length}${L10n.labelDocsFromLogiaSuffix(context)}', style: TextStyle(color: theme['text']?.withOpacity(0.7), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              if (visibleRadios.isNotEmpty)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: theme['card'],
                  elevation: 1,
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      iconColor: theme['accent'],
                      collapsedIconColor: theme['text'],
                      leading: Icon(Icons.radio, color: theme['accent']),
                      title: Text(
                        L10n.labelOfficialRadios(context),
                        style: TextStyle(color: theme['accent'], fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      children: visibleRadios.map((radio) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          child: Card(
                            elevation: 2, 
                            color: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: theme['bg'], shape: BoxShape.circle),
                                child: Icon(Icons.campaign, color: theme['text']?.withOpacity(0.7), size: 20),
                              ),
                              title: Text(radio.title, style: TextStyle(color: theme['text'], fontWeight: FontWeight.w600)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (radio.description.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(radio.description, style: TextStyle(color: theme['text']?.withOpacity(0.8), fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 12, color: theme['text']?.withOpacity(0.5)),
                                        const SizedBox(width: 4),
                                        Text(
                                          radio.createdAt.isNotEmpty 
                                            ? DateFormat('dd/MM/yyyy').format(DateTime.parse(radio.createdAt))
                                            : '', 
                                          style: TextStyle(color: theme['text']?.withOpacity(0.5), fontSize: 11)
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () async {
                                if (radio.documentUrl != null && radio.documentUrl!.isNotEmpty) {
                                  final uri = Uri.parse(radio.documentUrl!);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  }
                                }
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
               if (sortedGrades.isEmpty && visibleRadios.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Center(child: Text(L10n.labelNoDocsFound(context), style: TextStyle(color: theme['text']))),
                )
               else
                ...sortedGrades.map((grado) {
                  final docs = _groupedDocuments[grado]!;
                  final gradoTitulo = grado == 0 ? L10n.labelGeneralDocs(context) : "${L10n.labelGradePrefix(context)}$grado";

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: theme['card'],
                    elevation: 1,
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        iconColor: theme['accent'],
                        collapsedIconColor: theme['text'],
                        title: Text(
                          gradoTitulo,
                          style: TextStyle(color: theme['accent'], fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        children: docs.map((doc) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            child: Card(
                              elevation: 2, 
                              color: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme['bg'],
                                    shape: BoxShape.circle
                                  ),
                                  child: Icon(Icons.description, color: theme['text']?.withOpacity(0.7), size: 20),
                                ),
                                title: Text(
                                  doc.NombreCorto.isNotEmpty ? doc.NombreCorto : doc.Descripcion, 
                                  style: TextStyle(color: theme['text'], fontWeight: FontWeight.w600)
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (doc.NombreLargo.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(doc.NombreLargo, style: TextStyle(color: theme['text']?.withOpacity(0.8), fontSize: 12)),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 12, color: theme['text']?.withOpacity(0.5)),
                                          const SizedBox(width: 4),
                                          Text(doc.Fecha, style: TextStyle(color: theme['text']?.withOpacity(0.5), fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _getThemeColors();
    final bool isSecretary = widget.selectedProfile?.idPerfil == 5; // 5 = Secretario

    if (isSecretary) {
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text(L10n.myDocumentsTitle(context), style: TextStyle(color: theme['text'])),
            backgroundColor: theme['bg'],
            elevation: 0,
            iconTheme: IconThemeData(color: theme['text']),
            bottom: TabBar(
              labelColor: theme['accent'],
              unselectedLabelColor: theme['text']?.withOpacity(0.7),
              indicatorColor: theme['accent'],
              tabs: const [
                Tab(icon: Icon(Icons.folder), text: "Documentos"),
                Tab(icon: Icon(Icons.list_alt), text: "Asistencia"),
              ],
            ),
          ),
          drawer: AppDrawer(
            root: widget.root,
            selectedProfile: widget.selectedProfile ?? widget.root.user.perfiles_opciones.first,
          ),
          body: TabBarView(
            children: [
              _buildMyDocumentsView(theme), // Wrap existing body in this method
              _buildAttendanceTab(),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: theme['accent'],
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_to_photos),
            label: Text(L10n.requestDocumentTitle(context)),
            onPressed: _showRequestDocumentDialog,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme['bg'],
      appBar: AppBar(
        title: Text(L10n.myDocumentsTitle(context), style: TextStyle(color: theme['text'])),
        backgroundColor: theme['bg'],
        elevation: 0,
        iconTheme: IconThemeData(color: theme['text']),
      ),
      drawer: AppDrawer(
        root: widget.root,
        selectedProfile: widget.selectedProfile ?? widget.root.user.perfiles_opciones.first,
      ),
      body: _buildMyDocumentsView(theme),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme['accent'],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_to_photos),
        label: Text(L10n.requestDocumentTitle(context)),
        onPressed: _showRequestDocumentDialog,
      ),
    );
  }


  Widget _buildAttendanceTab() {
    final theme = _getThemeColors();
    
    return Column(
      children: [
        // Tab indicator
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme['bg'],
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              _buildAttendanceSubTabButton(0, "Sesiones", theme),
              _buildAttendanceSubTabButton(1, "Reporte", theme),
              _buildAttendanceSubTabButton(2, "Ciclo", theme),
            ],
          ),
        ),
        
        Expanded(
          child: _isAttendanceLoading 
            ? const Center(child: CircularProgressIndicator())
            : _buildAttendanceBody(theme),
        ),
      ],
    );
  }

  Widget _buildAttendanceSubTabButton(int index, String label, Map<String, Color> theme) {
    bool isSelected = _attendanceSubTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _attendanceSubTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? theme['accent'] : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : theme['text']?.withOpacity(0.6),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceBody(Map<String, Color> theme) {
    switch (_attendanceSubTab) {
      case 0: return _buildSessionsList(theme);
      case 1: return _buildAttendanceReportView(theme);
      case 2: return _buildCycleConfig(theme);
      default: return const SizedBox();
    }
  }

  Widget _buildCycleConfig(Map<String, Color> theme) {
    final days = {
      1: "Lunes", 2: "Martes", 3: "Miércoles", 4: "Jueves", 5: "Viernes", 6: "Sábado", 7: "Domingo"
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        color: theme['card'],
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Configuración del Ciclo", style: TextStyle(color: theme['text'], fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              ListTile(
                title: Text("Fecha Inicio", style: TextStyle(color: theme['text'])),
                subtitle: Text(_cycleStartDate == null ? "Seleccionar..." : DateFormat('dd/MM/yyyy').format(_cycleStartDate!)),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                  if (d != null) setState(() => _cycleStartDate = d);
                },
              ),
              ListTile(
                title: Text("Fecha Fin", style: TextStyle(color: theme['text'])),
                subtitle: Text(_cycleEndDate == null ? "Seleccionar..." : DateFormat('dd/MM/yyyy').format(_cycleEndDate!)),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                  if (d != null) setState(() => _cycleEndDate = d);
                },
              ),
              DropdownButtonFormField<int>(
                value: _sessionDayOfWeek,
                decoration: InputDecoration(labelText: "Día de Sesión", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                items: days.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (v) => setState(() => _sessionDayOfWeek = v!),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: theme['accent'], padding: const EdgeInsets.all(15)),
                  onPressed: _generateCycle,
                  child: const Text("Generar Calendario de Sesiones", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionsList(Map<String, Color> theme) {
    if (_sessions.isEmpty) {
      return Center(child: Text("No hay sesiones generadas. Ve a la pestaña 'Ciclo'.", style: TextStyle(color: theme['text'])));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final s = _sessions[index];
        final isNA = s.tipo == 'NA';
        
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: theme['card'],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isNA ? Colors.grey : theme['accent'],
              child: Text(s.tipo, style: const TextStyle(fontSize: 10, color: Colors.white)),
            ),
            title: Text(DateFormat('EEEE dd MMMM, yyyy', L10n.isEn(context) ? 'en_US' : 'es_MX').format(s.fecha), style: TextStyle(fontWeight: FontWeight.bold, color: theme['text'])),
            subtitle: Text(isNA ? "No hubo trabajos" : "Tenida ${s.tipo == 'TO' ? 'Ordinaria' : 'Especial'}", style: TextStyle(color: theme['text']?.withOpacity(0.6))),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showTakeAttendanceDialog(s),
          ),
        );
      },
    );
  }

  void _showTakeAttendanceDialog(SessionAttendance session) {
    // Prepare temp state
    _attendanceStates.clear();
    for (var m in _miembrosLogia) {
      final existing = _allMemberAttendances.firstWhere(
        (a) => a.idSession == session.idSession && a.idUsuario == m.idUsuario,
        orElse: () => MemberAttendance(idSession: session.idSession!, idUsuario: m.idUsuario, estado: AttendanceStatus.absent)
      );
      _attendanceStates[m.idUsuario] = existing.estado;
    }

    String currentTipo = session.tipo;
    final theme = _getThemeColors();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: theme['card'],
          title: Text("Pasar Asistencia", style: TextStyle(color: theme['text'])),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                Row(
                  children: [
                    const Text("Tipo: "),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: currentTipo,
                      items: const [
                        DropdownMenuItem(value: 'TO', child: Text("Ordinaria (TO)")),
                        DropdownMenuItem(value: 'TE', child: Text("Especial (TE)")),
                        DropdownMenuItem(value: 'NA', child: Text("No Trabajo (NA)")),
                      ],
                      onChanged: (v) => setStateDialog(() => currentTipo = v!),
                    ),
                  ],
                ),
                const Divider(),
                ..._miembrosLogia.map((m) {
                  final status = _attendanceStates[m.idUsuario]!;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(m.Nombre, style: const TextStyle(fontSize: 13)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _statusIcon(AttendanceStatus.present, status, (s) => setStateDialog(() => _attendanceStates[m.idUsuario] = s)),
                        _statusIcon(AttendanceStatus.absent, status, (s) => setStateDialog(() => _attendanceStates[m.idUsuario] = s)),
                        _statusIcon(AttendanceStatus.justified, status, (s) => setStateDialog(() => _attendanceStates[m.idUsuario] = s)),
                        _statusIcon(AttendanceStatus.notApplicable, status, (s) => setStateDialog(() => _attendanceStates[m.idUsuario] = s)),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: theme['accent']),
              onPressed: () => _saveSessionAttendance(SessionAttendance(
                idSession: session.idSession,
                iddLogia: session.iddLogia,
                fecha: session.fecha,
                tipo: currentTipo,
              )),
              child: const Text("Guardar", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  Widget _statusIcon(AttendanceStatus buttonStatus, AttendanceStatus currentStatus, Function(AttendanceStatus) onTap) {
    final isSelected = buttonStatus == currentStatus;
    Color color = Colors.grey;
    String label = "";
    
    switch (buttonStatus) {
      case AttendanceStatus.present: color = Colors.green; label = "✓"; break;
      case AttendanceStatus.absent: color = Colors.red; label = "X"; break;
      case AttendanceStatus.justified: color = Colors.blue; label = "J"; break;
      case AttendanceStatus.notApplicable: color = Colors.grey; label = "-"; break;
    }

    return GestureDetector(
      onTap: () => onTap(buttonStatus),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color)
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : color, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildAttendanceReportView(Map<String, Color> theme) {
    if (_sessions.isEmpty) return const Center(child: Text("No hay datos para el reporte"));

    // Calculation logic
    final stats = _miembrosLogia.map((m) {
      final userAtts = _allMemberAttendances.where((a) => a.idUsuario == m.idUsuario).toList();
      
      int totalLeCorrespondian = 0;
      int asistencias = 0;
      int faltas = 0;
      int justs = 0;

      for (var s in _sessions) {
        if (s.tipo == 'NA') continue; // Ignore NA sessions globally
        
        final att = userAtts.firstWhere((a) => a.idSession == s.idSession, 
            orElse: () => MemberAttendance(idSession: s.idSession!, idUsuario: m.idUsuario, estado: AttendanceStatus.absent));
        
        if (att.estado == AttendanceStatus.notApplicable) continue; // Ignore individual "-"

        totalLeCorrespondian++;
        if (att.estado == AttendanceStatus.present) asistencias++;
        if (att.estado == AttendanceStatus.absent) faltas++;
        if (att.estado == AttendanceStatus.justified) justs++;
      }

      return UserAttendanceStats(
        idUsuario: m.idUsuario,
        nombre: m.Nombre,
        totalSesionesLeCorrespondian: totalLeCorrespondian,
        totalAsistencias: asistencias,
        totalFaltas: faltas,
        totalJustificadas: justs,
      );
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: theme['accent']),
            onPressed: () => _generatePDFReport(stats),
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            label: const Text("Exportar Reporte Maestro (PDF)", style: TextStyle(color: Colors.white)),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: stats.length,
            itemBuilder: (context, index) {
              final s = stats[index];
              final color = _getSemaforoColor(s.percentage);
              return Card(
                color: theme['card'],
                child: ListTile(
                  title: Text(s.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("A: ${s.totalAsistencias} | F: ${s.totalFaltas} | J: ${s.totalJustificadas}"),
                  trailing: Text("${s.percentage.toStringAsFixed(1)}%", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _generatePDFReport(List<UserAttendanceStats> stats) async {
    final pdf = pw.Document();
    final theme = _getThemeColors();
    final logiaNombre = widget.selectedProfile?.LogiaNombre ?? "Logia";

    // Matrix data
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        orientation: pw.PageOrientation.landscape,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(logiaNombre, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text("REPORTE DE ASISTENCIA - CICLO ${DateTime.now().year}", style: pw.TextStyle(fontSize: 14)),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ["H.".toUpperCase(), "TEN.", "%", ..._sessions.map((s) => DateFormat('dd/MM').format(s.fecha))],
            data: stats.map((s) {
              final List<String> cells = [
                s.nombre,
                s.totalSesionesLeCorrespondian.toString(),
                "${s.percentage.toStringAsFixed(0)}%",
              ];
              for (var sess in _sessions) {
                if (sess.tipo == 'NA') {
                  cells.add("N/A");
                } else {
                  final att = _allMemberAttendances.firstWhere(
                    (a) => a.idSession == sess.idSession && a.idUsuario == s.idUsuario,
                    orElse: () => MemberAttendance(idSession: sess.idSession!, idUsuario: s.idUsuario, estado: AttendanceStatus.absent)
                  );
                  switch (att.estado) {
                    case AttendanceStatus.present: cells.add("✓"); break;
                    case AttendanceStatus.absent: cells.add("X"); break;
                    case AttendanceStatus.justified: cells.add("J"); break;
                    case AttendanceStatus.notApplicable: cells.add("-"); break;
                  }
                }
              }
              return cells;
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 7),
            border: pw.TableBorder.all(),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.center,
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Color _getSemaforoColor(double p) {
    if (p <= 50) return Colors.red;
    if (p <= 75) return Colors.orange;
    return Colors.green;
  }

}
