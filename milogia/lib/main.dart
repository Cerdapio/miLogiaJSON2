import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
//import 'package:http/http.dart' as http; // Se importa aunque no se use directamente aquí, es buena práctica
import 'screens/login_screen.dart'; // Importa la pantalla de Login
import 'config/auth_config.dart'; // Importa las constantes de Supabase

// -------------------------------------------------------------------
// 1. FUNCIÓN PRINCIPAL MAIN: INICIALIZA SUPABASE Y EJECUTA LA APP
// -------------------------------------------------------------------

Future<void> main() async {
  // Asegura que todos los widgets de Flutter estén inicializados antes
  // de llamar a plugins o servicios externos.
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización de Supabase
  // Usamos las constantes definidas en auth_config.dart
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: true, // Habilitar logs de Supabase para depuración
    );
  } catch (e) {
    // Manejo de error si la inicialización falla (por ejemplo, claves inválidas)
    // En un entorno real, puedes usar un logger o Crashlytics.
    debugPrint('Error al inicializar Supabase: $e');
    // Si la inicialización falla, se puede optar por detener la aplicación
    // o mostrar una pantalla de error.
  }

  // Ahora puedes acceder a la instancia global de Supabase si la necesitas:
  // final supabaseClient = Supabase.instance.client;
  
  runApp(const MyApp());
}

// -------------------------------------------------------------------
// 2. WIDGET RAIZ DE LA APLICACIÓN
// -------------------------------------------------------------------

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Usamos el tema por defecto para toda la aplicación
    final defaultTheme = LogiaTheme.defaultTheme();

    return MaterialApp(
      title: 'Mi Logia App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Colores base (se personalizan en HomeScreen)
        primaryColor: defaultTheme.primaryColor,
        // Usamos un esquema de color vibrante como acento
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.grey, // Permite que Material3 funcione bien con nuestro gris principal
        ).copyWith(
          secondary: defaultTheme.secondaryColor, // Dorado/Accent
        ),
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto', // O tu fuente preferida
        useMaterial3: true,
        // Configuración de Textos y Botones si es necesario
      ),
      // Definición de rutas
      // El '/' es la ruta principal que se carga al inicio
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(), // Pantalla de inicio es el Login
        // Puedes añadir otras rutas aquí si las necesitas para navegación sin argumentos
        // Ejemplo: '/register': (context) => const UserRegistrationScreen(),
      },
    );
  }
}