// ...existing code...
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:milogia/screens/super_admin_screen.dart';
import 'package:milogia/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart'; // Importación clave para las opciones
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import '../config/auth_config.dart';
import '../config/l10n.dart';
import 'home_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:developer';

// Usamos la instancia global inicializada en main.dart
final SupabaseClient supabase = Supabase.instance.client;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // **NUEVO: Instancia para autenticación local**
  final LocalAuthentication _localAuth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();

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

  // **NUEVO: Función para autenticación biométrica**
  Future<void> _authenticateWithBiometrics() async {
    bool authenticated = false;
    try {
      // 1. Verificar si el dispositivo soporta biometría
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) {
        _showSnackbar(L10n.biometricNoSupport(context), isError: true);
        return;
      }

      // 2. Iniciar el diálogo de autenticación
      authenticated = await _localAuth.authenticate(
        localizedReason: L10n.biometricReason(context),
        options: const AuthenticationOptions(
          stickyAuth: true, // Mantiene el diálogo hasta que se complete
          biometricOnly: true, // Solo permite huella/rostro, no PIN del dispositivo
        ),
      );

      if (authenticated) {
        _showSnackbar(L10n.authSuccess(context));
        // **NUEVO: Recuperar y usar credenciales guardadas**
        final email = await _storage.read(key: 'email');
        final password = await _storage.read(key: 'password');

        if (email != null && password != null) {
          // Rellenamos los controladores y llamamos a la función de login
          _userController.text = email;
          _passwordController.text = password;
          await _login();
        } else {
          _showSnackbar(L10n.credentialsNotFound(context), isError: true);
        }
      }
    } catch (e) {
      _showSnackbar('${L10n.biometricError(context)}: ${e.toString()}', isError: true);
    }
  }

  // **NUEVO: Funciones para guardar y borrar credenciales**
  Future<void> _saveCredentials(String email, String password) async {
    await _storage.write(key: 'email', value: email);
    await _storage.write(key: 'password', value: password);
  }

  Future<void> _deleteCredentials() async {
    await _storage.delete(key: 'email');
    await _storage.delete(key: 'password');
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    // **CAMBIO CRÍTICO DE SEGURIDAD**
    // Usamos el email para el login de Supabase Auth, no el nombre de usuario.
    // El campo de texto en la UI debería pedir el Correo Electrónico.
    final email = _userController.text.trim();
    final password = _passwordController.text;
    String accessToken = '';

    try {
      // Se usa el email y password introducidos por el usuario, no valores fijos.
      final AuthResponse authResponse = await supabase.auth.signInWithPassword(
        email: email, 
        password: password,
      );
      print(authResponse);
      if (authResponse.session == null) {
        throw AuthException(L10n.sessionUnavailable(context));
      }
      accessToken = authResponse.session!.accessToken;
      print(accessToken);

      final url = Uri.parse('$supabaseUrl/rest/v1/rpc/$rpcFunction');

      // **NUEVO: Obtener ubicación antes de llamar a sp_catcusuarios_v2**
      double? lat, lng;
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
          lat = pos.latitude;
          lng = pos.longitude;
        }
      } catch (_) {
        // Ignorar errores de GPS en login para no bloquear el acceso
      }

      final payload = {
        "popcion": 5,
        "pusuario": email,
        "pcontrasena": password,
        'pfechanacimiento': '1900-01-01',
        "plat": lat,
        "plng": lng,
      };

      final headers = {
        'Content-Type': 'application/json',
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer $accessToken',
      };
      print(supabaseAnonKey);
      final resp = await http.post(url, headers: headers, body: json.encode(payload));
      print(resp.body);
      log(jsonEncode(resp.body), name: 'LOGIN_JSON');
      if (resp.statusCode == 200) {
        final dynamic rawDecodedResponse = json.decode(resp.body);
        Map<String, dynamic>? processedDecodedResponse;
        
        if (rawDecodedResponse is List && rawDecodedResponse.isNotEmpty) {
          // Si obtenemos una lista (ej. de un SELECT), buscamos el primer elemento
          final first = rawDecodedResponse[0];
          if (first is Map<String, dynamic>) {
            // Si está envuelto en una llave con nombre del SP (común en PostgREST crudo)
            if (first.containsKey('sp_catcusuarios_v2')) {
              processedDecodedResponse = first['sp_catcusuarios_v2'] as Map<String, dynamic>;
            } else {
              processedDecodedResponse = first;
            }
          }
        } else if (rawDecodedResponse is Map<String, dynamic>) {
          processedDecodedResponse = rawDecodedResponse;
        }

        if (processedDecodedResponse != null) {
          if (processedDecodedResponse['status'] == 'error') {
            _showSnackbar(processedDecodedResponse['message'] as String, isError: true);
            return;
          }
          if (processedDecodedResponse.containsKey('user')) {
            // Usamos el modelo RootModel generado
            final root = RootModel.fromJson(processedDecodedResponse);
            _rootModel = root;

            // Filtro Anti-Duplicados: "Super Usuario" vs "Superusuario"
            final profilesRaw = root.user.perfiles_opciones;
            final profilesMap = <String, PerfilOpcion>{};
            for (var p in profilesRaw) {
               // Normalizamos creando una llave única. 
               // Usamos idLogia e idPerfil, ignorando variaciones leves en el nombre del perfil.
               final key = '${p.idLogia}_${p.idPerfil}';
               if (!profilesMap.containsKey(key)) {
                 profilesMap[key] = p;
               }
            }
            final profiles = profilesMap.values.toList();

            if (profiles.length > 1) {
              if (mounted) _showProfileSelectionDialog(profiles);
            } else if (profiles.length == 1) {
              _navigateToHome(profiles.first, accessToken);
            } else {
              // Si no hay perfiles, es un error de configuración
              await _deleteCredentials();
              if (mounted) _showSnackbar(L10n.noProfilesAssigned(context), isError: true);
              print('Email: $email, Password: $password, Payload: $payload');
              print('Response Body: ${resp.body}');
              print('Profiles List: $profiles');
            }
            return;
          }

           _showSnackbar(L10n.userKeyNotFound(context), isError: true);
          return;
        } else {
          _showSnackbar(L10n.rpcFormatError(context), isError: true);
          return;
        }
      } else {
         final errorBody = json.decode(resp.body);
        final errorMessage = errorBody['message'] ?? 'Error desconocido';
        _showSnackbar('${L10n.extraDataError(context)}Code: ${resp.statusCode}, Msg: $errorMessage', isError: true);
        
      }
    } on AuthException catch (e) {
       String errorMessage = e.message.contains('Invalid login credentials') == true
          ? L10n.loginCredentialsError(context)
          : '${L10n.authGenError(context)}${e.message}';
      // Si las credenciales son inválidas, las borramos del almacenamiento seguro
      await _deleteCredentials();
      _showSnackbar(errorMessage, isError: true);
      print('Error de autenticación: ${e.message}');
     } catch (e) {
      _showSnackbar('${L10n.unexpectedError(context)}${e.toString()}', isError: true);
      //print ('Ocurrió un error inesperado. ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

   void _showProfileSelectionDialog(List<PerfilOpcion> profiles) {
    if (profiles.isEmpty) {
      _showSnackbar(L10n.loginSuccessNoProfiles(context), isError: true);
      return;
    }
    _selectedProfile = profiles.first;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: Text(L10n.profileSelectionTitle(context)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(L10n.profileSelectionBody(context)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<PerfilOpcion>(
                    isExpanded: true,
                    // Asegurar que el valor seleccionado sea válido
                    value: profiles.contains(_selectedProfile) ? _selectedProfile : (profiles.isNotEmpty ? profiles.first : null),
                    decoration: InputDecoration(
                      labelText: L10n.groupLabel(context),
                      border: const OutlineInputBorder(),
                    ),
                    selectedItemBuilder: (BuildContext context) {
                      return profiles.map<Widget>((PerfilOpcion p) {
                        return SizedBox(
                          width: 200, // Forzar un ancho máximo para el texto seleccionado dentro del diálogo
                          child: Text(
                            '${p.LogiaNombre} (${p.PerfilNombre})',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList();
                    },
                    items: profiles.map((p) {
                      return DropdownMenuItem<PerfilOpcion>(
                        value: p,
                        child: Text(
                          '${p.LogiaNombre} (${p.PerfilNombre})',
                          overflow: TextOverflow.ellipsis,
                        ),
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
                  child: Text(L10n.loginButton(context)),
                ),
              ],
            );
          },
        );
      },
    );
  }

    // Pasamos el RootModel al HomeScreen (ajusta HomeScreen si requiere otros datos)
  void _navigateToHome(PerfilOpcion selectedProfile, [String? accessToken]) {
    if (_rootModel == null) return;
  
    // **NUEVO: Programamos las notificaciones aquí, donde ya sabemos la logia seleccionada.**
    // Pasamos el RootModel completo y el ID de la logia para filtrar.
    NotificationService().scheduleBirthdayNotifications(_rootModel!, selectedProfile.idLogia);
    
    // **NUEVO: Guardamos el token FCM para notificaciones push**
    // **NUEVO: Guardamos el token FCM para notificaciones push (contexto Logia)**
    // Pasamos el idLogia seleccionado
    NotificationService().saveTokenToDatabase(selectedProfile.idLogia);

    // **NUEVO: Guardamos las credenciales para el próximo inicio de sesión biométrico**
    _saveCredentials(_userController.text.trim(), _passwordController.text);
  
    // **MODIFICADO: Redirigir a la pantalla correcta según el perfil**
    final Widget destinationScreen = selectedProfile.idPerfil == 0
        ? SuperAdminScreen(root: _rootModel!, selectedProfile: selectedProfile)
        : HomeScreen(root: _rootModel!, selectedProfile: selectedProfile);
  
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        //builder: (context) => HomeScreen(root: _rootModel!, selectedProfile: selectedProfile),
        builder: (context) => destinationScreen,
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
                      Container( // Contenedor para definir el área circular
                        width: 140, // Doble del radio deseado (60 * 2)
                        height: 140, // Doble del radio deseado
                        decoration: BoxDecoration(
                          color: Colors.grey[200], // Color de fondo del círculo
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval( // Recorta el contenido a una forma ovalada (circular en este caso)
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain, // Asegura que la imagen completa sea visible, sin recortar
                          ),
                        ),
                      ),
                     
                      const SizedBox(height: 10),
                      Text(
                        L10n.loginTitle(context),
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
                                  labelText: L10n.emailLabel(context),
                                  hintText: L10n.emailHint(context),
                                  prefixIcon: Icon(Icons.person, color: _secondaryColor),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                style: TextStyle(color: _formTextColor),
                                validator: (value) {
                                  if (value == null || value.isEmpty || !value.contains('@')) {
                                    return L10n.emailError(context);
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _isObscure,
                                decoration: InputDecoration(
                                  labelText: L10n.passwordLabel(context),
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
                                    return L10n.passwordError(context);
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
                                          L10n.loginButton(context),
                                          style: TextStyle(
                                            color: _primaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 15),
                              // **NUEVO: Botón para biometría**
                              IconButton(
                                onPressed: _authenticateWithBiometrics,
                                icon: Icon(
                                  Icons.fingerprint,
                                  color: _secondaryColor,
                                  size: 48,
                                ),
                                tooltip: L10n.fingerprintTooltip(context),
                              ),
                              Text(
                                L10n.fingerprintLabel(context),
                                style: const TextStyle(color: Colors.white70),
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
