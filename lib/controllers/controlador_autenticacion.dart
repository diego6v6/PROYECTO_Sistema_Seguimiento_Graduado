import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthController extends ChangeNotifier {
  AuthController();

  final SupabaseClient _supabase = Supabase.instance.client;

  String? _rol;
  bool _cargando = true;

  String? get rol => _rol;
  bool get cargando => _cargando;

  bool get esSuperAdmin => _rol == 'SUPER_ADMIN';

  bool get esAdministrador => _rol == 'ADMINISTRADOR' || _rol == 'SUPER_ADMIN';

  Future<void> cargarRol() async {
    _cargando = true;
    notifyListeners();

    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        _rol = null;
        return;
      }

      final resultado = await _supabase.rpc(
        'obtener_rol_usuario',
      );

      _rol = resultado?.toString();
    } catch (e) {
      debugPrint(
        'Error al obtener rol: $e',
      );

      _rol = null;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> cerrarSesion() async {
    await _supabase.auth.signOut();

    _rol = null;

    notifyListeners();
  }
}
