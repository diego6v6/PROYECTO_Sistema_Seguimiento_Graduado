import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRecommendationsScreen extends StatefulWidget {
  const AdminRecommendationsScreen({
    super.key,
  });

  @override
  State<AdminRecommendationsScreen> createState() =>
      _AdminRecommendationsScreenState();
}

class _AdminRecommendationsScreenState
    extends State<AdminRecommendationsScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _recomendaciones = [];

  bool _cargando = true;
  bool _autorizado = false;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  // ==========================================================================
  // INICIALIZAR
  // ==========================================================================

  Future<void> _inicializar() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception('No hay un usuario autenticado.');
      }

      final perfil = await _supabase
          .from('perfiles')
          .select('id_rol, roles(nombre)')
          .eq('id', user.id)
          .maybeSingle();

      if (perfil == null) {
        throw Exception('No se encontró el perfil del usuario.');
      }

      final roles = perfil['roles'];

      String? nombreRol;

      if (roles is Map) {
        nombreRol = roles['nombre']?.toString();
      }

      if (nombreRol != 'SUPER_ADMIN' && nombreRol != 'ADMINISTRADOR') {
        if (mounted) {
          setState(() {
            _autorizado = false;
            _cargando = false;
          });
        }

        return;
      }

      if (mounted) {
        setState(() {
          _autorizado = true;
        });
      }

      await _cargarRecomendaciones();
    } catch (e) {
      debugPrint(
        'Error al inicializar gestión de recomendaciones: $e',
      );

      if (mounted) {
        setState(() {
          _cargando = false;
          _autorizado = false;
        });

        _mostrarMensaje(
          'No se pudo verificar el acceso.',
          esError: true,
        );
      }
    }
  }

  // ==========================================================================
  // CARGAR TODAS LAS RECOMENDACIONES
  // ==========================================================================

  Future<void> _cargarRecomendaciones() async {
    if (!_autorizado) {
      return;
    }

    if (mounted) {
      setState(() {
        _cargando = true;
      });
    }

    try {
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
            updated_at,
            graduados(
              id,
              ci,
              perfiles(
                id,
                nombres,
                apellidos,
                telefono
              )
            )
          ''').order(
        'created_at',
        ascending: false,
      );

      if (mounted) {
        setState(() {
          _recomendaciones = List<Map<String, dynamic>>.from(resultado);

          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint(
        'Error al cargar recomendaciones: $e',
      );

      if (mounted) {
        setState(() {
          _cargando = false;
        });

        _mostrarMensaje(
          'No se pudieron cargar las recomendaciones.',
          esError: true,
        );
      }
    }
  }

  // ==========================================================================
  // CAMBIAR ESTADO
  // ==========================================================================

  Future<void> _cambiarEstado(
    Map<String, dynamic> recomendacion,
    String nuevoEstado,
  ) async {
    final id = recomendacion['id'];

    if (id == null) {
      return;
    }

    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception('No hay usuario autenticado.');
      }

      await _supabase.from('recomendaciones').update({
        'estado': nuevoEstado,
        'id_usuario_revisor': user.id,
        'fecha_revision': DateTime.now().toIso8601String(),
      }).eq(
        'id',
        id,
      );

      if (mounted) {
        _mostrarMensaje(
          'Estado actualizado correctamente.',
        );
      }

      await _cargarRecomendaciones();
    } catch (e) {
      debugPrint(
        'Error al cambiar estado: $e',
      );

      if (mounted) {
        _mostrarMensaje(
          'No se pudo actualizar el estado.',
          esError: true,
        );
      }
    }
  }

  // ==========================================================================
  // RESPONDER RECOMENDACIÓN
  // ==========================================================================

  Future<void> _responderRecomendacion(
    Map<String, dynamic> recomendacion,
  ) async {
    final controller = TextEditingController(
      text: recomendacion['respuesta_admin']?.toString() ?? '',
    );

    final respuesta = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Responder recomendación',
          ),
          content: TextField(
            controller: controller,
            maxLines: 5,
            maxLength: 1000,
            decoration: InputDecoration(
              labelText: 'Respuesta',
              hintText: 'Escribe una respuesta para el graduado...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Cancelar',
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(
                  context,
                  controller.text.trim(),
                );
              },
              icon: const Icon(
                Icons.send,
              ),
              label: const Text(
                'Guardar',
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (respuesta == null) {
      return;
    }

    if (respuesta.isEmpty) {
      _mostrarMensaje(
        'La respuesta no puede estar vacía.',
        esError: true,
      );

      return;
    }

    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception('No hay usuario autenticado.');
      }

      await _supabase.from('recomendaciones').update({
        'respuesta_admin': respuesta,
        'estado': 'REVISADA',
        'id_usuario_revisor': user.id,
        'fecha_revision': DateTime.now().toIso8601String(),
      }).eq(
        'id',
        recomendacion['id'],
      );

      if (mounted) {
        _mostrarMensaje(
          'Respuesta guardada correctamente.',
        );
      }

      await _cargarRecomendaciones();
    } catch (e) {
      debugPrint(
        'Error al responder recomendación: $e',
      );

      if (mounted) {
        _mostrarMensaje(
          'No se pudo guardar la respuesta.',
          esError: true,
        );
      }
    }
  }

  // ==========================================================================
  // DETALLE
  // ==========================================================================

  void _mostrarDetalle(
    Map<String, dynamic> recomendacion,
  ) {
    final mensaje = recomendacion['mensaje']?.toString() ?? '';

    final estado = recomendacion['estado']?.toString() ?? 'PENDIENTE';

    final respuestaAdmin = recomendacion['respuesta_admin']?.toString();

    final fecha = recomendacion['fecha'];

    final graduado = recomendacion['graduados'];

    final perfil = graduado is Map ? graduado['perfiles'] : null;

    String nombreGraduado = 'Graduado';

    if (perfil is Map) {
      final nombres = perfil['nombres']?.toString() ?? '';

      final apellidos = perfil['apellidos']?.toString() ?? '';

      nombreGraduado = '$nombres $apellidos'.trim();

      if (nombreGraduado.isEmpty) {
        nombreGraduado = 'Graduado';
      }
    }

    final ci = graduado is Map ? graduado['ci']?.toString() : null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Detalle de recomendación',
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Graduado',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 6,
                ),
                Text(nombreGraduado),
                if (ci != null && ci.isNotEmpty) ...[
                  const SizedBox(
                    height: 5,
                  ),
                  Text(
                    'CI: $ci',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                const SizedBox(
                  height: 20,
                ),
                const Text(
                  'Recomendación',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                Text(mensaje),
                const SizedBox(
                  height: 20,
                ),
                const Text(
                  'Estado',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                _EstadoChip(
                  estado: estado,
                ),
                if (fecha != null) ...[
                  const SizedBox(
                    height: 20,
                  ),
                  const Text(
                    'Fecha',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 6,
                  ),
                  Text(
                    _formatearFecha(fecha),
                  ),
                ],
                if (respuestaAdmin != null && respuestaAdmin.isNotEmpty) ...[
                  const SizedBox(
                    height: 20,
                  ),
                  const Text(
                    'Respuesta del administrador',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
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
                Navigator.pop(context);
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
  // MENÚ DE ESTADOS
  // ==========================================================================

  void _mostrarMenuEstado(
    Map<String, dynamic> recomendacion,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Cambiar estado',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.pending_outlined,
                  color: Colors.orange,
                ),
                title: const Text(
                  'Pendiente',
                ),
                onTap: () {
                  Navigator.pop(context);

                  _cambiarEstado(
                    recomendacion,
                    'PENDIENTE',
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.rate_review_outlined,
                  color: Colors.blue,
                ),
                title: const Text(
                  'Revisada',
                ),
                onTap: () {
                  Navigator.pop(context);

                  _cambiarEstado(
                    recomendacion,
                    'REVISADA',
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                ),
                title: const Text(
                  'Atendida',
                ),
                onTap: () {
                  Navigator.pop(context);

                  _cambiarEstado(
                    recomendacion,
                    'ATENDIDA',
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.cancel_outlined,
                  color: Colors.red,
                ),
                title: const Text(
                  'Descartada',
                ),
                onTap: () {
                  Navigator.pop(context);

                  _cambiarEstado(
                    recomendacion,
                    'DESCARTADA',
                  );
                },
              ),
              const SizedBox(
                height: 10,
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================================
  // OBTENER NOMBRE DEL GRADUADO
  // ==========================================================================

  String _nombreGraduado(
    Map<String, dynamic> recomendacion,
  ) {
    final graduado = recomendacion['graduados'];

    if (graduado is! Map) {
      return 'Graduado';
    }

    final perfil = graduado['perfiles'];

    if (perfil is! Map) {
      return 'Graduado';
    }

    final nombres = perfil['nombres']?.toString() ?? '';

    final apellidos = perfil['apellidos']?.toString() ?? '';

    final nombre = '$nombres $apellidos'.trim();

    return nombre.isEmpty ? 'Graduado' : nombre;
  }

  // ==========================================================================
  // FECHA
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
  // MENSAJE
  // ==========================================================================

  void _mostrarMensaje(
    String mensaje, {
    bool esError = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esError ? Colors.red : Colors.green,
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Gestión de recomendaciones',
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_autorizado) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Acceso restringido',
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 70,
                  color: Colors.red.shade400,
                ),
                const SizedBox(
                  height: 20,
                ),
                const Text(
                  'Acceso restringido',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Text(
                  'Solo los administradores pueden consultar las recomendaciones de los graduados.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Volver',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestión de recomendaciones',
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _cargarRecomendaciones,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      body: _recomendaciones.isEmpty
          ? _SinRecomendaciones()
          : RefreshIndicator(
              onRefresh: _cargarRecomendaciones,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  30,
                ),
                itemCount: _recomendaciones.length,
                itemBuilder: (
                  context,
                  index,
                ) {
                  final recomendacion = _recomendaciones[index];

                  return _RecomendacionAdminCard(
                    recomendacion: recomendacion,
                    nombreGraduado: _nombreGraduado(
                      recomendacion,
                    ),
                    onTap: () {
                      _mostrarDetalle(
                        recomendacion,
                      );
                    },
                    onResponder: () {
                      _responderRecomendacion(
                        recomendacion,
                      );
                    },
                    onCambiarEstado: () {
                      _mostrarMenuEstado(
                        recomendacion,
                      );
                    },
                    formatearFecha: _formatearFecha,
                  );
                },
              ),
            ),
    );
  }
}

// ============================================================================
// CARD ADMIN
// ============================================================================

class _RecomendacionAdminCard extends StatelessWidget {
  const _RecomendacionAdminCard({
    required this.recomendacion,
    required this.nombreGraduado,
    required this.onTap,
    required this.onResponder,
    required this.onCambiarEstado,
    required this.formatearFecha,
  });

  final Map<String, dynamic> recomendacion;
  final String nombreGraduado;

  final VoidCallback onTap;
  final VoidCallback onResponder;
  final VoidCallback onCambiarEstado;

  final String Function(dynamic) formatearFecha;

  @override
  Widget build(BuildContext context) {
    final mensaje = recomendacion['mensaje']?.toString() ?? '';

    final estado = recomendacion['estado']?.toString() ?? 'PENDIENTE';

    final fecha = recomendacion['fecha'];

    final respuesta = recomendacion['respuesta_admin']?.toString();

    return Card(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.lightbulb_outline,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombreGraduado,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        if (fecha != null)
                          Text(
                            formatearFecha(
                              fecha,
                            ),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _EstadoChip(
                    estado: estado,
                  ),
                ],
              ),
              const SizedBox(
                height: 14,
              ),
              Text(
                mensaje,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (respuesta != null && respuesta.isNotEmpty) ...[
                const SizedBox(
                  height: 12,
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(
                      10,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.reply_outlined,
                        size: 18,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      Expanded(
                        child: Text(
                          respuesta,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(
                height: 12,
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onResponder,
                      icon: const Icon(
                        Icons.reply_outlined,
                        size: 18,
                      ),
                      label: const Text(
                        'Responder',
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  IconButton(
                    tooltip: 'Cambiar estado',
                    onPressed: onCambiarEstado,
                    icon: const Icon(
                      Icons.sync_alt,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ver detalle',
                    onPressed: onTap,
                    icon: const Icon(
                      Icons.visibility_outlined,
                    ),
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
// CHIP ESTADO
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
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(30),
      children: [
        const SizedBox(
          height: 100,
        ),
        Icon(
          Icons.lightbulb_outline,
          size: 80,
          color: Colors.grey.shade400,
        ),
        const SizedBox(
          height: 20,
        ),
        Text(
          'No hay recomendaciones',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(
          height: 8,
        ),
        Text(
          'Todavía no se han registrado recomendaciones de los graduados.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
      ],
    );
  }
}
