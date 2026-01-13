import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart'; // Importar Firebase Core
import 'package:milogia/services/notification_service.dart';
import 'package:milogia/firebase_options.dart'; // Importar opciones generadas
import 'screens/login_screen.dart'; // Importa la pantalla de Login
import 'config/auth_config.dart'; // Importa las constantes de Supabase

// -------------------------------------------------------------------
// 1. FUNCIÓN PRINCIPAL MAIN: INICIALIZA SUPABASE Y EJECUTA LA APP
// -------------------------------------------------------------------

Future<void> main() async {
  // Asegura que todos los widgets de Flutter estén inicializados antes
  // de llamar a plugins o servicios externos.
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inicialización de Supabase (DEBE SER LO PRIMERO si NotificationService lo usa)
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: true, 
    );
    debugPrint('Supabase inicializado correctamente');
  } catch (e) {
    debugPrint('Error al inicializar Supabase: $e');
  }

  // 2. Inicialización de Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase inicializado correctamente');
  } catch (e) {
    debugPrint('Error al inicializar Firebase: $e');
  }

  // 3. Inicializa el servicio de notificaciones
  // Ahora es seguro llamarlo porque Supabase ya está listo
  await NotificationService().init();

  // Ahora puedes acceder a la instancia global de Supabase si la necesitas:
  // final supabaseClient = Supabase.instance.client;
  
  runApp(const MyApp());
}

// -------------------------------------------------------------------
// 2. WIDGET RAIZ DE LA APLICACIÓN
// -------------------------------------------------------------------

class MyApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Usamos el tema por defecto para toda la aplicación
    final defaultTheme = LogiaTheme.defaultTheme();

    return MaterialApp(
      navigatorKey: navigatorKey,
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