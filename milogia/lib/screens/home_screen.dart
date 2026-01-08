//import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart' as dio; // Se añade el prefijo 'dio' para evitar colisión de nombres
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:milogia/config/auth_config.dart';
import 'package:milogia/services/notification_service.dart';
import 'package:milogia/screens/app_drawer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'actas_screen.dart'; // Importar Pantalla de Actas


//import 'home_screen.dart';
//import 'emergencies_screen.dart';
//import 'pago_screen.dart'; 

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

  @override
  void initState() {
    super.initState();
    // Guardar o actualizar el token FCM cada vez que se entra al perfil (Last Login Wins)
    // Usamos addPostFrameCallback para evitar problemas de contexto si se necesitan diálogos
    WidgetsBinding.instance.addPostFrameCallback((_) {
    // Sincronizar Token FCM con la Logia actual
    NotificationService().saveTokenToDatabase(widget.selectedProfile.idLogia);
    });
  }

 
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

  LogiaTheme _getDynamicTheme() {
    final colores = widget.selectedProfile.colores;
    return LogiaTheme(
      nombre: 'Dynamic',
      primaryColor: _parseHex(colores.C1, const Color(0xFFF5F5F5)), 
      secondaryColor: _parseHex(colores.C4, const Color(0xFFDAA520)),
      accentColor: _parseHex(colores.C2, const Color(0xFF222222)), 
      backgroundColor: _parseHex(colores.C3, Colors.white), 
    );
  }

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
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
    if (picked == null) return;

    setState(() => _isUploading = true);

    try {
      final supabase = Supabase.instance.client;
      final int userId = widget.root.user.idUsuario;
      final bytes = await picked.readAsBytes();
      final functionName = 'upload-avatar';

      // 1. Construir la URL de la Edge Function
      final functionUrl = '$supabaseUrl/functions/v1/$functionName';

      // 2. Obtener el token de autorización actual
      final headers = {
        'Authorization': 'Bearer ${supabase.auth.currentSession?.accessToken}',
      };

      // Creamos un FormData para enviar el archivo y el ID de usuario
      final formData = dio.FormData();
      formData.files.add(MapEntry(
          'avatar', dio.MultipartFile.fromBytes(bytes, filename: '${userId}.png')));
      formData.fields.add(MapEntry('userId', userId.toString()));

      // 3. Usar 'dio' para hacer la petición POST con el FormData
      final dioClient = dio.Dio();
      final response = await dioClient.post(
        functionUrl,
        data: formData,
        options: dio.Options(headers: headers),
      );

      if (response.statusCode != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        throw Exception(errorData?['error'] ?? 'Error desconocido en la función.');
      }

      final responseData = response.data as Map<String, dynamic>;
      final newAvatarUrl = responseData['avatarUrl'] as String;

      setState(() {
        // Guardamos la nueva URL en el estado local para que se muestre inmediatamente.
        widget.root.user.Foto = newAvatarUrl;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto de perfil actualizada correctamente.')));
      }
    } catch (e) {
      if (mounted) {
        // Muestra el error de RLS o cualquier otro error
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir la imagen: $e'), backgroundColor: Colors.red.shade700));
        print(('Error al subir la imagen: ${e.toString()}, .::.'));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }




  Widget _buildProfileHeader(BuildContext context) {
    // ... (rest of the code is the same)
    final theme = _getDynamicTheme();
    final profile = widget.selectedProfile;
    final userData = widget.root.user;

    final double headerHeight = MediaQuery.of(context).size.height * 0.33;

    return Container(
      width: double.infinity,
      height: headerHeight,
      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0),
      decoration: BoxDecoration(
        color: theme.primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
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
        mainAxisAlignment: MainAxisAlignment.center, // Centrar verticalmente
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              InkWell(
                onTap: _isUploading ? null : _pickAndUploadAvatar,
                borderRadius: BorderRadius.circular(80),
                child: CircleAvatar(
                  radius: 70, // Aumentado para aprovechar el espacio
                  backgroundColor: theme.secondaryColor,
                  child: ClipOval(
                    child: userData.Foto.isNotEmpty
                        ? Image.network(
                            _driveToDirect(userData.Foto),
                            width: 140,
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.person, size: 70, color: Colors.white);
                            },
                          )
                        : const Icon(Icons.person, size: 70, color: Colors.white),
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
          Text(
            profile.PerfilNombre,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: theme.secondaryColor.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 10),
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
    final theme = _getDynamicTheme();
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
            const Divider(height: 25),
            //_buildInfoRow(Icons.badge, 'ID Usuario', userData.idUsuario.toString()),
          ],
        ),
      ),
    );
  }

  

  // Lista de autores masones permitidos
List<String> masonesFamosos = [
    "George Washington",
    "Benjamin Franklin",
    "Mark Twain",
    "Winston Churchill",
    "Simón Bolívar",
    "José de San Martín",
    "Benito Juárez",
    "Oscar Wilde",
    "Rudyard Kipling",
    "Arthur Conan Doyle",
    "Wolfgang Amadeus Mozart",
    "Ludwig van Beethoven",
    "Johann Wolfgang von Goethe",
    "Voltaire",
    "Alexander Fleming",
    "Henry Ford",
    "Buzz Aldrin",
    "Charles Lindbergh",
    "Theodore Roosevelt",
    "Franklin D. Roosevelt",
    "Harry S. Truman",
    "Gerald Ford",
    "Andrew Jackson",
    "James Monroe",
    "Mario Moreno Cantinflas",
    "Salvador Allende",
    "Francisco de Miranda",
    "Antonio José de Sucre",
    "Bernardo O'Higgins",
    "José Martí",
    "Rubén Darío",
    "Antonio Machado",
    "Federico el Grande",
    "Giuseppe Garibaldi",
    "Lafayette",
    "Douglas MacArthur",
    "John Wayne",
    "Clark Gable",
    "Louis Armstrong",
    "Duke Ellington",
    "Harry Houdini",
    "Walt Disney",
    "Edwin Drake",
    "Steve Wozniak",
    "Albert Pike",
    "Manly P. Hall",
    "Jean-Jacques Rousseau",
    "Montesquieu",
    "Erasmo de Rotterdam",
    "Isaac Newton",
];

  // Frases de respaldo por si la API falla o no encuentra coincidencias
  final List<Map<String, String>> _fallbackQuotes = [
    {'texto': 'Bien hecho es mejor que bien dicho.', 'autor': 'Benjamin Franklin'},
    {'texto': 'El secreto de salir adelante es comenzar.', 'autor': 'Mark Twain'},
    {'texto': 'El éxito no es el final, el fracaso no es fatal: es el coraje para continuar lo que cuenta.', 'autor': 'Winston Churchill'},
    {'texto': 'Sé tú mismo; los demás puestos ya están ocupados.', 'autor': 'Oscar Wilde'},
    {'texto': 'No estoy de acuerdo con lo que dices, pero defenderé con mi vida tu derecho a expresarlo.', 'autor': 'Voltaire'},
    {'texto': 'La libertad, cuando empieza a echar raíces, es una planta de rápido crecimiento.', 'autor': 'George Washington'},
    {'texto': 'El arte de vencer se aprende en las derrotas.', 'autor': 'Simón Bolívar'},
    {'texto': 'La mejor manera de empezar es dejar de hablar y empezar a actuar.', 'autor': 'Walt Disney'},
    {'texto': 'Saber no es suficiente, debemos aplicar. Querer no es suficiente, debemos hacer.', 'autor': 'Johann Wolfgang von Goethe'},
    {'texto': 'Serás lo que debas ser o no serás nada.', 'autor': 'José de San Martín'},
  ];

  Future<Map<String, dynamic>> obtenerFrase() async {
    // Intentamos obtener una lista de 50 frases para tener más probabilidad de encontrar un autor
    final url = Uri.parse('https://zenquotes.io/api/quotes');
    
    try {
      final respuesta = await http.get(url);
      if (respuesta.statusCode == 200) {
        List datos = jsonDecode(respuesta.body);
        
        // Filtramos por autores permitidos
        final frasesFiltradas = datos.where((item) {
          String authorName = item['a'] ?? '';
          return masonesFamosos.any((allowed) => authorName.contains(allowed));
        }).toList();

        if (frasesFiltradas.isNotEmpty) {
           // Retornamos una aleatoria de las filtradas
           final randomItem = (frasesFiltradas..shuffle()).first;
           return {
             'texto': randomItem['q'],
             'autor': randomItem['a'],
           };
        }
      }
      // Si la API no contesta 200 o no hay coincidencias, lanzamos excepción para usar fallback
      throw Exception('No quotes found from masonic authors');
    } catch (e) {
      // Fallback: Retorna una frase aleatoria de nuestra lista local
      final randomFallback = (_fallbackQuotes..shuffle()).first;
      return {
        'texto': randomFallback['texto']!,
        'autor': randomFallback['autor']!,
      };
    }
  }

  Widget _buildQuoteCard(BuildContext context) {
    final theme = _getDynamicTheme();
    return Card(
      elevation: 5,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.format_quote, color: theme.secondaryColor, size: 30),
                const SizedBox(width: 10),
                Text(
                  'Frase del Día',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
              ],
            ),
            const Divider(height: 25),
            FutureBuilder<Map<String, dynamic>>(
              future: obtenerFrase(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Text('Error al cargar la frase.', style: TextStyle(color: Colors.red.shade300));
                } else if (snapshot.hasData) {
                  final data = snapshot.data!;
                  return Column(
                    children: [
                      Text(
                        '"${data['texto']}"',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade800,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          "- ${data['autor']}",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.accentColor,
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  return const Text('Sin frase disponible.');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... (rest of the code is the same)
    final theme = _getDynamicTheme();

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
            _buildQuoteCard(context),
            if (widget.selectedProfile.idPerfil == 5) // Solo Secretarios
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: SizedBox(
                   width: double.infinity,
                   height: 50,
                   child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: theme.accentColor),
                      icon: const Icon(Icons.description, color: Colors.white),
                      label: const Text('LEVANTAR ACTA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: () {
                         Navigator.push(context, MaterialPageRoute(
                           builder: (context) => ActasScreen(root: widget.root, selectedProfile: widget.selectedProfile)
                         ));
                      },
                   ),
                ),
              ),
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