import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

// --- IMPORTS DE PANTALLAS ---
import 'home_screen.dart';
import 'pago_screen.dart';
import 'documents_screen.dart';
import 'emergencies_screen.dart';
// import 'jobs_screen.dart'; 
// import 'profile_edit_screen.dart'; 
import 'profile_edit_screen.dart'; // <--- Añade esta línea
import 'login_screen.dart';

class AppDrawer extends StatelessWidget {
  final RootModel root;
  final PerfilOpcion selectedProfile;

  const AppDrawer({
    super.key, 
    required this.root, 
    required this.selectedProfile
  });

  // --- LÓGICA DE COLORES ---
  Map<String, Color> _getThemeColors() {
    final colores = selectedProfile.colores;

    Color parseHex(String? hex, Color fallback) {
      if (hex == null || hex.isEmpty) return fallback;
      String h = hex.replaceFirst('#', '');
      if (h.length == 6) h = 'FF$h';
      try {
        return Color(int.parse(h, radix: 16));
      } catch (_) {
        return fallback;
      }
    }

    return {
      'bg': parseHex(colores.C1, const Color(0xFFF5F5F5)),
      'text': parseHex(colores.C2, const Color(0xFF222222)),
      'card': parseHex(colores.C3, Colors.white),
      'accent': parseHex(colores.C4, const Color(0xFFDAA520)),
    };
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _getThemeColors();

    return Drawer(
      child: Container(
        color: theme['card'], 
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            // --- ENCABEZADO ---
            DrawerHeader(
              decoration: BoxDecoration(
                color: theme['bg'], 
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Mi Logia App', 
                    style: TextStyle(color: theme['accent'], fontSize: 24, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 8),
                  Text(
                    root.user.Nombre, 
                    style: TextStyle(color: theme['text']?.withOpacity(0.8), fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    selectedProfile.LogiaNombre,
                    style: TextStyle(color: theme['text']?.withOpacity(0.6), fontSize: 12),
                  )
                ],
              ),
            ),

            
            _buildMenuItem(
              context: context, // CORRECCIÓN: Se agrega "context:"
              icon: Icons.home, 
              text: 'Inicio / Mi Perfil', 
              theme: theme,
              onTap: () => _navigateTo(context, HomeScreen(root: root, selectedProfile: selectedProfile)),
            ),
             _buildMenuItem(
              context: context,
              icon: Icons.person_outline, // O el ícono que prefieras
              text: 'Editar Perfil',
              theme: theme,
              onTap: () => _navigateTo(context, ProfileEditScreen(root: root, selectedProfile: selectedProfile)), 
            ),
            _buildMenuItem(
              context: context, // CORRECCIÓN: Se agrega "context:"
              icon: Icons.local_hospital, 
              text: 'Contactos Emergencia', 
              theme: theme,
              onTap: () => _navigateTo(context, EmergenciesScreen(root: root, selectedProfile: selectedProfile)),
            ),
            _buildMenuItem(
              context: context, // CORRECCIÓN: Se agrega "context:"
              icon: Icons.monetization_on, 
              text: 'Mis Pagos', 
              theme: theme,
              onTap: () => _navigateTo(context, PagoScreen(root: root, selectedProfile: selectedProfile)),
            ),
            _buildMenuItem(
              context: context, // CORRECCIÓN: Se agrega "context:"
              icon: Icons.folder_open, 
              text: 'Mis Documentos', 
              theme: theme,
              onTap: () => _navigateTo(context, DocumentsScreen(root: root, selectedProfile: selectedProfile)),
            ),
            const Divider(),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () async {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) {
                   Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPER ---
  // Definición corregida sin duplicados
  Widget _buildMenuItem({
    required BuildContext context,  // Parámetro Nombrado (dentro de las llaves)
    required IconData icon, 
    required String text, 
    required Map<String, Color> theme, 
    required VoidCallback onTap
  }) {
    return ListTile(
      leading: Icon(icon, color: theme['accent']),
      title: Text(
        text, 
        style: TextStyle(color: theme['text'], fontWeight: FontWeight.w500)
      ),
      onTap: () {
        Navigator.pop(context); // Usamos el context pasado para cerrar el drawer
        onTap();
      },
    );
  }
}