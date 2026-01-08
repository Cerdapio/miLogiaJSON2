import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import 'package:milogia/config/auth_config.dart'; // Import correcto para LogiaTheme

class ActasScreen extends StatefulWidget {
  final RootModel root;
  final PerfilOpcion selectedProfile;

  const ActasScreen({super.key, required this.root, required this.selectedProfile});

  @override
  State<ActasScreen> createState() => _ActasScreenState();
}

class _ActasScreenState extends State<ActasScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Datos Generales
  DateTime _fecha = DateTime.now();
  String _tipoTenida = 'Ordinaria';
  TimeOfDay _hora = const TimeOfDay(hour: 20, minute: 0);
  
  // Oficiales (Cuadro)
  final Map<int, ListaLogiasPorUsuario?> _oficiales = {};
  
  // Trabajos
  final List<Map<String, dynamic>> _trabajos = [];
  
  // Asistencias / Disculpas
  final List<Map<String, dynamic>> _disculpas = [];
  
  // Saco
  double _sacoBeneficencia = 0.0;
  
  // Miembros de la Logia actual
  List<ListaLogiasPorUsuario> _miembrosLogia = [];

  // Theme Helpers
  Color _parseHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    String h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    try {
      return Color(int.parse(h, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  late LogiaTheme _theme;

  @override
  void initState() {
    super.initState();
    _loadMiembros();
    _prefillOficiales();
    _loadTheme();
  }

  void _loadTheme() {
    final colores = widget.selectedProfile.colores;
    _theme = LogiaTheme(
      nombre: 'Dynamic',
      primaryColor: _parseHex(colores.C1, const Color(0xFFF5F5F5)), 
      secondaryColor: _parseHex(colores.C4, const Color(0xFFDAA520)),
      accentColor: _parseHex(colores.C2, const Color(0xFF222222)), 
      backgroundColor: _parseHex(colores.C3, Colors.white), 
    );
  }

  void _loadMiembros() {
    _miembrosLogia = widget.root.catalogos.listaLogiasPorUsuario.where((u) {
      return u.perfiles.any((p) => p.idLogia == widget.selectedProfile.idLogia);
    }).toList();
  }

  void _prefillOficiales() {
    final puestos = [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 14];
    for (var idPerfil in puestos) {
      try {
        final oficial = _miembrosLogia.firstWhere((u) {
          return u.perfiles.any((p) => 
            p.idLogia == widget.selectedProfile.idLogia && p.idPerfil == idPerfil
          );
        });
        _oficiales[idPerfil] = oficial;
      } catch (e) {
        _oficiales[idPerfil] = null;
      }
    }
  }

  final Map<int, String> _nombresPuestos = {
    1: 'Venerable Maestro',
    5: 'Secretario',
    4: 'Orador',
    2: 'Primer Vigilante',
    3: 'Segundo Vigilante',
    6: 'Maestro de Ceremonias',
    8: 'Primer Experto',
    9: 'Segundo Experto',
    10: 'Hospitalario',
    11: 'Porta Estandarte',
    14: 'Guarda Templo Interior',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _theme.backgroundColor,
      appBar: AppBar(
        title: Text('LEVANTAR ACTA', style: TextStyle(color: _theme.secondaryColor, fontWeight: FontWeight.bold)),
        backgroundColor: _theme.primaryColor,
        iconTheme: IconThemeData(color: _theme.secondaryColor),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Datos Generales', Icons.calendar_today),
              const SizedBox(height: 10),
              _buildHeaderSection(),
              const SizedBox(height: 20),
              
              _buildSectionHeader('Cuadro Logial', Icons.groups),
              const SizedBox(height: 10),
              _buildCuadroSection(),
              const SizedBox(height: 20),
              
              _buildSectionHeader('Trabajos Presentados', Icons.history_edu),
              const SizedBox(height: 10),
              _buildTrabajosSection(),
              const SizedBox(height: 20),
              
              _buildSectionHeader('Saco de Proposiciones', Icons.mail_outline),
              const SizedBox(height: 10),
              _buildAsistenciasSection(),
              const SizedBox(height: 20),
              
              _buildSectionHeader('Saco de Beneficencia', Icons.volunteer_activism),
              const SizedBox(height: 10),
              _buildSacoSection(),
              const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _theme.accentColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _generarPrevisualizacion,
                  icon: const Icon(Icons.description, color: Colors.white),
                  label: const Text('GENERAR PREVISUALIZACIÓN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _theme.secondaryColor, size: 28),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(color: _theme.primaryColor, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildHeaderSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _tipoTenida,
              decoration: InputDecoration(
                labelText: 'Tipo de Tenida',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.event_note),
              ),
              items: ['Ordinaria', 'Extraordinaria', 'Fúnebre', 'Solsticial'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _tipoTenida = v!),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _fecha,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        builder: (ctx, child) {
                          return Theme(
                            data: Theme.of(ctx).copyWith(
                              colorScheme: ColorScheme.light(primary: _theme.primaryColor, onPrimary: _theme.secondaryColor),
                            ),
                            child: child!,
                          );
                        }
                      );
                      if (picked != null) setState(() => _fecha = picked);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Fecha',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.calendar_month),
                      ),
                      child: Text(DateFormat('dd/MM/yyyy').format(_fecha)),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(context: context, initialTime: _hora);
                      if (picked != null) setState(() => _hora = picked);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Hora',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.access_time),
                      ),
                      child: Text(_hora.format(context)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCuadroSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: _nombresPuestos.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: DropdownButtonFormField<ListaLogiasPorUsuario>(
                value: _oficiales[entry.key],
                decoration: InputDecoration(
                  labelText: entry.value,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                items: [
                  const DropdownMenuItem<ListaLogiasPorUsuario>(value: null, child: Text('Descubierto / Seleccionar...')),
                  ..._miembrosLogia.map((m) => DropdownMenuItem(value: m, child: Text(m.Nombre))),
                ],
                onChanged: (v) => setState(() => _oficiales[entry.key] = v),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTrabajosSection() {
    return Card(
       elevation: 4,
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
       child: Padding(
         padding: const EdgeInsets.all(16.0),
         child: Column(
          children: [
            if (_trabajos.isNotEmpty)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _trabajos.length,
                separatorBuilder: (ctx, i) => const Divider(),
                itemBuilder: (ctx, i) {
                   final t = _trabajos[i];
                   return ListTile(
                     leading: CircleAvatar(
                       backgroundColor: _theme.secondaryColor,
                       child: Text((i+1).toString(), style: TextStyle(color: _theme.primaryColor)),
                     ),
                     title: Text(t['titulo'], style: const TextStyle(fontWeight: FontWeight.bold)),
                     subtitle: Text('${t['tipo']} - Por: ${t['autor'].Nombre}'),
                     trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _trabajos.removeAt(i))),
                   );
                },
              ),
            if (_trabajos.isNotEmpty) const SizedBox(height: 15),
            OutlinedButton.icon(
              onPressed: _agregarTrabajoDialog,
              icon: const Icon(Icons.add),
              label: const Text('AGREGAR TRABAJO'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                side: BorderSide(color: _theme.primaryColor),
              ),
            ),
          ],
         ),
       ),
    );
  }

  Future<void> _agregarTrabajoDialog() async {
    ListaLogiasPorUsuario? autor;
    String tipo = 'Trazado de Arquitectura';
    bool esTemaObligatorio = false;
    String? temaObligatorioSeleccionado;
    String temaLibre = '';
    
    // Controlador de estado local para el diálogo
    List<String> opcionesObligatorias = [];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            
            // Lógica para actualizar las opciones según el autor seleccionado
            void actualizarOpciones() {
              opcionesObligatorias = [];
              if (autor != null) {
                // Obtener grado
                final perfil = autor!.perfiles.firstWhere(
                  (p) => p.idLogia == widget.selectedProfile.idLogia,
                  orElse: () => MiembroPerfil(idLogia: 0, Tratamiento: '', Grado: 0, idPerfil: 0, PerfilNombre: ''),
                );
                int grado = perfil.Grado;
                
                // Buscar en catalogo
                for (var doc in widget.root.catalogos.documentos_catalogo) {
                   for (var detalle in doc.detalles) {
                     if (detalle.Grado == grado) {
                       opcionesObligatorias.add(detalle.NombreLargo);
                     }
                   }
                }
              }
            }

            return AlertDialog(
              title: const Text('Agregar Trabajo'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<ListaLogiasPorUsuario>(
                      decoration: const InputDecoration(labelText: 'Autor'),
                      items: _miembrosLogia.map((m) => DropdownMenuItem(value: m, child: Text(m.Nombre))).toList(),
                      onChanged: (v) {
                        setStateDialog(() {
                          autor = v;
                          temaObligatorioSeleccionado = null; // Resetear selección
                          actualizarOpciones();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: tipo,
                      decoration: const InputDecoration(labelText: 'Tipo de Trabajo'),
                      items: ['Trazado de Arquitectura', 'Burilado', 'Trabajo de Albañilería', 'Otro'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setStateDialog(() => tipo = v!),
                    ),
                    const SizedBox(height: 10),
                   
                    if (autor != null && opcionesObligatorias.isNotEmpty)
                      SwitchListTile(
                        title: const Text('¿Es Tema Obligatorio del Grado?'),
                        value: esTemaObligatorio,
                        activeColor: _theme.secondaryColor,
                        onChanged: (v) => setStateDialog(() => esTemaObligatorio = v),
                      ),
                      
                    if (esTemaObligatorio && opcionesObligatorias.isNotEmpty)
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: temaObligatorioSeleccionado,
                        hint: const Text('Seleccione el tema...'),
                        items: opcionesObligatorias.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setStateDialog(() => temaObligatorioSeleccionado = v),
                      ),
                      
                    if (!esTemaObligatorio || opcionesObligatorias.isEmpty)
                      TextField(
                        decoration: const InputDecoration(labelText: 'Título del Trabajo (Tema Libre)'),
                        onChanged: (v) => temaLibre = v,
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _theme.primaryColor),
                  onPressed: () {
                    String tituloFinal = esTemaObligatorio 
                        ? (temaObligatorioSeleccionado ?? '') 
                        : temaLibre;
                        
                    if (autor != null && tituloFinal.isNotEmpty) {
                      setState(() {
                        _trabajos.add({'autor': autor, 'tipo': tipo, 'titulo': tituloFinal});
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Agregar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAsistenciasSection() {
     return Card(
       elevation: 4,
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
       child: Padding(
         padding: const EdgeInsets.all(16.0),
         child: Column(
           children: [
             if (_disculpas.isNotEmpty)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _disculpas.length,
                separatorBuilder: (ctx, i) => const Divider(),
                itemBuilder: (ctx, i) {
                   final d = _disculpas[i];
                   return ListTile(
                     leading: const Icon(Icons.mark_email_read, color: Colors.grey),
                     title: Text('Disculpa para: ${d['ausente'].Nombre}'),
                     subtitle: Text('Presentada por: ${d['solicitante'].Nombre}'),
                     trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _disculpas.removeAt(i))),
                   );
                },
              ),
            if (_disculpas.isNotEmpty) const SizedBox(height: 15),
            OutlinedButton.icon(
              onPressed: _agregarDisculpaDialog,
              icon: const Icon(Icons.add),
              label: const Text('REGISTRAR DISCULPA'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                side: BorderSide(color: _theme.primaryColor),
              ),
            ),
           ],
         ),
       ),
     );
  }

  Future<void> _agregarDisculpaDialog() async {
    ListaLogiasPorUsuario? ausente;
    ListaLogiasPorUsuario? solicitante;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Disculpa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<ListaLogiasPorUsuario>(
              decoration: const InputDecoration(labelText: 'H:. Ausente'),
              items: _miembrosLogia.map((m) => DropdownMenuItem(value: m, child: Text(m.Nombre))).toList(),
              onChanged: (v) => ausente = v,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<ListaLogiasPorUsuario>(
              decoration: const InputDecoration(labelText: 'H:. que disculpa'),
              items: _miembrosLogia.map((m) => DropdownMenuItem(value: m, child: Text(m.Nombre))).toList(),
              onChanged: (v) => solicitante = v,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _theme.primaryColor),
            onPressed: () {
              if (ausente != null && solicitante != null) {
                setState(() {
                  _disculpas.add({'ausente': ausente, 'solicitante': solicitante});
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Agregar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSacoSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextFormField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Monto Recaudado', 
            prefixText: '\$ ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.attach_money),
          ),
          onChanged: (v) => _sacoBeneficencia = double.tryParse(v) ?? 0.0,
        ),
      ),
    );
  }

  void _generarPrevisualizacion() {
    final logiaNombre = widget.selectedProfile.LogiaNombre;
    final fechaStr = DateFormat('dd/MM/yyyy').format(_fecha); 
    
    String n(int id) => _oficiales[id]?.Nombre ?? "______________________";

    String texto = """
En el Ote⸫ de Chihuahua, Chihuahua, siendo las ${_hora.format(context)} del día $fechaStr E⸫ V⸫ reunidos en el punto geométrico solo conocido por los HH⸫ que conformamos la Res⸫ y Cent⸫ Log⸫ Sim⸫ $logiaNombre, Juris⸫ a la M⸫R⸫G⸫L⸫ Cosmos A⸫C⸫ del estado de Chihuahua y del R⸫E⸫A⸫ y A⸫ celebrando tenida $_tipoTenida conformándose el cuadro de la sig⸫ manera:

V⸫M⸫ ${n(1)}
Sec⸫ P⸫T⸫ ${n(5)}
Or⸫ P⸫T⸫ ${n(4)}
1° Vig⸫ ${n(2)}
2° Vig⸫ ${n(3)}
M⸫C⸫ ${n(6)}
Pri⸫Exp⸫ ${n(8)}
Seg⸫Exp⸫ ${n(9)}
Hosp⸫ ${n(10)}
Porta⸫ Est⸫ ${n(11)}
G⸫T⸫I⸫ ${n(14)}

1. Se abren los trabajos con el ritual acostumbrado.
2. El V⸫M⸫ solicita al H⸫ Sec⸫ dar lectura a la plancha, el V⸫M⸫ concede la palabra para hacer observaciones a la plancha, reinando el silencio.
3. El V⸫M⸫ Solicita al M⸫C⸫ circule el saco de proposiciones de acuerdo al ritual de costumbre y este arroja entre sus despojos después de ser circulado el siguiente material:
""";

    if (_trabajos.isEmpty) {
      texto += "   (Sin trabajos presentados)\n";
    } else {
      for (var t in _trabajos) {
        texto += "   - ${t['tipo']} \"${t['titulo']}\" Del Q⸫H⸫ ${t['autor'].Nombre}\n";
      }
    }

    texto += """
4. El V⸫M⸫ concede la pal⸫ para disculpar a los H⸫ Aus⸫.
""";

    if (_disculpas.isEmpty) {
      texto += "   (Sin disculpas presentadas)\n";
    } else {
      for (var d in _disculpas) {
        texto += "   - El H⸫ ${d['solicitante'].Nombre} pide la palabra para disculpar al H⸫ ${d['ausente'].Nombre}\n";
      }
    }

    texto += """
5. El V⸫M⸫ solicita al H⸫ Or⸫ dar la bienvenida. El H⸫ Or⸫ realiza su trazado de bienvenida.
6. Se concede la pal⸫ en bien Gral⸫ de la Orden de la humanidad y de este taller en particular.
7. Tocan a las puertas en Gr⸫ de Apr⸫...
8. Con el permiso del Pri⸫ Vig⸫ y Seg⸫ Vig⸫ el V⸫M⸫ concede la palabra para hacer comentarios acerca de los trabajos.
Toman la pal⸫ en el sig⸫ orden: V⸫ M⸫, Pri⸫ Exp⸫, M⸫C⸫, G⸫T⸫I⸫, Pri⸫Vig⸫, H⸫ Hosp⸫ y V⸫M⸫.
9. El V⸫M⸫ solicita al H⸫ Hosp⸫ circular el saco de beneficiencia con el ritual acostumbrado el cual arrojo entre sus despojos \$$_sacoBeneficencia (u objetos).
10. El V⸫M⸫ solicita al H⸫ Or⸫ nos dé su opinión acerca de los trabajos y las gracias a los H⸫ asistentes el H⸫ Or⸫ realiza su trazado de despedida dando las gracias a todos los H⸫ asistentes y considerando Justos y perfectos los trabajos.
11. El V⸫M⸫ cierra los trabajos de acuerdo al ritual acostumbrado.
""";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vista Previa del Acta'),
        content: SingleChildScrollView(child: Text(texto)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _theme.primaryColor),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Acta guardada (Simulación)')));
            },
            child: const Text('Confirmar y Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
