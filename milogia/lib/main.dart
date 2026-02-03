import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // Necesario para detectar el mensaje inicial
import 'package:milogia/services/notification_service.dart';
import 'package:milogia/firebase_options.dart';
import 'dart:convert'; // Para decodificar payload
import 'screens/login_screen.dart';
import 'screens/panic_alert_screen.dart'; // Asegúrate de importar tu pantalla de pánico
import 'config/auth_config.dart';
import 'config/l10n.dart'; // Import L10n
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';


// Definimos la key globalmente para poder acceder a ella desde cualquier lado si es necesario
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX', null);
  await initializeDateFormatting('en_US', null);
  await initializeDateFormatting('es', null);
  await initializeDateFormatting(null, null);


  // 1. Inicialización de Supabase
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: true, 
    );
    debugPrint('✅ Supabase inicializado correctamente');
  } catch (e) {
    debugPrint('❌ Error al inicializar Supabase: $e');
  }

  // 2. Inicialización de Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase inicializado correctamente');
  } catch (e) {
    debugPrint('❌ Error al inicializar Firebase: $e');
  }

  // 3. Inicializa el servicio de notificaciones
  await NotificationService().init();

  runApp(const MyApp());
}

// -------------------------------------------------------------------
// CAMBIO IMPORTANTE: MyApp AHORA ES STATEFULWIDGET
// -------------------------------------------------------------------

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
    // Ejecutamos la verificación de pánico al arrancar la UI
    _setupInteractedMessage();
  }

  Future<void> _setupInteractedMessage() async {
    // 0. CASO: App iniciada por NOTIFICACIÓN LOCAL (Full Screen Intent o Click)
    final notificationAppLaunchDetails = 
          await NotificationService().flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    
    if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
       final payload = notificationAppLaunchDetails!.notificationResponse?.payload;
       if (payload != null) {
         try {
           debugPrint("💀 [MAIN-LOCAL] App iniciada por notificación local. Payload: $payload");
           final data = jsonDecode(payload);
           if (data is Map<String, dynamic> && data['type'] == 'PANIC_ALERT') {
             debugPrint("🚨 [MAIN-LOCAL] Detectado pánico local. Navegando...");
             _navigateToPanic(data);
             return; // Prioridad al local, ya que es el intent directo
           }
         } catch (e) {
           debugPrint("⚠️ Error al parsear payload local: $e");
         }
       }
    }

    // 1. CASO: App estaba CERRADA y se abrió por la alerta (Firebase Remote)
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      debugPrint("💀 [MAIN] App iniciada con mensaje: ${initialMessage.data}");
      if (initialMessage.data['type'] == 'PANIC_ALERT') {
        // Encontramos una alerta de pánico al arrancar.
        // Esperamos un momento para que el Navigator se monte y luego forzamos la pantalla.
        _navigateToPanic(initialMessage.data);
      }
    }

    // 2. CASO: App estaba en segundo plano y se abrió al tocar notificación
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data['type'] == 'PANIC_ALERT') {
        _navigateToPanic(message.data);
      }
    });
    
    // 3. CASO: App ya abierta (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
       if (message.data['type'] == 'PANIC_ALERT') {
         // Si es una alerta CRÍTICA (Pánico), interrumpimos.
         // Si es Auxilio, dejamos que la notificación local maneje el aviso (sin navegar solo).
         if (message.data['alert_type'] == 'panic') {
            _navigateToPanic(message.data);
         }
       }
    });
  }

  Future<void> _navigateToPanic(Map<String, dynamic> data) async {
    debugPrint("🚨 [NAV] Intentando navegar a Pánico...");

    // 1. Verificar sesión de Supabase
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      debugPrint("🚨 [NAV] No hay sesión activa. Iniciando sesión anónima...");
      try {
        await Supabase.instance.client.auth.signInAnonymously();
        debugPrint("🚨 [NAV] Sesión anónima iniciada con éxito.");
      } catch (e) {
        debugPrint("🚨 [NAV] Error al iniciar sesión anónima: $e");
        // Continuamos de todos modos, la pantalla de pánico podría funcionar sin auth
        // o mostrar lo que pueda.
      }
    } else {
      debugPrint("🚨 [NAV] Sesión activa detectada (Usuario: ${session.user.id}).");
    }
    
    // Usamos un pequeño delay para asegurar que el contexto de Flutter esté listo
    if (!mounted) return;

    Future.delayed(const Duration(milliseconds: 500), () {
      if (navigatorKey.currentState != null) {
        debugPrint("🚨 [NAV] Ejecutando pushAndRemoveUntil...");
        navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => PanicAlertScreen(data: data),
          ),
          (route) => false, // ⚠️ ESTO BORRA EL LOGIN O CUALQUIER OTRA PANTALLA
        );
      } else {
         debugPrint("🚨 [NAV] navigatorKey.currentState es NULL. No se pudo navegar.");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final defaultTheme = LogiaTheme.defaultTheme(); // Asegúrate de tener esta clase o comenta esta línea si da error

    return MaterialApp(
      navigatorKey: navigatorKey, // Usamos la key global
      title: L10n.appTitle(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.blue, // Ajusta a tus colores
        // colorScheme: ... (Tu configuración de tema actual)
        useMaterial3: true,
      ),
      supportedLocales: const [
        Locale('es', 'MX'),
        Locale('es', ''),
        Locale('en', 'US'),
        Locale('en', ''),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
      },
    );
  }
}

// Clase dummy para que compile si no me pasaste el archivo theme
// Bórrala si ya tienes LogiaTheme importado
class LogiaTheme {
  static dynamic defaultTheme() => _MockTheme();
}
class _MockTheme {
  get primaryColor => Colors.blue;
  get secondaryColor => Colors.amber;
}