import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final _supabase = Supabase.instance.client;
  final _mensajeController = TextEditingController();

  List<Map<String, dynamic>> _recomendaciones = [];

  bool _cargando = true;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _cargarRecomendaciones();
  }

  @override
  void dispose() {
    _mensajeController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // CARGAR RECOMENDACIONES
  // ==========================================================================

  Future<void> _cargarRecomendaciones() async {
    if (!mounted) return;

    setState(() {
      _cargando = true;
    });

    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception('No hay un usuario autenticado.');
      }

      final resultado = await _supabase.from('recomendaciones').select('''
            id,
            id_graduado,
            mensaje,
            fecha,
            estado,
            respuesta_admin,
            id_usuario_revisor,
            fecha_revision,
            created_at,
            updated_at
          ''').eq('id_graduado', user.id).order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _recomendaciones = List<Map<String, dynamic>>.from(resultado);
        _cargando = false;
      });
    } catch (e) {
      debugPrint('Error al cargar recomendaciones: $e');

      if (!mounted) return;

      setState(() {
        _cargando = false;
      });

      _mostrarMensaje(
        'No se pudieron cargar las recomendaciones.',
        esError: true,
      );
    }
  }

  // ==========================================================================
  // ENVIAR RECOMENDACIÓN
  // ==========================================================================

  Future<bool> _enviarRecomendacion(String mensaje) async {
    final texto = mensaje.trim();

    if (texto.isEmpty) {
      _mostrarMensaje(
        'Escribe una recomendación antes de enviarla.',
        esError: true,
      );
      return false;
    }

    if (texto.length < 5) {
      _mostrarMensaje(
        'La recomendación debe tener al menos 5 caracteres.',
        esError: true,
      );
      return false;
    }

    final user = _supabase.auth.currentUser;

    if (user == null) {
      _mostrarMensaje(
        'No hay un usuario autenticado.',
        esError: true,
      );
      return false;
    }

    if (_enviando) {
      return false;
    }

    setState(() {
      _enviando = true;
    });

    try {
      // ======================================================================
      // IMPORTANTE:
      //
      // id_graduado DEBE ser exactamente el UUID del usuario autenticado.
      //
      // Esto coincide con la política:
      //
      // id_graduado = auth.uid()
      //
      // ======================================================================

      await _supabase.from('recomendaciones').insert({
        'id_graduado': user.id,
        'mensaje': texto,
        'estado': 'PENDIENTE',
      });

      _mensajeController.clear();

      if (!mounted) return true;

      setState(() {
        _enviando = false;
      });

      // Cerramos el formulario solamente después de que Supabase
      // confirmó correctamente el INSERT.
      Navigator.of(context).pop();

      // Actualizamos la lista después de cerrar el formulario.
      await _cargarRecomendaciones();

      if (!mounted) return true;

      _mostrarMensaje(
        'Recomendación enviada correctamente.',
      );

      return true;
    } catch (e) {
      debugPrint('Error al enviar recomendación: $e');

      if (!mounted) return false;

      setState(() {
        _enviando = false;
      });

      String mensajeError = 'No se pudo enviar la recomendación.';

      // Mensaje específico para errores RLS.
      if (e is PostgrestException) {
        debugPrint('Código PostgREST: ${e.code}');
        debugPrint('Mensaje PostgREST: ${e.message}');
        debugPrint('Detalles PostgREST: ${e.details}');
        debugPrint('Hint PostgREST: ${e.hint}');

        if (e.code == '42501') {
          mensajeError = 'No tienes permisos para enviar recomendaciones.';
        }
      }

      _mostrarMensaje(
        mensajeError,
        esError: true,
      );

      return false;
    }
  }

  // ==========================================================================
  // DIALOGO / BOTTOM SHEET
  // ==========================================================================

  void _mostrarFormulario() {
    _mensajeController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ----------------------------------------------------------------
                  // TÍTULO
                  // ----------------------------------------------------------------

                  Row(
                    children: [
                      const Icon(
                        Icons.lightbulb_outline,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Nueva recomendación',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                      IconButton(
                        onPressed: _enviando
                            ? null
                            : () {
                                Navigator.of(modalContext).pop();
                              },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Comparte una sugerencia para mejorar el seguimiento a los graduados.',
                  ),

                  const SizedBox(height: 18),

                  // ----------------------------------------------------------------
                  // CAMPO
                  // ----------------------------------------------------------------

                  TextField(
                    controller: _mensajeController,
                    maxLines: 6,
                    maxLength: 1000,
                    enabled: !_enviando,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      labelText: 'Tu recomendación',
                      hintText: 'Escribe aquí tu sugerencia...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ----------------------------------------------------------------
                  // BOTÓN
                  // ----------------------------------------------------------------

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _enviando
                          ? null
                          : () async {
                              final texto = _mensajeController.text.trim();

                              if (texto.isEmpty) {
                                _mostrarMensaje(
                                  'Escribe una recomendación antes de enviarla.',
                                  esError: true,
                                );
                                return;
                              }

                              if (texto.length < 5) {
                                _mostrarMensaje(
                                  'La recomendación debe tener al menos 5 caracteres.',
                                  esError: true,
                                );
                                return;
                              }

                              // Actualizamos inmediatamente el modal.
                              setModalState(() {});

                              await _enviarRecomendacion(texto);
                            },
                      icon: _enviando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send,
                            ),
                      label: Text(
                        _enviando ? 'Enviando...' : 'Enviar recomendación',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================================================
  // MOSTRAR DETALLE
  // ==========================================================================

  void _mostrarDetalle(
    Map<String, dynamic> recomendacion,
  ) {
    final mensaje = recomendacion['mensaje']?.toString() ?? '';

    final estado = recomendacion['estado']?.toString() ?? 'PENDIENTE';

    final respuestaAdmin = recomendacion['respuesta_admin']?.toString();

    final fecha = recomendacion['fecha'];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Recomendación',
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tu mensaje',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(mensaje),
                const SizedBox(height: 20),
                const Text(
                  'Estado',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _EstadoChip(
                  estado: estado,
                ),
                if (fecha != null) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Fecha',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatearFecha(fecha),
                  ),
                ],
                if (respuestaAdmin != null && respuestaAdmin.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Respuesta del administrador',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      respuestaAdmin,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'Cerrar',
              ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================================
  // MENSAJE
  // ==========================================================================

  void _mostrarMensaje(
    String mensaje, {
    bool esError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: esError ? Colors.red : Colors.green,
        ),
      );
  }

  // ==========================================================================
  // FORMATEAR FECHA
  // ==========================================================================

  String _formatearFecha(
    dynamic fecha,
  ) {
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
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Recomendaciones',
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _cargando ? null : _cargarRecomendaciones,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),

      // ----------------------------------------------------------------------
      // BOTÓN NUEVA RECOMENDACIÓN
      // ----------------------------------------------------------------------

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _enviando ? null : _mostrarFormulario,
        icon: const Icon(
          Icons.add,
        ),
        label: const Text(
          'Nueva',
        ),
      ),

      // ----------------------------------------------------------------------
      // CONTENIDO
      // ----------------------------------------------------------------------

      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _cargarRecomendaciones,
              child: _recomendaciones.isEmpty
                  ? _SinRecomendaciones(
                      onNueva: _mostrarFormulario,
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        20,
                        20,
                        100,
                      ),
                      itemCount: _recomendaciones.length,
                      itemBuilder: (context, index) {
                        final recomendacion = _recomendaciones[index];

                        return _RecomendacionCard(
                          recomendacion: recomendacion,
                          onTap: () => _mostrarDetalle(
                            recomendacion,
                          ),
                          formatearFecha: _formatearFecha,
                        );
                      },
                    ),
            ),
    );
  }
}

// ============================================================================
// CARD DE RECOMENDACIÓN
// ============================================================================

class _RecomendacionCard extends StatelessWidget {
  const _RecomendacionCard({
    required this.recomendacion,
    required this.onTap,
    required this.formatearFecha,
  });

  final Map<String, dynamic> recomendacion;

  final VoidCallback onTap;

  final String Function(dynamic) formatearFecha;

  @override
  Widget build(BuildContext context) {
    final mensaje = recomendacion['mensaje']?.toString() ?? '';

    final estado = recomendacion['estado']?.toString() ?? 'PENDIENTE';

    final fecha = recomendacion['fecha'];

    return Card(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ----------------------------------------------------------------
              // CABECERA
              // ----------------------------------------------------------------

              Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.lightbulb_outline,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Mi recomendación',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _EstadoChip(
                    estado: estado,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ----------------------------------------------------------------
              // MENSAJE
              // ----------------------------------------------------------------

              Text(
                mensaje,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // ----------------------------------------------------------------
              // FECHA
              // ----------------------------------------------------------------

              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 15,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formatearFecha(fecha),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const Spacer(),
                  const Text(
                    'Ver detalle',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ESTADO
// ============================================================================

class _EstadoChip extends StatelessWidget {
  const _EstadoChip({
    required this.estado,
  });

  final String estado;

  Color _color() {
    switch (estado) {
      case 'PENDIENTE':
        return Colors.orange;

      case 'REVISADA':
        return Colors.blue;

      case 'ATENDIDA':
        return Colors.green;

      case 'DESCARTADA':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  String _texto() {
    switch (estado) {
      case 'PENDIENTE':
        return 'Pendiente';

      case 'REVISADA':
        return 'Revisada';

      case 'ATENDIDA':
        return 'Atendida';

      case 'DESCARTADA':
        return 'Descartada';

      default:
        return estado;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _texto(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ============================================================================
// SIN RECOMENDACIONES
// ============================================================================

class _SinRecomendaciones extends StatelessWidget {
  const _SinRecomendaciones({
    required this.onNueva,
  });

  final VoidCallback onNueva;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(30),
      children: [
        const SizedBox(height: 70),
        Icon(
          Icons.lightbulb_outline,
          size: 80,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 20),
        Text(
          'No tienes recomendaciones',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Puedes enviar una sugerencia para ayudar a mejorar el sistema de seguimiento a graduados.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
        const SizedBox(height: 25),
        Center(
          child: ElevatedButton.icon(
            onPressed: onNueva,
            icon: const Icon(
              Icons.add,
            ),
            label: const Text(
              'Enviar recomendación',
            ),
          ),
        ),
      ],
    );
  }
}
