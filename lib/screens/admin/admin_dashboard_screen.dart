import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/role_service.dart';
import '../../services/admin_dashboard_service.dart';
import '../admin_recommendations_screen.dart';
import '../create_survey_screen.dart';
import '../survey_results_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final Future<Map<String, dynamic>> _data;
  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;
    final role = await RoleService(client).currentRole();
    if (!RoleService(client).isAdmin(role)) {
      throw StateError('Tu cuenta no tiene acceso al área administrativa.');
    }
    return AdminDashboardService(client).load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Panel administrativo'), actions: [
          IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: () => Supabase.instance.client.auth.signOut(),
              icon: const Icon(Icons.logout)),
        ]),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorState(message: snapshot.error.toString());
            }
            final data = snapshot.data!;
            final total = _number(data['total_graduados']);
            final completed = _number(data['graduados_completaron']);
            final pending = _number(data['graduados_pendientes']);
            final participation = total == 0 ? 0.0 : completed * 100 / total;
            final surveys = _maps(data['por_encuesta']);
            return LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= 850;
              return SingleChildScrollView(
                padding: EdgeInsets.all(wide ? 28 : 16),
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1250),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Resumen del sistema',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium),
                              const SizedBox(height: 6),
                              const Text(
                                  'Indicadores calculados desde los registros actuales de Supabase.'),
                              const SizedBox(height: 22),
                              Wrap(spacing: 14, runSpacing: 14, children: [
                                _StatCard(
                                    title: 'Total graduados',
                                    value: '$total',
                                    icon: Icons.school_outlined,
                                    width: wide
                                        ? 285
                                        : (constraints.maxWidth - 48) / 2),
                                _StatCard(
                                    title: 'Respondieron',
                                    value: '$completed',
                                    icon: Icons.task_alt,
                                    width: wide
                                        ? 285
                                        : (constraints.maxWidth - 48) / 2),
                                _StatCard(
                                    title: 'Pendientes',
                                    value: '$pending',
                                    icon: Icons.pending_actions,
                                    width: wide
                                        ? 285
                                        : (constraints.maxWidth - 48) / 2),
                                _StatCard(
                                    title: 'Participación',
                                    value:
                                        '${participation.toStringAsFixed(1)}%',
                                    icon: Icons.pie_chart_outline,
                                    width: wide
                                        ? 285
                                        : (constraints.maxWidth - 48) / 2),
                              ]),
                              const SizedBox(height: 22),
                              _ChartCard(
                                  title: 'Participación de graduados',
                                  child: _ParticipationChart(
                                      completed: completed, pending: pending)),
                              const SizedBox(height: 16),
                              _ChartCard(
                                  title: 'Encuestas completadas por encuesta',
                                  child: _SurveyBars(rows: surveys)),
                              const SizedBox(height: 16),
                              if (_maps(data['por_anio_egreso'])
                                  .isNotEmpty) ...[
                                _ChartCard(
                                    title: 'Graduados por año de egreso',
                                    child: _SimpleBars(
                                        rows: _maps(data['por_anio_egreso']),
                                        labelKey: 'etiqueta',
                                        valueKey: 'cantidad')),
                                const SizedBox(height: 16),
                              ],
                              if (_maps(data['por_departamento'])
                                  .isNotEmpty) ...[
                                _ChartCard(
                                    title: 'Graduados por departamento',
                                    child: _SimpleBars(
                                        rows: _maps(data['por_departamento']),
                                        labelKey: 'etiqueta',
                                        valueKey: 'cantidad')),
                                const SizedBox(height: 16),
                              ],
                              if (_maps(data['distribucion_respuestas'])
                                  .isNotEmpty) ...[
                                _ChartCard(
                                    title:
                                        'Distribución de respuestas seleccionables',
                                    child: _SimpleBars(
                                        rows: _maps(
                                            data['distribucion_respuestas']),
                                        labelKey: 'etiqueta',
                                        valueKey: 'cantidad')),
                                const SizedBox(height: 16),
                              ],
                              Text('Administración',
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              Wrap(spacing: 12, runSpacing: 12, children: [
                                const _ActionButton(
                                    'Resultados de encuestas',
                                    Icons.bar_chart,
                                    const SurveyResultsScreen()),
                                const _ActionButton(
                                    'Gestión de recomendaciones',
                                    Icons.recommend,
                                    const AdminRecommendationsScreen()),
                                const _ActionButton(
                                    'Crear encuesta',
                                    Icons.add_chart,
                                    const CreateSurveyScreen()),
                              ]),
                            ]))),
              );
            });
          },
        ),
      );
}

int _number(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
List<Map<String, dynamic>> _maps(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : const [];

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.title,
      required this.value,
      required this.icon,
      required this.width});
  final String title, value;
  final IconData icon;
  final double width;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: width,
      child: Card(
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Icon(icon,
                    size: 32, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title),
                      const SizedBox(height: 6),
                      Text(value,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold))
                    ]))
              ]))));
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 18),
            SizedBox(height: 250, child: child)
          ])));
}

class _ParticipationChart extends StatelessWidget {
  const _ParticipationChart({required this.completed, required this.pending});
  final int completed, pending;
  @override
  Widget build(BuildContext context) => completed + pending == 0
      ? const _EmptyChart()
      : PieChart(PieChartData(sections: [
          PieChartSectionData(
              value: completed.toDouble(),
              title: 'Completaron\n$completed',
              color: Colors.teal,
              radius: 90),
          PieChartSectionData(
              value: pending.toDouble(),
              title: 'Pendientes\n$pending',
              color: Colors.orange,
              radius: 90),
        ]));
}

class _SurveyBars extends StatelessWidget {
  const _SurveyBars({required this.rows});
  final List<Map<String, dynamic>> rows;
  @override
  Widget build(BuildContext context) => rows.isEmpty
      ? const _EmptyChart()
      : BarChart(BarChartData(
          barGroups: [
            for (var i = 0; i < rows.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                    toY: _number(rows[i]['completadas']).toDouble(),
                    color: Theme.of(context).colorScheme.primary,
                    width: 22,
                    borderRadius: BorderRadius.circular(4))
              ])
          ],
          titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 54,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        return i >= 0 && i < rows.length
                            ? SideTitleWidget(
                                meta: meta,
                                child: Text('${rows[i]['titulo']}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 9)))
                            : const SizedBox.shrink();
                      }))),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
        ));
}

class _SimpleBars extends StatelessWidget {
  const _SimpleBars(
      {required this.rows, required this.labelKey, required this.valueKey});
  final List<Map<String, dynamic>> rows;
  final String labelKey, valueKey;
  @override
  Widget build(BuildContext context) => rows.isEmpty
      ? const _EmptyChart()
      : ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final row = rows[i];
            return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  SizedBox(
                      width: 125,
                      child: Text('${row[labelKey]}',
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Expanded(
                      child: LinearProgressIndicator(
                          value: _number(row[valueKey]) /
                              (rows
                                  .map((e) => _number(e[valueKey]))
                                  .fold<int>(1, (a, b) => a > b ? a : b)),
                          minHeight: 12)),
                  const SizedBox(width: 10),
                  Text('${row[valueKey]}')
                ]));
          });
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Sin datos disponibles para mostrar.'));
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(this.label, this.icon, this.destination);
  final String label;
  final IconData icon;
  final Widget destination;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
      onPressed: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => destination)),
      icon: Icon(icon),
      label: Text(label));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            const Text('No se pudieron cargar los datos del dashboard.'),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: () => Navigator.of(context)
                    .pushReplacementNamed('/admin/dashboard'),
                child: const Text('Reintentar'))
          ])));
}
