import 'package:supabase_flutter/supabase_flutter.dart';

class RoleService {
  RoleService(this._client);
  final SupabaseClient _client;

  Future<String> currentRole() async {
    if (_client.auth.currentSession == null) {
      throw StateError('La sesión expiró. Inicia sesión nuevamente.');
    }
    final result = await _client.rpc('obtener_rol_usuario');
    final role = result?.toString().trim().toUpperCase() ?? '';
    if (!{'SUPER_ADMIN', 'ADMINISTRADOR', 'GRADUADO'}.contains(role)) {
      throw StateError('No se encontró un rol válido para esta cuenta.');
    }
    return role;
  }

  bool isAdmin(String role) => role == 'SUPER_ADMIN' || role == 'ADMINISTRADOR';
}
