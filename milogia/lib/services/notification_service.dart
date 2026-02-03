import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:convert'; // Para serializar el payload en JSON

import '../models/user_model.dart';
import 'package:milogia/config/l10n.dart';

import 'package:milogia/screens/panic_alert_screen.dart';
import 'package:milogia/main.dart'; // Para acceder al navigatorKey
import 'package:firebase_core/firebase_core.dart'; // NUEVO: Importar Firebase Core
import 'package:milogia/firebase_options.dart'; // NUEVO: Importar opciones generadas
import 'package:milogia/config/auth_config.dart'; // Para credentials de Supabase
// import 'package:audioplayers/audioplayers.dart'; // Para el Alarm Stream (Si se agrega la dependencia)

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Inicializamos Firebase para el isolate del background
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inicializar Supabase también para el isolate de background
  // Es necesario porque NotificationService accede a Supabase.instance
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: true,
    );
   debugPrint("🔥 [BACKGROUND HANDLER] Supabase inicializado correctamente.");
  } catch (e) {
    debugPrint("⚠️ [BACKGROUND HANDLER] Supabase ya estaba inicializado o error: $e");
  }
  
  debugPrint("🔥🔥🔥 [BACKGROUND HANDLER] Manejando mensaje en background: ${message.messageId}");
  debugPrint("🔥 [BACKGROUND HANDLER] Data: ${message.data}");
  debugPrint("🔥 [BACKGROUND HANDLER] Notification: ${message.notification?.toMap()}");
  
  if (message.data['type'] == 'PANIC_ALERT') {
    debugPrint("🚨 [BACKGROUND HANDLER] ¡ALERTA DE PÁNICO DETECTADA!");
    final service = NotificationService();
    // Re-inicializar local notifications para este isolate
    await service._initForBackground();
    debugPrint("🚨 [BACKGROUND HANDLER] Servicio inicializado, mostrando notificación...");
    
    // 1. Mostrar notificación de pantalla completa
    await service._showPanicFullScreenNotification(message.data);
    debugPrint("🚨 [BACKGROUND HANDLER] Notificación mostrada exitosamente");
    
    // Nota: navigatorKey no funciona en background isolate. 
    // La app saltará al frente por el FullScreenIntent.
  } else {
    debugPrint("ℹ️ [BACKGROUND HANDLER] Mensaje no es PANIC_ALERT, tipo: ${message.data['type']}");
  }
}

void _handlePanicPayload(Map<String, dynamic> data) {
  // 1. LÓGICA DE SONIDO (COMENTADA POR AHORA)
  /*
  final player = AudioPlayer();
  player.setAudioContext(AudioContext(
    android: AudioContextAndroid(
      usageType: AndroidUsageType.alarm, // CLAVE: Canal de Alarma
      contentType: AndroidContentType.sonification,
      audioFocus: AndroidAudioFocus.gainTransient,
    ),
    ios: AudioContextIOS(category: AVAudioSessionCategory.playback),
  ));
  // await player.play(AssetSource('sounds/alarm.mp3'), volume: 1.0);
  */

  // 2. NAVEGACIÓN A PANTALLA COMPLETA
  // Si la app ya está abierta, navegamos. Si no, el FullScreenIntent se encargará al abrirse.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Usamos la key global definida en main.dart
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (context) => PanicAlertScreen(data: data))
    );
  });
}

class NotificationService {
  static final NotificationService _notificationService = NotificationService._internal();
  factory NotificationService() {
    return _notificationService;
  }
  NotificationService._internal();
  
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> init() async {
    // 1. Configuración Local (Existente)
    tz.initializeTimeZones();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_notification'); // APUNTAR EXPLÍCITAMENTE A MIPMAP
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestSoundPermission: false, 
      requestBadgePermission: false, 
      requestAlertPermission: false,
    );
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    // Configurar callback para cuando se toca la notificación local
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('🔔 [LOCAL] Click en notificación local. Payload: ${response.payload}');
        if (response.payload != null) {
          try {
             // Intentamos decodificar si es JSON
             final data = jsonDecode(response.payload!);
             if (data is Map<String, dynamic> && data['type'] == 'PANIC_ALERT') {
               debugPrint('🚨 [LOCAL] Detectado payload de pánico. Navegando...');
               _handlePanicPayload(data);
             }
          } catch (e) {
            // Si no es JSON o falla, verificamos si es el string simple 'PANIC_ALERT' (legacy)
            if (response.payload == 'PANIC_ALERT') {
               // En este caso no tenemos data, pero intentamos navegar vacío o manejarlo
               debugPrint('🚨 [LOCAL] Payload simple detectado. Navegando sin data extra...');
               // _handlePanicPayload({}); // Riesgoso sin data, mejor omitir o pedir recarga
            }
          }
        }
      },
    );

    // --- NUEVO: Crear Canal de Alerta Crítica para Pánico ---
    final AndroidNotificationChannel panicChannel = AndroidNotificationChannel(
      'panic_channel_critical', // ID
      L10n.panicChannel(), // Nombre
      description: L10n.panicChannelDesc(),
      importance: Importance.max,
      playSound: false, // Lo manejamos nosotros manualmente para bypass silencio
      enableVibration: true,
      showBadge: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(panicChannel);

    // --- NUEVO: Solicitar permisos en Android 13+ ---
    if (!kIsWeb) { // Solo ejecutar en plataformas móviles
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        // Esto mostrará un diálogo al usuario la primera vez.
        await androidImplementation.requestNotificationsPermission();
      }
    }

    // 2. Configuración de Firebase (Nueva)
    await _initFirebase();
  }

  Future<void> _initFirebase() async {
    // Solicitar permisos para notificaciones remotas (importante en iOS)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true, // NUEVO: Para iOS
    );

    debugPrint('Permiso de notificaciones: ${settings.authorizationStatus}');

    // Obtener y mostrar el FCM token para pruebas
    String? fcmToken = await _firebaseMessaging.getToken();
    debugPrint('📱📱📱 FCM TOKEN: $fcmToken');
    debugPrint('📱📱📱 Copia este token para enviar mensajes de prueba desde Supabase');

    // Escuchar mensajes en primer plano (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📱 [FOREGROUND] Mensaje recibido en foreground');
      debugPrint('📱 [FOREGROUND] Data: ${message.data}');
      debugPrint('📱 [FOREGROUND] Notification: ${message.notification?.toMap()}');
      
      if (message.data['type'] == 'PANIC_ALERT') {
        debugPrint('🚨 [FOREGROUND] ¡ALERTA DE PÁNICO DETECTADA!');
        // Solo mostramos la notificación. La navegación automática la decide main.dart
        // si es una alerta crítica.
        _showPanicFullScreenNotification(message.data);
      } else if (message.notification != null) {
        debugPrint('ℹ️ [FOREGROUND] Mostrando notificación remota normal');
        _showRemoteNotification(message);
      }
    });

    // Registrar el manejador de segundo plano
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Manejar cuando la app se abre desde una notificación (Background -> Foreground)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
       debugPrint('🔔 [OPENED APP] App abierta desde notificación');
       debugPrint('🔔 [OPENED APP] Data: ${message.data}');
       if (message.data['type'] == 'PANIC_ALERT') {
         // La navegación desde background la maneja main.dart
         // debugPrint('🚨 [OPENED APP] Navegando a pantalla de pánico...');
         // _handlePanicPayload(message.data);
       }
    });

    // --- NUEVO: Manejar cuando la app se abre desde un estado CERRADO (Terminated) ---
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('💀 [TERMINATED] App abierta desde estado cerrado por notificación');
        debugPrint('💀 [TERMINATED] Data: ${message.data}');
        if (message.data['type'] == 'PANIC_ALERT') {
          // La navegación inicial la maneja main.dart para evitar race conditions
          /*
          debugPrint('🚨 [TERMINATED] Navegando a pantalla de pánico tras delay...');
          Future.delayed(const Duration(milliseconds: 500), () {
            _handlePanicPayload(message.data);
          });
          */
        }
      } else {
        debugPrint('💀 [TERMINATED] No hay mensaje inicial');
      }
    });
  }

  /// Inicialización mínima para el isolate de background
  Future<void> _initForBackground() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_notification');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  /// Recupera el token FCM actual y lo guarda en la base de datos (Contexto: Logia Actual)
  Future<void> saveTokenToDatabase(int logiaId) async {
    try {
      debugPrint('Intentando guardar token para logia: $logiaId');
      
      // 1. Obtener el token del dispositivo
      String? token = await _firebaseMessaging.getToken();
      
      if (token == null) {
        debugPrint('Error: No se pudo obtener el token FCM.');
        return;
      }
      debugPrint('FCM Token obtenido: $token');

      // 2. Guardar en Supabase (catdUsuario -> fcm_token)
      // Llamamos a la nueva función RPC que usa auth.uid() para seguridad
      await _supabase.rpc('update_user_logia_token', params: {
        'p_fcm_token': token,
        'p_idd_logia': logiaId,
      });
      
      debugPrint('Token FCM sincronizado exitosamente para logia $logiaId');
    } catch (e) {
      debugPrint('Error al guardar token FCM: $e');
    }
  }

  // Método anterior vacío o redundante que vamos a limpiar
  // Método obsoleto eliminado
  // Future<void> createOrUpdateToken() async { ... }

  Future<int?> _getUserIdFromAuth() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;
      
      // Buscamos el idUsuario (int) basado en el auth_uuid (uuid)
      final response = await _supabase
          .from('catcUsuarios')
          .select('idUsuario')
          .eq('auth_uuid', user.id)
          .single();
          
      return response['idUsuario'] as int?;
    } catch (e) {
      debugPrint('Error al obtener idUsuario desde auth_uuid: $e');
      return null;
    }
  }

  /// Muestra una notificación recibida desde FCM
  Future<void> _showRemoteNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      await flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'default_channel_id', // Canal por defecto para mensajes FCM
            L10n.generalChannel(),
            channelDescription: L10n.generalChannelDesc(),
            icon: '@mipmap/ic_notification',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
             presentAlert: true,
             presentBadge: true,
             presentSound: true,
          )
        ),
      );
    }
  }

  Future<void> scheduleBirthdayNotifications(RootModel data, int currentLogiaId) async {
    // Cancela todas las notificaciones anteriores para evitar duplicados.
    await flutterLocalNotificationsPlugin.cancelAll();
    final now = DateTime.now();

    // Iteramos sobre la lista de todos los miembros que vino en el catálogo.
    for (final miembro in data.catalogos.listaLogiasPorUsuario) {
      if (miembro.FechaNacimiento.isEmpty) continue;
      try {
        final birthDate = DateTime.parse(miembro.FechaNacimiento);
        final perfilEnLogia = miembro.perfiles.where((p) => p.idLogia == currentLogiaId).firstOrNull;
        if (perfilEnLogia == null) continue;
        DateTime birthdayThisYear = DateTime(now.year, birthDate.month, birthDate.day, 8); // 8:00 AM
        if (birthdayThisYear.isAfter(now)) {
          int notificationId = (miembro.idUsuario * 10) + 1;
          _scheduleNotification(
            id: notificationId,
            title: L10n.birthdayTitle(),
            body: L10n.birthdayToday(perfilEnLogia.Tratamiento, miembro.Nombre),
            scheduledDate: tz.TZDateTime.from(birthdayThisYear, tz.local),
            logiaId: perfilEnLogia.idLogia,
          );
        }
        DateTime dayBeforeBirthday = birthdayThisYear.subtract(const Duration(days: 1));
        if (dayBeforeBirthday.isAfter(now)) {
          int notificationId = (miembro.idUsuario * 10) + 2;
          _scheduleNotification(
            id: notificationId,
            title: L10n.upcomingBirthdayTitle(),
            body: L10n.birthdayTomorrow(perfilEnLogia.Tratamiento, miembro.Nombre),
            scheduledDate: tz.TZDateTime.from(dayBeforeBirthday, tz.local),
            logiaId: perfilEnLogia.idLogia,
          );
        }
      } catch (e) {
        debugPrint('Error al programar notificación para ${miembro.Nombre}: $e');
      }
    }
  }
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required int logiaId, 
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'birthday_channel_id',
      L10n.birthdayChannel(),
      channelDescription: L10n.birthdayChannelDesc(),
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_notification', // APUNTAR EXPLÍCITAMENTE A MIPMAP
    );
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true, 
      presentBadge: true, 
      presentSound: true,
    );
    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexact, // Cambiado a inexact para mejor compatibilidad con Android 12+
     // uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  /// Muestra una notificación de pánico que despierta la app (Full Screen Intent)
  Future<void> _showPanicFullScreenNotification(Map<String, dynamic> data) async {
    debugPrint('🚨 [SHOW PANIC] Iniciando mostrar notificación de pánico...');
    debugPrint('🚨 [SHOW PANIC] Data recibida: $data');
    
    final isPanic = data['alert_type'] == 'panic';
    final name = data['sender_name'] ?? 'Hermano';
    
    debugPrint('🚨 [SHOW PANIC] isPanic: $isPanic, name: $name');
    
    final androidDetails = AndroidNotificationDetails(
      'panic_channel_critical', // ID del canal de pánico
      L10n.panicChannel(),
      channelDescription: L10n.panicChannelDesc(),
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: isPanic, // CLAVE: Solo lanza la app si es pánico real
      category: AndroidNotificationCategory.alarm,
      enableVibration: true,
      icon: '@mipmap/ic_notification',
      visibility: NotificationVisibility.public,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical, // Alerta Crítica en iOS
    );

    debugPrint('🚨 [SHOW PANIC] Llamando a flutterLocalNotificationsPlugin.show()...');
    
    await flutterLocalNotificationsPlugin.show(
      0, // ID fijo para que solo haya una alerta activa si llegan varias
      isPanic ? L10n.panicAlert() : L10n.assistanceRequest(),
      L10n.needsHelp(name),
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(data), // SERIALIZAR DATA COMPLETA EN EL PAYLOAD
    );
    
    debugPrint('🚨 [SHOW PANIC] ✅ Notificación mostrada exitosamente');
  }

  /// Sends a notification to the Lodge Secretary about a new document request
  Future<void> notifySecretaryRequest(int logiaId, String docName, String userName) async {
    try {
      debugPrint("🔔 Notifying secretary of logia $logiaId about $docName for $userName");
      
      // Note: This requires an Edge Function named 'notify-secretary-request' to be deployed.
      await _supabase.functions.invoke(
        'notify-secretary-request', 
        body: {
          'logiaId': logiaId, 
          'docName': docName, 
          'userName': userName
        },
      );
    } catch (e) {
      debugPrint("Error sending secretary notification: $e");
    }
  }
}
