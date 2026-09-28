import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboardService {
  AdminDashboardService(this._client);
  final SupabaseClient _client;

  Future<Map<String, dynamic>> load() async {
    final result = await _client.rpc('obtener_estadisticas_dashboard_admin');
    if (result is! Map) {
      throw const FormatException('Respuesta inválida del dashboard.');
    }
    return Map<String, dynamic>.from(result);
  }
}
