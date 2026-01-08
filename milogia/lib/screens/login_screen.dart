// ...existing code...
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../config/auth_config.dart';
import 'home_screen.dart';

final SupabaseClient supabase = SupabaseClient(
  supabaseUrl,
  supabaseAnonKey,
);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isObscure = true;
  bool _isLoading = false;
  String _errorMessage = '';

  PerfilOpcion? _selectedProfile;
  RootModel? _rootModel;        // ahora usamos RootModel del modelo generado
// guardamos el token de sesión

  final Color _primaryColor = Colors.grey.shade900;
  final Color _secondaryColor = const Color(0xFFDAA520);
  final Color _formBackgroundColor = Colors.white;
  final Color _formTextColor = Colors.black87;

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final username = _userController.text;
    final password = _passwordController.text;
    String accessToken = '';

    try {
      final AuthResponse authResponse = await supabase.auth.signInWithPassword(
        email: "laportillo1987@gmail.com", 
        password: "C3rd45-69*69",
      );
      print(authResponse);
      if (authResponse.session == null) {
        throw const AuthException('Sesión no disponible después de la autenticación. Credenciales inválidas.');
      }
      accessToken = authResponse.session!.accessToken;
      print(accessToken);
      final url = Uri.parse('$supabaseUrl/rest/v1/rpc/$rpcFunction');

      final payload = {
        "popcion": 5,
        "pidusuario": 1,
        "piddlogia": 1,
        "pnombre": "",
        "pusuario": username,
        "pcontrasena": password,
        "ptelefono": "",
        "pfechanacimiento": "",
        "pdireccion": "",
        "pcorreoelectronico": "",
        "pfoto": ""
      };

      final headers = {
        'Content-Type': 'application/json',
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer $accessToken',
      };
      print(supabaseAnonKey);
      final resp = await http.post(url, headers: headers, body: json.encode(payload));
      print(resp.body);
      if (resp.statusCode == 200) {
        final dynamic decodedResponse = json.decode(resp.body);

        if (decodedResponse is Map<String, dynamic>) {
          if (decodedResponse['status'] == 'error') {
            _showSnackbar(decodedResponse['message'] as String, isError: true);
            return;
          }
          print(decodedResponse);
          if (decodedResponse.containsKey('user')) {
            // Usamos el modelo RootModel generado
            final root = RootModel.fromJson(decodedResponse);
            _rootModel = root;
            print(accessToken);
            final profiles = root.user.perfiles_opciones;

            if (profiles.length > 1) {
              if (mounted) _showProfileSelectionDialog(profiles);
            } else if (profiles.length == 1) {
              _navigateToHome(profiles.first);
            } else {
              if (mounted) _showSnackbar('El usuario no tiene perfiles asignados, pero la sesión es válida.', isError: true);
            }
            return;
          }

          _showSnackbar('Respuesta de servidor válida, pero no se encontró la clave "user".', isError: true);
          return;
        } else {
          _showSnackbar('Formato de respuesta de la RPC inesperado.', isError: true);
          return;
        }
      } else {
        final errorBody = json.decode(resp.body);
        final errorMessage = errorBody['message'] ?? 'Error desconocido';
        _showSnackbar('Error al obtener datos adicionales (Código: ${resp.statusCode}, Mensaje: $errorMessage)', isError: true);
      }
    } on AuthException catch (e) {
      String errorMessage = e.message.contains('Invalid login credentials') == true
          ? 'Usuario o contraseña incorrectos.'
          : 'Error de autenticación: ${e.message}';
      _showSnackbar(errorMessage, isError: true);
      print('Error de autenticación: ${e.message}');
    } catch (e) {
      _showSnackbar('Ocurrió un error inesperado. ${e.toString()}', isError: true);
      //print ('Ocurrió un error inesperado. ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showProfileSelectionDialog(List<PerfilOpcion> profiles) {
    _selectedProfile = profiles.first;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: const Text('Selección de Perfil'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Por favor, selecciona el grupo con el que deseas trabajar:'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<PerfilOpcion>(
                    value: _selectedProfile,
                    decoration: const InputDecoration(
                      labelText: 'Grupo / Logia',
                      border: OutlineInputBorder(),
                    ),
                    items: profiles.map((p) {
                      // Ajustado a los nombres del modelo: Grupo y GradoNombre
                      return DropdownMenuItem<PerfilOpcion>(
                        value: p,
                        child: Text('${p.Grupo} (${p.GradoNombre})'),
                      );
                    }).toList(),
                    onChanged: (PerfilOpcion? newValue) {
                      setStateSB(() {
                        _selectedProfile = newValue;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _selectedProfile != null
                      ? () {
                          Navigator.of(context).pop();
                          _navigateToHome(_selectedProfile!);
                        }
                      : null,
                  child: const Text('INGRESAR'),
                ),
              ],
            );
          },
        );
      },
    );
  }

    // Pasamos el RootModel al HomeScreen (ajusta HomeScreen si requiere otros datos)
  void _navigateToHome(PerfilOpcion selectedProfile) {
    if (_rootModel == null) return;

    // Pasamos tanto RootModel como el perfil seleccionado al HomeScreen
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => HomeScreen(root: _rootModel!, selectedProfile: selectedProfile),
      ),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      //Icon(Icons.lock_open, size: 80, color: _secondaryColor),
                      CircleAvatar(
                        radius: 60, // Tamaño del círculo del logo
                        backgroundColor: Colors.grey[200],
                        backgroundImage: const AssetImage('images/logo.png'),
                        child: Image.asset('images/logo.png'),
                      ),
                     
                      const SizedBox(height: 10),
                      Text(
                        'MI LOGIA',
                        style: TextStyle(
                          color: _secondaryColor,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Container(
                        width: constraints.maxWidth > 400 ? 400 : constraints.maxWidth,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _formBackgroundColor,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextFormField(
                                controller: _userController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'Usuario',
                                  //hintText: 'ej. nombre@dominio.com',
                                  prefixIcon: Icon(Icons.person, color: _secondaryColor),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                style: TextStyle(color: _formTextColor),
                                validator: (value) {
                                  //if (value == null || value.isEmpty || !value.contains('@')) {
                                    //return 'Ingresa un correo electrónico válido';
                                  //}
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _isObscure,
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  prefixIcon: Icon(Icons.lock, color: _secondaryColor),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isObscure ? Icons.visibility : Icons.visibility_off,
                                      color: _secondaryColor,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isObscure = !_isObscure;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                style: TextStyle(color: _formTextColor),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor ingresa tu contraseña';
                                  }
                                  return null;
                                },
                              ),
                              if (_errorMessage.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10.0),
                                  child: Text(
                                    _errorMessage,
                                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              const SizedBox(height: 30),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _secondaryColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: _primaryColor,
                                            strokeWidth: 3,
                                          ),
                                        )
                                      : Text(
                                          'INGRESAR',
                                          style: TextStyle(
                                            color: _primaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
