import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/auth_config.dart'; 
import '../models/user_model.dart';
import '../utils/dropdown_utils.dart'; 
import 'app_drawer.dart'; 

class ProfileEditScreen extends StatefulWidget {
  final RootModel root;
  final PerfilOpcion? selectedProfile; 

  const ProfileEditScreen({super.key, required this.root, required this.selectedProfile});
    
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>(); 
  bool _isLoading = false;

  late TextEditingController _phoneController;
  late TextEditingController _dobController;
  late TextEditingController _addressController;
  late TextEditingController _emailController;

  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  final _newUserFormKey = GlobalKey<FormState>(); 
  final _newUserNameController = TextEditingController(); 
  final _newUserEmailController = TextEditingController();
  final _newUserPasswordController = TextEditingController(); 
  int? _newUserGradoId;
  int? _newUserPerfilId;

  late bool _canAdmin;

  late Future<List<Map<String, dynamic>>> _usersFuture;
  int? _selectedUserToEdit;
  int? _selectedNewProfileId;
  int? _selectedNewLogiaId;
  int? _selectedNewGrado;

  @override
  void initState() {
    super.initState();
    
    _canAdmin = widget.selectedProfile?.idPerfil == 1;

    final user = widget.root.user;
    _phoneController = TextEditingController(text: user.Telefono);
    _dobController = TextEditingController(text: user.FechaNacimiento);
    _addressController = TextEditingController(text: user.Direccion);
    _emailController = TextEditingController(text: user.CorreoElectronico);

    if (_canAdmin) {
      _usersFuture = _fetchLogiaMembers(); 
    }
  }
  
  @override
  void dispose() {
    _phoneController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
    _newUserNameController.dispose();
    _newUserEmailController.dispose();
    _newUserPasswordController.dispose();
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
    } else {
       return {
        'bg': const Color(0xFFF5F5F5),
        'text': const Color(0xFF222222),
        'card': Colors.white,
        'accent': const Color(0xFFDAA520),
      };
    }
  }

  Future<void> _updatePersonalInfo() async {
  if (!_formKey.currentState!.validate()) return;
  
  setState(() => _isLoading = true);

  try {
    final dataToUpdate = {
      'Telefono': _phoneController.text.trim(),
      'FechaNacimiento': _dobController.text.trim(),
      'Direccion': _addressController.text.trim(),
      'CorreoElectronico': _emailController.text.trim(),
    };
    
    final updatedUsers = await _supabase
        .from('catcUsuarios')
        .update(dataToUpdate)
        .eq('idUsuario', widget.root.user.idUsuario)
        .select(); 
        
    if (updatedUsers.isNotEmpty) {
        final Map<String, dynamic> updatedData = updatedUsers.first;
        
        widget.root.user.updateFromJson(updatedData);
      }

    _showSuccessDialog("Actualización Exitosa", "Tus datos personales han sido actualizados.");

  } on PostgrestException catch (e) {
    _showErrorDialog("Error de Actualización", e.message);
  } catch (e) {
    _showErrorDialog("Error Desconocido", e.toString());
    print(e.toString());
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  Future<void> _showChangePasswordDialog(Map<String, Color> theme) async {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();

    final String storedPassword = widget.root.user.Contrasena; 
    
    return showDialog<void>(
      context: context,
      barrierDismissible: true, 
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: theme['card'],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('Cambiar Contraseña', style: TextStyle(color: theme['text'])),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateDialog) {
              return Form(
                key: _passwordFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _buildTextField(_currentPasswordController, 'Contraseña Anterior', theme, isPassword: true),
                      _buildTextField(_newPasswordController, 'Nueva Contraseña', theme, isPassword: true, 
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return 'La nueva contraseña debe tener al menos 6 caracteres.';
                          }
                          return null;
                        }
                      ),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        style: TextStyle(color: theme['text']),
                        decoration: InputDecoration(
                          labelText: 'Confirmar Nueva Contraseña',
                          labelStyle: TextStyle(color: theme['text']?.withOpacity(0.7)),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: theme['accent']!)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Confirma la nueva contraseña.';
                          }
                          if (value != _newPasswordController.text) {
                            return 'Las contraseñas no coinciden.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancelar', style: TextStyle(color: theme['text']?.withOpacity(0.7))),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: theme['accent']),
              child: Text('Guardar', style: const TextStyle(color: Colors.white)),
              onPressed: _isLoading ? null : () async {
                if (_passwordFormKey.currentState!.validate()) {
                  setState(() => _isLoading = true);
                  if (storedPassword != _currentPasswordController.text) {
                    setState(() => _isLoading = false);
                    _showErrorDialog("Error de Contraseña", "La contraseña anterior es incorrecta. Por favor, verifica.");
                    return;
                  }
                  
                  try {
                    final newPassword = _newPasswordController.text;
await _supabase
                        .from('catcUsuarios')
                        .update({'Contraseña': newPassword})
                        .eq('idUsuario', widget.root.user.idUsuario);
                    
                    if (mounted) {
                      Navigator.of(context).pop(); 
                      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                    }

                  } on AuthApiException catch (e) {
                      if (e.code == 'same_password') {
                          print("La contraseña es la misma, la actualización en la tabla fue redundante pero no falló.");
                          _showSuccessDialog("Actualización", "La contraseña en su tabla ya estaba actualizada.");
                      } else {
                          _showErrorDialog("Error de Autenticación", e.message);
                      }
                  } on PostgrestException catch (e) {
                    _showErrorDialog("Error de Supabase", e.message);
                  } catch (e) {
                    _showErrorDialog("Error Desconocido", e.toString());
                    print(e.toString());
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }


  Future<List<Map<String, dynamic>>> _fetchLogiaMembers() async {
    final adminLogiaId = widget.selectedProfile?.idLogia;
    if (adminLogiaId == null) return [];
    final allUsersInCatalog = widget.root.catalogos.listaLogiasPorUsuario;
    final membersOfLodge = allUsersInCatalog.where((user) {
      return user.perfiles.any((perfil) => perfil.idLogia == adminLogiaId);
    }).toList();
    return membersOfLodge.map((user) => {
      'idUsuario': user.idUsuario,
      'Nombre': user.Nombre,
    }).toList();
  }

  Future<void> _callAdminSp() async {
     if (_selectedUserToEdit == null || _selectedNewProfileId == null || _selectedNewLogiaId == null || _selectedNewGrado == null) {
      _showErrorDialog("Datos Incompletos", "Debe seleccionar un Usuario, Perfil, Logia y Grado.");
      return;
    }

    setState(() => _isLoading = true);

    try {
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

      _showSuccessDialog("Actualización de Usuario Exitosa", "Los datos de usuario (Perfil, Logia, Grado) han sido actualizados.");

    } on PostgrestException catch (e) {
      _showErrorDialog("Error de Procedimiento", e.message);
    } catch (e) {
      _showErrorDialog("Error Desconocido", e.toString());
      print(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddUserDialog(Map<String, Color> theme) async {
    _newUserFormKey.currentState?.reset();
    _newUserNameController.clear();
    _newUserEmailController.clear();
    _newUserPasswordController.clear();
    _newUserGradoId = null;
    _newUserPerfilId = null;

    final List<PerfilCatalogo> perfilesCatalogo = widget.root.catalogos.perfiles_catalogo;
    
    final String adminGrupo = widget.selectedProfile?.Grupo ?? '';
    final List<GradoCatalogo> gradosDisponibles = widget.root.catalogos.grados_catalogo[adminGrupo] ?? [];


    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder( 
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: theme['card'],
              title: Text('Registrar Nuevo Miembro', style: TextStyle(color: theme['text'])),
              content: Form(
                key: _newUserFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _buildTextField(_newUserNameController, 'Nombre Completo', theme, validator: (v) => v!.isEmpty ? 'Requerido' : null),
                      _buildTextField(_newUserEmailController, 'Correo Electrónico', theme, keyboardType: TextInputType.emailAddress, validator: (v) => (v == null || !v.contains('@')) ? 'Correo inválido' : null),
                      _buildTextField(_newUserPasswordController, 'Contraseña', theme, isPassword: true, validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        isExpanded: true, 
                        decoration: InputDecoration(labelText: 'Perfil', labelStyle: TextStyle(color: theme['text']?.withOpacity(0.7))),
                        value: ensureValidDropdownValue(_newUserPerfilId, perfilesCatalogo.map((p) => p.idPerfil).toList()),
                        dropdownColor: theme['card'],
                        items: perfilesCatalogo.map((p) => DropdownMenuItem<int>(
                          value: p.idPerfil,
                          child: Text(p.Nombre, style: TextStyle(color: theme['text']), overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (val) => setStateDialog(() => _newUserPerfilId = val),
                        validator: (v) => v == null ? 'Selecciona un perfil' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        isExpanded: true, 
                        decoration: InputDecoration(labelText: 'Grado', labelStyle: TextStyle(color: theme['text']?.withOpacity(0.7))),
                        value: ensureValidDropdownValue(_newUserGradoId, gradosDisponibles.map((g) => g.idGrado).toList()),
                        dropdownColor: theme['card'],
                        items: gradosDisponibles.map((g) => DropdownMenuItem<int>(
                          value: g.idGrado,
                          child: Text(g.Descripcion, style: TextStyle(color: theme['text']), overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (val) => setStateDialog(() => _newUserGradoId = val),
                        validator: (v) => v == null ? 'Selecciona un grado' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancelar', style: TextStyle(color: theme['text']?.withOpacity(0.7))),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: theme['accent']),
                  child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Registrar', style: TextStyle(color: Colors.white)),
                  onPressed: _isLoading ? null : () async {
                    if (_newUserFormKey.currentState!.validate()) {
                      setState(() => _isLoading = true);
                      try {
                        final authResponse = await _supabase.auth.signUp(
                          email: _newUserEmailController.text.trim(),
                          password: _newUserPasswordController.text,
                        );
                        if (authResponse.user == null) throw Exception("No se pudo crear el usuario en el sistema de autenticación.");
                        final authUuid = authResponse.user!.id;

                        final newUserResponse = await _supabase
                            .from('catcUsuarios')
                            .insert({
                              'Nombre': _newUserNameController.text.trim(),
                              'Usuario': _newUserEmailController.text.split('@').first,
                              'Contraseña': _newUserPasswordController.text, 
                              'CorreoElectronico': _newUserEmailController.text.trim(),
                              'auth_uuid': authUuid,
                            })
                            .select('idUsuario, Nombre')
                            .single();
                        final newUserId = newUserResponse['idUsuario'] as int;

                        final adminLogiaId = widget.selectedProfile!.idLogia;
                        await _supabase.from('catdUsuario').insert({
                          'idUsuario': newUserId,
                          'idPerfil': _newUserPerfilId,
                          'Fecha': DateTime.now().toIso8601String(),
                          'iddLogia': adminLogiaId,
                          'Activo': true,
                        });

                        await _supabase.from('catdUsuarioGrado').insert({
                          'idUsuario': newUserId,
                          'idGrado': _newUserGradoId,
                          'Fecha': DateTime.now().toIso8601String(),
                          'iddLogia': adminLogiaId,
                          'Activo': true,
                        });

                        if (mounted) {
                          Navigator.of(context).pop();
                          _showSuccessDialog('Miembro Creado', 'El miembro "${newUserResponse['Nombre']}" ha sido creado y asignado a esta logia.');
                            setState(() {
                            _usersFuture = _fetchLogiaMembers();
                            _selectedUserToEdit = newUserId; 
                          });
                        }
                      } catch (e) {

                        _showErrorDialog('Error al Crear Miembro', e.toString());
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }


  Widget _buildTextField(TextEditingController controller, String label, Map<String, Color> theme, {bool isPassword = false, TextInputType keyboardType = TextInputType.text, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: theme['text']),
        obscureText: isPassword,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: theme['text']?.withOpacity(0.7)),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: theme['accent']!)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildPersonalInfoForm(Map<String, Color> theme) {
    return Column(
      children: [
        Container(
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
                child: Icon(Icons.person, color: theme['accent']), 
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Editar Datos Personales', style: TextStyle(color: theme['text'], fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(widget.selectedProfile?.LogiaNombre ?? 'Logia No Seleccionada', style: TextStyle(color: theme['text']?.withOpacity(0.7), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTextField(_emailController, 'Correo Electrónico', theme, keyboardType: TextInputType.emailAddress),
                      _buildTextField(_phoneController, 'Teléfono', theme, keyboardType: TextInputType.phone),
                      _buildTextField(_dobController, 'Fecha de Nacimiento (YYYY-MM-DD)', theme, keyboardType: TextInputType.datetime),
                      _buildTextField(_addressController, 'Dirección', theme),
                      
                      const SizedBox(height: 20),

                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _updatePersonalInfo,
                        icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save, color: Colors.white),
                        label: Text(_isLoading ? 'Guardando...' : 'Guardar Datos Personales', style: const TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme['accent'],
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      
                      const SizedBox(height: 30),

                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : () => _showChangePasswordDialog(theme),
                        icon: const Icon(Icons.lock_open),
                        label: const Text('Cambiar Contraseña'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme['accent'],
                          side: BorderSide(color: theme['accent']!),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),

                      const SizedBox(height: 20),
                      Text(
                        '**Nota:** La foto de perfil se actualiza desde el Home.', 
                        textAlign: TextAlign.center, 
                        style: TextStyle(color: theme['text']?.withOpacity(0.6), fontSize: 12)
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminHeader(Map<String, Color> theme) {
    return Container(
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
            child: Icon(Icons.admin_panel_settings, color: theme['accent']),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Herramientas de Administración', style: TextStyle(color: theme['text'], fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Gestión de perfiles, logias y grados', style: TextStyle(color: theme['text']?.withOpacity(0.7), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminPanel(Map<String, Color> theme) {
    final List<PerfilCatalogo> profilesDisponibles = widget.root.catalogos.perfiles_catalogo;
    final String adminGrupo = widget.selectedProfile?.Grupo ?? '';
    List<GradoCatalogo> gradosFiltrados = widget.root.catalogos.grados_catalogo[adminGrupo] ?? [];

    _selectedNewLogiaId = widget.selectedProfile?.idLogia;
    return Column(
      children: [
        _buildAdminHeader(theme),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Asignar/Actualizar Rol de Usuario", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme['text'])),
                    const SizedBox(height: 10),
          
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _usersFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) return const Text('No hay usuarios para mostrar.');
                        
                        final users = snapshot.data!;
                        return DropdownButtonFormField<int>(
                          isExpanded: true, 
                          decoration: InputDecoration(labelText: 'Usuario a Editar', labelStyle: TextStyle(color: theme['text']?.withOpacity(0.7))),
                          value: _selectedUserToEdit,
                          dropdownColor: theme['card'],
                          items: users.map((user) => DropdownMenuItem<int>(
                            value: user['idUsuario'],
                            child: Text('${user['Nombre']} (ID: ${user['idUsuario']})', style: TextStyle(color: theme['text']), overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedUserToEdit = val;
                              if (val != null) {
                                final selectedUser = widget.root.catalogos.listaLogiasPorUsuario.firstWhere((u) => u.idUsuario == val);
                                final userProfileInThisLodge = selectedUser.perfiles.firstWhere(
                                  (p) => p.idLogia == widget.selectedProfile?.idLogia,
                                  orElse: () => MiembroPerfil(idLogia: 0, Tratamiento: '', Grado: 0, idPerfil: 0, PerfilNombre: ''),
                                );
                                _selectedNewGrado = userProfileInThisLodge.Grado;
                              } else {
                                _selectedNewGrado = null;
                              }
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
          
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      decoration: InputDecoration(labelText: 'Nuevo Perfil', labelStyle: TextStyle(color: theme['text']?.withOpacity(0.7))),
                      value: ensureValidDropdownValue(_selectedNewProfileId, profilesDisponibles.map((p) => p.idPerfil).toList()),
                      dropdownColor: theme['card'],
                      items: profilesDisponibles.map((p) => DropdownMenuItem<int>( // Usamos el catálogo completo
                        value: p.idPerfil,
                        child: Text(p.Nombre, style: TextStyle(color: theme['text']), overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedNewProfileId = val;
                          _selectedNewGrado = null; 
                        });
                      },
                    ),
                    const SizedBox(height: 16),
          
                    DropdownButtonFormField<int>(
                      isExpanded: true, 
                      decoration: InputDecoration(labelText: 'Nuevo Grado', labelStyle: TextStyle(color: theme['text']?.withOpacity(0.7))),
                      value: ensureValidDropdownValue(_selectedNewGrado, gradosFiltrados.map((g) => g.idGrado).toList()),
                      dropdownColor: theme['card'],
                      items: gradosFiltrados.map((g) => DropdownMenuItem<int>(
                        value: g.idGrado,
                        child: Text('${g.Descripcion} (Grado ${g.idGrado})', style: TextStyle(color: theme['text']), overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (val) => setState(() => _selectedNewGrado = val),
                    ),
                    const SizedBox(height: 30),
          
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _callAdminSp,
                      icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.security_update_good, color: Colors.white),
                      label: Text(_isLoading ? 'Ejecutando...' : 'Asignar Rol (SP 8)', style: const TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme['accent'],
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const Divider(height: 40),
                    OutlinedButton.icon(
                      onPressed: () => _showAddUserDialog(theme),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Registrar Nuevo Usuario'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme['accent'],
                        side: BorderSide(color: theme['accent']!),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    final theme = _getThemeColors();
    if (_canAdmin) {
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: theme['bg'],
          appBar: AppBar(
            title: Text('Editar Perfil / Admin', style: TextStyle(color: theme['text'])),
            backgroundColor: theme['bg'],
            elevation: 0,               
            iconTheme: IconThemeData(color: theme['text']),
            bottom: TabBar(
              labelColor: theme['accent'],
              unselectedLabelColor: theme['text']?.withOpacity(0.7),
              indicatorColor: theme['accent'],
              tabs: const [
                Tab(icon: Icon(Icons.person), text: "Mis Datos"),
                Tab(icon: Icon(Icons.admin_panel_settings), text: "Admin Tools"),
              ],
            ),
          ),
          drawer: AppDrawer(root: widget.root, selectedProfile: widget.selectedProfile!),
          body: TabBarView(
            children: [
              _buildPersonalInfoForm(theme), 
              _buildAdminPanel(theme),      
            ],
          ),
        ),
      );
    } 
    else {
      return Scaffold(
        backgroundColor: theme['bg'],
        appBar: AppBar(
          title: Text('Editar Mi Perfil', style: TextStyle(color: theme['text'])),
          backgroundColor: theme['bg'], 
          elevation: 0,                
          iconTheme: IconThemeData(color: theme['text']),
        ),
        drawer: AppDrawer(root: widget.root, selectedProfile: widget.selectedProfile!),
        body: _buildPersonalInfoForm(theme),
      );
    }
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