import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateSurveyScreen extends StatefulWidget {
  const CreateSurveyScreen({super.key});

  @override
  State<CreateSurveyScreen> createState() => _CreateSurveyScreenState();
}

class _CreateSurveyScreenState extends State<CreateSurveyScreen> {
  final _supabase = Supabase.instance.client;

  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();

  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  bool _estado = true;
  bool _guardando = false;

  final List<_PreguntaFormulario> _preguntas = [];

  // ==========================================================================
  // TIPOS PERMITIDOS POR chk_tipo_pregunta
  // ==========================================================================

  static const List<String> _tiposPermitidos = [
    'TEXTO',
    'TEXTAREA',
    'NUMERO',
    'RADIO',
    'CHECKBOX',
    'SELECT',
    'ESCALA',
    'FECHA',
  ];

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();

    for (final pregunta in _preguntas) {
      pregunta.dispose();
    }

    super.dispose();
  }

  // ==========================================================================
  // AGREGAR PREGUNTA
  // ==========================================================================

  void _agregarPregunta() {
    if (_guardando) {
      return;
    }

    setState(() {
      _preguntas.add(
        _PreguntaFormulario(
          numero: _preguntas.length + 1,
        ),
      );
    });
  }

  // ==========================================================================
  // ELIMINAR PREGUNTA
  // ==========================================================================

  void _eliminarPregunta(int index) {
    if (_guardando) {
      return;
    }

    if (index < 0 || index >= _preguntas.length) {
      return;
    }

    setState(() {
      final pregunta = _preguntas.removeAt(index);
      pregunta.dispose();

      _actualizarNumeros();
    });
  }

  // ==========================================================================
  // ACTUALIZAR NÚMEROS
  // ==========================================================================

  void _actualizarNumeros() {
    for (int i = 0; i < _preguntas.length; i++) {
      _preguntas[i].numero = i + 1;
    }
  }

  // ==========================================================================
  // AGREGAR OPCIÓN
  // ==========================================================================

  void _agregarOpcion(_PreguntaFormulario pregunta) {
    if (_guardando) {
      return;
    }

    setState(() {
      pregunta.opciones.add(
        TextEditingController(),
      );
    });
  }

  // ==========================================================================
  // ELIMINAR OPCIÓN
  // ==========================================================================

  void _eliminarOpcion(
    _PreguntaFormulario pregunta,
    int index,
  ) {
    if (_guardando) {
      return;
    }

    if (index < 0 || index >= pregunta.opciones.length) {
      return;
    }

    setState(() {
      final controller = pregunta.opciones.removeAt(index);
      controller.dispose();
    });
  }

  // ==========================================================================
  // FECHA INICIO
  // ==========================================================================

  Future<void> _seleccionarFechaInicio() async {
    if (_guardando) {
      return;
    }

    final ahora = DateTime.now();

    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaInicio ?? ahora,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Selecciona la fecha de inicio',
    );

    if (fecha == null || !mounted) {
      return;
    }

    setState(() {
      _fechaInicio = fecha;

      if (_fechaFin != null && _fechaFin!.isBefore(fecha)) {
        _fechaFin = null;
      }
    });
  }

  // ==========================================================================
  // FECHA FIN
  // ==========================================================================

  Future<void> _seleccionarFechaFin() async {
    if (_guardando) {
      return;
    }

    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaFin ?? _fechaInicio ?? DateTime.now(),
      firstDate: _fechaInicio ?? DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Selecciona la fecha de finalización',
    );

    if (fecha == null || !mounted) {
      return;
    }

    setState(() {
      _fechaFin = fecha;
    });
  }

  // ==========================================================================
  // FORMATEAR FECHA
  // ==========================================================================

  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) {
      return 'Sin fecha';
    }

    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');

    return '$dia/$mes/${fecha.year}';
  }

  // ==========================================================================
  // NORMALIZAR TIPO
  // ==========================================================================

  String _normalizarTipo(String tipo) {
    return tipo.trim().toUpperCase();
  }

  // ==========================================================================
  // SABER SI EL TIPO ES VÁLIDO
  // ==========================================================================

  bool _tipoValido(String tipo) {
    final tipoNormalizado = _normalizarTipo(tipo);

    return _tiposPermitidos.contains(tipoNormalizado);
  }

  // ==========================================================================
  // GUARDAR ENCUESTA
  // ==========================================================================

  Future<void> _guardarEncuesta() async {
    if (_guardando) {
      return;
    }

    FocusScope.of(context).unfocus();

    final titulo = _tituloController.text.trim();
    final descripcion = _descripcionController.text.trim();

    // ------------------------------------------------------------------------
    // VALIDAR TÍTULO
    // ------------------------------------------------------------------------

    if (titulo.isEmpty) {
      _mostrarMensaje(
        'Debes ingresar el título de la encuesta.',
        esError: true,
      );
      return;
    }

    // ------------------------------------------------------------------------
    // VALIDAR FECHAS
    // ------------------------------------------------------------------------

    if (_fechaInicio != null &&
        _fechaFin != null &&
        _fechaFin!.isBefore(_fechaInicio!)) {
      _mostrarMensaje(
        'La fecha final no puede ser anterior a la fecha inicial.',
        esError: true,
      );
      return;
    }

    // ------------------------------------------------------------------------
    // VALIDAR PREGUNTAS
    // ------------------------------------------------------------------------

    if (_preguntas.isEmpty) {
      _mostrarMensaje(
        'Debes agregar al menos una pregunta.',
        esError: true,
      );
      return;
    }

    // ------------------------------------------------------------------------
    // VALIDAR CADA PREGUNTA
    // ------------------------------------------------------------------------

    for (int i = 0; i < _preguntas.length; i++) {
      final pregunta = _preguntas[i];

      final textoPregunta = pregunta.preguntaController.text.trim();

      final tipoPregunta = _normalizarTipo(pregunta.tipo);

      // ----------------------------------------------------------------------
      // TEXTO
      // ----------------------------------------------------------------------

      if (textoPregunta.isEmpty) {
        _mostrarMensaje(
          'La pregunta ${i + 1} no tiene texto.',
          esError: true,
        );
        return;
      }

      // ----------------------------------------------------------------------
      // TIPO
      // ----------------------------------------------------------------------

      if (!_tipoValido(tipoPregunta)) {
        _mostrarMensaje(
          'El tipo de la pregunta ${i + 1} no es válido: $tipoPregunta',
          esError: true,
        );
        return;
      }

      // ----------------------------------------------------------------------
      // OPCIONES
      // ----------------------------------------------------------------------

      if (_necesitaOpciones(tipoPregunta)) {
        final opcionesValidas = pregunta.opciones
            .map(
              (controller) => controller.text.trim(),
            )
            .where(
              (texto) => texto.isNotEmpty,
            )
            .toList();

        if (opcionesValidas.isEmpty) {
          _mostrarMensaje(
            'La pregunta ${i + 1} necesita al menos una opción.',
            esError: true,
          );
          return;
        }
      }

      // ----------------------------------------------------------------------
      // ESCALA
      // ----------------------------------------------------------------------

      if (tipoPregunta == 'ESCALA') {
        if (pregunta.valorMinimo < 0 ||
            pregunta.valorMaximo <= pregunta.valorMinimo) {
          _mostrarMensaje(
            'La escala de la pregunta ${i + 1} no es válida.',
            esError: true,
          );
          return;
        }
      }
    }

    setState(() {
      _guardando = true;
    });

    try {
      // ======================================================================
      // USUARIO
      // ======================================================================

      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception(
          'No hay un usuario autenticado.',
        );
      }

      debugPrint(
        '============================================================',
      );
      debugPrint(
        'CREANDO ENCUESTA',
      );
      debugPrint(
        'Título: $titulo',
      );
      debugPrint(
        'Cantidad de preguntas: ${_preguntas.length}',
      );
      debugPrint(
        '============================================================',
      );

      // ======================================================================
      // 1. CREAR ENCUESTA
      // ======================================================================

      final encuesta = await _supabase
          .from('encuestas')
          .insert({
            'titulo': titulo,
            'descripcion': descripcion.isEmpty ? null : descripcion,
            'fecha_inicio': _fechaInicio == null
                ? null
                : _fechaInicio!.toIso8601String().split('T').first,
            'fecha_fin': _fechaFin == null
                ? null
                : _fechaFin!.toIso8601String().split('T').first,
            'estado': _estado,
            'id_usuario_creador': user.id,
          })
          .select('id')
          .single();

      final encuestaId = encuesta['id'].toString();

      debugPrint(
        'Encuesta creada. ID: $encuestaId',
      );

      // ======================================================================
      // 2. CREAR PREGUNTAS
      // ======================================================================

      for (int i = 0; i < _preguntas.length; i++) {
        final preguntaFormulario = _preguntas[i];

        final tipoPregunta = _normalizarTipo(preguntaFormulario.tipo);

        final textoPregunta = preguntaFormulario.preguntaController.text.trim();

        debugPrint(
          '------------------------------------------------------------',
        );
        debugPrint(
          'Guardando pregunta ${i + 1}',
        );
        debugPrint(
          'Texto: $textoPregunta',
        );
        debugPrint(
          'Tipo enviado a Supabase: [$tipoPregunta]',
        );
        debugPrint(
          'Tipo válido: ${_tipoValido(tipoPregunta)}',
        );

        // --------------------------------------------------------------------
        // INSERTAR PREGUNTA
        // --------------------------------------------------------------------

        final pregunta = await _supabase
            .from('preguntas')
            .insert({
              'id_encuesta': encuestaId,
              'pregunta': textoPregunta,

              // IMPORTANTE:
              // Se manda exactamente uno de los valores permitidos
              // por chk_tipo_pregunta.
              'tipo': tipoPregunta,

              'obligatoria': preguntaFormulario.obligatoria,

              'orden': i + 1,

              'valor_minimo': tipoPregunta == 'ESCALA'
                  ? preguntaFormulario.valorMinimo
                  : null,

              'valor_maximo': tipoPregunta == 'ESCALA'
                  ? preguntaFormulario.valorMaximo
                  : null,

              'etiqueta_minimo': tipoPregunta == 'ESCALA' &&
                      preguntaFormulario.etiquetaMinimoController.text
                          .trim()
                          .isNotEmpty
                  ? preguntaFormulario.etiquetaMinimoController.text.trim()
                  : null,

              'etiqueta_maximo': tipoPregunta == 'ESCALA' &&
                      preguntaFormulario.etiquetaMaximoController.text
                          .trim()
                          .isNotEmpty
                  ? preguntaFormulario.etiquetaMaximoController.text.trim()
                  : null,
            })
            .select('id')
            .single();

        final preguntaId = pregunta['id'].toString();

        debugPrint(
          'Pregunta creada. ID: $preguntaId',
        );

        // ====================================================================
        // 3. CREAR OPCIONES
        // ====================================================================

        if (_necesitaOpciones(tipoPregunta)) {
          final opciones = preguntaFormulario.opciones
              .map(
                (controller) => controller.text.trim(),
              )
              .where(
                (texto) => texto.isNotEmpty,
              )
              .toList();

          debugPrint(
            'Opciones: ${opciones.length}',
          );

          for (int j = 0; j < opciones.length; j++) {
            await _supabase.from('opciones_pregunta').insert({
              'id_pregunta': preguntaId,
              'opcion': opciones[j],
              'orden': j + 1,
            });

            debugPrint(
              'Opción ${j + 1} creada.',
            );
          }
        }
      }

      // ======================================================================
      // ÉXITO
      // ======================================================================

      if (!mounted) {
        return;
      }

      setState(() {
        _guardando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Encuesta creada correctamente.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint(
        '============================================================',
      );
      debugPrint(
        'ERROR AL CREAR ENCUESTA',
      );
      debugPrint(
        '$e',
      );
      debugPrint(
        '============================================================',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _guardando = false;
      });

      _mostrarMensaje(
        'No se pudo crear la encuesta: $e',
        esError: true,
      );
    }
  }

  // ==========================================================================
  // SABER SI NECESITA OPCIONES
  // ==========================================================================

  bool _necesitaOpciones(String tipo) {
    final tipoNormalizado = _normalizarTipo(tipo);

    return tipoNormalizado == 'RADIO' ||
        tipoNormalizado == 'CHECKBOX' ||
        tipoNormalizado == 'SELECT';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Crear encuesta',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(
              right: 12,
            ),
            child: ElevatedButton.icon(
              onPressed: _guardando ? null : _guardarEncuesta,
              icon: _guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.save_outlined,
                    ),
              label: Text(
                _guardando ? 'Guardando...' : 'Guardar',
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 900,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // =============================================================
                // INFORMACIÓN DE ENCUESTA
                // =============================================================

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Información de la encuesta',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),

                        const SizedBox(height: 20),

                        // -----------------------------------------------------
                        // TÍTULO
                        // -----------------------------------------------------

                        TextField(
                          controller: _tituloController,
                          textCapitalization: TextCapitalization.sentences,
                          enabled: !_guardando,
                          decoration: const InputDecoration(
                            labelText: 'Título',
                            hintText: 'Ej. Encuesta de seguimiento a graduados',
                            prefixIcon: Icon(
                              Icons.title,
                            ),
                            border: OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // -----------------------------------------------------
                        // DESCRIPCIÓN
                        // -----------------------------------------------------

                        TextField(
                          controller: _descripcionController,
                          textCapitalization: TextCapitalization.sentences,
                          maxLines: 4,
                          enabled: !_guardando,
                          decoration: const InputDecoration(
                            labelText: 'Descripción',
                            hintText: 'Describe el objetivo de la encuesta',
                            prefixIcon: Icon(
                              Icons.description_outlined,
                            ),
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // -----------------------------------------------------
                        // FECHAS
                        // -----------------------------------------------------

                        Row(
                          children: [
                            Expanded(
                              child: Card(
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.calendar_today_outlined,
                                  ),
                                  title: const Text(
                                    'Fecha de inicio',
                                  ),
                                  subtitle: Text(
                                    _formatearFecha(
                                      _fechaInicio,
                                    ),
                                  ),
                                  onTap: _guardando
                                      ? null
                                      : _seleccionarFechaInicio,
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child: Card(
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.event_outlined,
                                  ),
                                  title: const Text(
                                    'Fecha de finalización',
                                  ),
                                  subtitle: Text(
                                    _formatearFecha(
                                      _fechaFin,
                                    ),
                                  ),
                                  onTap:
                                      _guardando ? null : _seleccionarFechaFin,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // -----------------------------------------------------
                        // ESTADO
                        // -----------------------------------------------------

                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Encuesta activa',
                          ),
                          subtitle: Text(
                            _estado
                                ? 'Los graduados podrán responderla cuando esté dentro del periodo.'
                                : 'La encuesta estará desactivada.',
                          ),
                          value: _estado,
                          onChanged: _guardando
                              ? null
                              : (valor) {
                                  setState(() {
                                    _estado = valor;
                                  });
                                },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // =============================================================
                // PREGUNTAS
                // =============================================================

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Preguntas',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _guardando ? null : _agregarPregunta,
                      icon: const Icon(
                        Icons.add,
                      ),
                      label: const Text(
                        'Agregar pregunta',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                if (_preguntas.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        children: [
                          Icon(
                            Icons.help_outline,
                            size: 60,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(
                            height: 12,
                          ),
                          Text(
                            'Todavía no hay preguntas',
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(
                            height: 6,
                          ),
                          Text(
                            'Agrega preguntas para construir tu encuesta.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(
                            height: 18,
                          ),
                          ElevatedButton.icon(
                            onPressed: _guardando ? null : _agregarPregunta,
                            icon: const Icon(
                              Icons.add,
                            ),
                            label: const Text(
                              'Agregar primera pregunta',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // =============================================================
                // LISTA DE PREGUNTAS
                // =============================================================

                ...List.generate(
                  _preguntas.length,
                  (index) {
                    return _construirPregunta(
                      index,
                      _preguntas[index],
                    );
                  },
                ),

                const SizedBox(height: 30),

                // =============================================================
                // GUARDAR
                // =============================================================

                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _guardando ? null : _guardarEncuesta,
                    icon: _guardando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.save_outlined,
                          ),
                    label: Text(
                      _guardando ? 'Guardando encuesta...' : 'Guardar encuesta',
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // CONSTRUIR PREGUNTA
  // ==========================================================================

  Widget _construirPregunta(
    int index,
    _PreguntaFormulario pregunta,
  ) {
    final tipoActual = _normalizarTipo(pregunta.tipo);

    return Card(
      margin: const EdgeInsets.only(
        bottom: 16,
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =================================================================
            // CABECERA
            // =================================================================

            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${pregunta.numero}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pregunta ${pregunta.numero}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Eliminar pregunta',
                  onPressed: _guardando
                      ? null
                      : () {
                          _eliminarPregunta(
                            index,
                          );
                        },
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // =================================================================
            // TEXTO DE PREGUNTA
            // =================================================================

            TextField(
              controller: pregunta.preguntaController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              enabled: !_guardando,
              decoration: const InputDecoration(
                labelText: 'Pregunta',
                hintText: 'Escribe aquí la pregunta...',
                prefixIcon: Icon(
                  Icons.help_outline,
                ),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 16),

            // =================================================================
            // TIPO
            // =================================================================

            DropdownButtonFormField<String>(
              value: tipoActual,
              decoration: const InputDecoration(
                labelText: 'Tipo de pregunta',
                prefixIcon: Icon(
                  Icons.category_outlined,
                ),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'TEXTO',
                  child: Text('Texto corto'),
                ),
                DropdownMenuItem(
                  value: 'TEXTAREA',
                  child: Text('Texto largo'),
                ),
                DropdownMenuItem(
                  value: 'NUMERO',
                  child: Text('Número'),
                ),
                DropdownMenuItem(
                  value: 'RADIO',
                  child: Text('Una opción'),
                ),
                DropdownMenuItem(
                  value: 'CHECKBOX',
                  child: Text(
                    'Varias opciones',
                  ),
                ),
                DropdownMenuItem(
                  value: 'SELECT',
                  child: Text(
                    'Lista desplegable',
                  ),
                ),
                DropdownMenuItem(
                  value: 'ESCALA',
                  child: Text('Escala'),
                ),
                DropdownMenuItem(
                  value: 'FECHA',
                  child: Text('Fecha'),
                ),
              ],
              onChanged: _guardando
                  ? null
                  : (valor) {
                      if (valor == null) {
                        return;
                      }

                      setState(() {
                        pregunta.tipo = _normalizarTipo(
                          valor,
                        );
                      });
                    },
            ),

            const SizedBox(height: 8),

            // =================================================================
            // OBLIGATORIA
            // =================================================================

            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Pregunta obligatoria',
              ),
              subtitle: const Text(
                'El graduado deberá responder esta pregunta.',
              ),
              value: pregunta.obligatoria,
              onChanged: _guardando
                  ? null
                  : (valor) {
                      setState(() {
                        pregunta.obligatoria = valor ?? false;
                      });
                    },
            ),

            // =================================================================
            // OPCIONES
            // =================================================================

            if (_necesitaOpciones(tipoActual))
              _construirOpciones(
                pregunta,
              ),

            // =================================================================
            // ESCALA
            // =================================================================

            if (tipoActual == 'ESCALA')
              _construirEscala(
                pregunta,
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // CONSTRUIR OPCIONES
  // ==========================================================================

  Widget _construirOpciones(
    _PreguntaFormulario pregunta,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Opciones de respuesta',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        ...List.generate(
          pregunta.opciones.length,
          (index) {
            return Padding(
              padding: const EdgeInsets.only(
                bottom: 8,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey.shade200,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: pregunta.opciones[index],
                      textCapitalization: TextCapitalization.sentences,
                      enabled: !_guardando,
                      decoration: InputDecoration(
                        labelText: 'Opción ${index + 1}',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Eliminar opción',
                    onPressed: _guardando
                        ? null
                        : () {
                            _eliminarOpcion(
                              pregunta,
                              index,
                            );
                          },
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: _guardando
              ? null
              : () {
                  _agregarOpcion(
                    pregunta,
                  );
                },
          icon: const Icon(
            Icons.add,
          ),
          label: const Text(
            'Agregar opción',
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // CONSTRUIR ESCALA
  // ==========================================================================

  Widget _construirEscala(
    _PreguntaFormulario pregunta,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Configuración de escala',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: pregunta.valorMinimoController,
                keyboardType: TextInputType.number,
                enabled: !_guardando,
                decoration: const InputDecoration(
                  labelText: 'Valor mínimo',
                  border: OutlineInputBorder(),
                ),
                onChanged: (valor) {
                  pregunta.valorMinimo = int.tryParse(valor) ?? 0;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: pregunta.valorMaximoController,
                keyboardType: TextInputType.number,
                enabled: !_guardando,
                decoration: const InputDecoration(
                  labelText: 'Valor máximo',
                  border: OutlineInputBorder(),
                ),
                onChanged: (valor) {
                  pregunta.valorMaximo = int.tryParse(valor) ?? 5;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: pregunta.etiquetaMinimoController,
          enabled: !_guardando,
          decoration: const InputDecoration(
            labelText: 'Etiqueta del mínimo',
            hintText: 'Ej. Muy malo',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: pregunta.etiquetaMaximoController,
          enabled: !_guardando,
          decoration: const InputDecoration(
            labelText: 'Etiqueta del máximo',
            hintText: 'Ej. Excelente',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// MODELO TEMPORAL DE PREGUNTA
// ============================================================================

class _PreguntaFormulario {
  _PreguntaFormulario({
    required this.numero,
  }) {
    valorMinimoController = TextEditingController(
      text: valorMinimo.toString(),
    );

    valorMaximoController = TextEditingController(
      text: valorMaximo.toString(),
    );
  }

  int numero;

  String tipo = 'TEXTO';

  bool obligatoria = false;

  int valorMinimo = 1;

  int valorMaximo = 5;

  final TextEditingController preguntaController = TextEditingController();

  final TextEditingController etiquetaMinimoController =
      TextEditingController();

  final TextEditingController etiquetaMaximoController =
      TextEditingController();

  late final TextEditingController valorMinimoController;

  late final TextEditingController valorMaximoController;

  final List<TextEditingController> opciones = [];

  void dispose() {
    preguntaController.dispose();

    etiquetaMinimoController.dispose();

    etiquetaMaximoController.dispose();

    valorMinimoController.dispose();

    valorMaximoController.dispose();

    for (final opcion in opciones) {
      opcion.dispose();
    }
  }
}
