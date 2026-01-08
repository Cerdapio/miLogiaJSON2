//import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:milogia/screens/app_drawer.dart';
import 'package:milogia/screens/pago_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../config/auth_config.dart'; // Asegúrate de que esta importación existe

//import 'home_screen.dart';
//import 'emergencies_screen.dart';
//import 'pago_screen.dart'; 

// Las clases de pantalla se mantienen igual.
class PaymentsScreen extends StatelessWidget {
  final RootModel root;
  const PaymentsScreen({super.key, required this.root});
  @override
  Widget build(BuildContext context) {
    final theme = LogiaTheme.getThemeById(root.user.perfiles_opciones.isNotEmpty ? root.user.perfiles_opciones.first.idLogia : 0);
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Pagos')),
      body: Center(child: Text('Total de pagos: ${root.user.pagos.length}', style: TextStyle(color: theme.primaryColor))),
    );
  }
}




class JobsScreen extends StatelessWidget {
  final RootModel root;
  const JobsScreen({super.key, required this.root});
  @override
  Widget build(BuildContext context) {
    LogiaTheme.defaultTheme();
    return Scaffold(
      appBar: AppBar(title: const Text('Trabajos y Tareas')),
      body: const Center(child: Text('Módulo de Trabajos (Pendiente de implementación)')),
    );
  }
}

// ----------------------------------------------------
// HomeScreen -> Stateful
// ----------------------------------------------------

class HomeScreen extends StatefulWidget {
  final RootModel root;
  final PerfilOpcion selectedProfile;
  const HomeScreen({super.key, required this.root, required this.selectedProfile});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isUploading = false;

 
  // Se mantiene esta función, pero se recomienda cambiar la URL guardada en DB
  String _driveToDirect(String url) {
    if (url.contains('drive.google.com')) {
      final idMatch = RegExp(r'/d/([a-zA-Z0-9_-]{10,})').firstMatch(url);
      if (idMatch != null) return 'https://drive.google.com/uc?export=view&id=${idMatch.group(1)}';
      final idQuery = RegExp(r'id=([a-zA-Z0-9_-]{10,})').firstMatch(url);
      if (idQuery != null) return 'https://drive.google.com/uc?export=view&id=${idQuery.group(1)}';
    }
    return url;
  }


  Future<void> _pickAndUploadAvatar() async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
      if (picked == null) return;

      final supabase = Supabase.instance.client;

      // Verificar que el usuario esté autenticado
      final current = supabase.auth.currentUser;
      if (current == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario no autenticado.')));
        return;
      }

      setState(() => _isUploading = true);

      final int userId = widget.root.user.idUsuario;
      final String bucketName = 'profilePictures';
      final String newPath = '$userId.png';
      final bytes = await picked.readAsBytes();

      try {
        // Subir (upsert = true para sobrescribir)
        await supabase.storage.from(bucketName).uploadBinary(newPath, bytes, fileOptions: const FileOptions(cacheControl: '3600', upsert: true));
      } catch (e) {
        // Error en upload -> mostrar detalle
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir archivo: $e'), backgroundColor: Colors.red));
        rethrow;
      }

      String publicUrl = '';
      try {
        // Intentar obtener URL pública
        publicUrl = supabase.storage.from(bucketName).getPublicUrl(newPath);
      } catch (_) {
        publicUrl = '';
      }

      // Si bucket es privado, la URL pública puede no funcionar.
      // En ese caso, pedir al backend (o usar createSignedUrl desde servidor) para obtener signed url.
      if (publicUrl.isEmpty || publicUrl.contains('null')) {
        // Intento de signed URL (puede requerir permisos desde el servidor)
        try {
          final signed = await supabase.storage.from(bucketName).createSignedUrl(newPath, 60 * 60); // 1 hora
          // createSignedUrl puede devolver Map o String según versión; adaptarlo si es necesario
          if (signed is Map && signed['signedURL'] != null) publicUrl = signed['signedURL'];
          else if (signed is String) publicUrl = signed;
        } catch (_) {
          // fallback: no se pudo generar signed url desde cliente
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subido pero no se pudo generar URL pública. Revisa permisos del bucket.'), backgroundColor: Colors.orange));
        }
      }

      // Actualizar DB con la URL (si se obtuvo)
      if (publicUrl.isNotEmpty) {
        await supabase.from('catcUsuarios').update({'Foto': publicUrl}).eq('idUsuario', userId);
        setState(() {
          widget.root.user.Foto = publicUrl;
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto de perfil actualizada correctamente.')));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Archivo subido, pero no se actualizó URL en perfil. Configure bucket o use servicio para signed URL.'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir la imagen: ${e.toString()}'), backgroundColor: Colors.red.shade700));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Widget _buildProfileHeader(BuildContext context) {
    // ... (rest of the code is the same)
    final theme = LogiaTheme.getThemeById(widget.selectedProfile.idLogia);
    final profile = widget.selectedProfile;
    final userData = widget.root.user;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0),
      decoration: BoxDecoration(
        color: theme.primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              InkWell(
                onTap: _isUploading ? null : _pickAndUploadAvatar,
                borderRadius: BorderRadius.circular(60),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: theme.secondaryColor,
                  child: ClipOval(
                    child: userData.Foto.isNotEmpty
                        ? Image.network(
                            _driveToDirect(userData.Foto),
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.person, size: 50, color: Colors.white);
                            },
                          )
                        : const Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                ),
              ),
              if (_isUploading)
                const SizedBox(
                  width: 100,
                  height: 100,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                    child: Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            '${profile.Tratamiento.isNotEmpty ? profile.Tratamiento + " " : ""}${userData.Nombre}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.secondaryColor,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: theme.accentColor,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              '${profile.GradoNombre} | ${profile.Grupo}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection(BuildContext context) {
    // ... (rest of the code is the same)
    final theme = LogiaTheme.getThemeById(widget.selectedProfile.idLogia);
    final userData = widget.root.user;
    
    Widget _buildInfoRow(IconData icon, String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.secondaryColor, size: 24),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    value.isNotEmpty ? value : 'N/A',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 5,
      margin: const EdgeInsets.only(top: 20, left: 10, right: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Datos de Contacto',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
            const Divider(height: 25),
            _buildInfoRow(Icons.email, 'Correo Electrónico (Usuario)', userData.CorreoElectronico),
            _buildInfoRow(Icons.phone, 'Teléfono', userData.Telefono),
            _buildInfoRow(Icons.location_on, 'Dirección', userData.Direccion),
            //_buildInfoRow(Icons.badge, 'ID Usuario', userData.idUsuario.toString()),
          ],
        ),
      ),
    );
  }

  

  @override
  Widget build(BuildContext context) {
    // ... (rest of the code is the same)
    final theme = LogiaTheme.getThemeById(widget.selectedProfile.idLogia);

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'MI PERFIL',
          style: TextStyle(
            color: theme.secondaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.primaryColor,
        iconTheme: IconThemeData(color: theme.secondaryColor),
        elevation: 0,
      ),
      drawer: AppDrawer(
        root: widget.root, 
        selectedProfile: widget.selectedProfile
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          children: [
            _buildProfileHeader(context),
            _buildPersonalInfoSection(context),
            //Card(
              //elevation: 5,
              //margin: const EdgeInsets.only(top: 20, left: 10, right: 10),
              //shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              //child: Padding(
                //padding: const EdgeInsets.all(20.0),
                //child: Row(
                  //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  //children: [
                    //Icon(Icons.monetization_on, color: theme.secondaryColor, size: 40),
                    //Column(
                      //crossAxisAlignment: CrossAxisAlignment.end,
                      //children: [
                        //Text(
                          //'Pagos Registrados',
                          //style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        //),
                        //Text(
                          //'${widget.root.user.pagos.length} Movimientos',
                          //style: TextStyle(
                            //fontSize: 20,
                            //fontWeight: FontWeight.bold,
                            //color: theme.primaryColor,
                          //),
                        //),
                      //],
                    //)
                  //],
                //),
              //),
            //),
          ],
        ),
      ),
    );
  }
}