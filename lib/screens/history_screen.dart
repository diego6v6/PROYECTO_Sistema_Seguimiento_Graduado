import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'answer_survey_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _historial = [];

  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  // ==========================================================================
  // CARGAR HISTORIAL
  // ==========================================================================

  Future<void> _cargarHistorial() async {
    setState(() {
      _cargando = true;
    });

    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception(
          'No hay un usuario autenticado.',
        );
      }

      final resultado = await _supabase
          .from('respuestas_encuesta')
          .select('''
            id,
            id_encuesta,
            id_graduado,
            fecha_respuesta,
            estado,
            created_at,
            updated_at,
            encuestas (
              id,
              titulo,
              descripcion,
              fecha_inicio,
              fecha_fin,
              estado
            )
          ''')
          .eq(
            'id_graduado',
            user.id,
          )
          .order(
            'created_at',
            ascending: false,
          );

      if (mounted) {
        setState(() {
          _historial = List<Map<String, dynamic>>.from(
            resultado,
          );

          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint(
        'Error al cargar historial: $e',
      );

      if (mounted) {
        setState(() {
          _cargando = false;
        });

        _mostrarMensaje(
          'No se pudo cargar el historial.',
          esError: true,
        );
      }
    }
  }

  // ==========================================================================
  // ABRIR REGISTRO
  // ==========================================================================

  Future<void> _abrirRegistro(
    Map<String, dynamic> registro,
  ) async {
    final encuesta = registro['encuestas'];

    if (encuesta is! Map) {
      _mostrarMensaje(
        'No se encontró la información de la encuesta.',
        esError: true,
      );

      return;
    }

    final encuestaId = encuesta['id']?.toString();

    final estado = registro['estado']?.toString() ?? 'BORRADOR';

    if (encuestaId == null || encuestaId.isEmpty) {
      _mostrarMensaje(
        'La encuesta no tiene un identificador válido.',
        esError: true,
      );

      return;
    }

    // ------------------------------------------------------------------------
    // ABRIR ENCUESTA
    // ------------------------------------------------------------------------

    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnswerSurveyScreen(
          encuestaId: encuestaId,
        ),
      ),
    );

    // Si regresamos de la pantalla de encuesta,
    // actualizamos el historial.
    if (resultado == true || estado == 'BORRADOR') {
      _cargarHistorial();
    }
  }

  // ==========================================================================
  // MOSTRAR MENSAJE
  // ==========================================================================

  void _mostrarMensaje(
    String mensaje, {
    bool esError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esError ? Colors.red : Colors.green,
      ),
    );
  }

  // ==========================================================================
  // FORMATEAR FECHA
  // ==========================================================================

  String _formatearFecha(dynamic fecha) {
    if (fecha == null) {
      return 'Sin fecha';
    }

    final texto = fecha.toString();

    if (texto.length < 10) {
      return texto;
    }

    final partes = texto.substring(0, 10).split('-');

    if (partes.length != 3) {
      return texto;
    }

    return '${partes[2]}/${partes[1]}/${partes[0]}';
  }

  // ==========================================================================
  // ESTADO
  // ==========================================================================

  Color _colorEstado(
    String estado,
  ) {
    switch (estado) {
      case 'COMPLETADA':
        return Colors.green;

      case 'BORRADOR':
        return Colors.orange;

      default:
        return Colors.grey;
    }
  }

  String _textoEstado(
    String estado,
  ) {
    switch (estado) {
      case 'COMPLETADA':
        return 'Completada';

      case 'BORRADOR':
        return 'Borrador';

      default:
        return estado;
    }
  }

  IconData _iconoEstado(
    String estado,
  ) {
    switch (estado) {
      case 'COMPLETADA':
        return Icons.check_circle_outline;

      case 'BORRADOR':
        return Icons.edit_note_outlined;

      default:
        return Icons.help_outline;
    }
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Historial',
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(
              Icons.refresh,
            ),
            onPressed: _cargando ? null : _cargarHistorial,
          ),
        ],
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _cargarHistorial,
              child: _historial.isEmpty
                  ? const _HistorialVacio()
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      itemCount: _historial.length,
                      itemBuilder: (context, index) {
                        final registro = _historial[index];

                        return _HistorialCard(
                          registro: registro,
                          onTap: () => _abrirRegistro(
                            registro,
                          ),
                          formatearFecha: _formatearFecha,
                          colorEstado: _colorEstado,
                          textoEstado: _textoEstado,
                          iconoEstado: _iconoEstado,
                        );
                      },
                    ),
            ),
    );
  }
}

// ============================================================================
// TARJETA DEL HISTORIAL
// ============================================================================

class _HistorialCard extends StatelessWidget {
  const _HistorialCard({
    required this.registro,
    required this.onTap,
    required this.formatearFecha,
    required this.colorEstado,
    required this.textoEstado,
    required this.iconoEstado,
  });

  final Map<String, dynamic> registro;

  final VoidCallback onTap;

  final String Function(dynamic) formatearFecha;

  final Color Function(String) colorEstado;

  final String Function(String) textoEstado;

  final IconData Function(String) iconoEstado;

  @override
  Widget build(BuildContext context) {
    final encuesta = registro['encuestas'];

    final titulo = encuesta is Map
        ? encuesta['titulo']?.toString() ?? 'Encuesta'
        : 'Encuesta';

    final descripcion =
        encuesta is Map ? encuesta['descripcion']?.toString() ?? '' : '';

    final estado = registro['estado']?.toString() ?? 'BORRADOR';

    final fechaRespuesta = registro['fecha_respuesta'];

    final fechaCreacion = registro['created_at'];

    final color = colorEstado(estado);

    return Card(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --------------------------------------------------------------
              // CABECERA
              // --------------------------------------------------------------

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withOpacity(
                        0.12,
                      ),
                      borderRadius: BorderRadius.circular(
                        12,
                      ),
                    ),
                    child: Icon(
                      iconoEstado(
                        estado,
                      ),
                      color: color,
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Expanded(
                    child: Text(
                      titulo,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                  ),
                ],
              ),

              // --------------------------------------------------------------
              // DESCRIPCIÓN
              // --------------------------------------------------------------

              if (descripcion.isNotEmpty) ...[
                const SizedBox(
                  height: 12,
                ),
                Text(
                  descripcion,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],

              const SizedBox(
                height: 14,
              ),

              // --------------------------------------------------------------
              // ESTADO
              // --------------------------------------------------------------

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(
                    0.12,
                  ),
                  borderRadius: BorderRadius.circular(
                    20,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      iconoEstado(
                        estado,
                      ),
                      size: 16,
                      color: color,
                    ),
                    const SizedBox(
                      width: 6,
                    ),
                    Text(
                      textoEstado(
                        estado,
                      ),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              // --------------------------------------------------------------
              // FECHA
              // --------------------------------------------------------------

              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                  ),
                  const SizedBox(
                    width: 6,
                  ),
                  Text(
                    estado == 'COMPLETADA'
                        ? 'Respondida: ${formatearFecha(fechaRespuesta)}'
                        : 'Creada: ${formatearFecha(fechaCreacion)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall,
                  ),
                ],
              ),

              // --------------------------------------------------------------
              // ACCIÓN
              // --------------------------------------------------------------

              const SizedBox(
                height: 14,
              ),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onTap,
                  icon: Icon(
                    estado == 'COMPLETADA'
                        ? Icons.visibility_outlined
                        : Icons.edit_outlined,
                  ),
                  label: Text(
                    estado == 'COMPLETADA'
                        ? 'Ver respuestas'
                        : 'Continuar encuesta',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// HISTORIAL VACÍO
// ============================================================================

class _HistorialVacio extends StatelessWidget {
  const _HistorialVacio();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(30),
      children: [
        const SizedBox(
          height: 80,
        ),
        Icon(
          Icons.history_outlined,
          size: 80,
          color: Colors.grey.shade400,
        ),
        const SizedBox(
          height: 20,
        ),
        Text(
          'No tienes historial',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(
          height: 8,
        ),
        Text(
          'Cuando respondas una encuesta, aparecerá aquí.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
      ],
    );
  }
}
