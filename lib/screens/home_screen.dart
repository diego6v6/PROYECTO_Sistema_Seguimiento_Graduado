import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../controllers/preferences_controller.dart';
import '../widgets/status_banner.dart';

import 'profile_screen.dart';
import 'surveys_screen.dart';
import 'history_screen.dart';
import 'recommendations_screen.dart';
import 'survey_results_screen.dart';
import 'admin_recommendations_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _cargandoRol = true;
  bool _esAdministrador = false;

  @override
  void initState() {
    super.initState();
    _obtenerRolUsuario();
  }

  // ==========================================================================
  // OBTENER ROL DEL USUARIO
  // ==========================================================================

  Future<void> _obtenerRolUsuario() async {
    try {
      final supabase = Supabase.instance.client;

      final usuario = supabase.auth.currentUser;

      if (usuario == null) {
        if (mounted) {
          setState(() {
            _cargandoRol = false;
            _esAdministrador = false;
          });
        }

        return;
      }

      final resultado = await supabase.rpc(
        'obtener_rol_usuario',
      );

      if (!mounted) {
        return;
      }

      final rol = resultado?.toString().toUpperCase();

      setState(() {
        _esAdministrador = rol == 'SUPER_ADMIN' || rol == 'ADMINISTRADOR';

        _cargandoRol = false;
      });
    } catch (e) {
      debugPrint(
        'Error al obtener rol del usuario: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _cargandoRol = false;
        _esAdministrador = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfig>();
    final prefs = context.watch<PreferencesController>();

    final name = prefs.studentName.isEmpty ? 'Graduado' : prefs.studentName;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Seguimiento al Graduado',
        ),
        actions: [
          if (config.useSupabase)
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();

                if (!mounted) {
                  return;
                }

                setState(() {
                  _esAdministrador = false;
                });
              },
              icon: const Icon(
                Icons.logout,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          StatusBanner(
            demoMode: !config.useSupabase,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(
                20,
              ),
              children: [
                _WelcomeSection(
                  name: name,
                ),

                const SizedBox(
                  height: 24,
                ),

                const _SystemInformationCard(),

                const SizedBox(
                  height: 24,
                ),

                Text(
                  'Menú principal',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),

                const SizedBox(
                  height: 12,
                ),

                // ============================================================
                // 1. MI PERFIL
                // ============================================================

                _MenuCard(
                  icon: Icons.person_outline,
                  title: '1. Mi perfil',
                  subtitle:
                      'Consulta y actualiza tus datos personales, académicos y profesionales.',
                  color: Colors.blue,
                  onTap: () {
                    _abrirPantalla(
                      context,
                      const ProfileScreen(),
                    );
                  },
                ),

                // ============================================================
                // 2. ENCUESTAS
                // ============================================================

                _MenuCard(
                  icon: Icons.assignment_outlined,
                  title: '2. Encuestas',
                  subtitle:
                      'Consulta las encuestas disponibles para los graduados.',
                  color: Colors.green,
                  onTap: () {
                    _abrirPantalla(
                      context,
                      const SurveysScreen(),
                    );
                  },
                ),

                // ============================================================
                // 3. RESPONDER ENCUESTA
                // ============================================================

                _MenuCard(
                  icon: Icons.edit_note_outlined,
                  title: '3. Responder encuesta',
                  subtitle: 'Completa las encuestas disponibles.',
                  color: Colors.orange,
                  onTap: () {
                    _abrirPantalla(
                      context,
                      const SurveysScreen(),
                    );
                  },
                ),

                // ============================================================
                // 4. HISTORIAL
                // ============================================================

                _MenuCard(
                  icon: Icons.history,
                  title: '4. Historial',
                  subtitle:
                      'Consulta las encuestas que has respondido anteriormente.',
                  color: Colors.purple,
                  onTap: () {
                    _abrirPantalla(
                      context,
                      const HistoryScreen(),
                    );
                  },
                ),

                // ============================================================
                // 5. RECOMENDACIONES
                // ============================================================

                _MenuCard(
                  icon: Icons.lightbulb_outline,
                  title: '5. Recomendaciones',
                  subtitle:
                      'Envía sugerencias y consulta el estado de tus recomendaciones.',
                  color: Colors.amber.shade800,
                  onTap: () {
                    _abrirPantalla(
                      context,
                      const RecommendationsScreen(),
                    );
                  },
                ),

                // ============================================================
                // 6. RESULTADOS DE ENCUESTAS
                // SOLO SUPER_ADMIN Y ADMINISTRADOR
                // ============================================================

                if (!_cargandoRol && _esAdministrador)
                  _MenuCard(
                    icon: Icons.bar_chart_outlined,
                    title: '6. Resultados de encuestas',
                    subtitle:
                        'Consulta los resultados de las encuestas mediante gráficos estadísticos.',
                    color: Colors.indigo,
                    onTap: () {
                      _abrirPantalla(
                        context,
                        const SurveyResultsScreen(),
                      );
                    },
                  ),

                // ============================================================
                // 7. GESTIÓN DE RECOMENDACIONES
                // SOLO SUPER_ADMIN Y ADMINISTRADOR
                // ============================================================

                if (!_cargandoRol && _esAdministrador) ...[
                  const SizedBox(
                    height: 4,
                  ),
                  _MenuCard(
                    icon: Icons.admin_panel_settings_outlined,
                    title: '7. Gestión de recomendaciones',
                    subtitle:
                        'Consulta, responde y administra las recomendaciones enviadas por los graduados.',
                    color: Colors.red.shade700,
                    onTap: () {
                      _abrirPantalla(
                        context,
                        const AdminRecommendationsScreen(),
                      );
                    },
                  ),
                ],

                const SizedBox(
                  height: 20,
                ),

                if (config.useSupabase) const _SecurityInformationCard(),

                const SizedBox(
                  height: 30,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // NAVEGACIÓN
  // ==========================================================================

  void _abrirPantalla(
    BuildContext context,
    Widget pantalla,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => pantalla,
      ),
    );
  }
}

// ============================================================================
// SECCIÓN DE BIENVENIDA
// ============================================================================

class _WelcomeSection extends StatelessWidget {
  const _WelcomeSection({
    required this.name,
  });

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hola, $name',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(
          height: 6,
        ),
        Text(
          'Bienvenido al Sistema de Seguimiento a Graduados.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(
          height: 12,
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.school_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(
                width: 7,
              ),
              Text(
                'Sistema de Graduados',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// INFORMACIÓN DEL SISTEMA
// ============================================================================

class _SystemInformationCard extends StatelessWidget {
  const _SystemInformationCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.school_outlined,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(
              width: 14,
            ),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seguimiento al Graduado',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  Text(
                    'Sistema de seguimiento de graduados de la carrera de Ingeniería Informática.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// INFORMACIÓN DE SEGURIDAD
// ============================================================================

class _SecurityInformationCard extends StatelessWidget {
  const _SecurityInformationCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.withOpacity(0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.security_outlined,
              color: Colors.green.shade700,
            ),
            const SizedBox(
              width: 12,
            ),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Conexión segura',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(
                    height: 4,
                  ),
                  Text(
                    'La aplicación está conectada al sistema de autenticación y base de datos.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TARJETA DEL MENÚ
// ============================================================================

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          child: Row(
            children: [
              // ============================================================
              // ICONO
              // ============================================================

              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(
                    0.12,
                  ),
                  borderRadius: BorderRadius.circular(
                    14,
                  ),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 26,
                ),
              ),

              const SizedBox(
                width: 14,
              ),

              // ============================================================
              // TEXTO
              // ============================================================

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              // ============================================================
              // FLECHA
              // ============================================================

              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade600,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
