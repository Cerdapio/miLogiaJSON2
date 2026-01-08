import 'package:flutter/material.dart';

// ----------------------------------------------------
// CONSTANTES DE SUPABASE
// ----------------------------------------------------

// DEBES REEMPLAZAR ESTOS VALORES CON TUS CLAVES REALES DE SUPABASE
const String supabaseUrl =  'https://ptylwwjhvoznaivzfpsa.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB0eWx3d2podm96bmFpdnpmcHNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI5NjMxNzksImV4cCI6MjA3ODUzOTE3OX0.xIa5OR6twP-XYUk5-wo9YEEUrD7nx4J_V10M6mGS9os'; // 
const String rpcFunction = 'sp_catcusuarios_v2';
// ----------------------------------------------------
// MODELO DE TEMA DINÁMICO
// ----------------------------------------------------

// Clase que define la apariencia (colores) de un perfil de Logia
class LogiaTheme {
  final String nombre;
  final Color primaryColor;   // Color principal (ej: Negro, Azul Marino)
  final Color secondaryColor; // Color secundario (ej: Dorado, Plateado, Rojo)
  final Color accentColor;    // Color de acento para botones/badges
  final Color backgroundColor; // Color de fondo del Scaffold

  LogiaTheme({
    required this.nombre,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.backgroundColor,
  });

  // Tema por defecto (para Login y si no hay perfil activo)
  static LogiaTheme defaultTheme() {
    return LogiaTheme(
      nombre: 'Default',
      primaryColor: const Color(0xFF000000), // Negro
      secondaryColor: const Color(0xFFDAA520), // Dorado
      accentColor: const Color(0xFF8B0000), // Rojo Oscuro
      backgroundColor: const Color(0xFFF0F0F0), // Gris claro
    );
  }

  // Ejemplo de un tema para un tipo de Logia (puedes añadir más)
  static LogiaTheme blueTheme() {
    return LogiaTheme(
      nombre: 'Blue Lodge',
      primaryColor: const Color(0xFF192F50), // Azul Marino Oscuro
      secondaryColor: const Color(0xFFD4AF37), // Dorado
      accentColor: Colors.red.shade700,
      backgroundColor: const Color(0xFFF8F8F8),
    );
  }
  
  // Mapeo simple de ID a Tema
  static LogiaTheme getThemeById(int id) {
    switch (id) {
      case 1:
        return LogiaTheme.blueTheme();
      case 2:
        return LogiaTheme(
          nombre: 'Red Lodge',
          primaryColor: const Color(0xFF8B0000), // Rojo Oscuro
          secondaryColor: Colors.white,
          accentColor: Colors.black,
          backgroundColor: const Color(0xFFEEEEEE),
        );
      default:
        return LogiaTheme.defaultTheme();
    }
  }
}