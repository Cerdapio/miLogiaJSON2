import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import '../models/user_model.dart';
import '../utils/dropdown_utils.dart';
import '../config/auth_config.dart';

class SuperAdminScreen extends StatefulWidget {
  final RootModel root;
  final PerfilOpcion selectedProfile;

  const SuperAdminScreen({super.key, required this.root, required this.selectedProfile});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  // --- Controllers para Gestión de Logias ---
  final _lodgeFormKey = GlobalKey<FormState>();
  final _lodgeNameController = TextEditingController();
  String? _selectedLodgeGroup;
  // Lista fija de grupos según lo solicitado
  final List<String> _lodgeGroups = const [
    "Grados Simbólicos",
    "Logias Capitulares de Perfección",
    "Capítulos de Caballeros Rosacruz",
    "Areópagos de Caballeros Kadosh",
    "Consistorios y Supremo Consejo",
  ];

  // --- Controllers para Gestión de Usuarios (similar a ProfileEditScreen) ---
  final _userAssignFormKey = GlobalKey<FormState>();
  int? _selectedUserToEdit;
  int? _selectedNewProfileId;
  int? _selectedNewLogiaId;
  int? _selectedNewGrado;
  late Future<List<Map<String, dynamic>>> _usersFuture;

  // --- Controllers para Nuevo Usuario ---
  final _newUserFormKey = GlobalKey<FormState>();
  final _newUserNameController = TextEditingController();
  final _newUserEmailController = TextEditingController();
  final _newUserPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _usersFuture = _fetchAllUsers();
  }

  @override
  void dispose() {
    _lodgeNameController.dispose();
    _newUserNameController.dispose();
    _newUserEmailController.dispose();
    _newUserPasswordController.dispose();
    super.dispose();
  }

  // **CORRECCIÓN: Usar el catálogo local en lugar de una llamada a la red.**
  Future<List<Map<String, dynamic>>> _fetchAllUsers() async {
    // La lista ya viene en el RootModel, la transformamos al formato esperado.
    final localUsers = widget.root.catalogos.listaLogiasPorUsuario;
    return localUsers.map((user) => {
      'idUsuario': user.idUsuario,
      'Nombre': user.Nombre,
    }).toList();
  }

  Future<void> _createLodge() async {
    if (!_lodgeFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // **CAMBIO CRÍTICO: Usar el RPC en lugar de una inserción directa**
      // Esto maneja la creación en catcLogia y la relación en catdLogia de forma atómica y segura.

      // El idLogia del perfil del Super Admin es, en realidad, su idGranLogia.
      final idGranLogia = widget.selectedProfile.idLogia;

      final newLodgeData = await _supabase.rpc('create_lodge_and_link', params: {
        'p_descripcion': _lodgeNameController.text.trim(),
        'p_grupo': _selectedLodgeGroup,
        'p_id_gran_logia': idGranLogia,
      });

      _showSuccessDialog('Éxito', 'La logia ha sido creada correctamente.');

      // **SOLUCIÓN: Actualizar el catálogo local en tiempo real**
      if (newLodgeData != null) {
        // El RPC devuelve un JSON que coincide con LogiaCatalogo.fromJson
        final newLodge = LogiaCatalogo.fromJson(newLodgeData);
        setState(() {
          // Añadimos la nueva logia a la lista del modelo para que se refleje en la UI
          widget.root.catalogos.logias_catalogo.add(newLodge);
        });
      }
      
      _lodgeFormKey.currentState?.reset();
      _lodgeNameController.clear();
      setState(() {
        _selectedLodgeGroup = null; // Limpiar el dropdown
      });
    } on PostgrestException catch (e) {
      _showErrorDialog('Error de Base de Datos', e.message);
    } catch (e) {
      _showErrorDialog('Error Desconocido', e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createNewUser() async {
    if (!_newUserFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final authResponse = await _supabase.auth.signUp(
        email: _newUserEmailController.text.trim(),
        password: _newUserPasswordController.text,
      );
      if (authResponse.user == null) throw Exception("No se pudo crear el usuario en el sistema de autenticación.");

      final newUserResponse = await _supabase
          .from('catcUsuarios')
          .insert({
            'Nombre': _newUserNameController.text.trim(),
            'Usuario': _newUserEmailController.text.split('@').first,
            'Contraseña': _newUserPasswordController.text,
            'CorreoElectronico': _newUserEmailController.text.trim(),
            'auth_uuid': authResponse.user!.id,
          })
          .select('idUsuario, Nombre')
          .single();

      _showSuccessDialog('Usuario Creado', 'El usuario "${newUserResponse['Nombre']}" ha sido creado. Ahora puedes asignarle un rol.');
      _newUserFormKey.currentState?.reset();
      _newUserNameController.clear();
      _newUserEmailController.clear();
      _newUserPasswordController.clear();
      // Recargar la lista de usuarios para que aparezca el nuevo
      setState(() {
        _usersFuture = _fetchAllUsers();
        _selectedUserToEdit = newUserResponse['idUsuario'];
      });
    } catch (e) {
      _showErrorDialog('Error al Crear Usuario', e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Llama a la Edge Function para enviar una notificación push al usuario.
  Future<void> _notifyUserByPush(int userId, String title, String body) async {
    try {
      // 1. Obtener el auth.uuid del usuario desde la tabla catcUsuarios.
      final response = await _supabase
          .from('catcUsuarios')
          .select('auth_uuid')
          .eq('idUsuario', userId)
          .single();

      final authUuid = response['auth_uuid'];
      if (authUuid == null) {
        print("Advertencia: No se encontró el auth_uuid para el usuario con ID $userId.");
        return;
      }

      // 2. Llamar a la Edge Function
      await _supabase.functions.invoke('send-push-notification', body: {'user_id': authUuid, 'title': title, 'body': body});
    } catch (e) {
      print('Error al intentar enviar notificación push: $e');
    }
  }

  Future<void> _assignRole() async {
    if (!_userAssignFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Usamos el SP con opción 8, igual que en el perfil de admin de logia
      await _supabase.rpc(
        rpcFunction,
        params: {
          'popcion': 8,
          'pidusuario': _selectedUserToEdit,
          'piddlogia': _selectedNewLogiaId,
          'pnombre': '',
          'pusuario': '', 
          'pcontrasena': '',
          'ptelefono': '',
          'pfechanacimiento': '',
          'pdireccion': '',
          'pcorreoelectronico': '',
          'pfoto': '',
          'pidgrado': _selectedNewGrado,
          'pidperfil': _selectedNewProfileId
        },
      );
      _showSuccessDialog("Asignación Exitosa", "El rol ha sido asignado/actualizado para el usuario.");

      // --- NUEVO: Notificar al usuario por PUSH ---
      final perfilNombre = widget.root.catalogos.perfiles_catalogo.firstWhere((p) => p.idPerfil == _selectedNewProfileId).Nombre;
      final logiaNombre = widget.root.catalogos.logias_catalogo.firstWhere((l) => l.idLogia == _selectedNewLogiaId).Nombre;

      final notificationTitle = 'Actualización de tu perfil';
      final notificationBody = 'Tu rol ha sido actualizado a $perfilNombre en la logia $logiaNombre.';

      // Llamamos a la función de notificación en segundo plano
      _notifyUserByPush(_selectedUserToEdit!, notificationTitle, notificationBody);

    } on PostgrestException catch (e) {
      _showErrorDialog("Error de Procedimiento", e.message);
    } catch (e) {
      _showErrorDialog("Error Desconocido", e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Muestra un diálogo para cambiar a otro perfil disponible.
  Future<void> _showSwitchProfileDialog() async {
    // Filtra los perfiles para mostrar solo los que NO son de Super Admin.
    final availableProfiles = widget.root.user.perfiles_opciones
        .where((p) => p.idPerfil != 0)
        .toList();

    if (availableProfiles.isEmpty) {
      _showErrorDialog("Sin Perfiles", "No tienes otros perfiles de logia a los que cambiar.");
      return;
    }

    PerfilOpcion? selectedProfile = availableProfiles.first;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Cambiar de Perfil'),
                content: DropdownButtonFormField<PerfilOpcion>(
                isExpanded: true,
                // Asegurar que selectedProfile esté en availableProfiles
                value: availableProfiles.contains(selectedProfile) ? selectedProfile : (availableProfiles.isNotEmpty ? availableProfiles.first : null),
                selectedItemBuilder: (BuildContext context) {
                  return availableProfiles.map<Widget>((PerfilOpcion p) {
                    return SizedBox(
                      width: 200, 
                      child: Text(
                        '${p.LogiaNombre} (${p.PerfilNombre})',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList();
                },
                items: availableProfiles.map((p) {
                  return DropdownMenuItem<PerfilOpcion>(
                    value: p,
                    child: Text(
                      '${p.LogiaNombre} (${p.PerfilNombre})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setStateDialog(() {
                    selectedProfile = newValue;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Seleccionar Logia/Perfil',
                  border: OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    if (selectedProfile == null) return;
                    // Navega a HomeScreen con el nuevo perfil y limpia el stack
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => HomeScreen(root: widget.root, selectedProfile: selectedProfile!)),
                      (Route<dynamic> route) => false,
                    );
                  },
                  child: const Text('Cambiar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Colores del Tema ---
  final Color _primaryColor = Colors.grey.shade900;
  final Color _secondaryColor = const Color(0xFFDAA520);
  final Color _formBackgroundColor = Colors.white;
  final Color _formTextColor = Colors.black87;

  Widget _buildLodgeManagement() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        color: _formBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _lodgeFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Crear Nueva Logia', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _formTextColor)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _lodgeNameController,
                  style: TextStyle(color: _formTextColor),
                  // CORRECCIÓN: El label ahora es 'Descripción' para coincidir con el campo
                  decoration: InputDecoration(
                    labelText: 'Descripción (Nombre de la Logia)',
                    labelStyle: TextStyle(color: _secondaryColor.withOpacity(0.7)),
                    prefixIcon: Icon(Icons.business, color: _secondaryColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'El nombre es requerido' : null,
                ),
                const SizedBox(height: 16),
                // NUEVO: Dropdown para seleccionar el grupo
                DropdownButtonFormField<String>(
                  isExpanded: true, // Ajusta el ancho al contenedor padre
                  value: _selectedLodgeGroup,
                  style: TextStyle(color: _formTextColor),
                  decoration: InputDecoration(
                    labelText: 'Grupo de la Logia',
                    labelStyle: TextStyle(color: _secondaryColor.withOpacity(0.7)),
                    prefixIcon: Icon(Icons.groups, color: _secondaryColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  items: _lodgeGroups.map((group) {
                    return DropdownMenuItem<String>(value: group, child: Text(group, overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedLodgeGroup = value),
                  validator: (value) => value == null ? 'Debes seleccionar un grupo' : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _createLodge,
                  icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add, color: Colors.white),
                  label: const Text('Crear Logia', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: _secondaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserManagement() {
    final perfiles = widget.root.catalogos.perfiles_catalogo;
    final logias = widget.root.catalogos.logias_catalogo;
    final grados = widget.root.catalogos.grados_catalogo.values.expand((e) => e).toList(); // Todos los grados

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // --- Asignar Rol ---
          Card(
            elevation: 4,
            color: _formBackgroundColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _userAssignFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Asignar Rol a Usuario', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _formTextColor)),
                    const SizedBox(height: 20),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _usersFuture,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        return DropdownButtonFormField<int>(
                          isExpanded: true, // Ajusta el ancho
                          value: _selectedUserToEdit,
                          style: TextStyle(color: _formTextColor),
                          decoration: InputDecoration(
                            labelText: 'Usuario',
                            labelStyle: TextStyle(color: _secondaryColor.withOpacity(0.7)),
                            prefixIcon: Icon(Icons.person_search, color: _secondaryColor),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          items: snapshot.data!.map((u) => DropdownMenuItem<int>(value: u['idUsuario'], child: Text(u['Nombre'], overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) {
                            setState(() {
                              _selectedUserToEdit = v;
                              // **MEJORA: Pre-seleccionar logia y grado del usuario seleccionado**
                              if (v != null) {
                                final selectedUser = widget.root.catalogos.listaLogiasPorUsuario.firstWhere((user) => user.idUsuario == v);
                                if (selectedUser.perfiles.isNotEmpty) {
                                  // Validar que los IDs existan en los catálogos para evitar errores de UI
                                  final logiaId = selectedUser.perfiles.first.idLogia;
                                  final gradoId = selectedUser.perfiles.first.Grado;

                                  final logiaExists = widget.root.catalogos.logias_catalogo.any((l) => l.idLogia == logiaId);
                                  // Reconstruimos la lista plana de grados para verificar existencia
                                  final allGrados = widget.root.catalogos.grados_catalogo.values.expand((e) => e).toList();
                                  final gradoExists = allGrados.any((g) => g.idGrado == gradoId);

                                  _selectedNewLogiaId = logiaExists ? logiaId : null;
                                  _selectedNewGrado = gradoExists ? gradoId : null;
                                }
                              } else {
                                _selectedNewLogiaId = null;
                                _selectedNewGrado = null;
                              }
                            });
                          },
                          validator: (v) => v == null ? 'Selecciona un usuario' : null,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      isExpanded: true, // Ajusta el ancho
                      value: _selectedNewLogiaId,
                      style: TextStyle(color: _formTextColor),
                      decoration: InputDecoration(
                        labelText: 'Logia',
                        labelStyle: TextStyle(color: _secondaryColor.withOpacity(0.7)),
                        prefixIcon: Icon(Icons.business, color: _secondaryColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      items: logias.map((l) => DropdownMenuItem<int>(value: l.idLogia, child: Text(l.Nombre, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setState(() => _selectedNewLogiaId = v),
                      validator: (v) => v == null ? 'Selecciona una logia' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      isExpanded: true, // Ajusta el ancho
                      value: _selectedNewProfileId,
                      style: TextStyle(color: _formTextColor),
                      decoration: InputDecoration(
                        labelText: 'Perfil',
                        labelStyle: TextStyle(color: _secondaryColor.withOpacity(0.7)),
                        prefixIcon: Icon(Icons.badge, color: _secondaryColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      items: perfiles.map((p) => DropdownMenuItem<int>(value: p.idPerfil, child: Text(p.Nombre, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setState(() => _selectedNewProfileId = v),
                      validator: (v) => v == null ? 'Selecciona un perfil' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      isExpanded: true, // Ajusta el ancho
                      value: _selectedNewGrado,
                      style: TextStyle(color: _formTextColor),
                      decoration: InputDecoration(
                        labelText: 'Grado',
                        labelStyle: TextStyle(color: _secondaryColor.withOpacity(0.7)),
                        prefixIcon: Icon(Icons.star, color: _secondaryColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      items: grados.map((g) => DropdownMenuItem<int>(value: g.idGrado, child: Text(g.Descripcion, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setState(() => _selectedNewGrado = v),
                      validator: (v) => v == null ? 'Selecciona un grado' : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _assignRole,
                      icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.assignment_ind, color: Colors.white),
                      label: const Text('Asignar Rol', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: _secondaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // --- Crear Nuevo Usuario ---
          Card(
            elevation: 4,
            color: _formBackgroundColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _newUserFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Crear Nuevo Usuario', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _formTextColor)),
                    const SizedBox(height: 20),
                    TextFormField(controller: _newUserNameController, style: TextStyle(color: _formTextColor), decoration: InputDecoration(labelText: 'Nombre Completo', prefixIcon: Icon(Icons.person, color: _secondaryColor), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.grey.shade50), validator: (v) => v!.isEmpty ? 'Requerido' : null),
                    const SizedBox(height: 16),
                    TextFormField(controller: _newUserEmailController, style: TextStyle(color: _formTextColor), keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Correo Electrónico', prefixIcon: Icon(Icons.email, color: _secondaryColor), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.grey.shade50), validator: (v) => !v!.contains('@') ? 'Correo inválido' : null),
                    const SizedBox(height: 16),
                    TextFormField(controller: _newUserPasswordController, style: TextStyle(color: _formTextColor), obscureText: true, decoration: InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock, color: _secondaryColor), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.grey.shade50), validator: (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _createNewUser,
                      icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.person_add, color: Colors.white),
                      label: const Text('Crear Usuario', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: _secondaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _primaryColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          // **MEJORA: Mostrar el nombre de la Gran Logia**
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.selectedProfile.LogiaNombre,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _secondaryColor),
                overflow: TextOverflow.ellipsis, // Evita desbordamiento en nombres largos
              ),
              const Text('Plataforma de Administración', style: TextStyle(fontSize: 14, color: Colors.white), overflow: TextOverflow.ellipsis),
            ],
          ),
          actions: [
            // NUEVO: Botón para cambiar de perfil
            IconButton(
              icon: const Icon(Icons.switch_account, color: Colors.white),
              tooltip: 'Cambiar a perfil de logia',
              onPressed: _showSwitchProfileDialog,
            ),
          ],
          // No hay drawer para el super admin
          bottom: TabBar(
            indicatorColor: _secondaryColor,
            labelColor: _secondaryColor,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.business), text: 'Logias'),
              Tab(icon: Icon(Icons.people), text: 'Usuarios'),
            ],
          ),
        ),
        body: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              height: 90,
              width: 90,
              decoration: BoxDecoration(
                color: _secondaryColor, // Fondo dorado para el logo
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TabBarView(
                children: [
                  _buildLodgeManagement(),
                  _buildUserManagement(),
                ],
              ),
            ),
          ],
        ),
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
}