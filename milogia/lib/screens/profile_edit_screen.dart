import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Asegúrate de que las rutas sean correctas
import '../config/auth_config.dart'; // Si contiene helpers de color
import '../models/user_model.dart'; 
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
  final _formKey = GlobalKey<FormState>(); // Key para validar el formulario personal
  bool _isLoading = false;

  // Controllers para datos personales
  late TextEditingController _phoneController;
  late TextEditingController _dobController;
  late TextEditingController _addressController;
  late TextEditingController _emailController;

  // Controllers y Key para el Diálogo de Contraseña
  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();


  // Lógica de Administración
  late bool _canAdmin;
  
  // Variables y controllers para administración (idPerfil == 1)
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
  }


  // --- LÓGICA DE COLORES ---
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

  // --- LÓGICA DE DATOS PERSONALES (UPDATE en catcUsuario) ---
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
    
    // 1. Ejecutar la actualización y solicitar los datos actualizados con .select()
    final updatedUsers = await _supabase
        .from('catcUsuarios')
        .update(dataToUpdate)
        .eq('idUsuario', widget.root.user.idUsuario)
        .select(); // 👈 IMPORTANTE: Pide que se devuelva la fila actualizada
        
    // 2. Verificar que se haya devuelto al menos una fila
    if (updatedUsers.isNotEmpty) {
        final Map<String, dynamic> updatedData = updatedUsers.first;
        
        // 3. Sincronizar el modelo local (Asumiendo que puedes rellenar tu User model con Map)
        // ESTO ES PSEUDOCÓDIGO, adapta la forma en que rellenas tu modelo:
        widget.root.user.updateFromJson(updatedData);
        
        // O si tu modelo es inmutable y necesitas reemplazarlo:
         //widget.root.user = CatcUser.fromJson(updatedData); 
        
        // *******************************************************************
        // Si estás usando un State Management (Provider, Riverpod, BLoC, etc.) 
        // probablemente debas llamar a un método del provider/bloc aquí para notificar 
        // el cambio de estado con el nuevo objeto 'updatedData'.
        // *******************************************************************
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
  // --- LÓGICA DE CAMBIO DE CONTRASEÑA ---

  Future<void> _showChangePasswordDialog(Map<String, Color> theme) async {
    // Reset controllers before showing the dialog
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();

    // Contraseña almacenada en el modelo (se utiliza para validación)
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
                      // Contraseña Anterior
                      _buildTextField(_currentPasswordController, 'Contraseña Anterior', theme, isPassword: true),
                      // Nueva Contraseña
                      _buildTextField(_newPasswordController, 'Nueva Contraseña', theme, isPassword: true, 
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return 'La nueva contraseña debe tener al menos 6 caracteres.';
                          }
                          return null;
                        }
                      ),
                      // Confirmar Contraseña
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
                  
                  // 1. Validar Contraseña Anterior (case sensitive, del user_model)
                  if (storedPassword != _currentPasswordController.text) {
                    setState(() => _isLoading = false);
                    _showErrorDialog("Error de Contraseña", "La contraseña anterior es incorrecta. Por favor, verifica.");
                    return;
                  }
                  
                  // 2. Ejecutar cambio de contraseña
                  try {
                    final newPassword = _newPasswordController.text;
                    
                    // A. Supabase Auth Update (Crucial para el login)
                    //await _supabase.auth.updateUser(UserAttributes(
                    //  password: newPassword,
                    //));
                    
                    // B. Actualización en la tabla catcUsuario
                    // Esto se hace para actualizar el campo Contrasena en tu tabla,
                    // asumiendo que es donde se almacena el hash/plain-text para la validación anterior.
                    await _supabase
                        .from('catcUsuarios')
                        .update({'Contraseña': newPassword})
                        .eq('idUsuario', widget.root.user.idUsuario);
                    
                    // 3. Cerrar sesión y navegar a login
                    //await _supabase.auth.signOut();

                    if (mounted) {
                      Navigator.of(context).pop(); // Cierra el diálogo
                      // Navega a la pantalla de Login y elimina todas las rutas anteriores
                      // Asume que la ruta '/' te lleva a la pantalla de Login.
                      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                    }

                  } on AuthApiException catch (e) {
                      // 🚨 MANEJO ESPECÍFICO DEL ERROR DE MISMA CONTRASEÑA 🚨R
                      if (e.code == 'same_password') {
                          // La contraseña es la misma. Puedes mostrar un mensaje de éxito/informativo
                          // o simplemente ignorar el error si para ti no es un fallo crítico.
                          print("La contraseña es la misma, la actualización en la tabla fue redundante pero no falló.");
                          _showSuccessDialog("Actualización", "La contraseña en su tabla ya estaba actualizada.");
                      } else {
                          // Manejar otros errores de autenticación (ej: token expirado, etc.)
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

  // --- LÓGICA DE ADMINISTRACIÓN (Mantenida) ---

  Future<List<Map<String, dynamic>>> _fetchLogiaMembers() async {
    // ... (El código de administración se mantiene igual)
    try {
      final response = await _supabase
          .from('catcUsuarios')
          .select('idUsuario, Nombre')
          .order('Nombre', ascending: true);

      return (response as List).map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error fetching users for admin: $e');
      return [];
    }
  }

  Future<void> _callAdminSp() async {
    // ... (El código de administración se mantiene igual)
     if (_selectedUserToEdit == null || _selectedNewProfileId == null || _selectedNewLogiaId == null || _selectedNewGrado == null) {
      _showErrorDialog("Datos Incompletos", "Debe seleccionar un Usuario, Perfil, Logia y Grado.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _supabase.rpc(
        'sp_catcusuarios',
        params: {
          'p_opcion': 8, 
          'p_idusuario': _selectedUserToEdit,
          'p_idperfil': _selectedNewProfileId,
          'p_iddlogia': _selectedNewLogiaId,
          'p_idgrado': _selectedNewGrado,
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


  // --- WIDGETS DE UI ---

  // Se añade un validador opcional al TextField para la nueva contraseña
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
        validator: validator ?? (value) {
          if (label.contains('Correo') && (value == null || !value.contains('@'))) {
            return 'Ingresa un correo válido.';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildPersonalInfoForm(Map<String, Color> theme) {
    return Column(
      children: [
        // --- 1. Encabezado Tipo PagoScreen (Card Header) ---
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

        // --- 2. Contenido Principal con Card de Edición ---
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
                      // No se incluye el título "Editar Datos Personales" aquí, ya está en el header card.
                      
                      // Campos de Edición (sin Contraseña)
                      _buildTextField(_emailController, 'Correo Electrónico', theme, keyboardType: TextInputType.emailAddress),
                      _buildTextField(_phoneController, 'Teléfono', theme, keyboardType: TextInputType.phone),
                      _buildTextField(_dobController, 'Fecha de Nacimiento (YYYY-MM-DD)', theme, keyboardType: TextInputType.datetime),
                      _buildTextField(_addressController, 'Dirección', theme),
                      
                      const SizedBox(height: 20),

                      // Botón de Guardar Cambios
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
                      
                      // Botón de Cambiar Contraseña (Abre el diálogo)
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


  Widget _buildAdminPanel(Map<String, Color> theme) {
    // ... (El código del panel de administración se mantiene igual)
     final List<PerfilOpcion> perfiles = widget.root.user.perfiles_opciones;
    //final List<LogiaCatalogo> logias = widget.root.catalogos.logias_catalogo;
    final List<int> grados = List.generate(34, (index) => index); 

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Herramientas de Administración",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme['accent']),
          ),
          const Divider(height: 30),

          Text("Modificar Perfil, Logia y Grado de Usuario", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme['text'])),
          const SizedBox(height: 10),

          FutureBuilder<List<Map<String, dynamic>>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
                return const Text('Error al cargar usuarios o no hay usuarios disponibles.');
              }
              
              final users = snapshot.data!;
              return DropdownButtonFormField<int>(
                decoration: InputDecoration(labelText: 'Usuario a Editar', labelStyle: TextStyle(color: theme['text']?.withOpacity(0.7))),
                value: _selectedUserToEdit,
                dropdownColor: theme['card'],
                items: users.map((user) => DropdownMenuItem<int>(
                  value: user['idUsuario'],
                  child: Text('${user['Nombre']} (ID: ${user['idUsuario']})', style: TextStyle(color: theme['text'])),
                )).toList(),
                onChanged: (val) => setState(() => _selectedUserToEdit = val),
              );
            },
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<int>(
            decoration: InputDecoration(labelText: 'Nuevo Perfil', labelStyle: TextStyle(color: theme['text']?.withOpacity(0.7))),
            value: _selectedNewProfileId,
            dropdownColor: theme['card'],
            items: perfiles.map((p) => DropdownMenuItem<int>(
              value: p.idPerfil,
              child: Text(p.idPerfil as String, style: TextStyle(color: theme['text'])),
            )).toList(),
            onChanged: (val) => setState(() => _selectedNewProfileId = val),
          ),
          const SizedBox(height: 16),

          //DropdownButtonFormField<int>(
            //decoration: InputDecoration(labelText: 'Nueva Logia (iddLogia)', labelStyle: TextStyle(color: theme['text']?.withOpacity(0.7))),
            //value: _selectedNewLogiaId,
            //dropdownColor: theme['card'],
            //items: logias.map((l) => DropdownMenuItem<int>(
              //value: l.iddLogia,
              //child: Text(l.Nombre, style: TextStyle(color: theme['text'])),
            //)).toList(),
            //onChanged: (val) => setState(() => _selectedNewLogiaId = val),
          //),
          //const SizedBox(height: 16),

          DropdownButtonFormField<int>(
            decoration: InputDecoration(labelText: 'Nuevo Grado (idGrado)', labelStyle: TextStyle(color: theme['text']?.withOpacity(0.7))),
            value: _selectedNewGrado,
            dropdownColor: theme['card'],
            items: grados.map((g) => DropdownMenuItem<int>(
              value: g,
              child: Text(g.toString(), style: TextStyle(color: theme['text'])),
            )).toList(),
            onChanged: (val) => setState(() => _selectedNewGrado = val),
          ),
          const SizedBox(height: 30),

          // Botón de Actualización SP
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _callAdminSp,
            icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.security, color: Colors.white),
            label: Text(_isLoading ? 'Ejecutando SP...' : 'Actualizar Usuario (SP 8)', style: const TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme['accent'],
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET PRINCIPAL ---

  @override
  Widget build(BuildContext context) {
    final theme = _getThemeColors();
    
    // Admin (Perfil 1): usa TabBar
    if (_canAdmin) {
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: theme['bg'],
          appBar: AppBar(
            title: Text('Editar Perfil / Admin', style: TextStyle(color: theme['text'])),
            backgroundColor: theme['bg'], // Estilo solicitado
            elevation: 0,                // Estilo solicitado
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
              _buildPersonalInfoForm(theme), // Pestaña 1: Datos personales
              _buildAdminPanel(theme),      // Pestaña 2: Administración
            ],
          ),
        ),
      );
    } 
    // Usuario Estándar: solo muestra el formulario personal
    else {
      return Scaffold(
        backgroundColor: theme['bg'],
        appBar: AppBar(
          title: Text('Editar Mi Perfil', style: TextStyle(color: theme['text'])),
          backgroundColor: theme['bg'], // Estilo solicitado
          elevation: 0,                // Estilo solicitado
          iconTheme: IconThemeData(color: theme['text']),
        ),
        drawer: AppDrawer(root: widget.root, selectedProfile: widget.selectedProfile!),
        body: _buildPersonalInfoForm(theme),
      );
    }
  }

  // --- DIALOGS ---

  void _showErrorDialog(String title, String msg) {
    showDialog(context: context, builder: (_) => AlertDialog(title: Text(title, style: const TextStyle(color: Colors.red)), content: Text(msg), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))]));
  }
  
  void _showSuccessDialog(String title, String msg) {
    showDialog(context: context, builder: (_) => AlertDialog(title: Text(title, style: const TextStyle(color: Colors.green)), content: Text(msg), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))]));
  }
}