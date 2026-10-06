import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/servicio_roles.dart';
import '../../services/servicio_panel_administracion.dart';
import '../pantalla_recomendaciones_administracion.dart';
import '../pantalla_crear_encuesta.dart';
import '../pantalla_resultados_encuestas.dart';

// Si ya tienes estas pantallas creadas, descomenta/importa sus archivos.
// import '../admin_role_management_screen.dart';
// import '../admin_graduates_screen.dart';
// import '../admin_audit_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<Map<String, dynamic>> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;

    final roleService = RoleService(client);
    final role = await roleService.currentRole();

    // El administrador actual del sistema es exclusivamente
    // SUPER_ADMIN.
    if (role != 'SUPER_ADMIN') {
      throw StateError(
        'Tu cuenta no tiene acceso al área administrativa.',
      );
    }

    return AdminDashboardService(client).load();
  }

  Future<void> _reload() async {
    setState(() {
      _data = _load();
    });

    try {
      await _data;
    } catch (_) {
      // El FutureBuilder mostrará el error.
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel administrativo'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error.toString(),
              onRetry: _reload,
            );
          }

          final data = snapshot.data ?? <String, dynamic>{};

          final total = _number(data['total_graduados']);
          final completed = _number(data['graduados_completaron']);
          final pending = _number(data['graduados_pendientes']);

          final participation = total == 0 ? 0.0 : completed * 100 / total;

          final surveys = _maps(data['por_encuesta']);
          final byGraduationYear = _maps(data['por_anio_egreso']);
          final byDepartment = _maps(data['por_departamento']);
          final answerDistribution = _maps(data['distribucion_respuestas']);

          final totalSurveys = _number(data['total_encuestas']);

          final activeSurveys = _number(data['encuestas_activas']);

          final totalResponses = _number(data['total_respuestas']);

          final totalRecommendations = _number(data['total_recomendaciones']);

          final pendingRecommendations =
              _number(data['recomendaciones_pendientes']);

          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;

              return RefreshIndicator(
                onRefresh: _reload,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(
                    wide ? 28 : 16,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 1250,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HeaderSection(
                            onRefresh: _reload,
                          ),

                          const SizedBox(height: 22),

                          // ==================================================
                          // INDICADORES PRINCIPALES
                          // ==================================================

                          _SectionTitle(
                            title: 'Resumen general',
                            icon: Icons.dashboard_outlined,
                          ),

                          const SizedBox(height: 12),

                          Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: [
                              _StatCard(
                                title: 'Total graduados',
                                value: '$total',
                                icon: Icons.school_outlined,
                                color: Colors.blue,
                                width: wide
                                    ? 285
                                    : (constraints.maxWidth - 48) / 2,
                              ),
                              _StatCard(
                                title: 'Respondieron',
                                value: '$completed',
                                icon: Icons.task_alt,
                                color: Colors.teal,
                                width: wide
                                    ? 285
                                    : (constraints.maxWidth - 48) / 2,
                              ),
                              _StatCard(
                                title: 'Pendientes',
                                value: '$pending',
                                icon: Icons.pending_actions,
                                color: Colors.orange,
                                width: wide
                                    ? 285
                                    : (constraints.maxWidth - 48) / 2,
                              ),
                              _StatCard(
                                title: 'Participación',
                                value: '${participation.toStringAsFixed(1)}%',
                                icon: Icons.pie_chart_outline,
                                color: Colors.purple,
                                width: wide
                                    ? 285
                                    : (constraints.maxWidth - 48) / 2,
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: [
                              _StatCard(
                                title: 'Encuestas',
                                value: '$totalSurveys',
                                icon: Icons.assignment_outlined,
                                color: Colors.indigo,
                                width: wide
                                    ? 285
                                    : (constraints.maxWidth - 48) / 2,
                              ),
                              _StatCard(
                                title: 'Encuestas activas',
                                value: '$activeSurveys',
                                icon: Icons.play_circle_outline,
                                color: Colors.green,
                                width: wide
                                    ? 285
                                    : (constraints.maxWidth - 48) / 2,
                              ),
                              _StatCard(
                                title: 'Respuestas',
                                value: '$totalResponses',
                                icon: Icons.question_answer_outlined,
                                color: Colors.cyan,
                                width: wide
                                    ? 285
                                    : (constraints.maxWidth - 48) / 2,
                              ),
                              _StatCard(
                                title: 'Recomendaciones',
                                value: '$totalRecommendations',
                                icon: Icons.recommend_outlined,
                                color: Colors.deepOrange,
                                width: wide
                                    ? 285
                                    : (constraints.maxWidth - 48) / 2,
                              ),
                            ],
                          ),

                          const SizedBox(height: 22),

                          // ==================================================
                          // PARTICIPACIÓN
                          // ==================================================

                          _ChartCard(
                            title: 'Participación de graduados',
                            icon: Icons.pie_chart_outline,
                            child: _ParticipationChart(
                              completed: completed,
                              pending: pending,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ==================================================
                          // ENCUESTAS
                          // ==================================================

                          _ChartCard(
                            title: 'Encuestas completadas por encuesta',
                            icon: Icons.bar_chart_outlined,
                            child: _SurveyBars(
                              rows: surveys,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ==================================================
                          // AÑO DE EGRESO
                          // ==================================================

                          if (byGraduationYear.isNotEmpty) ...[
                            _ChartCard(
                              title: 'Graduados por año de egreso',
                              icon: Icons.calendar_month_outlined,
                              child: _SimpleBars(
                                rows: byGraduationYear,
                                labelKey: 'etiqueta',
                                valueKey: 'cantidad',
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // ==================================================
                          // DEPARTAMENTO
                          // ==================================================

                          if (byDepartment.isNotEmpty) ...[
                            _ChartCard(
                              title: 'Graduados por departamento',
                              icon: Icons.location_on_outlined,
                              child: _SimpleBars(
                                rows: byDepartment,
                                labelKey: 'etiqueta',
                                valueKey: 'cantidad',
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // ==================================================
                          // RESPUESTAS
                          // ==================================================

                          if (answerDistribution.isNotEmpty) ...[
                            _ChartCard(
                              title:
                                  'Distribución de respuestas seleccionables',
                              icon: Icons.poll_outlined,
                              child: _SimpleBars(
                                rows: answerDistribution,
                                labelKey: 'etiqueta',
                                valueKey: 'cantidad',
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // ==================================================
                          // RECOMENDACIONES
                          // ==================================================

                          _RecommendationSummary(
                            total: totalRecommendations,
                            pending: pendingRecommendations,
                            onOpen: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AdminRecommendationsScreen(),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 24),

                          // ==================================================
                          // ADMINISTRACIÓN
                          // ==================================================

                          _SectionTitle(
                            title: 'Administración',
                            icon: Icons.admin_panel_settings_outlined,
                          ),

                          const SizedBox(height: 12),

                          _AdminActionsGrid(
                            onCreateSurvey: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CreateSurveyScreen(),
                                ),
                              );
                            },
                            onSurveyResults: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SurveyResultsScreen(),
                                ),
                              );
                            },
                            onRecommendations: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AdminRecommendationsScreen(),
                                ),
                              );
                            },
                            onRoles: () {
                              _showComingSoon(
                                context,
                                'Gestión de roles',
                                'Aquí se integrará la pantalla para que el SUPER_ADMIN pueda administrar los roles de los usuarios.',
                              );
                            },
                            onGraduates: () {
                              _showComingSoon(
                                context,
                                'Gestión de graduados',
                                'Aquí se integrará la gestión de perfiles y datos de graduados.',
                              );
                            },
                            onAudit: () {
                              _showComingSoon(
                                context,
                                'Auditoría',
                                'Aquí se integrará el registro de acciones administrativas.',
                              );
                            },
                          ),

                          const SizedBox(height: 30),

                          // ==================================================
                          // SEGURIDAD
                          // ==================================================

                          _SecurityNotice(),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showComingSoon(
    BuildContext context,
    String title,
    String description,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(description),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }
}

// ================================================================
// HEADER
// ================================================================

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.onRefresh,
  });

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Panel administrativo',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Supervisión y administración del sistema de seguimiento a graduados.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 17,
                      color: Colors.deepPurple,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'SUPER_ADMIN',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Actualizar estadísticas',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

// ================================================================
// SECTION TITLE
// ================================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

// ================================================================
// STAT CARD
// ================================================================

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.width,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 29,
                  color: color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// CHART CARD
// ================================================================

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 250,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// PARTICIPATION CHART
// ================================================================

class _ParticipationChart extends StatelessWidget {
  const _ParticipationChart({
    required this.completed,
    required this.pending,
  });

  final int completed;
  final int pending;

  @override
  Widget build(BuildContext context) {
    if (completed + pending == 0) {
      return const _EmptyChart();
    }

    return PieChart(
      PieChartData(
        centerSpaceRadius: 45,
        sectionsSpace: 3,
        sections: [
          PieChartSectionData(
            value: completed.toDouble(),
            title: 'Completaron\n$completed',
            color: Colors.teal,
            radius: 90,
            titleStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          PieChartSectionData(
            value: pending.toDouble(),
            title: 'Pendientes\n$pending',
            color: Colors.orange,
            radius: 90,
            titleStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// SURVEY BAR CHART
// ================================================================

class _SurveyBars extends StatelessWidget {
  const _SurveyBars({
    required this.rows,
  });

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyChart();
    }

    return BarChart(
      BarChartData(
        barGroups: [
          for (var i = 0; i < rows.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: _number(
                    rows[i]['completadas'],
                  ).toDouble(),
                  color: Theme.of(context).colorScheme.primary,
                  width: 22,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(
              showTitles: false,
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(
              showTitles: false,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 58,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();

                if (i < 0 || i >= rows.length) {
                  return const SizedBox.shrink();
                }

                return SideTitleWidget(
                  meta: meta,
                  child: SizedBox(
                    width: 75,
                    child: Text(
                      '${rows[i]['titulo']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 9,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: false,
        ),
        gridData: const FlGridData(
          show: true,
          drawVerticalLine: false,
        ),
      ),
    );
  }
}

// ================================================================
// SIMPLE BARS
// ================================================================

class _SimpleBars extends StatelessWidget {
  const _SimpleBars({
    required this.rows,
    required this.labelKey,
    required this.valueKey,
  });

  final List<Map<String, dynamic>> rows;
  final String labelKey;
  final String valueKey;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyChart();
    }

    final maxValue = rows.map((e) => _number(e[valueKey])).fold<int>(
          1,
          (a, b) => a > b ? a : b,
        );

    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        final value = _number(row[valueKey]);

        return Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 5,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 125,
                child: Text(
                  '${row[labelKey]}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: LinearProgressIndicator(
                  value: maxValue == 0 ? 0 : value / maxValue,
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 35,
                child: Text(
                  '$value',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ================================================================
// RECOMMENDATION SUMMARY
// ================================================================

class _RecommendationSummary extends StatelessWidget {
  const _RecommendationSummary({
    required this.total,
    required this.pending,
    required this.onOpen,
  });

  final int total;
  final int pending;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.deepOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.recommend_outlined,
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recomendaciones',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$total registradas · $pending pendientes de revisión',
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: onOpen,
              child: const Text('Gestionar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// ADMIN ACTIONS
// ================================================================

class _AdminActionsGrid extends StatelessWidget {
  const _AdminActionsGrid({
    required this.onCreateSurvey,
    required this.onSurveyResults,
    required this.onRecommendations,
    required this.onRoles,
    required this.onGraduates,
    required this.onAudit,
  });

  final VoidCallback onCreateSurvey;
  final VoidCallback onSurveyResults;
  final VoidCallback onRecommendations;
  final VoidCallback onRoles;
  final VoidCallback onGraduates;
  final VoidCallback onAudit;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _AdminActionButton(
          label: 'Resultados',
          icon: Icons.bar_chart,
          onPressed: onSurveyResults,
        ),
        _AdminActionButton(
          label: 'Crear encuesta',
          icon: Icons.add_chart,
          onPressed: onCreateSurvey,
        ),
        _AdminActionButton(
          label: 'Recomendaciones',
          icon: Icons.recommend,
          onPressed: onRecommendations,
        ),
        _AdminActionButton(
          label: 'Gestión de roles',
          icon: Icons.admin_panel_settings,
          onPressed: onRoles,
          highlighted: true,
        ),
        _AdminActionButton(
          label: 'Graduados',
          icon: Icons.school_outlined,
          onPressed: onGraduates,
        ),
        _AdminActionButton(
          label: 'Auditoría',
          icon: Icons.history,
          onPressed: onAudit,
        ),
      ],
    );
  }
}

class _AdminActionButton extends StatelessWidget {
  const _AdminActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.highlighted = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          side: BorderSide(
            color: highlighted
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        icon: Icon(icon),
        label: Text(
          label,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ================================================================
// SECURITY NOTICE
// ================================================================

class _SecurityNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.security_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Las operaciones administrativas sensibles, '
                'como cambios de rol, deben validarse también '
                'en Supabase mediante políticas RLS y funciones '
                'seguras. Ocultar una opción en Flutter no sustituye '
                'la autorización del servidor.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// EMPTY CHART
// ================================================================

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Sin datos disponibles para mostrar.',
      ),
    );
  }
}

// ================================================================
// ERROR STATE
// ================================================================

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 52,
            ),
            const SizedBox(height: 14),
            Text(
              'No se pudieron cargar los datos del dashboard.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// HELPERS
// ================================================================

int _number(dynamic value) {
  if (value is num) {
    return value.toInt();
  }

  return int.tryParse('$value') ?? 0;
}

List<Map<String, dynamic>> _maps(dynamic value) {
  if (value is! List) {
    return const [];
  }

  return value
      .whereType<Map>()
      .map(
        (e) => Map<String, dynamic>.from(e),
      )
      .toList();
}
