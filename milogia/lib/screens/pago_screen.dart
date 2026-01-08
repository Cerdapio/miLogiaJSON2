import 'package:flutter/material.dart';
import 'package:milogia/screens/app_drawer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/pago_model.dart'; 
import 'app_drawer.dart';
// Importa tus otras pantallas aquí

//import 'home_screen.dart';
//import 'documents_screen.dart'; 
//import 'emergencies_screen.dart';
//import 'jobs_screen.dart';

//import 'profile_edit_screen.dart';

// Clases auxiliares solo para la vista (ViewModel helpers)
//class PagoConcepto {
 // final ConceptoCatalogo concepto;
//  int cantidad;
//  PagoConcepto({required this.concepto, this.cantidad = 1});
//  double get subtotal {
//    // Lógica para obtener el costo del primer detalle o 0.0
//    // En un escenario real, deberías filtrar el detalle específico por grado/logia aquí también
//    if (concepto.detalles.isEmpty) return 0.0;
//    return concepto.detalles.first.Costo * cantidad;
//  }
  
//  // Helper para obtener el precio unitario visualmente
//  double get precioUnitario {
//     if (concepto.detalles.isEmpty) return 0.0;
//     return concepto.detalles.first.Costo;
//  }
//}
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

  const PagoScreen({super.key, required this.root, required this.selectedProfile});

  @override
  State<PagoScreen> createState() => _PagoScreenState();
}

class _PagoScreenState extends State<PagoScreen> {
  late Future<List<PagoModel>> _pagosFuture;
  final _supabase = Supabase.instance.client;
  
  // Listas para el dropdown de generar pago
  List<ConceptoCatalogo> _conceptosCatalogo = [];
  List<PagoConcepto> _conceptosSeleccionados = [];

  @override
  void initState() {
    super.initState();
    _loadConceptosFromCatalog();
    _pagosFuture = _consultarPagos();
    
    // Pre-seleccionar un concepto si existe
    if (_conceptosCatalogo.isNotEmpty) {
      final firstConcepto = _conceptosCatalogo.first;
      final firstPrice = _getCostoUnitario(firstConcepto);

      _conceptosSeleccionados.add(PagoConcepto(
        concepto: firstConcepto,
        precioUnitario: firstPrice, // ARGUMENTO REQUERIDO AGREGADO
        cantidad: 1,
      ));
    }
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

  /// Consulta los pagos históricos vía RPC (Stored Procedure)
  Future<List<PagoModel>> _consultarPagos() async {
    try {
      final response = await _supabase.rpc(
        'sp_catcusuariosn', 
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
          'pfoto': ''
        },
      );

      if (response == null) return [];
      
      final dynamic data = response['users'];
      if (data == null || data is! List) return [];

      // Mapeo manual porque el SP devuelve claves con Mayúscula (SQL Server style) 
      // y PagoModel.fromJson espera camelCase o minúsculas según tu modelo.
      final pagos = data.map((e) {
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
    // Lógica: Si el perfil es 7 (Tesorero), puede ver el botón de subir estados.
    final canUploadStatements = widget.selectedProfile.idPerfil == 7;

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
      body: FutureBuilder<List<PagoModel>>(
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
                            //print ('Ref: ${p.idPago} idFormaPago: ${p.idFormaPago} Folio: ${p.folio}');
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme['accent'],
        foregroundColor: Colors.white,
        onPressed: _showConceptSelectionDialog,
        icon: const Icon(Icons.add),
        label: const Text("Nuevo Pago"),
      ),
    );
  }
}