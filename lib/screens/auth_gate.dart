import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/role_service.dart';
import 'admin/admin_dashboard_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.dashboardRoute = false});
  final bool dashboardRoute;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final SupabaseClient _client;
  late final RoleService _roles;
  late final bool _dashboardRoute;
  bool _loading = true;
  String? _role;
  String? _error;
  late final StreamSubscription<AuthState> _subscription;

  @override
  void initState() {
    super.initState();
    _client = Supabase.instance.client;
    _roles = RoleService(_client);
    _dashboardRoute = widget.dashboardRoute;
    _subscription = _client.auth.onAuthStateChange.listen((_) => _resolve());
    _resolve();
  }

  Future<void> _resolve() async {
    if (!mounted) return;
    if (_client.auth.currentSession == null) {
      setState(() {
        _role = null;
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final role = await _roles.currentRole();
      if (mounted) {
        setState(() {
          _role = role;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Bad state: ', '');
          _role = null;
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_client.auth.currentSession == null) return const LoginScreen();
    if (_error != null) {
      return _AccessMessage(
          message: _error!, onExit: () => _client.auth.signOut());
    }
    final role = _role!;
    if (!kIsWeb) return const HomeScreen();
    if (_dashboardRoute && !_roles.isAdmin(role)) {
      return _AccessMessage(
          message: 'Tu cuenta no tiene acceso al área administrativa.',
          onExit: () =>
              Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false));
    }
    if (_roles.isAdmin(role)) return const AdminDashboardScreen();
    return const HomeScreen();
  }
}

class _AccessMessage extends StatelessWidget {
  const _AccessMessage({required this.message, required this.onExit});
  final String message;
  final VoidCallback onExit;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.lock_outline, size: 52),
                  const SizedBox(height: 16),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: onExit, child: const Text('Volver')),
                ]))),
      );
}
