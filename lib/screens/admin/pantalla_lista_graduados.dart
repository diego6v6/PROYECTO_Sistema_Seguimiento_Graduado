import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ListaGraduadosScreen extends StatefulWidget {
  const ListaGraduadosScreen({super.key});

  @override
  State<ListaGraduadosScreen> createState() => _ListaGraduadosScreenState();
}

class _ListaGraduadosScreenState extends State<ListaGraduadosScreen> {
  final supabase = Supabase.instance.client;

  bool cargando = true;
  String? error;
  List<Map<String, dynamic>> graduados = [];
  String busqueda = '';

  @override
  void initState() {
    super.initState();
    cargarGraduados();
  }

  Future<void> cargarGraduados() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final resultado = await supabase.from('graduados').select('''
            id,
            ci,
            año_ingreso,
            año_egreso,
            año_titulacion,
            modalidad_titulacion,
            ciudad,
            departamento,
            perfiles!inner(
              nombres,
              apellidos,
              telefono,
              estado
            )
          ''').order('año_egreso', ascending: false);

      if (!mounted) return;

      setState(() {
        graduados = List<Map<String, dynamic>>.from(resultado);
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

  @override
  Widget build(BuildContext context) {
    final filtrados = graduados.where((g) {
      final perfil = g['perfiles'] as Map<String, dynamic>;

      final nombre = '${perfil['nombres'] ?? ''} ${perfil['apellidos'] ?? ''}'
          .toLowerCase();

      final ci = '${g['ci'] ?? ''}'.toLowerCase();
      final texto = busqueda.trim().toLowerCase();

      return nombre.contains(texto) || ci.contains(texto);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de graduados'),
        actions: [
          IconButton(
            onPressed: cargarGraduados,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
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
                        Text('Error al cargar graduados:\n$error'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: cargarGraduados,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Buscar por nombre o CI',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (valor) {
                          setState(() {
                            busqueda = valor;
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Graduados encontrados: ${filtrados.length}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtrados.isEmpty
                          ? const Center(
                              child: Text(
                                'No se encontraron graduados.',
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: filtrados.length,
                              itemBuilder: (context, index) {
                                final g = filtrados[index];
                                final p = g['perfiles'] as Map<String, dynamic>;

                                final nombre = '${p['nombres'] ?? ''} '
                                    '${p['apellidos'] ?? ''}';

                                return Card(
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      child: Icon(Icons.school_outlined),
                                    ),
                                    title: Text(nombre.trim()),
                                    subtitle: Text(
                                      'CI: ${g['ci'] ?? 'No registrado'}\n'
                                      'Egreso: ${g['año_egreso'] ?? 'Sin dato'}\n'
                                      'Departamento: ${g['departamento'] ?? 'Sin dato'}\n'
                                      'Teléfono: ${p['telefono'] ?? 'Sin dato'}',
                                    ),
                                    isThreeLine: true,
                                    trailing: Icon(
                                      p['estado'] == true
                                          ? Icons.check_circle_outline
                                          : Icons.block_outlined,
                                      color: p['estado'] == true
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
