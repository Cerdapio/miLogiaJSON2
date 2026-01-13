import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

// --- IMPORTS DE PANTALLAS ---
import 'home_screen.dart';
import 'pago_screen.dart';
import 'documents_screen.dart';
import 'emergencies_screen.dart';
import 'profile_edit_screen.dart';
import 'super_admin_screen.dart'; // Importar la nueva pantalla
import 'radio_create_screen.dart'; 
import 'payment_report_screen.dart';
import 'panic_test_screen.dart'; // Pantalla de prueba de alertas
// Integrated into PagoScreen:
// import 'payment_validator_screen.dart';
// import 'cash_collector_screen.dart';

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

  // Helper para navegar y cerrar el drawer
  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.pop(context); // Cierra el drawer
    Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _getThemeColors();

    // Filtramos los perfiles para excluir el actual
    final availableProfiles = root.user.perfiles_opciones
        .where((p) => p.idLogia != selectedProfile.idLogia || p.idPerfil != selectedProfile.idPerfil)
        .toList();

    return Drawer(
      child: Container(
        color: theme['card'],
        child: Column(
          children: [
            Expanded(
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
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            selectedProfile.LogiaNombre,
                            style: TextStyle(color: theme['accent'], fontSize: 20, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${selectedProfile.Tratamiento} ${root.user.Nombre}',
                          style: TextStyle(color: theme['accent'], fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          '${selectedProfile.GradoNombre} | ${selectedProfile.Grupo}',
                          style: TextStyle(color: theme['accent'], fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        )
                      ],
                    ),
                  ),

                  _buildMenuItem(
                    context: context,
                    icon: Icons.home,
                    text: 'Inicio / Mi Perfil',
                    theme: theme,
                    onTap: () => _navigateTo(context, HomeScreen(root: root, selectedProfile: selectedProfile)),
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.person_outline,
                    text: 'Editar Perfil',
                    theme: theme,
                    onTap: () => _navigateTo(context, ProfileEditScreen(root: root, selectedProfile: selectedProfile)),
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.local_hospital,
                    text: 'Contactos Emergencia',
                    theme: theme,
                    onTap: () => _navigateTo(context, EmergenciesScreen(root: root, selectedProfile: selectedProfile)),
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.monetization_on,
                    text: 'Mis Pagos',
                    theme: theme,
                    onTap: () => _navigateTo(context, PagoScreen(root: root, selectedProfile: selectedProfile)),
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.folder_open,
                    text: 'Mis Documentos',
                    theme: theme,
                    onTap: () => _navigateTo(context, DocumentsScreen(root: root, selectedProfile: selectedProfile)),
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.upload_file,
                    text: 'Reportar Transferencia',
                    theme: theme,
                    onTap: () => _navigateTo(context, PaymentReportScreen(root: root, selectedProfile: selectedProfile)),
                  ),

                  // --- OPCIÓN SECRETARIO (Perfil 5) ---
                  if (selectedProfile.idPerfil == 5)
                    _buildMenuItem(
                      context: context,
                      icon: Icons.broadcast_on_personal,
                      text: 'Emitir Radio',
                      theme: theme,
                      onTap: () => _navigateTo(context, RadioCreateScreen(root: root, selectedProfile: selectedProfile)),
                    ),

                  // --- OPCIÓN TESORERO (Perfil 7) ---
                  if (selectedProfile.idPerfil == 7)
                    ExpansionTile(
                      leading: Icon(Icons.account_balance, color: theme['accent']),
                      title: Text(
                        'Tesorería',
                        style: TextStyle(color: theme['text'], fontWeight: FontWeight.w500),
                      ),
                      children: [
                        _buildMenuItem(
                          context: context,
                          icon: Icons.fact_check,
                          text: 'Validar Transferencias',
                          theme: theme,
                          onTap: () => _navigateTo(context, PagoScreen(root: root, selectedProfile: selectedProfile, initialTab: 1)),
                        ),
                        _buildMenuItem(
                          context: context,
                          icon: Icons.point_of_sale,
                          text: 'Cobro en Logia (Efectivo)',
                          theme: theme,
                          onTap: () => _navigateTo(context, PagoScreen(root: root, selectedProfile: selectedProfile, initialTab: 2)),
                        ),
                      ],
                    ),

                  // --- OPCIÓN DE PRUEBA DE PÁNICO (Solo en desarrollo) ---
                  _buildMenuItem(
                    context: context,
                    icon: Icons.bug_report,
                    text: '🧪 Prueba de Pánico',
                    theme: theme,
                    onTap: () => _navigateTo(context, const PanicTestScreen()),
                  ),

                  // --- CAMBIAR PERFIL (ExpansionTile) ---
                  if (availableProfiles.isNotEmpty)
                    ExpansionTile(
                      leading: Icon(Icons.swap_horiz, color: theme['accent']),
                      title: Text(
                        'Cambiar Perfil',
                        style: TextStyle(color: theme['text'], fontWeight: FontWeight.w500),
                      ),
                      children: availableProfiles.map((profile) {
                        return ListTile(
                          contentPadding: const EdgeInsets.only(left: 30, right: 10),
                          leading: Icon(Icons.account_circle, color: theme['text']?.withOpacity(0.7)),
                          title: Text(profile.LogiaNombre, style: TextStyle(color: theme['text'], fontSize: 14)),
                          subtitle: Text(
                            profile.idPerfil == 0 ? 'Super Admin' : '${profile.GradoNombre}',
                            style: TextStyle(color: theme['text']?.withOpacity(0.6), fontSize: 12),
                          ),
                          onTap: () {
                            Navigator.pop(context); // Cierra el drawer
                            if (profile.idPerfil == 0) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SuperAdminScreen(root: root, selectedProfile: profile),
                                ),
                              );
                            } else {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HomeScreen(root: root, selectedProfile: profile),
                                ),
                              );
                            }
                          },
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            // --- CERRAR SESIÓN (Pegado al fondo) ---
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
            const SizedBox(height: 10), // Margen inferior opcional
          ],
        ),
      ),
    );
  }

  // --- HELPER ---
  Widget _buildMenuItem({
    required BuildContext context,
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
      onTap: onTap, // Llama directamente al callback que ya contiene la navegación
    );
  }
}