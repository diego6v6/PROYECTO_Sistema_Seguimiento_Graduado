import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuditoriaScreen extends StatefulWidget {
  const AuditoriaScreen({super.key});

  @override
  State<AuditoriaScreen> createState() => _AuditoriaScreenState();
}

class _AuditoriaScreenState extends State<AuditoriaScreen> {
  final supabase = Supabase.instance.client;

  bool cargando = true;
  String? error;
  List<Map<String, dynamic>> registros = [];

  @override
  void initState() {
    super.initState();
    cargarAuditoria();
  }

  Future<void> cargarAuditoria() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final resultado = await supabase.from('auditoria').select('''
            id,
            id_usuario,
            accion,
            tabla_afectada,
            id_registro,
            descripcion,
            ip,
            fecha,
            perfiles(nombres, apellidos)
          ''').order('fecha', ascending: false).limit(300);

      if (!mounted) return;

      setState(() {
        registros = List<Map<String, dynamic>>.from(resultado);
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
        cargando = false;
      });
    }
  }

  String nombreUsuario(Map<String, dynamic> registro) {
    final perfil = registro['perfiles'];

    if (perfil is Map) {
      final nombre = '${perfil['nombres'] ?? ''} '
              '${perfil['apellidos'] ?? ''}'
          .trim();

      if (nombre.isNotEmpty) return nombre;
    }

    return registro['id_usuario']?.toString() ?? 'Usuario desconocido';
  }

  String fechaLegible(dynamic valor) {
    if (valor == null) return 'Fecha no disponible';

    final fecha = DateTime.tryParse(valor.toString());
    if (fecha == null) return valor.toString();

    final local = fecha.toLocal();

    String dos(int n) => n.toString().padLeft(2, '0');

    return '${dos(local.day)}/${dos(local.month)}/${local.year} '
        '${dos(local.hour)}:${dos(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auditoría del sistema'),
        actions: [
          IconButton(
            onPressed: cargarAuditoria,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar registros',
          ),
        ],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Error al cargar auditoría:\n$error'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: cargarAuditoria,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : registros.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay registros de auditoría.',
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: cargarAuditoria,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        itemCount: registros.length,
                        itemBuilder: (context, index) {
                          final r = registros[index];

                          return Card(
                            child: ExpansionTile(
                              leading: const Icon(
                                Icons.history,
                                color: Colors.indigo,
                              ),
                              title: Text(
                                '${r['accion'] ?? 'Acción desconocida'}',
                              ),
                              subtitle: Text(
                                '${nombreUsuario(r)}\n'
                                '${fechaLegible(r['fecha'])}',
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                16,
                              ),
                              children: [
                                _detalle(
                                  'Tabla afectada',
                                  r['tabla_afectada'],
                                ),
                                _detalle(
                                  'ID del registro',
                                  r['id_registro'],
                                ),
                                _detalle(
                                  'Descripción',
                                  r['descripcion'],
                                ),
                                _detalle('IP', r['ip']),
                                _detalle(
                                  'ID del usuario',
                                  r['id_usuario'],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _detalle(String titulo, dynamic valor) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              '$titulo:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              valor?.toString() ?? 'No disponible',
            ),
          ),
        ],
      ),
    );
  }
}
