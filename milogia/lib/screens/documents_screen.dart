import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// Asegúrate de que las rutas sean correctas según tu estructura de carpetas
import '../config/auth_config.dart'; // Contiene clases como LogiaTheme (si lo usas)
import '../models/user_model.dart'; // Contiene RootModel, Documento, PerfilOpcion, etc.
import 'app_drawer.dart'; // Tu clase AppDrawer

class DocumentsScreen extends StatefulWidget {
  final RootModel root;
  final PerfilOpcion? selectedProfile; 

  const DocumentsScreen({super.key, required this.root, required this.selectedProfile});
    
  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _supabase = Supabase.instance.client;
  
  // Variables para el formulario
  DocumentosCatalogo? _selectedDocType;
  int? _selectedGrado;
  final TextEditingController _descripcionController = TextEditingController();
  bool _isLoading = false;

  // Mapa para agrupar documentos
  Map<int, List<Documento>> _groupedDocuments = {};

  @override
  void initState() {
    super.initState();
    _groupDocumentsByGrade();
  }

  /// CORRECCIÓN FINAL: Filtra por la Logia Seleccionada y luego agrupa por el idGrado del documento.
  void _groupDocumentsByGrade() {
    final Map<int, List<Documento>> tempMap = {};
    
    // 1. OBTENER EL ID DE LA LOGIA ACTUAL
    final int currentLogiaId = widget.selectedProfile?.idLogia ?? 0;
    
    // 2. FILTRAR: Solo documentos que pertenecen a la Logia actual.
    final filteredDocuments = widget.root.user.documentos.where((userDoc) {
      return userDoc.iddLogia == currentLogiaId; 
    }).toList();
    
    // 3. AGRUPAR: Usar 'idGrado' de los documentos filtrados para la agrupación.
    for (var userDoc in filteredDocuments) {
      // Usamos 'idGrado' directamente. Si es nulo o inválido, se agrupa bajo '0'.
      final int gradoEncontrado = userDoc.idGrado ?? 0; 
      
      if (!tempMap.containsKey(gradoEncontrado)) {
        tempMap[gradoEncontrado] = [];
      }
      tempMap[gradoEncontrado]!.add(userDoc);
    }

    // Ordenar por fecha
    tempMap.forEach((key, list) {
      list.sort((a, b) => b.Fecha.compareTo(a.Fecha));
    });

    setState(() {
      _groupedDocuments = tempMap;
    });
  }

  // --- LÓGICA DE PAGO Y SOLICITUD ---

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
    for (var concepto in allConcepts) {
      for (var detalle in concepto.detalles) {
        if (detalle.ctaBanco.isNotEmpty) {
          return detalle.ctaBanco;
        }
      }
    }
    return 'N/A - Cuenta no configurada';
  }

  /// Busca el detalle específico del concepto cruzando Logia + Grado solicitado.
  ConceptoDetalle? _getDetallePagoEspecifico() {
    if (_selectedDocType == null) return null;

    final gradoBusqueda = _selectedDocType!.RequiereGrado ? (_selectedGrado ?? 0) : 0;
    int idConceptoGenericoStr = 0;

    try {
      // 1. Obtener el ID de Concepto genérico del documento para el grado seleccionado
      final detalleDoc = _selectedDocType!.detalles.firstWhere(
        (d) => d.Grado == gradoBusqueda,
        orElse: () => _selectedDocType!.detalles.first, 
      );
      // Asumo que idConcepto en DocumentosCatalogoDetalle es de tipo String
      idConceptoGenericoStr = detalleDoc.idConcepto; 
    } catch (e) {
      return null; 
    }
    
    final int idConceptoGenerico = idConceptoGenericoStr ?? 0;
    if (idConceptoGenerico == 0) return null;

    try {
      // 2. Buscar en el catálogo de conceptos
      final conceptoCat = widget.root.catalogos.conceptos_catalogo.firstWhere(
        (c) => c.idConcepto == idConceptoGenerico,
      );

      final idLogiaActual = widget.selectedProfile?.idLogia ?? 0;
      
      // 3. Filtrar el detalle exacto (Logia + Grado) para obtener el costo y el iddConcepto
      final detalleEspecifico = conceptoCat.detalles.firstWhere(
        (d) => d.iddLogia == idLogiaActual && d.idGrado == gradoBusqueda,
        orElse: () {
            // Fallback: Buscar solo por Logia si el grado no es específico
             return conceptoCat.detalles.firstWhere(
                (d) => d.iddLogia == idLogiaActual,
                orElse: () => conceptoCat.detalles.first // Último recurso
             );
        }
      );

      return detalleEspecifico;

    } catch (e) {
      debugPrint("Error buscando detalle específico: $e");
      return null;
    }
  }

  Future<void> _procesarSolicitud() async {
    if (_selectedDocType == null) return;
    
    if (_selectedDocType!.RequiereGrado && _selectedGrado == null) {
      _showErrorDialog("Datos incompletos", "Por favor selecciona un grado.");
      return;
    }
    if (_selectedDocType!.RequiereDescripcion && _descripcionController.text.isEmpty) {
      _showErrorDialog("Datos incompletos", "Este documento requiere una descripción o motivo.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_selectedDocType!.RequierePago) {
        // Obtenemos el ConceptoDetalle que contiene el iddConcepto correcto y el costo
        final detallePago = _getDetallePagoEspecifico();
        
        if (detallePago != null && detallePago.Costo > 0) {
           await _generarPagoReferencia(detallePago);
        } else {
           _showErrorDialog("Error de Configuración", "No se encontró costo o configuración para este documento en tu Logia.");
        }
      } else {
        _showSuccessDialog("Solicitud Enviada", "Tu solicitud de ${_selectedDocType!.Descripcion} ha sido registrada.");
      }
    } catch (e) {
      _showErrorDialog("Error", e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Genera la referencia de pago usando el iddConcepto REAL.
  Future<void> _generarPagoReferencia(ConceptoDetalle detallePago) async {
    final fecha = DateTime.now().toIso8601String();
    final importe = detallePago.Costo;
    final iddConceptoReal = detallePago.iddConcepto; // El ID específico

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
        'iddConcepto': iddConceptoReal, // GUARDAMOS EL ID ESPECÍFICO CORRECTO
        'Cantidad': 1,
      });

      if (mounted) {
        Navigator.of(context).pop(); 
        _showPaymentSlipDialog(idPagoGenerado, importe, _selectedDocType!.Descripcion);
      }

    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  // --- UI HELPERS ---

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
    } else {
       return {
        'bg': const Color(0xFFF5F5F5),
        'text': const Color(0xFF222222),
        'card': Colors.white,
        'accent': const Color(0xFFDAA520),
      };
    }
  }

  void _showRequestDialog() {
    _selectedDocType = null;
    _selectedGrado = null;
    _descripcionController.clear();
    
    final perfilId = widget.selectedProfile?.idPerfil ?? 0;
    // Obtener el grado máximo del usuario, que es el límite superior de selección.
    final maxGradoUsuario = widget.selectedProfile?.idGrado ?? 0; 

    final docsSolicitables = widget.root.catalogos.documentos_catalogo
        .where((d) {
          if (!d.Solicitud) return false;
          final desc = d.Descripcion.toLowerCase();
          if (desc.contains('radio') || desc.contains('plancha')) {
            return perfilId == 5; // Solo perfil 5 puede solicitar estos (asumo)
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

            // 1. OBTENER Y FILTRAR DETALLES: Usamos el objeto completo para tener Grado y NombreCorto.
            final List<DocumentosCatalogoDetalle> selectableDetails = _selectedDocType?.detalles
                .where((det) => det.Grado > -1 && det.Grado <= maxGradoUsuario)
                .toList() ?? [];

            // 2. Ordenar por grado para mantener el orden de la lista.
            selectableDetails.sort((a, b) => a.Grado.compareTo(b.Grado));

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: theme['card'],
              title: Text('Solicitud de Documento', style: TextStyle(color: theme['text'])),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (docsSolicitables.isEmpty)
                       Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text("No tienes permisos para solicitar documentos especiales.", style: TextStyle(color: theme['text'])),
                      )
                    else
                      DropdownButtonFormField<DocumentosCatalogo>(
                        isExpanded: true,
                        decoration: InputDecoration(labelText: 'Tipo de Documento', labelStyle: TextStyle(color: theme['text'])),
                        dropdownColor: theme['card'],
                        items: docsSolicitables.map((d) => DropdownMenuItem(
                          value: d,
                          child: Text(d.Descripcion, style: TextStyle(color: theme['text'])),
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
                        decoration: InputDecoration(labelText: 'Grado (Max: $maxGradoUsuario)', labelStyle: TextStyle(color: theme['text'])),
                        dropdownColor: theme['card'],
                        // USANDO selectableDetails
                        items: selectableDetails.map((detail) {
                          return DropdownMenuItem<int>(
                            // El valor (value) sigue siendo el int del grado
                            value: detail.Grado,
                            // El texto (child) ahora es NombreCorto
                            child: Text(detail.NombreCorto, style: TextStyle(color: theme['text'])),
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
                        child: Text("No hay grados disponibles para solicitud en este documento (Max: $maxGradoUsuario).", style: TextStyle(color: Colors.red, fontSize: 12)),
                      ),


                    if (_selectedDocType != null && (_selectedDocType!.RequiereDescripcion || _selectedDocType!.Descripcion == "Tema libre"))
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: TextField(
                          controller: _descripcionController,
                          maxLines: 2,
                          style: TextStyle(color: theme['text']),
                          decoration: InputDecoration(
                            labelText: 'Descripción / Motivo',
                            labelStyle: TextStyle(color: theme['text']),
                            border: const OutlineInputBorder(),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: theme['accent']!))
                          ),
                        ),
                      ),

                    if (_selectedDocType != null && _selectedDocType!.RequierePago)
                      Padding(
                        padding: const EdgeInsets.only(top: 20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text("Costo: ", style: TextStyle(color: theme['text'])),
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
                  child: const Text('Cancelar'),
                ),
                if (docsSolicitables.isNotEmpty)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: theme['accent']),
                    onPressed: _isLoading ? null : () async {
                      await _procesarSolicitud();
                    },
                    child: Text(
                      _selectedDocType?.RequierePago == true ? 'Pagar y Solicitar' : 'Solicitar',
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
        title: const Text("Referencia Generada"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 60),
              const SizedBox(height: 10),
              Text("Se ha generado la referencia para: $concepto", textAlign: TextAlign.center, style: TextStyle(color: theme['text'])),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme['bg'],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.3))
                ),
                child: Column(
                  children: [
                    _infoRow("Referencia:", "$idPago", theme),
                    _infoRow("Cuenta Destino:", cuentaBanco, theme),
                    const Divider(),
                    _infoRow("Importe:", NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(importe), theme, isBold: true),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text("Ve a la sección 'Mis Pagos' para ver el detalle completo.", style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Entendido")),
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
    showDialog(context: context, builder: (_) => AlertDialog(title: Text(title, style: const TextStyle(color: Colors.red)), content: Text(msg), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))]));
  }
  
  void _showSuccessDialog(String title, String msg) {
    showDialog(context: context, builder: (_) => AlertDialog(title: Text(title, style: const TextStyle(color: Colors.green)), content: Text(msg), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))]));
  }

  @override
  Widget build(BuildContext context) {
    final theme = _getThemeColors();
    // Obtener las claves (grados) y ordenarlas
    final sortedGrades = _groupedDocuments.keys.toList()..sort();

    return Scaffold(
      backgroundColor: theme['bg'],
      appBar: AppBar(
        title: Text('Mis Documentos', style: TextStyle(color: theme['text'])),
        backgroundColor: theme['bg'],
        elevation: 0,
        iconTheme: IconThemeData(color: theme['text']),
      ),
      drawer: AppDrawer(
        root: widget.root, 
        selectedProfile: widget.selectedProfile ?? widget.root.user.perfiles_opciones.first 
      ),
      body: Column(
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
                        Text('Biblioteca Personal', style: TextStyle(color: theme['text'], fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('${_groupedDocuments.values.expand((x) => x).length} documentos de esta Logia', style: TextStyle(color: theme['text']?.withOpacity(0.7), fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 10),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: sortedGrades.length,
                itemBuilder: (context, index) {
                  final grado = sortedGrades[index];
                  final docs = _groupedDocuments[grado]!;
                  final gradoTitulo = grado == 0 ? "Documentos Generales" : "Grado $grado";

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
                                onTap: () {},
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme['accent'],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_to_photos),
        label: const Text("Solicitar Documento"),
        onPressed: _showRequestDialog,
      ),
    );
  }
}