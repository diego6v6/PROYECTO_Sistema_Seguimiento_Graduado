import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'answer_survey_screen.dart';
import 'create_survey_screen.dart';

class SurveysScreen extends StatefulWidget {
  const SurveysScreen({super.key});

  @override
  State<SurveysScreen> createState() => _SurveysScreenState();
}

class _SurveysScreenState extends State<SurveysScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _encuestas = [];

  String _rol = 'GRADUADO';

  bool _cargando = true;
  bool _esAdministrador = false;

  @override
  void initState() {
    super.initState();
    _cargarEncuestas();
  }

  // ==========================================================================
  // CARGAR ENCUESTAS
  // ==========================================================================

  Future<void> _cargarEncuestas() async {
    if (mounted) {
      setState(() {
        _cargando = true;
      });
    }

    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception('No hay un usuario autenticado.');
      }

      // ----------------------------------------------------------------------
      // OBTENER PERFIL Y ROL
      // ----------------------------------------------------------------------

      final perfil = await _supabase
          .from('perfiles')
          .select('id_rol, roles(nombre)')
          .eq('id', user.id)
          .maybeSingle();

      _rol = 'GRADUADO';

      if (perfil != null) {
        final roles = perfil['roles'];

        if (roles is Map) {
          _rol = roles['nombre']?.toString() ?? 'GRADUADO';
        }
      }

      // ----------------------------------------------------------------------
      // NORMALIZAR ROL
      // ----------------------------------------------------------------------

      final rolNormalizado = _rol.trim().toUpperCase();

      _esAdministrador = rolNormalizado == 'ADMINISTRADOR' ||
          rolNormalizado == 'SUPER_ADMIN' ||
          rolNormalizado == 'SUPER ADMIN' ||
          rolNormalizado == 'SUPERADMIN';

      debugPrint('Rol actual: $_rol');
      debugPrint('¿Es administrador?: $_esAdministrador');

      // ----------------------------------------------------------------------
      // CONSULTAR ENCUESTAS
      // ----------------------------------------------------------------------

      List<Map<String, dynamic>> resultado;

      if (_esAdministrador) {
        // ====================================================================
        // ADMINISTRADOR / SUPER ADMIN
        // ====================================================================

        resultado = List<Map<String, dynamic>>.from(
          await _supabase.from('encuestas').select('''
                id,
                titulo,
                descripcion,
                fecha_inicio,
                fecha_fin,
                estado,
                id_usuario_creador,
                created_at,
                updated_at
              ''').order(
            'created_at',
            ascending: false,
          ),
        );
      } else {
        // ====================================================================
        // GRADUADO
        // ====================================================================

        final hoy = DateTime.now().toIso8601String().substring(0, 10);

        resultado = List<Map<String, dynamic>>.from(
          await _supabase
              .from('encuestas')
              .select('''
                id,
                titulo,
                descripcion,
                fecha_inicio,
                fecha_fin,
                estado,
                id_usuario_creador,
                created_at,
                updated_at
              ''')
              .eq('estado', true)
              .or(
                'fecha_inicio.is.null,fecha_inicio.lte.$hoy',
              )
              .or(
                'fecha_fin.is.null,fecha_fin.gte.$hoy',
              )
              .order(
                'created_at',
                ascending: false,
              ),
        );
      }

      if (!mounted) return;

      setState(() {
        _encuestas = resultado;
        _cargando = false;
      });
    } catch (e) {
      debugPrint('Error al cargar encuestas: $e');

      if (!mounted) return;

      setState(() {
        _cargando = false;
      });

      _mostrarMensaje(
        'No se pudieron cargar las encuestas.',
        esError: true,
      );
    }
  }

  // ==========================================================================
  // CREAR ENCUESTA
  // ==========================================================================

  Future<void> _abrirCrearEncuesta() async {
    if (!_esAdministrador) {
      _mostrarMensaje(
        'No tienes permisos para crear encuestas.',
        esError: true,
      );
      return;
    }

    // ------------------------------------------------------------------------
    // ABRIR LA NUEVA PANTALLA CREATE SURVEY SCREEN
    // ------------------------------------------------------------------------

    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateSurveyScreen(),
      ),
    );

    // ------------------------------------------------------------------------
    // RECARGAR ENCUESTAS SI SE CREÓ UNA NUEVA
    // ------------------------------------------------------------------------

    if (resultado == true && mounted) {
      await _cargarEncuestas();
    }
  }

  // ==========================================================================
  // ABRIR ENCUESTA
  // ==========================================================================

  void _abrirEncuesta(
    Map<String, dynamic> encuesta,
  ) {
    final id = encuesta['id']?.toString();

    if (id == null || id.isEmpty) {
      _mostrarMensaje(
        'La encuesta no tiene un identificador válido.',
        esError: true,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnswerSurveyScreen(
          encuestaId: id,
        ),
      ),
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esError ? Colors.red : Colors.green,
      ),
    );
  }

  // ==========================================================================
  // DISPONIBILIDAD DE ENCUESTA
  // ==========================================================================

  bool _estaDisponible(
    Map<String, dynamic> encuesta,
  ) {
    if (encuesta['estado'] != true) {
      return false;
    }

    final ahora = DateTime.now();

    // ------------------------------------------------------------------------
    // FECHA DE INICIO
    // ------------------------------------------------------------------------

    final fechaInicioTexto = encuesta['fecha_inicio']?.toString();

    if (fechaInicioTexto != null && fechaInicioTexto.isNotEmpty) {
      final fechaInicio = DateTime.tryParse(fechaInicioTexto);

      if (fechaInicio != null) {
        final inicioDelDia = DateTime(
          fechaInicio.year,
          fechaInicio.month,
          fechaInicio.day,
        );

        if (ahora.isBefore(inicioDelDia)) {
          return false;
        }
      }
    }

    // ------------------------------------------------------------------------
    // FECHA FINAL
    // ------------------------------------------------------------------------

    final fechaFinTexto = encuesta['fecha_fin']?.toString();

    if (fechaFinTexto != null && fechaFinTexto.isNotEmpty) {
      final fechaFin = DateTime.tryParse(fechaFinTexto);

      if (fechaFin != null) {
        final finDelDia = DateTime(
          fechaFin.year,
          fechaFin.month,
          fechaFin.day,
          23,
          59,
          59,
        );

        if (ahora.isAfter(finDelDia)) {
          return false;
        }
      }
    }

    return true;
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
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Encuestas'),
        actions: [
          // ==================================================================
          // AÑADIR ENCUESTA
          // ==================================================================

          if (_esAdministrador)
            IconButton(
              tooltip: 'Añadir encuesta',
              icon: const Icon(Icons.add),
              onPressed: _cargando ? null : _abrirCrearEncuesta,
            ),

          // ==================================================================
          // ACTUALIZAR
          // ==================================================================

          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _cargando ? null : _cargarEncuestas,
          ),
        ],
      ),

      // ========================================================================
      // BODY
      // ========================================================================

      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _cargarEncuestas,
              child: _encuestas.isEmpty
                  ? _EstadoVacio(
                      esAdministrador: _esAdministrador,
                      onAgregar: _esAdministrador ? _abrirCrearEncuesta : null,
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      itemCount: _encuestas.length,
                      itemBuilder: (context, index) {
                        final encuesta = _encuestas[index];

                        final disponible = _estaDisponible(
                          encuesta,
                        );

                        return _EncuestaCard(
                          encuesta: encuesta,
                          esAdministrador: _esAdministrador,
                          estaDisponible: disponible,
                          onTap: () {
                            _abrirEncuesta(
                              encuesta,
                            );
                          },
                        );
                      },
                    ),
            ),
    );
  }
}

// ============================================================================
// TARJETA DE ENCUESTA
// ============================================================================

class _EncuestaCard extends StatelessWidget {
  const _EncuestaCard({
    required this.encuesta,
    required this.esAdministrador,
    required this.estaDisponible,
    required this.onTap,
  });

  final Map<String, dynamic> encuesta;
  final bool esAdministrador;
  final bool estaDisponible;
  final VoidCallback onTap;

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

  @override
  Widget build(BuildContext context) {
    final titulo = encuesta['titulo']?.toString() ?? 'Sin título';

    final descripcion = encuesta['descripcion']?.toString() ?? '';

    final fechaInicio = encuesta['fecha_inicio'];

    final fechaFin = encuesta['fecha_fin'];

    final estado = encuesta['estado'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================================================================
            // TÍTULO
            // ================================================================

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.assignment_outlined,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titulo,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),

            // ================================================================
            // DESCRIPCIÓN
            // ================================================================

            if (descripcion.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                descripcion,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],

            const SizedBox(height: 14),

            // ================================================================
            // FECHA INICIO
            // ================================================================

            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 17,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Inicio: ${_formatearFecha(fechaInicio)}',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // ================================================================
            // FECHA FINAL
            // ================================================================

            Row(
              children: [
                const Icon(
                  Icons.event_outlined,
                  size: 17,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Fin: ${_formatearFecha(fechaFin)}',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ================================================================
            // ESTADOS
            // ================================================================

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _EstadoChip(
                  texto: estado ? 'Activa' : 'Inactiva',
                  color: estado ? Colors.green : Colors.grey,
                ),
                if (!esAdministrador && estaDisponible)
                  const _EstadoChip(
                    texto: 'Disponible',
                    color: Colors.blue,
                  ),
                if (!esAdministrador && !estaDisponible)
                  const _EstadoChip(
                    texto: 'No disponible',
                    color: Colors.orange,
                  ),
                if (esAdministrador)
                  const _EstadoChip(
                    texto: 'Administrador',
                    color: Colors.deepPurple,
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // ================================================================
            // BOTÓN
            // ================================================================

            if (!esAdministrador)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: estaDisponible ? onTap : null,
                  icon: const Icon(
                    Icons.edit_note_outlined,
                  ),
                  label: Text(
                    estaDisponible ? 'Responder encuesta' : 'No disponible',
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(
                    Icons.visibility_outlined,
                  ),
                  label: const Text(
                    'Ver encuesta',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CHIP DE ESTADO
// ============================================================================

class _EstadoChip extends StatelessWidget {
  const _EstadoChip({
    required this.texto,
    required this.color,
  });

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ============================================================================
// ESTADO VACÍO
// ============================================================================

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({
    required this.esAdministrador,
    this.onAgregar,
  });

  final bool esAdministrador;
  final VoidCallback? onAgregar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(30),
      children: [
        const SizedBox(height: 60),

        Icon(
          Icons.assignment_outlined,
          size: 80,
          color: Colors.grey.shade400,
        ),

        const SizedBox(height: 20),

        Text(
          esAdministrador
              ? 'No hay encuestas registradas'
              : 'No hay encuestas disponibles',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),

        const SizedBox(height: 8),

        Text(
          esAdministrador
              ? 'Todavía no se han creado encuestas en el sistema.'
              : 'Actualmente no tienes encuestas disponibles para responder.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),

        // ================================================================
        // BOTÓN AÑADIR
        // ================================================================

        if (esAdministrador && onAgregar != null) ...[
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAgregar,
              icon: const Icon(Icons.add),
              label: const Text(
                'Añadir encuesta',
              ),
            ),
          ),
        ],
      ],
    );
  }
}
