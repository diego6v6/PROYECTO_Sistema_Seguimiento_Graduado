import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SurveyResultsScreen extends StatefulWidget {
  const SurveyResultsScreen({
    super.key,
  });

  @override
  State<SurveyResultsScreen> createState() => _SurveyResultsScreenState();
}

class _SurveyResultsScreenState extends State<SurveyResultsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _encuestas = [];

  String? _encuestaSeleccionada;

  List<Map<String, dynamic>> _preguntas = [];

  bool _cargando = true;
  bool _cargandoResultados = false;

  @override
  void initState() {
    super.initState();

    _cargarEncuestas();
  }

  // ==========================================================================
  // CARGAR ENCUESTAS
  // ==========================================================================

  Future<void> _cargarEncuestas() async {
    setState(() {
      _cargando = true;
    });

    try {
      final rol = await _supabase.rpc(
        'obtener_rol_usuario',
      );

      if (rol != 'SUPER_ADMIN' && rol != 'ADMINISTRADOR') {
        if (mounted) {
          setState(() {
            _cargando = false;
          });

          _mostrarError(
            'No tienes permisos para consultar los resultados.',
          );
        }

        return;
      }

      final resultado = await _supabase
          .from('encuestas')
          .select(
            'id, titulo, descripcion, fecha_inicio, fecha_fin, estado',
          )
          .order(
            'created_at',
            ascending: false,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _encuestas = List<Map<String, dynamic>>.from(
          resultado,
        );

        _cargando = false;
      });
    } catch (e) {
      debugPrint(
        'Error al cargar encuestas: $e',
      );

      if (mounted) {
        setState(() {
          _cargando = false;
        });

        _mostrarError(
          'No se pudieron cargar las encuestas.',
        );
      }
    }
  }

  // ==========================================================================
  // SELECCIONAR ENCUESTA
  // ==========================================================================

  Future<void> _seleccionarEncuesta(
    String? encuestaId,
  ) async {
    if (encuestaId == null) {
      return;
    }

    setState(() {
      _encuestaSeleccionada = encuestaId;
      _preguntas = [];
      _cargandoResultados = true;
    });

    try {
      final preguntas = await _supabase
          .from('preguntas')
          .select(
            '''
            id,
            pregunta,
            tipo,
            obligatoria,
            orden,
            valor_minimo,
            valor_maximo,
            etiqueta_minimo,
            etiqueta_maximo,
            opciones_pregunta (
              id,
              opcion,
              orden
            )
            ''',
          )
          .eq(
            'id_encuesta',
            encuestaId,
          )
          .order(
            'orden',
            ascending: true,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _preguntas = List<Map<String, dynamic>>.from(
          preguntas,
        );

        _cargandoResultados = false;
      });
    } catch (e) {
      debugPrint(
        'Error al cargar resultados: $e',
      );

      if (mounted) {
        setState(() {
          _cargandoResultados = false;
        });

        _mostrarError(
          'No se pudieron cargar los resultados.',
        );
      }
    }
  }

  // ==========================================================================
  // OBTENER RESPUESTAS DE UNA PREGUNTA
  // ==========================================================================

  Future<List<Map<String, dynamic>>> _obtenerRespuestas(
    String preguntaId,
  ) async {
    final resultado = await _supabase
        .from('respuestas')
        .select(
          '''
          id,
          id_opcion,
          respuesta_texto,
          respuestas_encuesta!inner(
            id,
            id_encuesta,
            id_graduado,
            estado
          ),
          opciones_pregunta(
            id,
            opcion
          )
          ''',
        )
        .eq(
          'id_pregunta',
          preguntaId,
        )
        .eq(
          'respuestas_encuesta.id_encuesta',
          _encuestaSeleccionada!,
        )
        .eq(
          'respuestas_encuesta.estado',
          'COMPLETADA',
        );

    return List<Map<String, dynamic>>.from(
      resultado,
    );
  }

  // ==========================================================================
  // CONTAR RESPUESTAS POR OPCIÓN
  // ==========================================================================

  Future<Map<String, int>> _contarOpciones(
    Map<String, dynamic> pregunta,
  ) async {
    final respuestas = await _obtenerRespuestas(
      pregunta['id'].toString(),
    );

    final resultado = <String, int>{};

    final opciones = List<Map<String, dynamic>>.from(
      pregunta['opciones_pregunta'] ?? [],
    );

    for (final opcion in opciones) {
      final id = opcion['id'].toString();

      resultado[id] = 0;
    }

    for (final respuesta in respuestas) {
      final opcion = respuesta['id_opcion']?.toString();

      if (opcion != null && resultado.containsKey(opcion)) {
        resultado[opcion] = (resultado[opcion] ?? 0) + 1;
      }
    }

    return resultado;
  }

  // ==========================================================================
  // MOSTRAR ERROR
  // ==========================================================================

  void _mostrarError(
    String mensaje,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Resultados de encuestas',
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _cargando ? null : _cargarEncuestas,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _encuestas.isEmpty
              ? const Center(
                  child: Text(
                    'No existen encuestas.',
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seleccione una encuesta',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _encuestaSeleccionada,
                        decoration: InputDecoration(
                          labelText: 'Encuesta',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              12,
                            ),
                          ),
                        ),
                        items: _encuestas.map(
                          (
                            encuesta,
                          ) {
                            return DropdownMenuItem<String>(
                              value: encuesta['id'],
                              child: Text(
                                encuesta['titulo'].toString(),
                              ),
                            );
                          },
                        ).toList(),
                        onChanged: _seleccionarEncuesta,
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      Expanded(
                        child: _cargandoResultados
                            ? const Center(
                                child: CircularProgressIndicator(),
                              )
                            : _preguntas.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Seleccione una encuesta para ver sus resultados.',
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _preguntas.length,
                                    itemBuilder: (
                                      context,
                                      index,
                                    ) {
                                      return _ResultadoPreguntaCard(
                                        pregunta: _preguntas[index],
                                        obtenerDatos: _contarOpciones,
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

// ============================================================================
// CARD DE RESULTADO
// ============================================================================

class _ResultadoPreguntaCard extends StatefulWidget {
  const _ResultadoPreguntaCard({
    required this.pregunta,
    required this.obtenerDatos,
  });

  final Map<String, dynamic> pregunta;

  final Future<Map<String, int>> Function(
    Map<String, dynamic>,
  ) obtenerDatos;

  @override
  State<_ResultadoPreguntaCard> createState() => _ResultadoPreguntaCardState();
}

class _ResultadoPreguntaCardState extends State<_ResultadoPreguntaCard> {
  Map<String, int> _datos = {};

  bool _cargando = true;

  @override
  void initState() {
    super.initState();

    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final datos = await widget.obtenerDatos(
        widget.pregunta,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _datos = datos;
        _cargando = false;
      });
    } catch (e) {
      debugPrint(
        'Error en gráfico: $e',
      );

      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final tipo = widget.pregunta['tipo']?.toString();

    final opciones = List<Map<String, dynamic>>.from(
      widget.pregunta['opciones_pregunta'] ?? [],
    );

    return Card(
      margin: const EdgeInsets.only(
        bottom: 18,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.pregunta['pregunta'].toString(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(
              height: 18,
            ),
            if (_cargando)
              const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (tipo == 'RADIO' || tipo == 'SELECT')
              _GraficoBarras(
                opciones: opciones,
                datos: _datos,
              )
            else if (tipo == 'CHECKBOX')
              _GraficoBarras(
                opciones: opciones,
                datos: _datos,
              )
            else
              const Padding(
                padding: EdgeInsets.all(
                  20,
                ),
                child: Text(
                  'Esta pregunta no tiene un gráfico estadístico disponible.',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// GRÁFICO DE BARRAS
// ============================================================================

class _GraficoBarras extends StatelessWidget {
  const _GraficoBarras({
    required this.opciones,
    required this.datos,
  });

  final List<Map<String, dynamic>> opciones;

  final Map<String, int> datos;

  @override
  Widget build(
    BuildContext context,
  ) {
    if (opciones.isEmpty) {
      return const Text(
        'Esta pregunta no tiene opciones.',
      );
    }

    final valores = opciones
        .map(
          (opcion) => (datos[opcion['id'].toString()] ?? 0).toDouble(),
        )
        .toList();

    final maxValor = valores.isEmpty
        ? 1.0
        : valores.reduce(
              (a, b) => a > b ? a : b,
            ) +
            1;

    return SizedBox(
      height: 280,
      child: BarChart(
        BarChartData(
          maxY: maxValor,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(
            show: true,
          ),
          borderData: FlBorderData(
            show: false,
          ),
          titlesData: FlTitlesData(
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
                reservedSize: 70,
                getTitlesWidget: (
                  value,
                  meta,
                ) {
                  final index = value.toInt();

                  if (index < 0 || index >= opciones.length) {
                    return const SizedBox();
                  }

                  final texto = opciones[index]['opcion'].toString();

                  return SideTitleWidget(
                    meta: meta,
                    child: SizedBox(
                      width: 70,
                      child: Text(
                        texto,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(
            opciones.length,
            (index) {
              final cantidad = valores[index];

              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: cantidad,
                    width: 28,
                    borderRadius: BorderRadius.circular(
                      5,
                    ),
                    color: Theme.of(
                      context,
                    ).colorScheme.primary,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
