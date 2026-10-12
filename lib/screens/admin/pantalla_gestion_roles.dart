import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GestionRolesScreen extends StatefulWidget {
  const GestionRolesScreen({super.key});

  @override
  State<GestionRolesScreen> createState() => _GestionRolesScreenState();
}

class _GestionRolesScreenState extends State<GestionRolesScreen> {
  final supabase = Supabase.instance.client;

  bool cargando = true;
  String? error;
  List<Map<String, dynamic>> usuarios = [];
  List<Map<String, dynamic>> roles = [];

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final resultadoRoles = await supabase
          .from('roles')
          .select('id, nombre, descripcion')
          .order('nombre');

      final resultadoUsuarios = await supabase
          .from('perfiles')
          .select(
            'id, nombres, apellidos, id_rol, roles(nombre)',
          )
          .order('apellidos');

      if (!mounted) return;

      setState(() {
        roles = List<Map<String, dynamic>>.from(
          resultadoRoles,
        );
        usuarios = List<Map<String, dynamic>>.from(
          resultadoUsuarios,
        );
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

  Future<void> cambiarRol(
    Map<String, dynamic> usuario,
  ) async {
    final rolActualId = usuario['id_rol'];
    final idUsuario = usuario['id'];

    final nuevoRolId = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        int? seleccionado =
            rolActualId is int ? rolActualId : int.tryParse('$rolActualId');

        return StatefulBuilder(
          builder: (context, actualizarDialogo) {
            return AlertDialog(
              title: const Text('Cambiar rol'),
              content: DropdownButtonFormField<int>(
                value: seleccionado,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Selecciona el nuevo rol',
                  border: OutlineInputBorder(),
                ),
                items: roles.map((rol) {
                  final id = rol['id'] as int;
                  return DropdownMenuItem<int>(
                    value: id,
                    child: Text('${rol['nombre']}'),
                  );
                }).toList(),
                onChanged: (valor) {
                  actualizarDialogo(() {
                    seleccionado = valor;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    if (seleccionado != null) {
                      Navigator.pop(
                        dialogContext,
                        seleccionado,
                      );
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (nuevoRolId == null || nuevoRolId == rolActualId) {
      return;
    }

    try {
      await supabase.rpc(
        'administrar_rol_usuario',
        params: {
          'p_usuario_id': idUsuario,
          'p_rol_id': nuevoRolId,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rol actualizado correctamente.'),
        ),
      );

      await cargarDatos();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cambiar el rol: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de roles'),
        actions: [
          IconButton(
            onPressed: cargarDatos,
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
                        Text(error!),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: cargarDatos,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : usuarios.isEmpty
                  ? const Center(
                      child: Text('No hay usuarios registrados.'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: usuarios.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final usuario = usuarios[index];
                        final rol = usuario['roles'];

                        final nombreRol = rol is Map
                            ? '${rol['nombre'] ?? 'Sin rol'}'
                            : 'Sin rol';

                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.person_outline),
                            ),
                            title: Text(
                              '${usuario['nombres']} '
                              '${usuario['apellidos']}',
                            ),
                            subtitle: Text(
                              'Rol actual: $nombreRol',
                            ),
                            trailing: IconButton(
                              tooltip: 'Cambiar rol',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => cambiarRol(usuario),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
