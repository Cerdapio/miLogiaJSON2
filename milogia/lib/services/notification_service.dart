import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/user_model.dart';

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
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

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
    );

    debugPrint('Permiso de notificaciones: ${settings.authorizationStatus}');

    // Escuchar mensajes en primer plano (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Mensaje recibido en foreground: ${message.notification?.title}');
      
      // Mostrar notificación localmente si la app está abierta
      if (message.notification != null) {
        _showRemoteNotification(message);
      }
    });

    // Manejar cuando la app se abre desde una notificación (Background -> Foreground)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
       debugPrint('App abierta desde notificación: ${message.data}');
       // Aquí podrías navegar a una pantalla específica usando message.data
    });
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
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'default_channel_id', // Canal por defecto para mensajes FCM
            'Avisos Generales',
            channelDescription: 'Notificaciones generales de la aplicación',
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
            title: 'Celebración de Nacimiento',
            body: 'Hoy festejamos el nacimiento del ${perfilEnLogia.Tratamiento} ${miembro.Nombre}',
            scheduledDate: tz.TZDateTime.from(birthdayThisYear, tz.local),
            logiaId: perfilEnLogia.idLogia,
          );
        }
        DateTime dayBeforeBirthday = birthdayThisYear.subtract(const Duration(days: 1));
        if (dayBeforeBirthday.isAfter(now)) {
          int notificationId = (miembro.idUsuario * 10) + 2;
          _scheduleNotification(
            id: notificationId,
            title: 'Próximo Nacimiento',
            body: 'Mañana se celebra el nacimiento del ${perfilEnLogia.Tratamiento} ${miembro.Nombre}',
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
    const androidDetails = AndroidNotificationDetails(
      'birthday_channel_id',
      'Notificaciones de Cumpleaños',
      channelDescription: 'Canal para recordatorios de cumpleaños.',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_notification', // APUNTAR EXPLÍCITAMENTE A MIPMAP
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true, 
      presentBadge: true, 
      presentSound: true,
    );
    const notificationDetails = NotificationDetails(
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

  // --- NUEVA FUNCIÓN PARA PRUEBAS ---
  /// Muestra una notificación de prueba de inmediato.
  Future<void> showTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'birthday_channel_id', // Debe ser el mismo ID de canal que las reales
      'Notificaciones de Cumpleaños',
      channelDescription: 'Canal para recordatorios de cumpleaños.',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_notification', // APUNTAR EXPLÍCITAMENTE A MIPMAP
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      999, // Un ID único para la notificación de prueba
      'Celebración de Nacimiento', // Título real de la notificación
      'Hoy festejamos el nacimiento del Q:.H:. Juan Pérez', // Cuerpo de ejemplo, como en la notificación real
      notificationDetails,
    );
  }
}
