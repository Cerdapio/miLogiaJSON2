import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/pago_model.dart'; 
import '../config/auth_config.dart'; 
import 'app_drawer.dart';

class PagoConcepto {
  final ConceptoCatalogo concepto;
  int cantidad;
  final double precioUnitario; // NUEVO: Almacena el precio unitario ya filtrado

  // Modificamos el constructor para recibir el precio unitario
  PagoConcepto({required this.concepto, this.cantidad = 1, required this.precioUnitario});

  // El subtotal es ahora simple
  double get subtotal => precioUnitario * cantidad;
}
class PagoDetalle {
  final int iddconcepto;
  final String nombre;
  final int cantidad;
  final double precioUnitario;
  double get subtotal => precioUnitario * cantidad;
  PagoDetalle({
    required this.iddconcepto,
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
  });
}

class PagoScreen extends StatefulWidget {
  final RootModel root;
  final PerfilOpcion selectedProfile;
  final int initialTab; // 0 for Mis Pagos, 1 for Validar, 2 for Cobro

  const PagoScreen({
    super.key, 
    required this.root, 
    required this.selectedProfile,
    this.initialTab = 0,
  });

  @override
  State<PagoScreen> createState() => _PagoScreenState();
}

class _PagoScreenState extends State<PagoScreen> {
  late Future<List<PagoModel>> _pagosFuture;
  final _supabase = Supabase.instance.client;
  
  // Listas para el dropdown de generar pago
  List<ConceptoCatalogo> _conceptosCatalogo = [];
  List<PagoConcepto> _conceptosSeleccionados = [];

  // --- VARIABLES PARA TESORERÍA ---
  List<PagoReportado> _reportesPendientes = [];
  bool _isLoadingReportes = false;
  ListaLogiasPorUsuario? _selectedMemberForCash;
  List<PagoConcepto> _conceptosCobroEfectivo = [];
  final _folioEfectivoController = TextEditingController();
  bool _isSavingCash = false;
  bool _hasFetchedReportes = false; // Flag para evitar bucle de carga

  @override
  void initState() {
    super.initState();
    _loadConceptosFromCatalog();
    _pagosFuture = _consultarPagos();
    
    // Pre-seleccionar un concepto si existe
    // Fix: _loadConceptosFromCatalog ya inicializa la selección, eliminamos la duplicidad aquí.
  }

  /// Carga los conceptos disponibles desde el RootModel (local)
  // En pago_screen.dart, dentro de la clase _PagoScreenState
  /// Carga y filtra los conceptos disponibles por la Logia actualmente seleccionada
  void _loadConceptosFromCatalog() {
    try {
      final allConcepts = widget.root.catalogos.conceptos_catalogo;
      final currentLogiaId = widget.selectedProfile.idLogia;

      // 1. FILTRADO: Un concepto es elegible si tiene al menos un detalle
      // que coincide con la Logia actual (currentLogiaId).
      _conceptosCatalogo = allConcepts.where((concepto) {
        if (concepto.detalles.isEmpty) {
          // Si no tiene detalles, asumimos que aplica a todas las logias (concepto general).
          return true;
        }

        // Devolvemos true si encontramos AL MENOS UN detalle con la iddLogia actual
        return concepto.detalles.any((detalle) => detalle.iddLogia == currentLogiaId);
      }).toList();

      // 2. REINICIALIZACIÓN DE LA SELECCIÓN:
      if (_conceptosCatalogo.isEmpty) {
        _conceptosSeleccionados = [];
      } else {
        // Obtenemos el precio del primer concepto filtrado
        final firstConcepto = _conceptosCatalogo.first;
        final firstPrice = _getCostoUnitario(firstConcepto);

        // Inicializamos la lista de conceptos seleccionados con el primer elemento filtrado
        _conceptosSeleccionados = [
          PagoConcepto(
            concepto: firstConcepto,
            cantidad: 1,
            precioUnitario: firstPrice, // Usamos el precio ya filtrado
          )
        ];
      }
    } catch (e) {
      debugPrint("Error al cargar y filtrar conceptos: $e");
      _conceptosCatalogo = [];
      _conceptosSeleccionados = [];
    }
  }

  // --- LÓGICA DE TESORERÍA ---

  Future<void> _fetchReportesPendientes() async {
    setState(() => _isLoadingReportes = true);
    try {
      final response = await _supabase
          .from('movcPagosReportados')
          .select()
          .eq('iddLogia', widget.selectedProfile.idLogia)
          .eq('Estatus', 'Revision')
          .order('FechaReporte', ascending: false);

      if (mounted) {
        setState(() {
          _reportesPendientes = (response as List).map((e) => PagoReportado.fromJson(e)).toList();
          _isLoadingReportes = false;
          _hasFetchedReportes = true;
        });
      }
    } catch (e) {
      debugPrint('Error fetchReportes: $e');
      if (mounted) setState(() => _isLoadingReportes = false);
    }
  }

  Future<void> _approveReport(PagoReportado reporte) async {
    try {
      final result = await _supabase.rpc('confirmar_pago_reportado', params: {
        'p_id_reporte': reporte.idReporte,
        'p_id_forma_pago': 1, // Transferencia
      });

      //if (reporte.UrlComprobante != null) {
        //print(reporte.UrlComprobante!);
        //await _supabase.storage.from('radios_docs').remove([reporte.UrlComprobante!]);
      //}

     if (reporte.UrlComprobante != null) {
        try {
          // 1. Limpieza de URL (Igual que antes, esto estaba bien)
          final rawUrl = reporte.UrlComprobante!;
          final decodedUrl = Uri.decodeFull(rawUrl);
          
          String cleanPath = decodedUrl;
          if (decodedUrl.contains('/radios_docs/')) {
            cleanPath = decodedUrl.split('/radios_docs/').last;
          }

          print('RPC: Intentando borrar path: $cleanPath');

          // --- CAMBIO CLAVE AQUÍ ---
          // Usamos RPC para llamar a la función administradora
          final response = await _supabase.rpc(
            'delete_file_admin', 
            params: {
              'bucket_name': 'radios_docs',
              'object_path': cleanPath,
            }
          );
          
          print('Respuesta RPC: $response'); // Debería decir {"success": true, "deleted": 1}

        } catch (e) {
          print('Error RPC: $e');
          // Opcional: Mostrar alerta visual si falla
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('Error borrando imagen: $e')),
             );
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pago aprobado con éxito.')));
        _fetchReportesPendientes();
        _pagosFuture = _consultarPagos(); // Recargar mis pagos por si acaso
      }
    } catch (e) {
      if (mounted) _showErrorDialog('Error', 'No se pudo aprobar: $e; ${reporte.UrlComprobante!}');
    }
  }

  Future<void> _saveCashPayment() async {
    if (_selectedMemberForCash == null || _conceptosCobroEfectivo.isEmpty) {
      _showErrorDialog('Faltan datos', 'Selecciona un miembro y al menos un concepto.');
      return;
    }

    setState(() => _isSavingCash = true);

    try {
      final total = _conceptosCobroEfectivo.fold<double>(0, (sum, item) => sum + item.subtotal);
      final folio = _folioEfectivoController.text.isNotEmpty 
          ? _folioEfectivoController.text 
          : 'EFEC-${DateTime.now().millisecondsSinceEpoch}';

      // 1. Insertar cabecera en movcPagos (idFormaPago = 3)
      final insertRes = await _supabase.from('movcPagos').insert({
        'idUsuario': _selectedMemberForCash!.idUsuario,
        'Fecha': DateTime.now().toIso8601String(),
        'Folio': folio,
        'Importe': total,
        'idFormaPago': 3, // Efectivo
        'Activo': true,
      }).select().single();

      final idPago = insertRes['idPago'] as int;

      // 2. Insertar detalles
      final detalles = _conceptosCobroEfectivo.map((pc) => {
        'idPago': idPago,
        'iddConcepto': pc.concepto.idConcepto,
        'Cantidad': pc.cantidad,
      }).toList();

      await _supabase.from('movdPagos').insert(detalles);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cobro de \$${total} registrado con éxito.')));
        setState(() {
          _selectedMemberForCash = null;
          _conceptosCobroEfectivo = [];
          _folioEfectivoController.clear();
          _isSavingCash = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error', 'No se pudo registrar: $e');
        setState(() => _isSavingCash = false);
      }
    }
  }

  /// Consulta los pagos históricos vía RPC (Stored Procedure)
  Future<List<PagoModel>> _consultarPagos() async {
    try {
      final response = await _supabase.rpc(
        rpcFunction, 
        params: {
          'popcion': 7, 
          'pidusuario': widget.root.user.idUsuario,
          'piddlogia': widget.selectedProfile.idLogia, 
          'pnombre': '',
          'pusuario': '', 
          'pcontrasena': '',
          'ptelefono': '',
          'pfechanacimiento': '',
          'pdireccion': '',
          'pcorreoelectronico': '',
          'pfoto': '',
          'pidgrado': null,
          'pidperfil': null
        },
      );

      if (response == null) return [];
      
      final dynamic data = response['users'];
      if (data == null || data is! List) return [];

      // Mapeo manual porque el SP devuelve claves con Mayúscula (SQL Server style) 
      // y PagoModel.fromJson espera camelCase o minúsculas según tu modelo.
      List<PagoModel> pagos = data.map((e) {
        return PagoModel(
          idPago: e['idPago'] ?? e['idpago'] ?? 0,
          idUsuario: widget.root.user.idUsuario, // Dato conocido
          importe: (e['Importe'] ?? 0).toDouble(),
          fecha: e['Fecha']?.toString() ?? '',
          activo: true, 
          idFormaPago: 2, // Transferencia por defecto
          folio: e['Folio']?.toString() ?? '',
        );
      }).toList();

      // FILTRO: Excluir pagos que ya tienen un reporte en 'Revision'
      try {
        final pendingReportsRes = await _supabase
            .from('movcPagosReportados')
            .select('idPago')
            .eq('idUsuario', widget.root.user.idUsuario)
            .eq('Estatus', 'Revision');
        
        final List<int> pendingPaymentIds = (pendingReportsRes as List)
            .map((r) => r['idPago'] as int?)
            .where((id) => id != null) // Filtra nulos
            .cast<int>()
            .toList();

        if (pendingPaymentIds.isNotEmpty) {
          pagos = pagos.where((p) => !pendingPaymentIds.contains(p.idPago)).toList();
        }
      } catch (e) {
        debugPrint('Error filtrando pagos reportados: $e');
      }

      return pagos;
    } catch (e) {
      debugPrint('Error consultando pagos RPC: $e');
      return [];
    }
  }

double _getCostoUnitario(ConceptoCatalogo concepto) {
    if (concepto.detalles.isEmpty) return 0.0;
    final currentLogiaId = widget.selectedProfile.idLogia;

    // Buscar el detalle que coincida con la Logia actual.
    // Si no lo encuentra, tomar el costo del primer detalle como fallback.
    // La lista de conceptos ya estará filtrada, así que el primer detalle debe ser relevante.
    final ConceptoDetalle match = concepto.detalles.firstWhere(
      (d) => (d.iddLogia == currentLogiaId),
      orElse: () => concepto.detalles.first, // Fallback, aunque el filtro debería evitar esto
    );

    return match.Costo;
  }
  /// Consulta el detalle (conceptos) de un pago específico
  Future<List<PagoDetalle>> _consultarDetallePago(int idPago) async {
    try {
      final res = await _supabase.from('movdPagos').select().eq('idPago', idPago);
      final rows = (res is List) ? res.cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
      final List<PagoDetalle> detalles = [];

      for (final r in rows) {
        final iddconcepto = (r['iddConcepto'] ?? r['iddConcepto'] ?? 0);
        final cantidadRaw = r['Cantidad'] ?? r['Cantidad'] ?? 1;
        final cantidad = (cantidadRaw is int) ? cantidadRaw : int.tryParse(cantidadRaw.toString()) ?? 1;

        String nombre = 'Concepto $iddconcepto';
        double precio = 0.0;

        // Buscar nombre y precio en el catálogo local para mostrarlo bonito
        try {
          final catalogoList = widget.root.catalogos.conceptos_catalogo;
          
          // Usamos cast nullable para firstWhere
          final ConceptoCatalogo? found = catalogoList.cast<ConceptoCatalogo?>().firstWhere(
            (c) => (c?.idConcepto ?? 0) == iddconcepto,
            orElse: () => null,
          );

          if (found != null) {
            nombre = found.Descripcion;
            
            // Buscar el precio correcto según Logia o Grado
            if (found.detalles.isNotEmpty) {
              final idLogia = widget.selectedProfile.idLogia;
              
              // CORRECCIÓN CRÍTICA: Usar .iddLogia y .Costo (Notación de punto, no corchetes)
              final match = found.detalles.firstWhere(
                (d) => (d.iddLogia == idLogia) || (d.idGrado == widget.selectedProfile.idGrado),
                orElse: () => found.detalles.first,
              );
              
              precio = match.Costo;
            }
          }
        } catch (e) {
          debugPrint("Error buscando detalle local: $e");
        }

        detalles.add(PagoDetalle(
          iddconcepto: iddconcepto is int ? iddconcepto : int.tryParse(iddconcepto.toString()) ?? 0,
          nombre: nombre,
          cantidad: cantidad,
          precioUnitario: precio,
        ));
      }

      return detalles;
    } catch (e) {
      debugPrint('Error _consultarDetallePago: $e');
      return [];
    }
  }

  Future<void> _generarReferencia() async {
    if (_conceptosSeleccionados.isEmpty) return;
    
    final totalImporte = _conceptosSeleccionados.fold<double>(0.0, (sum, item) => sum + item.subtotal);
    final fecha = DateTime.now().toIso8601String();

    try {
      // 1. Insertar cabecera
      final insertRes = await _supabase
          .from('movcPagos')
          .insert({
            'idUsuario': widget.root.user.idUsuario,
            'Importe': totalImporte,
            'Fecha': fecha,
            'idFormaPago': 2, // Transferencia
            'Folio': '0',
            'Activo': 1,
          })
          .select()
          .single(); 
          
      int idPagoGenerado = 0;
      if (insertRes is Map<String, dynamic>) {
        idPagoGenerado = (insertRes['idPago'] ?? insertRes['idPago']) as int;
      }
print('idUsuario: ${widget.root.user.idUsuario}, Importe: $totalImporte, Fecha: $fecha,idFormaPago: 2, Folio: 0,Activo: 1');
      // 2. Insertar detalles
      final detallesInsert = _conceptosSeleccionados.map((pc) {
        return {
          'idPago': idPagoGenerado,
          'iddConcepto': pc.concepto.idConcepto,
          'Cantidad': pc.cantidad,
          //'iddLogia': widget.selectedProfile.idLogia,
        };
      }).toList();

      await _supabase.from('movdPagos').insert(detallesInsert);

      // 3. Mostrar papeleta y recargar
      if (mounted) {
        Navigator.of(context).pop(); // Cerrar el diálogo de selección
        _showPaymentSlipDialog(idPagoGenerado, totalImporte);
        setState(() {
          _pagosFuture = _consultarPagos();
          _conceptosSeleccionados = []; 
          if (_conceptosCatalogo.isNotEmpty) {
             // Calcula el precio del primer concepto antes de inicializarlo
            final firstConcepto = _conceptosCatalogo.first;
            final firstPrice = _getCostoUnitario(firstConcepto);

            _conceptosSeleccionados = [
              PagoConcepto(
                concepto: firstConcepto,
                precioUnitario: firstPrice, // ARGUMENTO REQUERIDO AGREGADO
                cantidad: 1,
              )
            ];
          }
        });
        // Resetear selección
        _conceptosSeleccionados = []; 
        if (_conceptosCatalogo.isNotEmpty) {
           final firstConcepto = _conceptosCatalogo.first;
          final firstPrice = _getCostoUnitario(firstConcepto);

          _conceptosSeleccionados = [
            PagoConcepto(
              concepto: firstConcepto,
              precioUnitario: firstPrice, // ARGUMENTO REQUERIDO AGREGADO
              cantidad: 1,
            )
          ];
        }
      }
    } on PostgrestException catch (e) {
      _showErrorDialog('Error Supabase', e.message);
      print('Error Supabase ${e.message}');
    } catch (e) {
      _showErrorDialog('Error', e.toString());
      print('Error ${e.toString()}');
    }
  }
// En pago_screen.dart, dentro de la clase _PagoScreenState

/// Busca el número de cuenta bancaria que coincida con la Logia actual.
  String _getCuentaBancariaForLogia() {
      final currentLogiaId = widget.selectedProfile.idLogia;
      final allConcepts = widget.root.catalogos.conceptos_catalogo;

      // 1. Búsqueda prioritaria: Encontrar la cuenta que tiene el ID de Logia actual
      for (var concepto in allConcepts) {
          for (var detalle in concepto.detalles) {
              // Verifica que el detalle sea de la Logia actual Y tenga una cuenta bancaria configurada
              if (detalle.iddLogia == currentLogiaId && detalle.ctaBanco.isNotEmpty) {
                  return detalle.ctaBanco;
              }
          }
      }

      // 2. Fallback: Si no hay una cuenta específica para esta Logia, 
      // devolvemos la primera cuenta que encontremos, como mínimo.
      for (var concepto in allConcepts) {
          for (var detalle in concepto.detalles) {
              if (detalle.ctaBanco.isNotEmpty) {
                  return detalle.ctaBanco;
              }
          }
      }

      // 3. Fallback final
      return 'N/A - Cuenta no configurada';
  }
  Future<void> _subirEstadosDeCuenta() async {
    // Lógica específica para tesoreros (Perfil 7)
    final canUpload = widget.selectedProfile.idPerfil == 7;
    if (!canUpload) {
      _showErrorDialog('Acceso denegado', 'Solo el Tesorero puede subir estados de cuenta.');
      return;
    }
    // Aquí iría la navegación o lógica de upload
    _showErrorDialog('En desarrollo', 'El módulo de carga de archivos está en construcción.');
  }

  // --- DIÁLOGOS ---

  void _showPaymentSlipDialog(int idPago, double importe) {
    final formattedImporte = NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(importe);
    final reference = idPago.toString().padLeft(7, '0');
    final concepto = 'CON-$idPago-${widget.root.user.idUsuario}';
    
    // Llama a la nueva función para obtener la cuenta específica de la Logia
    String accountNumber = _getCuentaBancariaForLogia(); 

    showDialog(
      context: context,
      builder: (context) {
        final themeColors = _getThemeColors();
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: themeColors['card'], 
          title: const Text('Papeleta de Pago Generada'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.green, size: 64),
                const SizedBox(height: 12),
                _infoRow('Referencia:', reference, themeColors['text']!),
                _infoRow('Concepto:', concepto, themeColors['text']!),
                const SizedBox(height: 8),
                // Aquí se usa la cuenta ya filtrada
                _infoRow('Cuenta destino:', accountNumber, themeColors['text']!),
                _infoRow('Importe a pagar:', formattedImporte, themeColors['text']!),
                const Divider(),
                const Text(
                  'Realiza la transferencia usando EXACTAMENTE esta referencia. Conserva esta captura.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
}

  // En pago_screen.dart

Future<void> _showPaymentDetailDialog(PagoModel pago) async {
    final detalles = await _consultarDetallePago(pago.idPago);
    final theme = _getThemeColors();
    final formattedTotal = NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(pago.importe);

    // 1. Determinar el estado del pago
    final isProcessed = (pago.folio != null && pago.folio!.isNotEmpty && pago.folio != '0');
    final statusText = isProcessed ? 'PAGO VALIDADO' : 'PENDIENTE DE VALIDAR';
    final statusColor = isProcessed ? Colors.green : Colors.redAccent;
    
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: theme['card'],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Detalle Pago #${pago.idPago}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- NUEVO WIDGET DE ESTADO ---
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor),
                  ),
                  width: double.infinity,
                  child: Text(
                    statusText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // -------------------------------
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Fecha:', style: TextStyle(fontWeight: FontWeight.w600, color: theme['text'])),
                  Text(pago.fecha, style: TextStyle(color: theme['text'])),
                ]),
                const Divider(),
                // ... (El resto del contenido de los detalles)
                Align(alignment: Alignment.centerLeft, child: Text('Conceptos:', style: TextStyle(fontWeight: FontWeight.bold, color: theme['text']))),
                const SizedBox(height: 8),
                if (detalles.isEmpty)
                  const Text('Cargando detalles o sin conceptos...')
                else
                  ...detalles.map((d) {
                    print(d.nombre);
                    print(d);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Expanded(flex: 4, child: Text(d.nombre, style: TextStyle(color: theme['text'], fontSize: 13))),
                          Expanded(flex: 1, child: Text('x${d.cantidad}', style: TextStyle(color: theme['text'], fontSize: 13))),
                          Expanded(flex: 2, child: Text(NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(d.subtotal), textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: theme['text'], fontSize: 13))),
                        ],
                      ),
                    );
                  }).toList(),
                const Divider(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, color: theme['text'])),
                  Text(formattedTotal, style: TextStyle(fontWeight: FontWeight.bold, color: theme['accent'], fontSize: 16)),
                ]),
                 if (isProcessed) // Solo muestra el folio si está procesado
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Folio Tesorería: ${pago.folio}', style: const TextStyle(fontStyle: FontStyle.italic)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cerrar')),
          ],
        );
      },
    );
}

  void _showConceptSelectionDialog() {
    // Si no hay conceptos cargados, no mostramos nada
    if (_conceptosCatalogo.isEmpty) {
      _showErrorDialog("Error", "No se pudieron cargar los conceptos del catálogo o no hay para esta Logia.");
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          double currentTotal() => _conceptosSeleccionados.fold(0.0, (s, item) => s + item.subtotal);

          return AlertDialog(
            title: const Text('Nuevo Pago'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ..._conceptosSeleccionados.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final pc = entry.value;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              DropdownButton<ConceptoCatalogo>(
                                isExpanded: true,
                                value: pc.concepto,
                                underline: Container(),
                                onChanged: (newVal) {
                                  if (newVal == null) return;
                                  
                                  // **CORRECCIÓN:** Obtenemos el nuevo precio unitario
                                  final newPrice = _getCostoUnitario(newVal);

                                  setStateDialog(() {
                                    _conceptosSeleccionados[idx] = PagoConcepto(
                                      concepto: newVal,
                                      cantidad: pc.cantidad,
                                      precioUnitario: newPrice, // Usamos el precio correcto
                                    );
                                  });
                                },
                                items: _conceptosCatalogo.map((c) {
                                  // **CORRECCIÓN:** Usamos la función auxiliar para mostrar el precio en el dropdown
                                  final p = _getCostoUnitario(c); 
                                  return DropdownMenuItem(
                                    value: c, 
                                    child: Text('${c.Descripcion} (\$${p.toStringAsFixed(0)})', overflow: TextOverflow.ellipsis)
                                  );
                                }).toList(),
                              ),
                              Row(
                                children: [
                                  const Text("Cantidad: "),
                                  SizedBox(
                                    width: 60,
                                    child: TextFormField(
                                      initialValue: pc.cantidad.toString(),
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      onChanged: (v) {
                                        final n = int.tryParse(v) ?? 1;
                                        // Aquí modificamos la cantidad sin cambiar el precio unitario
                                        setStateDialog(() => _conceptosSeleccionados[idx].cantidad = n > 0 ? n : 1);
                                      },
                                    ),
                                  ),
                                  const Spacer(),
                                  Text('\$${pc.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      if (_conceptosSeleccionados.length > 1) {
                                        setStateDialog(() => _conceptosSeleccionados.removeAt(idx));
                                      }
                                    }
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    
                    TextButton.icon(
                      onPressed: () {
                        // **CORRECCIÓN:** Inicializamos el nuevo concepto con el primer concepto filtrado y su precio correcto
                        final firstConcepto = _conceptosCatalogo.first;
                        final firstPrice = _getCostoUnitario(firstConcepto);

                        setStateDialog(() => _conceptosSeleccionados.add(
                          PagoConcepto(
                            concepto: firstConcepto, 
                            precioUnitario: firstPrice, 
                            cantidad: 1
                          )
                        ));
                      },
                      icon: const Icon(Icons.add_circle),
                      label: const Text('Agregar otro concepto'),
                    ),
                    const Divider(),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Total a Pagar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(currentTotal()), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 18)),
                    ]),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: _conceptosSeleccionados.isEmpty ? null : _generarReferencia,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                child: const Text('Generar Referencia', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
  }

  // --- DRAWER Y UI HELPERS ---

  
  Widget _infoRow(String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
        Text(value, style: TextStyle(color: textColor)),
      ]),
    );
  }

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

  void _showErrorDialog(String title, String message) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(title, style: const TextStyle(color: Colors.red)), content: Text(message), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Aceptar'))]));
  }

  @override
  Widget build(BuildContext context) {
    final theme = _getThemeColors();
    final isTreasurer = widget.selectedProfile.idPerfil == 7;

    if (isTreasurer) {
      return DefaultTabController(
        length: 3,
        initialIndex: widget.initialTab,
        child: Scaffold(
          backgroundColor: theme['bg'],
          appBar: AppBar(
            title: Text('Tesorería - ${widget.selectedProfile.LogiaNombre}', style: TextStyle(color: theme['text'])),
            backgroundColor: theme['bg'],
            elevation: 0,
            iconTheme: IconThemeData(color: theme['text']),
            bottom: TabBar(
              labelColor: theme['accent'],
              unselectedLabelColor: theme['text']?.withOpacity(0.6),
              indicatorColor: theme['accent'],
              tabs: const [
                Tab(icon: Icon(Icons.person), text: "Mis Pagos"),
                Tab(icon: Icon(Icons.fact_check), text: "Validar"),
                Tab(icon: Icon(Icons.point_of_sale), text: "Cobro"),
              ],
            ),
          ),
          drawer: AppDrawer(root: widget.root, selectedProfile: widget.selectedProfile),
          body: TabBarView(
            children: [
              _buildMainPaymentsList(theme),
              _buildValidatorTab(theme),
              _buildCashCollectorTab(theme),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: theme['accent'],
            foregroundColor: Colors.white,
            onPressed: _showConceptSelectionDialog,
            icon: const Icon(Icons.add),
            label: const Text("Nuevo Pago"),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme['bg'],
      appBar: AppBar(
        title: Text('Mis Pagos', style: TextStyle(color: theme['text'])),
        backgroundColor: theme['bg'],
        elevation: 0,
        iconTheme: IconThemeData(color: theme['text']),
      ),
      drawer: AppDrawer(
        root: widget.root, 
        selectedProfile: widget.selectedProfile
      ),
      body: _buildMainPaymentsList(theme),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme['accent'],
        foregroundColor: Colors.white,
        onPressed: _showConceptSelectionDialog,
        icon: const Icon(Icons.add),
        label: const Text("Nuevo Pago"),
      ),
    );
  }

  Widget _buildMainPaymentsList(Map<String, Color> theme) {
    final canUploadStatements = widget.selectedProfile.idPerfil == 7;
    return FutureBuilder<List<PagoModel>>(
      future: _pagosFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: theme['accent']));
        }
        if (snap.hasError) {
          return Center(child: Text('Error al cargar pagos.', style: TextStyle(color: theme['text'])));
        }
        
        final pagos = snap.data ?? [];
        
        return Column(
          children: [
            // Header visual
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
                    child: Icon(Icons.account_balance_wallet, color: theme['accent']),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Estado de Cuenta', style: TextStyle(color: theme['text'], fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(widget.selectedProfile.LogiaNombre, style: TextStyle(color: theme['text']?.withOpacity(0.7), fontSize: 12)),
                      ],
                    ),
                  ),
                  if (canUploadStatements)
                    IconButton(
                      icon: const Icon(Icons.upload_file),
                      color: theme['accent'],
                      tooltip: "Subir Estados de Cuenta",
                      onPressed: _subirEstadosDeCuenta,
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 10),

            // Lista de Pagos
            Expanded(
              child: pagos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('No tienes pagos registrados.', style: TextStyle(color: theme['text'])),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        setState(() { _pagosFuture = _consultarPagos(); });
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80), // Espacio para el FAB
                        itemCount: pagos.length,
                        itemBuilder: (context, i) {
                          final p = pagos[i];
                          // Lógica de visualización basada en si tiene folio (pagado) o no
                          final isProcessed = (p.folio.isNotEmpty && p.folio != '0' && p.idFormaPago == 2);
                          final statusText = isProcessed ? 'Procesado' : 'Pendiente';
                          final statusColor = isProcessed ? Colors.green : Colors.orange;

                          return Card(
                            color: theme['card'],
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: statusColor.withOpacity(0.2),
                                child: Icon(isProcessed ? Icons.check : Icons.access_time, color: statusColor),
                              ),
                              title: Text(
                                NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(p.importe),
                                style: TextStyle(color: theme['text'], fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('Ref: ${p.idPago}', style: TextStyle(color: theme['text']?.withOpacity(0.6), fontSize: 12)),
                                  Text(p.fecha, style: TextStyle(color: theme['text']?.withOpacity(0.8), fontSize: 12)),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                  const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
                                ],
                              ),
                              onTap: () => _showPaymentDetailDialog(p),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildValidatorTab(Map<String, Color> theme) {
    if (!_hasFetchedReportes && !_isLoadingReportes) {
      // Usamos microtask para no llamar setState durante el build
      Future.microtask(() => _fetchReportesPendientes());
    }

    return _isLoadingReportes
        ? const Center(child: CircularProgressIndicator())
        : _reportesPendientes.isEmpty
            ? Center(child: Text('No hay transferencias por validar.', style: TextStyle(color: theme['text'])))
            : RefreshIndicator(
                onRefresh: _fetchReportesPendientes,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reportesPendientes.length,
                  itemBuilder: (context, index) {
                    final r = _reportesPendientes[index];
                    final miembro = widget.root.catalogos.listaLogiasPorUsuario.firstWhere(
                      (m) => m.idUsuario == r.idUsuario,
                      orElse: () => ListaLogiasPorUsuario(Nombre: 'Usuario Desconocido', idUsuario: 0, FechaNacimiento: '', perfiles: []),
                    );

                    return Card(
                      color: theme['card'],
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: theme['bg'],
                          child: Icon(Icons.transfer_within_a_station, color: theme['accent']),
                        ),
                        title: Text(
                          miembro.Nombre,
                          style: TextStyle(color: theme['text'], fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Monto: \$${r.Monto} - Ref: ${r.ReferenciaUnica ?? "N/A"}',
                              style: TextStyle(color: theme['text']?.withOpacity(0.7), fontSize: 13),
                            ),
                            if (r.idPago != null)
                              Text(
                                'VINCULADO A PAGO #${r.idPago}',
                                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                          ],
                        ),
                        iconColor: theme['accent'],
                        collapsedIconColor: theme['text']?.withOpacity(0.5),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: theme['bg']?.withOpacity(0.3),
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _infoRow('Fecha Pago Real:', r.FechaPagoReal, theme['text']!),
                                _infoRow('Folio Bancario:', r.FolioBancario ?? "N/A", theme['text']!),
                                const SizedBox(height: 15),
                                if (r.UrlComprobante != null)
                                  InkWell(
                                    onTap: () => _showFullImage(r.UrlComprobante!),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Image.network(
                                            _supabase.storage.from('radios_docs').getPublicUrl(r.UrlComprobante!),
                                            height: 200,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                                            child: const Icon(Icons.fullscreen, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _rejectReport(r),
                                        icon: const Icon(Icons.close, color: Colors.red, size: 18),
                                        label: const Text('RECHAZAR', style: TextStyle(color: Colors.red, fontSize: 13)),
                                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _approveReport(r),
                                        icon: const Icon(Icons.check, color: Colors.white, size: 18),
                                        label: const Text('APROBAR', style: TextStyle(color: Colors.white, fontSize: 13)),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
  }

  Future<void> _rejectReport(PagoReportado reporte) async {
    String motivo = '';
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar Pago'),
        content: TextField(
          decoration: const InputDecoration(labelText: 'Motivo del rechazo'),
          onChanged: (v) => motivo = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              print('DEBUG: Botón RECHAZAR presionado');
              print('DEBUG: Motivo: $motivo');
              print('DEBUG: ID Reporte: ${reporte.idReporte}');
              
              try {
                  // USO DE RPC PARA EVITAR PROBLEMAS DE RLS
                  final res = await _supabase.rpc('rechazar_pago_reportado', params: {
                    'p_id_reporte': reporte.idReporte,
                    'p_motivo': motivo,
                  });
                  print('DEBUG: RPC Mensaje respuesta: $res');
              } catch (e) {
                  print('DEBUG: ERROR RPC: $e');
              }

              // BORRAR IMAGEN DEL BUCKET SI ES RECHAZADO (Para no usar espacio innecesario)
              if (reporte.UrlComprobante != null) {
                try {
                  final rawUrl = reporte.UrlComprobante!;
                  final decodedUrl = Uri.decodeFull(rawUrl);
                  
                  String cleanPath = decodedUrl;
                  if (decodedUrl.contains('/radios_docs/')) {
                    cleanPath = decodedUrl.split('/radios_docs/').last;
                  }

                  await _supabase.rpc(
                    'delete_file_admin', 
                    params: {
                      'bucket_name': 'radios_docs',
                      'object_path': cleanPath,
                    }
                  );
                } catch (e) {
                   debugPrint('Error borrando imagen al rechazar: $e');
                }
              }

              Navigator.pop(ctx);
              _fetchReportesPendientes();
            },
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
  }


  Widget _buildCashCollectorTab(Map<String, Color> theme) {
    final miembros = widget.root.catalogos.listaLogiasPorUsuario.where((m) {
      return m.perfiles.any((p) => p.idLogia == widget.selectedProfile.idLogia);
    }).toList();

    double totalCobro = _conceptosCobroEfectivo.fold(0.0, (s, item) => s + item.subtotal);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sección de Selección de Miembro
          Card(
            color: theme['card'],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_search, color: theme['accent'], size: 20),
                      const SizedBox(width: 8),
                      Text('1. Seleccionar Miembro', style: TextStyle(color: theme['text'], fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ListaLogiasPorUsuario>(
                    value: _selectedMemberForCash,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: theme['bg']?.withOpacity(0.3),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      prefixIcon: Icon(Icons.person, color: theme['accent']),
                      hintText: "Selecciona un hermano",
                    ),
                    items: miembros.map((m) => DropdownMenuItem(value: m, child: Text(m.Nombre, style: const TextStyle(fontSize: 14)))).toList(),
                    onChanged: (v) => setState(() => _selectedMemberForCash = v),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          const SizedBox(height: 16),
          
          // Sección de Conceptos (Envuelta en Card Unificada)
          Card(
            color: theme['card'],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shopping_cart_checkout, color: theme['accent'], size: 20),
                          const SizedBox(width: 8),
                          Text('2. Conceptos', style: TextStyle(color: theme['text'], fontSize: 15, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      // Botón "Agregar" en el header si hay elementos
                       if (_conceptosCobroEfectivo.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            if (_conceptosCatalogo.isNotEmpty) {
                              final first = _conceptosCatalogo.first;
                              setState(() {
                                  _conceptosCobroEfectivo.add(PagoConcepto(
                                    concepto: first,
                                    cantidad: 1,
                                    precioUnitario: _getCostoUnitario(first),
                                  ));
                                });
                            }
                          },
                          icon: Icon(Icons.add_circle, color: theme['accent'], size: 20),
                          label: Text('Agregar', style: TextStyle(color: theme['accent'])),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Lista de conceptos editables
                  if (_conceptosCobroEfectivo.isEmpty)
                    InkWell(
                      onTap: () {
                        if (_conceptosCatalogo.isNotEmpty) {
                            final first = _conceptosCatalogo.first;
                            setState(() {
                              _conceptosCobroEfectivo.add(PagoConcepto(
                                concepto: first,
                                cantidad: 1,
                                precioUnitario: _getCostoUnitario(first),
                              ));
                            });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.withOpacity(0.3), style: BorderStyle.solid), // Usando solid ;)
                          borderRadius: BorderRadius.circular(12),
                          color: theme['bg']?.withOpacity(0.5),
                        ),
                        child: const Center(child: Text('+ Agregar primer concepto', style: TextStyle(color: Colors.grey))),
                      ),
                    )
                  else
                    ..._conceptosCobroEfectivo.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final pc = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme['bg']?.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme['bg'] ?? Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            DropdownButton<ConceptoCatalogo>(
                              isExpanded: true,
                              value: pc.concepto,
                              underline: Container(), // Sin línea fea
                              icon: const Icon(Icons.arrow_drop_down),
                              isDense: true,
                              onChanged: (newVal) {
                                if (newVal == null) return;
                                final newPrice = _getCostoUnitario(newVal);
                                setState(() {
                                  _conceptosCobroEfectivo[idx] = PagoConcepto(
                                    concepto: newVal,
                                    cantidad: pc.cantidad,
                                    precioUnitario: newPrice,
                                  );
                                });
                              },
                              items: _conceptosCatalogo.map((c) {
                                final p = _getCostoUnitario(c); 
                                return DropdownMenuItem(
                                  value: c, 
                                  child: Text('${c.Descripcion} (\$${p.toStringAsFixed(0)})', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: theme['text']))
                                );
                              }).toList(),
                            ),
                            const Divider(height: 20),
                            Row(
                              children: [
                                const Text("Cant: ", style: TextStyle(fontSize: 13)),
                                SizedBox(
                                  width: 50,
                                  child: TextFormField(
                                    initialValue: pc.cantidad.toString(),
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                      decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                                      border: InputBorder.none, // Más limpio
                                    ),
                                    onChanged: (v) {
                                      final n = int.tryParse(v) ?? 1;
                                      setState(() => _conceptosCobroEfectivo[idx].cantidad = n > 0 ? n : 1);
                                    },
                                  ),
                                ),
                                const Spacer(),
                                Text('\$${pc.subtotal.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: theme['text'], fontSize: 15)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                      setState(() => _conceptosCobroEfectivo.removeAt(idx));
                                  }
                                ),
                              ],
                            )
                          ],
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          
          // Sección de Folio y Registro
          Card(
            color: theme['card'],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.receipt_long, color: theme['accent'], size: 20),
                      const SizedBox(width: 8),
                      Text('3. Folio Recibo Físico', style: TextStyle(color: theme['text'], fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _folioEfectivoController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: theme['bg']?.withOpacity(0.3),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      hintText: 'Ej: A-1234',
                      hintStyle: TextStyle(color: theme['text']?.withOpacity(0.3)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 25),
          
          // Resumen y Botón Final
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [theme['accent']!, theme['accent']!.withOpacity(0.8)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: theme['accent']!.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL A COBRAR:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(totalCobro), 
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: theme['accent'],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _isSavingCash ? null : _saveCashPayment,
                    child: _isSavingCash
                        ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: theme['accent'], strokeWidth: 2))
                        : const Text('REGISTRAR COBRO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80), // Espacio para scroll
        ],
      ),
    );
  }

  void _showAddConceptForCashDialog() {
    if (_conceptosCatalogo.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (ctx) {
        ConceptoCatalogo sel = _conceptosCatalogo.first;
        int cant = 1;
        return StatefulBuilder(
          builder: (context, setSt) {
            return AlertDialog(
              title: const Text('Añadir Concepto'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<ConceptoCatalogo>(
                    isExpanded: true,
                    value: sel,
                    items: _conceptosCatalogo.map((c) => DropdownMenuItem(
                      value: c, 
                      child: Text(c.Descripcion, overflow: TextOverflow.ellipsis)
                    )).toList(),
                    onChanged: (v) { if (v != null) setSt(() => sel = v); },
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      const Text('Cantidad:'),
                      const SizedBox(width: 10),
                      IconButton(onPressed: () => setSt(() => cant = (cant > 1) ? cant - 1 : 1), icon: const Icon(Icons.remove)),
                      Text('$cant'),
                      IconButton(onPressed: () => setSt(() => cant++), icon: const Icon(Icons.add)),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _conceptosCobroEfectivo.add(PagoConcepto(
                        concepto: sel,
                        cantidad: cant,
                        precioUnitario: _getCostoUnitario(sel),
                      ));
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Añadir'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _showFullImage(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(_supabase.storage.from('radios_docs').getPublicUrl(url), fit: BoxFit.contain),
            ),
          ],
        ),
      ),
    );
  }
}
