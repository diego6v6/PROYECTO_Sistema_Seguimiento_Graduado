import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnswerSurveyScreen extends StatefulWidget {
  const AnswerSurveyScreen({
    super.key,
    required this.encuestaId,
  });

  final String encuestaId;

  @override
  State<AnswerSurveyScreen> createState() => _AnswerSurveyScreenState();
}

class _AnswerSurveyScreenState extends State<AnswerSurveyScreen> {
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _encuesta;

  List<Map<String, dynamic>> _preguntas = [];

  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, String?> _selectedOptions = {};
  final Map<String, Set<String>> _selectedMultipleOptions = {};
  final Map<String, int> _scaleValues = {};
  final Map<String, DateTime?> _dateValues = {};
  final Map<String, String?> _errors = {};

  String? _respuestaEncuestaId;

  bool _cargando = true;
  bool _guardando = false;
  bool _yaCompletada = false;

  @override
  void initState() {
    super.initState();
    _cargarEncuesta();
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  // ==========================================================================
  // CARGAR ENCUESTA
  // ==========================================================================

  Future<void> _cargarEncuesta() async {
    if (!mounted) return;

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

      debugPrint('==========================================');
      debugPrint('USUARIO AUTH: ${user.id}');
      debugPrint('ENCUESTA: ${widget.encuestaId}');
      debugPrint('==========================================');

      // ----------------------------------------------------------------------
      // COMPROBAR QUE EL USUARIO ES GRADUADO
      // ----------------------------------------------------------------------

      final graduado = await _supabase
          .from('graduados')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (graduado == null) {
        throw Exception(
          'El usuario autenticado no tiene un registro en la tabla graduados.',
        );
      }

      debugPrint(
        'GRADUADO EN BD: ${graduado['id']}',
      );

      // ----------------------------------------------------------------------
      // CARGAR ENCUESTA
      // ----------------------------------------------------------------------

      final encuesta = await _supabase
          .from('encuestas')
          .select('''
            id,
            titulo,
            descripcion,
            fecha_inicio,
            fecha_fin,
            estado
          ''')
          .eq(
            'id',
            widget.encuestaId,
          )
          .maybeSingle();

      if (encuesta == null) {
        throw Exception(
          'La encuesta no existe o no tienes permiso para verla.',
        );
      }

      debugPrint(
        'ENCUESTA CARGADA: $encuesta',
      );

      // ----------------------------------------------------------------------
      // COMPROBAR ESTADO DE ENCUESTA
      // ----------------------------------------------------------------------

      final estadoEncuesta = encuesta['estado'] == true;

      if (!estadoEncuesta) {
        throw Exception(
          'La encuesta está desactivada.',
        );
      }

      final hoy = DateTime.now();

      final fechaInicioTexto = encuesta['fecha_inicio']?.toString();
      final fechaFinTexto = encuesta['fecha_fin']?.toString();

      if (fechaInicioTexto != null && fechaInicioTexto.isNotEmpty) {
        final fechaInicio = DateTime.tryParse(
          fechaInicioTexto,
        );

        if (fechaInicio != null &&
            DateTime(
              hoy.year,
              hoy.month,
              hoy.day,
            ).isBefore(
              DateTime(
                fechaInicio.year,
                fechaInicio.month,
                fechaInicio.day,
              ),
            )) {
          throw Exception(
            'La encuesta todavía no está disponible.',
          );
        }
      }

      if (fechaFinTexto != null && fechaFinTexto.isNotEmpty) {
        final fechaFin = DateTime.tryParse(
          fechaFinTexto,
        );

        if (fechaFin != null &&
            DateTime(
              hoy.year,
              hoy.month,
              hoy.day,
            ).isAfter(
              DateTime(
                fechaFin.year,
                fechaFin.month,
                fechaFin.day,
              ),
            )) {
          throw Exception(
            'El periodo de la encuesta ya terminó.',
          );
        }
      }

      // ----------------------------------------------------------------------
      // CARGAR PREGUNTAS
      // ----------------------------------------------------------------------

      final preguntas = await _supabase
          .from('preguntas')
          .select('''
            id,
            id_encuesta,
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
          ''')
          .eq(
            'id_encuesta',
            widget.encuestaId,
          )
          .order('orden');

      final listaPreguntas = List<Map<String, dynamic>>.from(preguntas);

      if (listaPreguntas.isEmpty) {
        throw Exception(
          'La encuesta no tiene preguntas.',
        );
      }

      // ----------------------------------------------------------------------
      // PREPARAR CONTROLES
      // ----------------------------------------------------------------------

      for (final pregunta in listaPreguntas) {
        final id = pregunta['id'].toString();
        final tipo = pregunta['tipo']?.toString();

        if (_esTexto(tipo)) {
          _textControllers.putIfAbsent(
            id,
            () => TextEditingController(),
          );
        }

        if (tipo == 'CHECKBOX') {
          _selectedMultipleOptions[id] = <String>{};
        }

        if (tipo == 'ESCALA') {
          final minimo = _numero(pregunta['valor_minimo']) ?? 1;

          _scaleValues[id] = minimo;
        }

        if (tipo == 'FECHA') {
          _dateValues[id] = null;
        }
      }

      // ----------------------------------------------------------------------
      // BUSCAR RESPUESTA EXISTENTE
      // ----------------------------------------------------------------------

      final respuestaExistente = await _supabase
          .from('respuestas_encuesta')
          .select('id, estado, fecha_respuesta')
          .eq(
            'id_encuesta',
            widget.encuestaId,
          )
          .eq(
            'id_graduado',
            user.id,
          )
          .maybeSingle();

      if (respuestaExistente != null) {
        final respuestaId = respuestaExistente['id']?.toString();

        final estado = respuestaExistente['estado']?.toString();

        debugPrint(
          'RESPUESTA EXISTENTE: $respuestaExistente',
        );

        if (respuestaId != null) {
          _respuestaEncuestaId = respuestaId;
        }

        if (estado == 'COMPLETADA') {
          _yaCompletada = true;
        }

        if (respuestaId != null) {
          await _cargarRespuestasExistentes(
            respuestaId,
            listaPreguntas,
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _encuesta = Map<String, dynamic>.from(encuesta);

        _preguntas = listaPreguntas;

        _cargando = false;
      });
    } catch (e, stackTrace) {
      debugPrint(
        'ERROR AL CARGAR ENCUESTA: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (!mounted) return;

      setState(() {
        _cargando = false;
      });

      _mostrarMensaje(
        e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
        esError: true,
      );
    }
  }

  // ==========================================================================
  // CARGAR RESPUESTAS EXISTENTES
  // ==========================================================================

  Future<void> _cargarRespuestasExistentes(
    String respuestaEncuestaId,
    List<Map<String, dynamic>> preguntas,
  ) async {
    final respuestas = await _supabase.from('respuestas').select('''
          id,
          id_pregunta,
          respuesta_texto,
          id_opcion,
          respuestas_opciones (
            id_opcion
          )
        ''').eq(
      'id_respuesta_encuesta',
      respuestaEncuestaId,
    );

    for (final respuesta in List<Map<String, dynamic>>.from(respuestas)) {
      final preguntaId = respuesta['id_pregunta']?.toString();

      if (preguntaId == null) {
        continue;
      }

      final pregunta = preguntas.firstWhere(
        (p) => p['id'].toString() == preguntaId,
        orElse: () => <String, dynamic>{},
      );

      if (pregunta.isEmpty) {
        continue;
      }

      final tipo = pregunta['tipo']?.toString();

      // ----------------------------------------------------------------------
      // TEXTO / TEXTAREA / NUMERO
      // ----------------------------------------------------------------------

      if (_esTexto(tipo)) {
        final texto = respuesta['respuesta_texto']?.toString() ?? '';

        final controller = _textControllers[preguntaId];

        if (controller != null) {
          controller.text = texto;
        }
      }

      // ----------------------------------------------------------------------
      // RADIO / SELECT
      // ----------------------------------------------------------------------

      if (tipo == 'RADIO' || tipo == 'SELECT') {
        _selectedOptions[preguntaId] = respuesta['id_opcion']?.toString();
      }

      // ----------------------------------------------------------------------
      // CHECKBOX
      // ----------------------------------------------------------------------

      if (tipo == 'CHECKBOX') {
        final opciones = respuesta['respuestas_opciones'];

        if (opciones is List) {
          _selectedMultipleOptions[preguntaId] = opciones
              .map(
                (item) => item['id_opcion'].toString(),
              )
              .toSet();
        }
      }

      // ----------------------------------------------------------------------
      // ESCALA
      // ----------------------------------------------------------------------

      if (tipo == 'ESCALA') {
        final numero = int.tryParse(
          respuesta['respuesta_texto']?.toString() ?? '',
        );

        if (numero != null) {
          _scaleValues[preguntaId] = numero;
        }
      }

      // ----------------------------------------------------------------------
      // FECHA
      // ----------------------------------------------------------------------

      if (tipo == 'FECHA') {
        final fecha = DateTime.tryParse(
          respuesta['respuesta_texto']?.toString() ?? '',
        );

        _dateValues[preguntaId] = fecha;
      }
    }
  }

  // ==========================================================================
  // OBTENER / CREAR RESPUESTA DE ENCUESTA
  // ==========================================================================

  Future<String> _obtenerRespuestaEncuesta() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'No hay un usuario autenticado.',
      );
    }

    // ------------------------------------------------------------------------
    // SI YA TENEMOS ID
    // ------------------------------------------------------------------------

    if (_respuestaEncuestaId != null) {
      return _respuestaEncuestaId!;
    }

    // ------------------------------------------------------------------------
    // COMPROBAR QUE REALMENTE ES GRADUADO
    // ------------------------------------------------------------------------

    final graduado = await _supabase
        .from('graduados')
        .select('id')
        .eq(
          'id',
          user.id,
        )
        .maybeSingle();

    if (graduado == null) {
      throw Exception(
        'Tu usuario no tiene un registro válido como graduado.',
      );
    }

    // ------------------------------------------------------------------------
    // COMPROBAR NUEVAMENTE SI YA EXISTE
    // ------------------------------------------------------------------------

    final existente = await _supabase
        .from('respuestas_encuesta')
        .select('id, estado')
        .eq(
          'id_encuesta',
          widget.encuestaId,
        )
        .eq(
          'id_graduado',
          user.id,
        )
        .maybeSingle();

    if (existente != null) {
      final id = existente['id']?.toString();

      final estado = existente['estado']?.toString();

      if (estado == 'COMPLETADA') {
        throw Exception(
          'Ya completaste esta encuesta.',
        );
      }

      if (id != null) {
        _respuestaEncuestaId = id;
        return id;
      }
    }

    // ------------------------------------------------------------------------
    // CREAR BORRADOR
    // ------------------------------------------------------------------------

    debugPrint(
      'CREANDO RESPUESTA_ENCUESTA',
    );

    debugPrint(
      'id_encuesta: ${widget.encuestaId}',
    );

    debugPrint(
      'id_graduado: ${user.id}',
    );

    final respuesta = await _supabase
        .from('respuestas_encuesta')
        .insert({
          'id_encuesta': widget.encuestaId,
          'id_graduado': user.id,
          'estado': 'BORRADOR',
        })
        .select('id, estado')
        .single();

    final id = respuesta['id']?.toString();

    if (id == null) {
      throw Exception(
        'Supabase no devolvió el ID de la respuesta.',
      );
    }

    _respuestaEncuestaId = id;

    debugPrint(
      'RESPUESTA CREADA: $id',
    );

    return id;
  }

  // ==========================================================================
  // VALIDAR FORMULARIO
  // ==========================================================================

  bool _validarFormulario() {
    _errors.clear();

    for (final pregunta in _preguntas) {
      final id = pregunta['id'].toString();

      final obligatoria = pregunta['obligatoria'] == true;

      if (!obligatoria) {
        continue;
      }

      final tipo = pregunta['tipo']?.toString();

      bool respondida = true;

      if (_esTexto(tipo)) {
        final texto = _textControllers[id]?.text.trim() ?? '';

        respondida = texto.isNotEmpty;
      } else if (tipo == 'RADIO' || tipo == 'SELECT') {
        respondida = _selectedOptions[id] != null;
      } else if (tipo == 'CHECKBOX') {
        respondida = _selectedMultipleOptions[id]?.isNotEmpty ?? false;
      } else if (tipo == 'ESCALA') {
        respondida = _scaleValues[id] != null;
      } else if (tipo == 'FECHA') {
        respondida = _dateValues[id] != null;
      }

      if (!respondida) {
        _errors[id] = 'Esta pregunta es obligatoria.';
      }
    }

    setState(() {});

    return _errors.isEmpty;
  }

  // ==========================================================================
  // ENVIAR ENCUESTA
  // ==========================================================================

  Future<void> _enviarEncuesta() async {
    if (_guardando) {
      return;
    }

    if (_yaCompletada) {
      _mostrarMensaje(
        'Esta encuesta ya fue completada.',
        esError: true,
      );
      return;
    }

    FocusScope.of(context).unfocus();

    if (!_validarFormulario()) {
      _mostrarMensaje(
        'Completa las preguntas obligatorias.',
        esError: true,
      );
      return;
    }

    final confirmar = await _mostrarConfirmacion();

    if (confirmar != true) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _guardando = true;
    });

    try {
      // ----------------------------------------------------------------------
      // OBTENER O CREAR ENCUESTA DE RESPUESTA
      // ----------------------------------------------------------------------

      final respuestaEncuestaId = await _obtenerRespuestaEncuesta();

      // ----------------------------------------------------------------------
      // GUARDAR RESPUESTAS
      // ----------------------------------------------------------------------

      for (final pregunta in _preguntas) {
        await _guardarRespuesta(
          respuestaEncuestaId,
          pregunta,
        );
      }

      // ----------------------------------------------------------------------
      // COMPLETAR ENCUESTA
      // ----------------------------------------------------------------------

      debugPrint(
        'MARCANDO RESPUESTA COMO COMPLETADA: '
        '$respuestaEncuestaId',
      );

      await _supabase.from('respuestas_encuesta').update({
        'estado': 'COMPLETADA',
        'fecha_respuesta': DateTime.now().toIso8601String(),
      }).eq(
        'id',
        respuestaEncuestaId,
      );

      _yaCompletada = true;

      if (!mounted) return;

      _mostrarMensaje(
        'Encuesta enviada correctamente.',
      );

      await Future.delayed(
        const Duration(
          milliseconds: 700,
        ),
      );

      if (mounted) {
        Navigator.pop(
          context,
          true,
        );
      }
    } catch (e, stackTrace) {
      debugPrint(
        '==========================================',
      );

      debugPrint(
        'ERROR AL ENVIAR ENCUESTA',
      );

      debugPrint(
        e.toString(),
      );

      debugPrint(
        stackTrace.toString(),
      );

      debugPrint(
        '==========================================',
      );

      if (mounted) {
        _mostrarMensaje(
          e.toString().replaceFirst(
                'Exception: ',
                '',
              ),
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
  // GUARDAR RESPUESTA
  // ==========================================================================

  Future<void> _guardarRespuesta(
    String respuestaEncuestaId,
    Map<String, dynamic> pregunta,
  ) async {
    final preguntaId = pregunta['id'].toString();

    final tipo = pregunta['tipo']?.toString();

    String? respuestaTexto;
    String? idOpcion;

    // ------------------------------------------------------------------------
    // TEXTO
    // ------------------------------------------------------------------------

    if (_esTexto(tipo)) {
      final texto = _textControllers[preguntaId]?.text.trim() ?? '';

      respuestaTexto = texto.isEmpty ? null : texto;
    }

    // ------------------------------------------------------------------------
    // RADIO / SELECT
    // ------------------------------------------------------------------------

    if (tipo == 'RADIO' || tipo == 'SELECT') {
      idOpcion = _selectedOptions[preguntaId];
    }

    // ------------------------------------------------------------------------
    // ESCALA
    // ------------------------------------------------------------------------

    if (tipo == 'ESCALA') {
      final valor = _scaleValues[preguntaId];

      respuestaTexto = valor?.toString();
    }

    // ------------------------------------------------------------------------
    // FECHA
    // ------------------------------------------------------------------------

    if (tipo == 'FECHA') {
      final fecha = _dateValues[preguntaId];

      if (fecha != null) {
        respuestaTexto = '${fecha.year.toString().padLeft(4, '0')}-'
            '${fecha.month.toString().padLeft(2, '0')}-'
            '${fecha.day.toString().padLeft(2, '0')}';
      }
    }

    // ------------------------------------------------------------------------
    // BUSCAR RESPUESTA EXISTENTE
    // ------------------------------------------------------------------------

    final existente = await _supabase
        .from('respuestas')
        .select('id')
        .eq(
          'id_respuesta_encuesta',
          respuestaEncuestaId,
        )
        .eq(
          'id_pregunta',
          preguntaId,
        )
        .maybeSingle();

    String respuestaId;

    // ------------------------------------------------------------------------
    // INSERTAR
    // ------------------------------------------------------------------------

    if (existente == null) {
      final nueva = await _supabase
          .from('respuestas')
          .insert({
            'id_respuesta_encuesta': respuestaEncuestaId,
            'id_pregunta': preguntaId,
            'respuesta_texto': respuestaTexto,
            'id_opcion': idOpcion,
          })
          .select('id')
          .single();

      respuestaId = nueva['id'].toString();
    }

    // ------------------------------------------------------------------------
    // ACTUALIZAR
    // ------------------------------------------------------------------------

    else {
      respuestaId = existente['id'].toString();

      await _supabase.from('respuestas').update({
        'respuesta_texto': respuestaTexto,
        'id_opcion': idOpcion,
      }).eq(
        'id',
        respuestaId,
      );
    }

    // ------------------------------------------------------------------------
    // CHECKBOX
    // ------------------------------------------------------------------------

    if (tipo == 'CHECKBOX') {
      await _supabase.from('respuestas_opciones').delete().eq(
            'id_respuesta',
            respuestaId,
          );

      final seleccionadas = _selectedMultipleOptions[preguntaId] ?? <String>{};

      if (seleccionadas.isNotEmpty) {
        final registros = seleccionadas.map(
          (opcionId) {
            return {
              'id_respuesta': respuestaId,
              'id_opcion': opcionId,
            };
          },
        ).toList();

        await _supabase.from('respuestas_opciones').insert(registros);
      }
    }
  }

  // ==========================================================================
  // CONFIRMACIÓN
  // ==========================================================================

  Future<bool?> _mostrarConfirmacion() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Enviar encuesta',
          ),
          content: const Text(
            'Una vez enviada, no podrás modificar tus respuestas. ¿Deseas continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text(
                'Cancelar',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text(
                'Enviar',
              ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================================
  // SELECCIONAR FECHA
  // ==========================================================================

  Future<void> _seleccionarFecha(
    String preguntaId,
  ) async {
    if (_yaCompletada) {
      return;
    }

    final fecha = await showDatePicker(
      context: context,
      initialDate: _dateValues[preguntaId] ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (fecha == null) {
      return;
    }

    setState(() {
      _dateValues[preguntaId] = fecha;

      _errors.remove(
        preguntaId,
      );
    });
  }

  // ==========================================================================
  // UTILIDADES
  // ==========================================================================

  bool _esTexto(String? tipo) {
    return tipo == 'TEXTO' || tipo == 'TEXTAREA' || tipo == 'NUMERO';
  }

  int? _numero(dynamic valor) {
    if (valor == null) {
      return null;
    }

    if (valor is int) {
      return valor;
    }

    return int.tryParse(
      valor.toString(),
    );
  }

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

  List<Map<String, dynamic>> _convertirOpciones(
    dynamic opciones,
  ) {
    if (opciones is! List) {
      return [];
    }

    final lista = List<Map<String, dynamic>>.from(
      opciones.map(
        (opcion) => Map<String, dynamic>.from(
          opcion,
        ),
      ),
    );

    lista.sort(
      (a, b) {
        final ordenA = _numero(a['orden']) ?? 0;

        final ordenB = _numero(b['orden']) ?? 0;

        return ordenA.compareTo(
          ordenB,
        );
      },
    );

    return lista;
  }

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
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _encuesta?['titulo']?.toString() ?? 'Responder encuesta',
        ),
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _construirContenido(),
    );
  }

  Widget _construirContenido() {
    if (_encuesta == null) {
      return const Center(
        child: Text(
          'No se encontró la encuesta.',
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(
              20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _encuesta!['titulo']?.toString() ?? 'Encuesta',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(
                  height: 8,
                ),
                if (_encuesta!['descripcion'] != null &&
                    _encuesta!['descripcion'].toString().isNotEmpty)
                  Text(
                    _encuesta!['descripcion'].toString(),
                  ),
                const SizedBox(
                  height: 10,
                ),
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
                      'Inicio: ${_formatearFecha(_encuesta!['fecha_inicio'])}',
                    ),
                  ],
                ),
                const SizedBox(
                  height: 4,
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.event_outlined,
                      size: 16,
                    ),
                    const SizedBox(
                      width: 6,
                    ),
                    Text(
                      'Fin: ${_formatearFecha(_encuesta!['fecha_fin'])}',
                    ),
                  ],
                ),
                if (_yaCompletada) ...[
                  const SizedBox(
                    height: 16,
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(
                      14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(
                        0.1,
                      ),
                      borderRadius: BorderRadius.circular(
                        10,
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                        SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: Text(
                            'Esta encuesta ya fue completada.',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(
                  height: 24,
                ),
                ...List.generate(
                  _preguntas.length,
                  (index) {
                    return _construirPregunta(
                      _preguntas[index],
                      index + 1,
                    );
                  },
                ),
                const SizedBox(
                  height: 20,
                ),
              ],
            ),
          ),
        ),
        if (!_yaCompletada)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                10,
                20,
                12,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _guardando ? null : _enviarEncuesta,
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
                          Icons.send_outlined,
                        ),
                  label: Text(
                    _guardando ? 'Enviando...' : 'Enviar encuesta',
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ==========================================================================
  // CONSTRUIR PREGUNTA
  // ==========================================================================

  Widget _construirPregunta(
    Map<String, dynamic> pregunta,
    int numero,
  ) {
    final id = pregunta['id'].toString();

    final texto = pregunta['pregunta']?.toString() ?? '';

    final tipo = pregunta['tipo']?.toString();

    final obligatoria = pregunta['obligatoria'] == true;

    final opciones = pregunta['opciones_pregunta'];

    final error = _errors[id];

    return Card(
      margin: const EdgeInsets.only(
        bottom: 16,
      ),
      child: Padding(
        padding: const EdgeInsets.all(
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(
                          0.1,
                        ),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$numero',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: Text(
                    texto + (obligatoria ? ' *' : ''),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 16,
            ),
            _construirCampo(
              pregunta,
              tipo,
              opciones,
            ),
            if (error != null) ...[
              const SizedBox(
                height: 8,
              ),
              Text(
                error,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // CONSTRUIR CAMPO
  // ==========================================================================

  Widget _construirCampo(
    Map<String, dynamic> pregunta,
    String? tipo,
    dynamic opciones,
  ) {
    final id = pregunta['id'].toString();

    final deshabilitado = _yaCompletada || _guardando;

    // ------------------------------------------------------------------------
    // TEXTO
    // ------------------------------------------------------------------------

    if (tipo == 'TEXTO') {
      return TextField(
        enabled: !deshabilitado,
        controller: _textControllers[id],
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          hintText: 'Escribe tu respuesta',
        ),
        onChanged: (_) {
          if (_errors.containsKey(id)) {
            setState(() {
              _errors.remove(id);
            });
          }
        },
      );
    }

    // ------------------------------------------------------------------------
    // TEXTAREA
    // ------------------------------------------------------------------------

    if (tipo == 'TEXTAREA') {
      return TextField(
        enabled: !deshabilitado,
        controller: _textControllers[id],
        minLines: 4,
        maxLines: 8,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          hintText: 'Escribe tu respuesta',
        ),
        onChanged: (_) {
          if (_errors.containsKey(id)) {
            setState(() {
              _errors.remove(id);
            });
          }
        },
      );
    }

    // ------------------------------------------------------------------------
    // NUMERO
    // ------------------------------------------------------------------------

    if (tipo == 'NUMERO') {
      return TextField(
        enabled: !deshabilitado,
        controller: _textControllers[id],
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          hintText: 'Ingresa un número',
        ),
        onChanged: (_) {
          if (_errors.containsKey(id)) {
            setState(() {
              _errors.remove(id);
            });
          }
        },
      );
    }

    // ------------------------------------------------------------------------
    // RADIO
    // ------------------------------------------------------------------------

    if (tipo == 'RADIO') {
      return Column(
        children: _convertirOpciones(
          opciones,
        ).map(
          (opcion) {
            final opcionId = opcion['id'].toString();

            return RadioListTile<String>(
              value: opcionId,
              groupValue: _selectedOptions[id],
              title: Text(
                opcion['opcion']?.toString() ?? '',
              ),
              contentPadding: EdgeInsets.zero,
              onChanged: deshabilitado
                  ? null
                  : (value) {
                      setState(() {
                        _selectedOptions[id] = value;

                        _errors.remove(
                          id,
                        );
                      });
                    },
            );
          },
        ).toList(),
      );
    }

    // ------------------------------------------------------------------------
    // SELECT
    // ------------------------------------------------------------------------

    if (tipo == 'SELECT') {
      final lista = _convertirOpciones(
        opciones,
      );

      return DropdownButtonFormField<String>(
        value: _selectedOptions[id],
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Selecciona una opción',
        ),
        items: lista.map(
          (opcion) {
            return DropdownMenuItem<String>(
              value: opcion['id'].toString(),
              child: Text(
                opcion['opcion']?.toString() ?? '',
              ),
            );
          },
        ).toList(),
        onChanged: deshabilitado
            ? null
            : (value) {
                setState(() {
                  _selectedOptions[id] = value;

                  _errors.remove(
                    id,
                  );
                });
              },
      );
    }

    // ------------------------------------------------------------------------
    // CHECKBOX
    // ------------------------------------------------------------------------

    if (tipo == 'CHECKBOX') {
      final seleccionadas = _selectedMultipleOptions[id] ?? <String>{};

      return Column(
        children: _convertirOpciones(
          opciones,
        ).map(
          (opcion) {
            final opcionId = opcion['id'].toString();

            final seleccionada = seleccionadas.contains(
              opcionId,
            );

            return CheckboxListTile(
              value: seleccionada,
              contentPadding: EdgeInsets.zero,
              title: Text(
                opcion['opcion']?.toString() ?? '',
              ),
              onChanged: deshabilitado
                  ? null
                  : (value) {
                      setState(() {
                        final set = _selectedMultipleOptions[id] ?? <String>{};

                        if (value == true) {
                          set.add(
                            opcionId,
                          );
                        } else {
                          set.remove(
                            opcionId,
                          );
                        }

                        _selectedMultipleOptions[id] = set;

                        if (set.isNotEmpty) {
                          _errors.remove(
                            id,
                          );
                        }
                      });
                    },
            );
          },
        ).toList(),
      );
    }

    // ------------------------------------------------------------------------
    // ESCALA
    // ------------------------------------------------------------------------

    if (tipo == 'ESCALA') {
      final minimo = _numero(
            pregunta['valor_minimo'],
          ) ??
          1;

      final maximo = _numero(
            pregunta['valor_maximo'],
          ) ??
          5;

      final valor = _scaleValues[id] ?? minimo;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                pregunta['etiqueta_minimo']?.toString() ?? '$minimo',
              ),
              Text(
                pregunta['etiqueta_maximo']?.toString() ?? '$maximo',
              ),
            ],
          ),
          Slider(
            value: valor.toDouble(),
            min: minimo.toDouble(),
            max: maximo.toDouble(),
            divisions: maximo - minimo,
            label: valor.toString(),
            onChanged: deshabilitado
                ? null
                : (nuevoValor) {
                    setState(() {
                      _scaleValues[id] = nuevoValor.round();

                      _errors.remove(
                        id,
                      );
                    });
                  },
          ),
          Center(
            child: Text(
              'Valor seleccionado: $valor',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }

    // ------------------------------------------------------------------------
    // FECHA
    // ------------------------------------------------------------------------

    if (tipo == 'FECHA') {
      final fecha = _dateValues[id];

      return OutlinedButton.icon(
        onPressed: deshabilitado
            ? null
            : () => _seleccionarFecha(
                  id,
                ),
        icon: const Icon(
          Icons.calendar_today_outlined,
        ),
        label: Text(
          fecha == null
              ? 'Seleccionar fecha'
              : _formatearFecha(
                  fecha.toIso8601String(),
                ),
        ),
      );
    }

    return Text(
      'Tipo de pregunta no soportado: $tipo',
      style: const TextStyle(
        color: Colors.red,
      ),
    );
  }
}
