import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();

  // Datos personales
  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _ciController = TextEditingController();

  // Datos académicos
  final _anioIngresoController = TextEditingController();
  final _anioEgresoController = TextEditingController();
  final _anioTitulacionController = TextEditingController();
  final _modalidadController = TextEditingController();

  // Datos de ubicación
  final _ciudadController = TextEditingController();
  final _departamentoController = TextEditingController();
  final _direccionController = TextEditingController();
  final _linkedinController = TextEditingController();

  DateTime? _fechaNacimiento;

  String _rol = 'GRADUADO';

  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  @override
  void dispose() {
    _nombresController.dispose();
    _apellidosController.dispose();
    _telefonoController.dispose();
    _ciController.dispose();

    _anioIngresoController.dispose();
    _anioEgresoController.dispose();
    _anioTitulacionController.dispose();
    _modalidadController.dispose();

    _ciudadController.dispose();
    _departamentoController.dispose();
    _direccionController.dispose();
    _linkedinController.dispose();

    super.dispose();
  }

  // ==========================================================================
  // CARGAR PERFIL
  // ==========================================================================

  Future<void> _cargarPerfil() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception('No hay un usuario autenticado.');
      }

      final perfil = await _supabase.from('perfiles').select('''
            nombres,
            apellidos,
            telefono,
            id_rol,
            roles (
              nombre
            ),
            graduados (
              ci,
              fecha_nacimiento,
              año_ingreso,
              año_egreso,
              año_titulacion,
              modalidad_titulacion,
              ciudad,
              departamento,
              direccion,
              linkedin
            )
          ''').eq('id', user.id).maybeSingle();

      if (perfil == null) {
        throw Exception('No se encontró el perfil del usuario.');
      }

      final graduado = perfil['graduados'];

      _nombresController.text = perfil['nombres']?.toString() ?? '';

      _apellidosController.text = perfil['apellidos']?.toString() ?? '';

      _telefonoController.text = perfil['telefono']?.toString() ?? '';

      if (perfil['roles'] is Map) {
        _rol = (perfil['roles']['nombre'] ?? 'GRADUADO').toString();
      }

      if (graduado is Map) {
        _ciController.text = graduado['ci']?.toString() ?? '';

        _anioIngresoController.text = graduado['año_ingreso']?.toString() ?? '';

        _anioEgresoController.text = graduado['año_egreso']?.toString() ?? '';

        _anioTitulacionController.text =
            graduado['año_titulacion']?.toString() ?? '';

        _modalidadController.text =
            graduado['modalidad_titulacion']?.toString() ?? '';

        _ciudadController.text = graduado['ciudad']?.toString() ?? '';

        _departamentoController.text =
            graduado['departamento']?.toString() ?? '';

        _direccionController.text = graduado['direccion']?.toString() ?? '';

        _linkedinController.text = graduado['linkedin']?.toString() ?? '';

        final fecha = graduado['fecha_nacimiento'];

        if (fecha != null) {
          _fechaNacimiento = DateTime.tryParse(
            fecha.toString(),
          );
        }
      }

      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar perfil: $e');

      if (mounted) {
        setState(() {
          _cargando = false;
        });

        _mostrarMensaje(
          'No se pudo cargar el perfil.',
          esError: true,
        );
      }
    }
  }

  // ==========================================================================
  // GUARDAR PERFIL
  // ==========================================================================
  Future<void> _guardarPerfil() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = _supabase.auth.currentUser;

    if (user == null) {
      _mostrarMensaje(
        'No hay un usuario autenticado.',
        esError: true,
      );
      return;
    }

    // ==========================================================
    // CONVERTIR AÑOS
    // ==========================================================

    final anioIngreso = _convertirEntero(
      _anioIngresoController.text,
    );

    final anioEgreso = _convertirEntero(
      _anioEgresoController.text,
    );

    final anioTitulacion = _convertirEntero(
      _anioTitulacionController.text,
    );

    // ==========================================================
    // VALIDAR AÑOS
    // ==========================================================

    if (anioIngreso != null && anioIngreso < 1900) {
      _mostrarMensaje(
        'El año de ingreso debe ser igual o mayor a 1900.',
        esError: true,
      );
      return;
    }

    if (anioEgreso != null && anioEgreso < 1900) {
      _mostrarMensaje(
        'El año de egreso debe ser igual o mayor a 1900.',
        esError: true,
      );
      return;
    }

    if (anioTitulacion != null && anioTitulacion < 1900) {
      _mostrarMensaje(
        'El año de titulación debe ser igual o mayor a 1900.',
        esError: true,
      );
      return;
    }

    if (anioIngreso != null && anioEgreso != null && anioEgreso < anioIngreso) {
      _mostrarMensaje(
        'El año de egreso no puede ser menor que el año de ingreso.',
        esError: true,
      );
      return;
    }

    if (anioEgreso != null &&
        anioTitulacion != null &&
        anioTitulacion < anioEgreso) {
      _mostrarMensaje(
        'El año de titulación no puede ser menor que el año de egreso.',
        esError: true,
      );
      return;
    }

    setState(() {
      _guardando = true;
    });

    try {
      // ========================================================
      // ACTUALIZAR PERFIL
      // ========================================================

      await _supabase.from('perfiles').update({
        'nombres': _nombresController.text.trim(),
        'apellidos': _apellidosController.text.trim(),
        'telefono': _telefonoController.text.trim().isEmpty
            ? null
            : _telefonoController.text.trim(),
      }).eq('id', user.id);

      // ========================================================
      // COMPROBAR SI EXISTE EL GRADUADO
      // ========================================================

      final graduadoExiste = await _supabase
          .from('graduados')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      // ========================================================
      // DATOS DEL GRADUADO
      // ========================================================

      final datosGraduado = {
        'id': user.id,
        'ci': _ciController.text.trim().isEmpty
            ? null
            : _ciController.text.trim(),
        'fecha_nacimiento':
            _fechaNacimiento?.toIso8601String().split('T').first,
        'año_ingreso': anioIngreso,
        'año_egreso': anioEgreso,
        'año_titulacion': anioTitulacion,
        'modalidad_titulacion': _modalidadController.text.trim().isEmpty
            ? null
            : _modalidadController.text.trim(),
        'ciudad': _ciudadController.text.trim().isEmpty
            ? null
            : _ciudadController.text.trim(),
        'departamento': _departamentoController.text.trim().isEmpty
            ? null
            : _departamentoController.text.trim(),
        'direccion': _direccionController.text.trim().isEmpty
            ? null
            : _direccionController.text.trim(),
        'linkedin': _linkedinController.text.trim().isEmpty
            ? null
            : _linkedinController.text.trim(),
      };

      // ========================================================
      // INSERTAR O ACTUALIZAR
      // ========================================================

      if (graduadoExiste == null) {
        await _supabase.from('graduados').insert(datosGraduado);
      } else {
        await _supabase
            .from('graduados')
            .update(datosGraduado)
            .eq('id', user.id);
      }

      if (mounted) {
        _mostrarMensaje(
          'Perfil actualizado correctamente.',
        );
      }
    } catch (e) {
      debugPrint('Error al guardar perfil: $e');

      if (mounted) {
        _mostrarMensaje(
          'No se pudo actualizar el perfil: $e',
          esError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  // ==========================================================================
  // FECHA DE NACIMIENTO
  // ==========================================================================

  Future<void> _seleccionarFecha() async {
    final ahora = DateTime.now();

    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ??
          DateTime(
            ahora.year - 25,
            ahora.month,
            ahora.day,
          ),
      firstDate: DateTime(1900),
      lastDate: ahora,
      helpText: 'Selecciona tu fecha de nacimiento',
    );

    if (fecha != null) {
      setState(() {
        _fechaNacimiento = fecha;
      });
    }
  }

  // ==========================================================================
  // UTILIDADES
  // ==========================================================================

  int? _convertirEntero(String valor) {
    final texto = valor.trim();

    if (texto.isEmpty) {
      return null;
    }

    return int.tryParse(texto);
  }

  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) {
      return 'Seleccionar fecha';
    }

    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';
  }

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
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ==========================================================
                  // ENCABEZADO
                  // ==========================================================

                  _ProfileHeader(
                    nombre:
                        '${_nombresController.text} ${_apellidosController.text}'
                            .trim(),
                    rol: _rol,
                  ),

                  const SizedBox(height: 24),

                  // ==========================================================
                  // DATOS PERSONALES
                  // ==========================================================

                  const _SectionTitle(
                    icon: Icons.person_outline,
                    title: 'Datos personales',
                  ),

                  const SizedBox(height: 12),

                  _campoTexto(
                    controller: _nombresController,
                    label: 'Nombres',
                    icon: Icons.person_outline,
                    obligatorio: true,
                  ),

                  _campoTexto(
                    controller: _apellidosController,
                    label: 'Apellidos',
                    icon: Icons.person_outline,
                    obligatorio: true,
                  ),

                  _campoTexto(
                    controller: _telefonoController,
                    label: 'Teléfono',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),

                  _campoTexto(
                    controller: _ciController,
                    label: 'Carnet de Identidad',
                    icon: Icons.badge_outlined,
                  ),

                  const SizedBox(height: 20),

                  // ==========================================================
                  // DATOS ACADÉMICOS
                  // ==========================================================

                  const _SectionTitle(
                    icon: Icons.school_outlined,
                    title: 'Datos académicos',
                  ),

                  const SizedBox(height: 12),

                  _campoTexto(
                    controller: _anioIngresoController,
                    label: 'Año de ingreso',
                    icon: Icons.calendar_today_outlined,
                    keyboardType: TextInputType.number,
                  ),

                  _campoTexto(
                    controller: _anioEgresoController,
                    label: 'Año de egreso',
                    icon: Icons.calendar_month_outlined,
                    keyboardType: TextInputType.number,
                  ),

                  _campoTexto(
                    controller: _anioTitulacionController,
                    label: 'Año de titulación',
                    icon: Icons.workspace_premium_outlined,
                    keyboardType: TextInputType.number,
                  ),

                  _campoTexto(
                    controller: _modalidadController,
                    label: 'Modalidad de titulación',
                    icon: Icons.school_outlined,
                  ),

                  const SizedBox(height: 20),

                  // ==========================================================
                  // FECHA DE NACIMIENTO
                  // ==========================================================

                  const _SectionTitle(
                    icon: Icons.cake_outlined,
                    title: 'Fecha de nacimiento',
                  ),

                  const SizedBox(height: 12),

                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.calendar_today_outlined,
                      ),
                      title: const Text(
                        'Fecha de nacimiento',
                      ),
                      subtitle: Text(
                        _formatearFecha(
                          _fechaNacimiento,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                      ),
                      onTap: _seleccionarFecha,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==========================================================
                  // UBICACIÓN
                  // ==========================================================

                  const _SectionTitle(
                    icon: Icons.location_on_outlined,
                    title: 'Ubicación',
                  ),

                  const SizedBox(height: 12),

                  _campoTexto(
                    controller: _ciudadController,
                    label: 'Ciudad',
                    icon: Icons.location_city_outlined,
                  ),

                  _campoTexto(
                    controller: _departamentoController,
                    label: 'Departamento',
                    icon: Icons.map_outlined,
                  ),

                  _campoTexto(
                    controller: _direccionController,
                    label: 'Dirección',
                    icon: Icons.home_outlined,
                  ),

                  const SizedBox(height: 20),

                  // ==========================================================
                  // INFORMACIÓN PROFESIONAL
                  // ==========================================================

                  const _SectionTitle(
                    icon: Icons.work_outline,
                    title: 'Información profesional',
                  ),

                  const SizedBox(height: 12),

                  _campoTexto(
                    controller: _linkedinController,
                    label: 'LinkedIn',
                    icon: Icons.link,
                    keyboardType: TextInputType.url,
                  ),

                  const SizedBox(height: 30),

                  // ==========================================================
                  // BOTÓN GUARDAR
                  // ==========================================================

                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _guardando ? null : _guardarPerfil,
                      icon: _guardando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.save_outlined,
                            ),
                      label: Text(
                        _guardando ? 'Guardando...' : 'Guardar cambios',
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  // ==========================================================================
  // CAMPO DE TEXTO
  // ==========================================================================

  Widget _campoTexto({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obligatorio = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 14,
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        validator: obligatorio
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Este campo es obligatorio';
                }

                return null;
              }
            : null,
      ),
    );
  }
}

// ============================================================================
// ENCABEZADO DEL PERFIL
// ============================================================================

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.nombre,
    required this.rol,
  });

  final String nombre;
  final String rol;

  @override
  Widget build(BuildContext context) {
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U';

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 42,
              child: Text(
                inicial,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              nombre.isEmpty ? 'Usuario' : nombre,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                rol,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
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
// TÍTULO DE SECCIÓN
// ============================================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}
