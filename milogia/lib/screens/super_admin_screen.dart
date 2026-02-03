import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import '../models/user_model.dart';
import '../utils/dropdown_utils.dart';
import '../config/auth_config.dart';
import '../config/l10n.dart';

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
  List<String> get _lodgeGroups => L10n.lodgeGroups(context);

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
    // Inicializar con la logia del perfil actual si es posible
    _selectedLodgeForConcepts = widget.selectedProfile.idLogia;
  }

  @override
  void dispose() {
    _newUserNameController.dispose();
    _newUserEmailController.dispose();
    _newUserPasswordController.dispose();
    // Conceptos Controllers
    _conceptDescController.dispose();
    _addConceptCostoController.dispose(); // NUEVO
    // Documentos Controllers
    _documentDescController.dispose();
    super.dispose();
  }

  // --- Conceptos State ---
  final _conceptFormKey = GlobalKey<FormState>();
  final _conceptDescController = TextEditingController();
  bool _conceptRequiresPayment = false;
  bool _conceptRequiresGrade = false;
  String _conceptInputType = 'ninguno';
  int? _selectedLodgeForConcepts; // NUEVO: Para filtrar conceptos por Logia

  // --- NUEVOS: State para la Tarjeta de Búsqueda Inteligente ---
  final _addConceptCostoController = TextEditingController();
  int? _selectedGradeForAddConcept;
  ConceptoCatalogo? _selectedGlobalConcept;
  bool _newConceptRequiresPayment = true; // NUEVO
  bool _newConceptRequiresGrade = true;   // NUEVO

  // --- Documentos State ---
  final _documentFormKey = GlobalKey<FormState>();
  final _documentDescController = TextEditingController(); // Description (Category) or ShortName (Detail)
  bool _documentRequiresDesc = false;
  bool _documentRequiresGrade = false;
  
  // Anti-duplicate lists (in-memory cache from RootModel)
  List<String> get _existingConcepts => widget.root.catalogos.conceptos_catalogo.map((c) => c.Descripcion).toList();
  // We assume there is a list of documents in catalogos, or we fetch it. 
  // If not available in root, we might need to fetch. 
  // For now, let's assume concept list is robust.

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

      _showSuccessDialog(L10n.successTitle(context), L10n.lodgeCreatedSuccess(context));

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
      _showErrorDialog(L10n.dbError(context), e.message);
    } catch (e) {
      _showErrorDialog(L10n.unknownError(context), e.toString());
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
      if (authResponse.user == null) throw Exception(L10n.authErrorCreateUser(context));

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

      _showSuccessDialog(L10n.userCreatedTitle(context), '${L10n.userCreatedSuccessPrefix(context)}${newUserResponse['Nombre']}${L10n.userCreatedSuccessSuffix(context)}');
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
      _showErrorDialog(L10n.errorCreatingUser(context), e.toString());
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
      _showSuccessDialog(L10n.assignmentSuccessTitle(context), L10n.assignRoleSuccess(context));

      // --- NUEVO: Notificar al usuario por PUSH ---
      final perfilNombre = widget.root.catalogos.perfiles_catalogo.firstWhere((p) => p.idPerfil == _selectedNewProfileId).Nombre;
      final logiaNombre = widget.root.catalogos.logias_catalogo.firstWhere((l) => l.idLogia == _selectedNewLogiaId).Nombre;

      final notificationTitle = L10n.profileUpdateTitlePush(context);
      final notificationBody = '${L10n.profileUpdateBodyPushPrefix(context)}$perfilNombre${L10n.profileUpdateBodyPushIn(context)}$logiaNombre.';

      // Llamamos a la función de notificación en segundo plano
      _notifyUserByPush(_selectedUserToEdit!, notificationTitle, notificationBody);

    } on PostgrestException catch (e) {
      _showErrorDialog(L10n.procedureError(context), e.message);
    } catch (e) {
      _showErrorDialog(L10n.unknownError(context), e.toString());
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
      _showErrorDialog(L10n.noProfilesTitle(context), L10n.noOtherProfilesMsg(context));
      return;
    }

    PerfilOpcion? selectedProfile = availableProfiles.first;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(L10n.switchProfileTitle(context)),
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
                decoration: InputDecoration(
                  labelText: L10n.switchProfileLabel(context),
                  border: const OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(L10n.cancelButton(context))),
                ElevatedButton(
                  onPressed: () {
                    if (selectedProfile == null) return;
                    // Navega a HomeScreen con el nuevo perfil y limpia el stack
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => HomeScreen(root: widget.root, selectedProfile: selectedProfile!)),
                      (Route<dynamic> route) => false,
                    );
                  },
                  child: Text(L10n.switchButton(context)),
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
                Text(L10n.createNewLodgeTitle(context), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _formTextColor)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _lodgeNameController,
                  style: TextStyle(color: _formTextColor),
                  // CORRECCIÓN: El label ahora es 'Descripción' para coincidir con el campo
                  decoration: InputDecoration(
                    labelText: L10n.lodgeDescriptionLabel(context),
                    labelStyle: TextStyle(color: _secondaryColor.withOpacity(0.7)),
                    prefixIcon: Icon(Icons.business, color: _secondaryColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  validator: (v) => v == null || v.isEmpty ? L10n.requiredField(context) : null,
                ),
                const SizedBox(height: 16),
                // NUEVO: Dropdown para seleccionar el grupo
                DropdownButtonFormField<String>(
                  isExpanded: true, // Ajusta el ancho al contenedor padre
                  value: _selectedLodgeGroup,
                  style: TextStyle(color: _formTextColor),
                  decoration: InputDecoration(
                    labelText: L10n.lodgeGroupLabel(context),
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
                  validator: (value) => value == null ? L10n.selectGroupMsg(context) : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _createLodge,
                  icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add, color: Colors.white),
                  label: Text(L10n.createLodgeButton(context), style: const TextStyle(color: Colors.white)),
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
                    Text(L10n.assignRoleToUserTitle(context), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _formTextColor)),
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
                            labelText: L10n.userLabel(context),
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
                          validator: (v) => v == null ? L10n.selectUserMsg(context) : null,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      isExpanded: true, // Ajusta el ancho
                      value: _selectedNewLogiaId,
                      style: TextStyle(color: _formTextColor),
                      decoration: InputDecoration(
                        labelText: L10n.logiaLabel(context),
                        labelStyle: TextStyle(color: _secondaryColor.withOpacity(0.7)),
                        prefixIcon: Icon(Icons.business, color: _secondaryColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      items: logias.map((l) => DropdownMenuItem<int>(value: l.idLogia, child: Text(l.Nombre, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setState(() => _selectedNewLogiaId = v),
                      validator: (v) => v == null ? L10n.selectLodgeMsg(context) : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      isExpanded: true, // Ajusta el ancho
                      value: _selectedNewProfileId,
                      style: TextStyle(color: _formTextColor),
                      decoration: InputDecoration(
                        labelText: L10n.profileLabel(context),
                        labelStyle: TextStyle(color: _secondaryColor.withOpacity(0.7)),
                        prefixIcon: Icon(Icons.badge, color: _secondaryColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      items: perfiles.map((p) => DropdownMenuItem<int>(value: p.idPerfil, child: Text(p.Nombre, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setState(() => _selectedNewProfileId = v),
                      validator: (v) => v == null ? L10n.selectProfileMsg(context) : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      isExpanded: true, // Ajusta el ancho
                      value: _selectedNewGrado,
                      style: TextStyle(color: _formTextColor),
                      decoration: InputDecoration(
                        labelText: L10n.gradoLabel(context),
                        labelStyle: TextStyle(color: _secondaryColor.withOpacity(0.7)),
                        prefixIcon: Icon(Icons.star, color: _secondaryColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      items: grados.map((g) => DropdownMenuItem<int>(value: g.idGrado, child: Text(g.Descripcion, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setState(() => _selectedNewGrado = v),
                      validator: (v) => v == null ? L10n.selectGradeLabel(context) : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _assignRole,
                      icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.assignment_ind, color: Colors.white),
                      label: Text(L10n.assignRoleButton(context), style: const TextStyle(color: Colors.white)),
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
                    Text(L10n.createNewUserTitleSuper(context), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _formTextColor)),
                    const SizedBox(height: 20),
                    TextFormField(controller: _newUserNameController, style: TextStyle(color: _formTextColor), decoration: InputDecoration(labelText: L10n.fullNameLabel(context), prefixIcon: Icon(Icons.person, color: _secondaryColor), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.grey.shade50), validator: (v) => v!.isEmpty ? L10n.requiredField(context) : null),
                    const SizedBox(height: 16),
                    TextFormField(controller: _newUserEmailController, style: TextStyle(color: _formTextColor), keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: L10n.emailLabel(context), prefixIcon: Icon(Icons.email, color: _secondaryColor), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.grey.shade50), validator: (v) => !v!.contains('@') ? L10n.invalidEmailMsg(context) : null),
                    const SizedBox(height: 16),
                    TextFormField(controller: _newUserPasswordController, style: TextStyle(color: _formTextColor), obscureText: true, decoration: InputDecoration(labelText: L10n.passwordLabel(context), prefixIcon: Icon(Icons.lock, color: _secondaryColor), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.grey.shade50), validator: (v) => v!.length < 6 ? L10n.minCharsMsg(context) : null),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _createNewUser,
                      icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.person_add, color: Colors.white),
                      label: Text(L10n.createUserButton(context), style: const TextStyle(color: Colors.white)),
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
      length: 3,
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
                overflow: TextOverflow.ellipsis,
              ),
              Text(L10n.adminPlatformTitle(context), style: const TextStyle(fontSize: 14, color: Colors.white), overflow: TextOverflow.ellipsis),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.switch_account, color: Colors.white),
              tooltip: L10n.switchProfileTooltip(context),
              onPressed: _showSwitchProfileDialog,
            ),
          ],
          bottom: TabBar(
            isScrollable: true, // Allow scrolling for 4 tabs
            indicatorColor: _secondaryColor,
            labelColor: _secondaryColor,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: const Icon(Icons.business), text: L10n.lodgesTab(context)),
              Tab(icon: const Icon(Icons.people), text: L10n.usersTab(context)),
              // Nuevos Tabs
              Tab(icon: const Icon(Icons.monetization_on), text: L10n.conceptsLabel(context).replaceAll(':', '')), 
              // Tab(icon: const Icon(Icons.description), text: L10n.myDocumentsTitle(context)), // OCULTADO TEMPORALMENTE
              // const Tab(icon: Icon(Icons.copy), text: "Machotes"), // REMOVED
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
                  _buildConceptManagement(),
                  // _buildDocumentManagement(), // OCULTADO TEMPORALMENTE
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

  // --- Concept Management ---

  Widget _buildConceptManagement() {
    final logias = widget.root.catalogos.logias_catalogo;
    
    // Filtramos los detalles de conceptos por la logia seleccionada
    final List<Map<String, dynamic>> displayList = [];
    for (var cat in widget.root.catalogos.conceptos_catalogo) {
      for (var det in cat.detalles) {
        if (det.iddLogia == _selectedLodgeForConcepts) {
          displayList.add({'cat': cat, 'det': det});
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAddConceptCard(), 
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Gestión de Conceptos por Logia',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _formTextColor),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: _selectedLodgeForConcepts,
                    decoration: InputDecoration(
                      labelText: 'Filtrar listado por Logia',
                      prefixIcon: Icon(Icons.filter_list, color: _secondaryColor),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    items: logias.map((l) => DropdownMenuItem<int>(
                      value: l.idLogia,
                      child: Text(l.Nombre, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedLodgeForConcepts = v),
                  ),
                  const SizedBox(height: 20),
                  Text('Conceptos Asignados (${displayList.length})', 
                    style: TextStyle(fontWeight: FontWeight.bold, color: _secondaryColor)),
                  const SizedBox(height: 10),
                  if (displayList.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: Text('No hay conceptos configurados para esta logia.')),
                    )
                  else
                    ...displayList.map((item) => _buildConceptListItem(item['det'], item['cat'])),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConceptListItem(ConceptoDetalle det, ConceptoCatalogo cat) {
    final gradoDesc = widget.root.catalogos.grados_catalogo.values
        .expand((e) => e)
        .firstWhere((g) => g.idGrado == det.idGrado, 
          orElse: () => GradoCatalogo(Grupo: '', idGrado: 0, Descripcion: 'N/A'))
        .Descripcion;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: det.Activo ? Colors.green.shade100 : Colors.red.shade100,
          child: Icon(
            det.Activo ? Icons.check_circle : Icons.cancel,
            color: det.Activo ? Colors.green : Colors.red,
          ),
        ),
        title: Text(cat.Descripcion, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Grado: $gradoDesc | Costo: \$${det.Costo}'),
        trailing: const Icon(Icons.edit, color: Colors.blueGrey),
        onTap: () => _showEditConceptDialog(cat, det),
      ),
    );
  }

  Future<void> _showEditConceptDialog(ConceptoCatalogo cat, ConceptoDetalle det) async {
    final costoController = TextEditingController(text: det.Costo.toString());
    bool isActive = det.Activo;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateSB) {
          return AlertDialog(
            title: Text('Editar Concepto: ${cat.Descripcion}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: costoController,
                  decoration: const InputDecoration(labelText: 'Costo (\$)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Activo'),
                  value: isActive,
                  onChanged: (v) => setStateSB(() => isActive = v),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(L10n.cancelButton(context))),
              ElevatedButton(
                onPressed: () async {
                  final newCosto = double.tryParse(costoController.text) ?? det.Costo;
                  Navigator.pop(context);
                  await _updateConceptDetail(det, newCosto, isActive);
                },
                child: Text(L10n.saveButton(context)),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _updateConceptDetail(ConceptoDetalle det, double newCosto, bool newStatus) async {
    setState(() => _isLoading = true);
    try {
      // 1. Actualización en Supabase
      await _supabase
          .from('catdConceptos')
          .update({
            'Costo': newCosto,
            'Activo': newStatus,
          })
          .eq('iddConcepto', det.iddConcepto);

      // 2. Actualización local del estado para reflejar cambios inmediatamente
      setState(() {
        det.Costo = newCosto;
        det.Activo = newStatus;
      });

      _showSuccessDialog("Éxito", "Concepto actualizado correctamente.");
    } catch (e) {
      _showErrorDialog("Error", e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildAddConceptCard() {
    final grados = widget.root.catalogos.grados_catalogo.values.expand((e) => e).toList();
    final allConcepts = widget.root.catalogos.conceptos_catalogo;

    final bool isSelected = _selectedGlobalConcept != null;
    final bool showCosto = isSelected ? _selectedGlobalConcept!.RequierePago : _newConceptRequiresPayment;
    final bool showGrado = isSelected ? _selectedGlobalConcept!.RequiereGrado : _newConceptRequiresGrade;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Asignar Nuevo Concepto a Logia', 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryColor)),
            const SizedBox(height: 16),
            
            // Buscador Inteligente
            Autocomplete<ConceptoCatalogo>(
              displayStringForOption: (ConceptoCatalogo option) => option.Descripcion,
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) return const Iterable<ConceptoCatalogo>.empty();
                return allConcepts.where((ConceptoCatalogo option) {
                  return option.Descripcion.toLowerCase().contains(textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (ConceptoCatalogo selection) {
                setState(() {
                  _selectedGlobalConcept = selection;
                  _conceptDescController.text = selection.Descripcion;
                });
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'Buscar o escribir concepto nuevo',
                    prefixIcon: Icon(Icons.search, color: _secondaryColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (value) {
                    if (_selectedGlobalConcept != null && value != _selectedGlobalConcept!.Descripcion) {
                      setState(() => _selectedGlobalConcept = null);
                    }
                    _conceptDescController.text = value;
                  },
                );
              },
            ),
            
            // Toggles para Concepto NUEVO
            if (!isSelected) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      dense: true,
                      title: const Text('Requiere Pago', style: TextStyle(fontSize: 13)),
                      value: _newConceptRequiresPayment,
                      onChanged: (v) => setState(() => _newConceptRequiresPayment = v),
                    ),
                  ),
                  Expanded(
                    child: SwitchListTile(
                      dense: true,
                      title: const Text('Requiere Grado', style: TextStyle(fontSize: 13)),
                      value: _newConceptRequiresGrade,
                      onChanged: (v) => setState(() => _newConceptRequiresGrade = v),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),
            
            // Campos Condicionales
            if (showCosto || showGrado)
              Row(
                children: [
                  if (showCosto)
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _addConceptCostoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Costo (\$)',
                          prefixIcon: Icon(Icons.attach_money, color: _secondaryColor),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  if (showCosto && showGrado) const SizedBox(width: 12),
                  if (showGrado)
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        value: _selectedGradeForAddConcept,
                        decoration: InputDecoration(
                          labelText: 'Grado',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: grados.map((g) => DropdownMenuItem<int>(
                          value: g.idGrado,
                          child: Text(g.Descripcion, overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (v) => setState(() => _selectedGradeForAddConcept = v),
                      ),
                    ),
                ],
              ),
            
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _smartAddConcept,
              icon: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.add_task),
              label: Text(isSelected ? 'Asignar Existente' : 'Crear y Asignar Nuevo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _secondaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _smartAddConcept() async {
    final desc = _conceptDescController.text.trim();
    final costo = double.tryParse(_addConceptCostoController.text) ?? 0.0;
    
    final bool isSelected = _selectedGlobalConcept != null;
    final bool showCosto = isSelected ? _selectedGlobalConcept!.RequierePago : _newConceptRequiresPayment;
    final bool showGrado = isSelected ? _selectedGlobalConcept!.RequiereGrado : _newConceptRequiresGrade;

    if (desc.isEmpty || _selectedLodgeForConcepts == null || 
       (showCosto && _addConceptCostoController.text.isEmpty) || 
       (showGrado && _selectedGradeForAddConcept == null)) {
      _showErrorDialog("Faltan Datos", "Por favor completa la descripción, logia${showCosto ? ', costo' : ''}${showGrado ? ' y grado' : ''}.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      int idGlobal;
      
      // 1. Determinar ID Global
      if (_selectedGlobalConcept != null) {
        idGlobal = _selectedGlobalConcept!.idConcepto;
        
        // Verificar duplicado local
        final alreadyAssigned = _selectedGlobalConcept!.detalles.any(
          (d) => d.iddLogia == _selectedLodgeForConcepts && d.idGrado == _selectedGradeForAddConcept
        );
        
        if (alreadyAssigned) {
          _showErrorDialog("Concepto Duplicado", "Este concepto ya está asignado a esta logia con el mismo grado.");
          return;
        }
      } else {
        final existing = widget.root.catalogos.conceptos_catalogo.firstWhere(
          (c) => c.Descripcion.toLowerCase() == desc.toLowerCase(),
          orElse: () => ConceptoCatalogo(detalles: [], idConcepto: -1, Descripcion: '', RequierePago: false, RequiereGrado: false),
        );

        if (existing.idConcepto != -1) {
          idGlobal = existing.idConcepto;
          if (existing.detalles.any((d) => d.iddLogia == _selectedLodgeForConcepts && d.idGrado == _selectedGradeForAddConcept)) {
            _showErrorDialog("Concepto Duplicado", "El concepto ya existe en esta logia.");
            return;
          }
        } else {
          // NUEVO GLOBAL
          final newCatResponse = await _supabase.from('catcConceptos').insert({
            'Descripcion': desc,
            'RequierePago': _newConceptRequiresPayment,
            'RequiereGrado': _newConceptRequiresGrade,
            'Activo': true,
          }).select('idConcepto').single();
          
          idGlobal = newCatResponse['idConcepto'];
          
          final newGlobal = ConceptoCatalogo(
            idConcepto: idGlobal,
            Descripcion: desc,
            RequierePago: _newConceptRequiresPayment,
            RequiereGrado: _newConceptRequiresGrade,
            detalles: [],
          );
          widget.root.catalogos.conceptos_catalogo.add(newGlobal);
        }
      }

      final bool isSelected = _selectedGlobalConcept != null;
      
      // 2. Detalle (Solo si requiere pago o grado, o ambos, según la lógica de la tabla detalle)
      // Nota: catdConceptos siempre necesita Costo e idGrado, pero si el concepto dice que REQUERIDOS son false, podrías usar 0 o N/A.
      // El usuario pidió: "lo de grado y costo deberian aparecer SI SE SELECCIONA que ese concepto tendrá costo y requiere un grado"
      final newDetResponse = await _supabase.from('catdConceptos').insert({
        'idConcepto': idGlobal,
        'iddLogia': _selectedLodgeForConcepts,
        'idGrado': (isSelected ? _selectedGlobalConcept!.RequiereGrado : _newConceptRequiresGrade) ? _selectedGradeForAddConcept : 0,
        'Costo': (isSelected ? _selectedGlobalConcept!.RequierePago : _newConceptRequiresPayment) ? costo : 0.0,
        'Activo': true,
      }).select('iddConcepto').single();

      // 3. Local
      final newDet = ConceptoDetalle(
        iddConcepto: newDetResponse['iddConcepto'],
        iddLogia: _selectedLodgeForConcepts!,
        idGrado: (isSelected ? _selectedGlobalConcept!.RequiereGrado : _newConceptRequiresGrade) ? _selectedGradeForAddConcept! : 0,
        Costo: (isSelected ? _selectedGlobalConcept!.RequierePago : _newConceptRequiresPayment) ? costo : 0.0,
        Activo: true,
        ctaBanco: "",
      );

      final globalConcept = widget.root.catalogos.conceptos_catalogo.firstWhere((c) => c.idConcepto == idGlobal);
      setState(() {
        globalConcept.detalles.add(newDet);
        _addConceptCostoController.clear();
        _selectedGlobalConcept = null;
      });

      _showSuccessDialog("Éxito", "Concepto asignado correctamente.");
    } catch (e) {
      _showErrorDialog("Error", e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Document Management ---

  Widget _buildDocumentManagement() {
     return Center(child: Text("Gestión de Documentos (catc & catd) - En Desarrollo\nUse Conceptos como ejemplo."));
     // Full implementation omitted for brevity in this response, but similar structure applies.
     // Ideally, I would add a button to create Category and another for Specific Document.
  }


}